# 子弹射击与准星实现复盘（含跨项目复用经验）

> 适用项目：DreamerHeroines
> 引擎：Godot 4.6.1
> 最后更新：2026-04-09

---

## 1. 这套实现解决了什么问题

当前项目现在把“射击 + 伤害结算”拆成了四层：

1. **武器只负责战斗节奏与发射决策**：射速、换弹、部署、散布、弹药。
2. **投射物生成由全局 Spawner 统一管理**：负责对象池、实例激活、参数灌入。
3. **投射物负责飞行、命中、回收，但不再直接决定如何扣血**。
4. **伤害统一经过 `DamageData + DamageSystem + Hurtbox + HealthComponent`**：把伤害数据、命中入口、生命值状态源拆开。

准星则拆成了另一条三层链路：

1. **`CrosshairSettings`** 定义可持久化 schema 和默认值。
2. **`CrosshairSettingsService`** 负责校验、存储、广播配置变更。
3. **`CrosshairUI`** 只做绘制与视觉状态，不直接依赖设置面板或存档格式。

这两个系统之间通过 HUD 和玩家层做“薄转发”，所以耦合点相对清晰，适合在其他项目中裁剪复用。

---

## 2. 当前子弹射击链路

### 2.1 核心文件

| 文件 | 职责 |
|---|---|
| `src/weapons/weapon.gd` | 通用武器组件；管理射击窗口、换弹、部署、弹药、视觉扩散，并通过 `shot_fired` 发射开火事件 |
| `src/weapons/shotgun_weapon.gd` | 在通用武器之上扩展多弹丸发射 |
| `src/autoload/projectile_spawner.gd` | 投射物对象池与统一生成入口 |
| `src/weapons/projectile.gd` | 投射物飞行、碰撞、伤害、回收 |
| `src/characters/player.gd` | 输入采样、瞄准、把武器信号转接给 HUD/Spawner |
| `src/enemies/enemy_base.gd` | 敌人武器接入，同样走 `shot_fired -> ProjectileSpawner` |
| `src/utils/damage_data.gd` | 标准伤害数据载体，统一 amount / knockback / source / causer |
| `src/utils/damage_system.gd` | 标准伤害分发入口，优先解析真实 `Hurtbox` |
| `src/utils/hurtbox.gd` | 统一受击入口，负责伤害倍率、无敌帧和转发 |
| `src/utils/health_component.gd` | 统一生命值状态源 |
| `src/weapons/weapon_stats.gd` | 武器静态数据资源 |
| `config/weapon_stats.json` | 武器数值来源 |

### 2.2 实际调用链

```text
Player/Enemy 输入或 AI
    -> Weapon.try_shoot(muzzle_pos, aim_dir)
    -> Weapon._fire(...)
    -> shot_fired.emit(position, direction, faction)
    -> Player/Enemy 监听 shot_fired
    -> ProjectileSpawner.spawn_projectile(...)
    -> Projectile.fire()
    -> Projectile._physics_process() 飞行
    -> Projectile 命中后构造 DamageData
    -> DamageSystem.apply_damage(target, damage_data)
    -> Hurtbox.apply_damage(...)
    -> HealthComponent.apply_damage(...)
    -> Player/Enemy 通过信号同步 current_health / 状态反馈
    -> Projectile 命中/超时/出屏
    -> Projectile._recycle_to_pool()
    -> ProjectileSpawner.return_to_pool()
```

### 2.3 这套射击实现最值得复用的点

#### A. 武器只发“射击意图”，不直接实例化子弹

`Weapon` 不知道子弹场景挂在哪里，也不负责 `instantiate()`。它只在 `_fire()` 里：

- 扣弹
- 计算射速窗口
- 计算散布后的方向
- 发出 `shot_fired(position, direction, faction)`
- 播放枪口火焰、弹壳、音效

这让 `Weapon` 可以被：

- 玩家复用
- 敌人复用
- 测试直接单测
- 替换成射线武器/激光武器时保留相同接口

这是最值得跨项目照搬的分层。

#### B. 发射物池在 Spawner，不在 Projectile 本身

`ProjectileSpawner` 维护 `_projectile_pools`，并统一负责：

- 预加载场景
- 预热对象池
- 激活前灌入运行时参数
- 池上限控制
- 回收入口统一化

`Projectile` 只关心“自己是否 active、何时回收”。这比“武器持有自己的对象池”更容易全局调试，也更适合不同发射者共用。

#### C. 阵营与碰撞是运行时注入，不写死在场景里

`ProjectileSpawner.spawn_projectile()` 把 `faction_type`、`owner_node`、`damage`、`speed`、`lifetime` 注入 `Projectile`。`Projectile` 再通过 `Faction.get_projectile_collision_mask()` 动态设置 `collision_mask`。

这让同一个投射物场景能同时服务：

- 玩家子弹
- 敌人子弹
- 测试场景里的临时发射物

如果迁移到别的项目，**优先保留“同一发射物 prefab + 运行时注入阵营”**，不要一开始就拆成 `player_bullet.tscn` / `enemy_bullet.tscn` 两套。

#### D. 视觉扩散和真实弹道扩散被有意分开

`weapon.gd` 里有两套概念：

- `stats.spread`：真实弹道散布
- `current_visual_spread`：UI 用的视觉扩散

射击时先按 `stats.spread` 旋转真实方向，再把 `current_visual_spread` 拉高并发 `spread_changed`。这能避免“为了手感去改准星动画，却意外改变命中表现”。

这是非常好的经验：**命中逻辑和反馈逻辑必须分层**。

#### E. 伤害入口必须是“标准数据 + 标准分发”，不要让子弹或敌人各自决定怎么扣血

这次重构之后，`Projectile`、`Hitbox`、敌人近战、玩家受伤都不再把“伤害如何结算”写死在各自逻辑里，而是统一成：

- 先构造 `DamageData`
- 再调用 `DamageSystem.apply_damage(...)`
- 由 `DamageSystem` 优先找到真实 `Hurtbox`
- 再由 `Hurtbox` 转给 `HealthComponent`

这个分层的价值是：

- 生产伤害的对象只负责描述伤害，不负责解释伤害
- 角色是否有无敌、倍率、击退、死亡状态，不再散落在每个攻击者里
- 同一条管线可以同时承接投射物、近战、AOE、以后新增的技能或陷阱

这是本次最重要的复用经验：**统一入口不是“提供一个公共 helper”，而是让真实运行路径优先走同一条管线。**

### 2.4 当前实现的依赖与边界

这套射击/伤害系统并不是完全无依赖，迁移时要识别这些项目特有耦合：

- `Weapon` 直接调用了 `AudioManager`、`LightBudgetManager`
- `Projectile` 依赖 `Faction`、`EffectManager`
- `DamageSystem` 依赖场景里已经接好 `Hurtbox` / `HealthComponent`
- 玩家命中反馈通过 `GameManager.hud` 反向通知准星
- `ProjectileSpawner` 被配置成 autoload（`project.godot`）

所以跨项目复用时，真正可直接抽走的是：

- `Weapon` 的状态机和信号接口思想
- `ProjectileSpawner` 的池化模式
- `Projectile` 的 active/pool 生命周期约定

而下面这些需要做适配层：

- 音频播放
- 特效播放
- 阵营定义
- HUD 通知路径
- 场景节点命名与角色组件装配方式

### 2.5 本次统一伤害管线重构带来的额外经验

#### A. “统一入口”必须落到真实场景接线，不然只是代码层错觉

这次重构里，真正让统一管线生效的关键，不只是新增 `damage_system.gd`，而是把：

- `scenes/player.tscn`
- `scenes/enemies/melee_enemy.tscn`
- `scenes/enemies/flying_enemy.tscn`
- `scenes/enemies/ranged_enemy.tscn`

都接上真实的 `HealthComponent` / `Hurtbox` / `Hitbox` 脚本。

如果只改脚本、不改预制体，项目表面上“支持统一入口”，实际上运行时还会继续走旧路径。这是跨项目复用时最容易犯的错。

#### B. 解析顺序决定“标准入口”是不是真正的标准入口

`DamageSystem` 一开始如果先看根节点 `take_damage/apply_damage`，再看子节点 `Hurtbox`，那么角色根脚本就会永远把真正的受击组件短路掉。

这次重构后改成：

1. 先找 `Hurtbox`
2. 再找 `HealthComponent`
3. 最后才退回根节点兼容方法

这个顺序本身就是经验：**兼容层可以保留，但必须排在标准入口之后。**

#### C. 状态统一不只包含“掉血”，还包括无敌、治疗、复活

第一次重构只把受伤入口统一了，但 Oracle 复核指出：

- `Hurtbox` 的无敌计时器初始化顺序可能导致永久无敌
- `heal()` 没同步 `HealthComponent`
- `respawn()` 没同步 `HealthComponent` 和 `Hurtbox`

这说明统一伤害管线不能只看“第一次命中是否掉血”，还要看：

- 无敌结束后是否能再次受伤
- 补血后根节点与组件血量是否一致
- 复活后状态是否回到统一状态源

这是本次重构里很有价值的经验：**战斗状态源一旦统一，所有反向修改生命值的入口也必须回到同一个状态源。**

#### D. 测试不能只测临时对象，必须至少测一个真实场景

这次最终补的 `tests/unit/test_damage_pipeline.gd` 不只测临时 new 出来的组件，还补了：

- 真实 `player.tscn`
- 真实 `melee_enemy.tscn`
- 玩家无敌结束后二次受击
- 玩家 heal / respawn 后与 `HealthComponent` 同步

如果一个“统一管线”只有纯单元测试，没有真实场景验证，就很容易出现“类设计正确，但预制体没接上”的假完成。

---

## 3. 当前准星链路

### 3.1 核心文件

| 文件 | 职责 |
|---|---|
| `src/data/crosshair_settings.gd` | 准星配置 Resource；定义默认值、别名映射、序列化与兼容持久化键 |
| `src/autoload/crosshair_settings_service.gd` | 准星配置服务层；负责 clamp、变更广播、存盘/读盘 |
| `src/ui/crosshair_ui.gd` | 纯表现层；绘制准星、处理动态扩散、命中反馈、状态色 |
| `src/ui/hud.gd` | 薄转发层；把玩家/武器事件同步给准星 |
| `src/ui/crosshair_settings_panel.gd` | 设置面板；通过 Service 更新配置 |
| `tests/unit/test_crosshair.gd` | 对 schema、service、UI 行为做单测 |
| `scenes/ui/crosshair.tscn` | 准星场景 |

### 3.2 实际调用链

```text
设置面板 / 存档加载
    -> CrosshairSettingsService
    -> settings_changed / settings_loaded
    -> CrosshairUI._apply_settings()

武器状态变化
    -> Player 监听 Weapon 信号
    -> HUD 转发给 CrosshairUI
    -> update_spread / on_reload_start / on_ammo_changed / show_hit_feedback
    -> CrosshairUI 重绘
```

### 3.3 这套准星实现最值得复用的点

#### A. Settings Resource + Service 分层非常适合复用

当前不是让 UI 直接读写 `ConfigFile`，而是：

- `CrosshairSettings` 负责定义合法字段和默认值
- `CrosshairSettingsService` 负责：
  - 参数约束
  - 兼容旧 key
  - 保存/读取
  - 广播 `settings_changed`
- `CrosshairUI` 只是被动应用 settings

这能把“可配置 UI”做成平台能力，而不是耦合在某个设置面板里。这个设计非常适合搬到别的项目。

#### B. HUD 做转发层，比让准星直接找玩家更稳

`HUD` 提供了这些转发方法：

- `update_crosshair_spread()`
- `on_crosshair_reload_started()` / `finished()`
- `on_crosshair_deploy_started()` / `finished()`
- `on_crosshair_ammo_changed()` / `empty()`
- `on_crosshair_confirmed_hit()`

这让 `CrosshairUI` 不需要知道玩家节点路径、武器类型或 AI 结构。跨项目迁移时，只要别的项目也有一个“战斗 HUD 协调层”，准星就能原样接入。

#### C. 命中反馈建立在“确认命中”上，而不是“开火成功”上

玩家层并不是一开枪就让准星闪命中，而是：

1. 给武器或投射物接入命中监听
2. 在 `body_entered` / `area_entered` / `hit_hurtbox` 里解析真正目标
3. 去重同一目标
4. 最后调用 `HUD.on_crosshair_confirmed_hit()`

这意味着准星命中反馈和真实命中结果对齐，不会出现“枪响就误报命中”的假反馈。

这是可复用文档里必须强调的一条经验。

#### D. UI 允许视觉扩散独立恢复，不绑定武器内部帧逻辑

`CrosshairUI.recover(delta)` 每帧恢复视觉扩散，而 `Weapon` 也维护自己的 `current_visual_spread`。当前项目最终以武器上报值为主，HUD 同步到 UI。

这说明作者有一个明确思路：

- 武器负责战斗真实节奏
- 准星负责最终显示节奏

迁移时建议二选一：

1. **保留现在的做法**：武器是视觉扩散真源，准星只显示；
2. **更激进的做法**：完全让准星本地插值，但仍由武器提供 base spread 和状态事件。

如果项目里存在网络同步、回放系统或慢动作，推荐保留“武器上报视觉状态，准星只显示”的模式，避免双源漂移。

### 3.4 当前实现的依赖与边界

准星系统本身依赖比射击系统轻，但仍有几处要注意：

- `CrosshairSettingsService` 当前被做成 autoload
- 启动阶段还依赖 `BootSequence` / `SaveManager` 先把已保存设置应用回来
- `CrosshairUI` 在 `_ready()` 中主动连接 `CrosshairSettingsService`
- `HUD` 默认知道准星节点路径
- 命中反馈默认从玩家层转发到 `GameManager.hud`

所以跨项目复用时，最稳的切法是：

- **保留** `CrosshairSettings` / `CrosshairSettingsService` / `CrosshairUI`
- **适配** `HUD` 中的转发方法
- **重写** 命中确认来源（你的项目可能是 hitscan、Ability、锁定导弹等）

---

## 4. 如果要在其他项目复用，建议按这四层打包

### 4.1 推荐拆分包结构

```text
combat/
├── weapon.gd
├── projectile.gd
├── projectile_spawner.gd
├── weapon_stats.gd
└── faction.gd

ui/crosshair/
├── crosshair_ui.gd
├── crosshair_settings.gd
├── crosshair_settings_service.gd
└── crosshair.tscn
```

### 4.2 最小复用接口

#### 武器侧

建议保留这些对外接口：

- `try_shoot(muzzle_pos, aim_dir) -> bool`
- `reload()`
- `start_deploy()` / `cancel_deploy()`
- `get_muzzle_position()`

建议保留这些信号：

- `shot_fired(position, direction, faction)`
- `ammo_changed(current, max)`
- `reload_started`
- `reload_finished`
- `out_of_ammo`
- `spread_changed(current_spread, base_spread)`

#### 准星侧

建议保留这些入口：

- `update_spread(current_spread, base_spread)`
- `on_reload_start()` / `on_reload_end()`
- `on_deploy_start()` / `on_deploy_end()`
- `on_ammo_changed(current, maximum)`
- `on_ammo_empty()`
- `show_hit_feedback()`

这样别的项目只要提供转发层，就能无痛接入。

---

## 5. 真正可复用的经验

### 经验 1：把“开火”视为事件，而不是实例化动作

一旦武器直接 `instantiate bullet`，它就会被场景树、对象池、阵营、命中特效绑死。把开火建模为 `shot_fired` 事件后，武器立刻变成通用战斗组件。

### 经验 2：视觉反馈永远不要反向污染命中逻辑

当前实现里，视觉扩散和真实弹道散布分开；命中反馈也只在“确认命中”时触发。这两条都说明：**反馈层可以夸张，判定层必须保守。**

### 经验 3：配置 schema 应该独立于 UI 控件

`CrosshairSettings` 不是面板脚本的一部分，而是独立 Resource。这样将来换成手柄设置页、开发者控制台、远程配置同步，都不需要重写准星本体。

### 经验 4：对象池状态要有明确的 active/inactive 协议

当前 `Projectile` 明确暴露：

- `fire()`
- `deactivate_for_pool()`
- `is_available_for_pool()`
- `is_pool_active()`

这比只用 `visible` 或 “是否在树上” 判断生命周期稳得多。跨项目复用时，务必保留这组协议。

### 经验 5：玩家/HUD 适合做跨系统编排层

射击和准星不是直接互相依赖，而是通过 `Player` 和 `HUD` 协调。这种“薄编排层”比让武器直接拿 HUD 引用更容易维护。

### 经验 6：兼容壳可以保留，但必须明确它只是过渡层

本次重构后，`take_damage(...)` 还保留在若干类里，但它已经降级为兼容壳：真正的主路径是 `DamageSystem -> Hurtbox -> HealthComponent`。

这对活跃项目很重要：

- 你可以先统一真实运行路径
- 再逐步清理旧 API 调用
- 不需要在一次提交里推倒所有旧接口

但前提是要保证**兼容壳不会抢走标准入口**。

### 经验 7：Oracle 式复核很适合抓“看起来统一了，其实状态没闭环”的问题

这次重构里最难发现的 bug，不是语法或类型，而是：

- 受击一次后会不会永久无敌
- heal/respawn 会不会绕过统一状态源

这类问题往往不会在第一次实现时自然暴露，所以在做“可复用系统”时，最好主动用一轮偏苛刻的复核视角去问：

> 标准入口是不是主路径？
> 状态是否真正闭环？
> 真实场景是不是默认走这套系统？

---

## 6. 跨项目迁移时的落地建议

### 6.1 可以直接抄走的部分

- `Weapon` 的信号式设计
- `ProjectileSpawner` 的池化模式
- `Projectile` 的 active/pool 生命周期
- `DamageData + DamageSystem + Hurtbox + HealthComponent` 的统一伤害管线
- `CrosshairSettings` 的 schema/别名/持久化键映射
- `CrosshairSettingsService` 的 clamp + 广播模式
- `CrosshairUI` 的状态色、动态扩散、命中反馈绘制模型

### 6.2 一定要改成本项目适配层的部分

- `AudioManager`
- `EffectManager`
- `GameManager.hud`
- `Faction`
- `LightBudgetManager`
- `EnhancedInput`
- `SaveManager` / `BootSequence` 的设置加载链路

### 6.3 建议先做的抽象

如果打算把它沉淀成通用模块，建议先补一个小接口层：

```text
ICombatFeedback
    play_fire_sfx(weapon_id)
    play_hit_effect(position)
    play_impact_effect(position)

IProjectileFactionResolver
    get_collision_mask(faction_type)
    get_target_group(faction_type)
```

这样迁移时只换适配器，不改核心逻辑。

### 6.4 迁移时顺手应修掉的实现债

- 当前仓库虽然已经统一到 `DamageSystem` 主路径，但仍保留了一些 `take_damage()` 兼容壳；如果你在新项目里从零落地，建议从第一天就把外部调用收敛到 `DamageSystem.apply_damage(...)`。
- `Weapon` 里有少量项目内资源路径和全局单例调用，复用前应改成通过配置或接口注入。
- 玩家层里“命中反馈源绑定”逻辑仍偏重，若要长期复用，建议拆成独立组件或 CombatFeedbackBridge。
- 目前 `HealthComponent` 负责生命值，但击退和一些受伤反馈仍在角色脚本里；如果目标项目想做得更彻底，可以继续往“战斗状态组件化”推进。

---

## 7. 对当前实现的判断

这套方案现在已经不只是“有不错的复用基础”，而是已经完成了一轮真实的复用向重构，尤其是下面三点做得比较扎实：

1. **武器通过信号出战斗事件，而不是控制整条发射链。**
2. **伤害通过 `DamageData + DamageSystem + Hurtbox + HealthComponent` 成为统一主路径，而不是散落在 Projectile / Enemy / Player 各处。**
3. **准星通过 Resource + Service + UI 分层，而不是把设置、绘制、存档混在一起。**

如果后续还要继续为“跨项目复用”打磨，我最建议优先做两件事：

1. 把 `AudioManager` / `EffectManager` / `Faction` 之类的项目单例依赖再包一层接口。
2. 把玩家里的“命中反馈源绑定逻辑”和角色里的受伤反馈逻辑继续拆成独立组件，避免它们继续堆在 `player.gd` / `enemy_base.gd` 中膨胀。

这样这套系统就不只是“这个项目里写得还行”，而是真能变成下一项目的成熟模板。
