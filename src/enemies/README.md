# enemies — 敌人AI模块

## 职责

本模块负责游戏中所有敌人的AI行为控制，包括状态管理、移动逻辑、攻击行为和与玩家的交互。通过继承体系实现不同类型敌人的差异化行为。

---

## 文件

| 名称 | 用途 | 备注 |
|------|------|------|
| `enemy_base.gd` | 敌人基类 | 定义通用状态机、属性、信号和基础AI逻辑 |
| `melee_enemy.gd` | 近战敌人 | 冲锋攻击、高击退、快速接近玩家 |
| `flying_enemy.gd` | 飞行敌人 | 悬停移动、俯冲攻击、无视重力 |
| `ranged_enemy.gd` | 远程敌人 | 距离控制、瞄准射击、武器切换 |

---

## 架构设计

### 状态机模式

敌人采用**内嵌枚举状态机**实现，在 `EnemyBase` 中定义：

```
状态流转: IDLE → PATROL ⇄ CHASE → ATTACK → HURT → DEAD
                ↑___________|
```

- **IDLE**: 空闲等待，短暂后进入巡逻
- **PATROL**: 区域巡逻，检测到玩家后切换追踪
- **CHASE**: 追踪玩家，进入攻击范围后攻击
- **ATTACK**: 执行攻击，冷却后返回追踪
- **HURT**: 受击硬直，短暂后恢复追踪
- **DEAD**: 死亡处理，播放动画后销毁

子类通过重写 `_state_*` 方法定制特定状态的逻辑。

### 行为类型

| 类型 | 移动方式 | 攻击方式 | 特殊能力 |
|------|----------|----------|----------|
| **近战** | 地面移动 | 近战打击 | 冲锋加速 |
| **飞行** | 空中悬停 | 俯冲撞击 | 越障飞行 |
| **远程** | 距离维持 | 射击 | 武器切换 |

### 配置与逻辑分离

数值属性通过 `config/enemy_stats.json` 配置，脚本仅负责行为逻辑：

- **配置文件管理**: 生命值、速度、伤害、范围、冷却时间等数值
- **脚本职责**: 状态转换、AI决策、动画触发、特效播放

每个敌人类型实现 `_load_enemy_config()` 从JSON加载属性，支持热调参无需改代码。

### 继承体系

```
CharacterBody2D
    └── EnemyBase          # 通用状态机、检测、伤害处理
            ├── MeleeEnemy   # 重写 _state_chase, _state_attack
            ├── FlyingEnemy  # 重写 _physics_process, 悬停逻辑
            └── RangedEnemy  # 重写 _state_chase, 射击逻辑
```

---

## 依赖关系

- **配置**: `config/enemy_stats.json`
- **工具**: `src/utils/health_component.gd` (间接)
- **场景**: `scenes/enemies/*.tscn`
- **单例**: `GameManager`, `AudioManager`, `ProjectileSpawner`
