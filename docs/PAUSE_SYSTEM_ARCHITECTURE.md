# 暂停系统架构与复用指南

> **项目**: DreamerHeroines
> **引擎**: Godot 4.6.2
> **最后更新**: 2026-04-08
> **适用范围**: 当前项目暂停系统梳理，以及后续项目复用参考

---

## 1. 文档目的

本文档说明 DreamerHeroines 当前暂停系统的真实实现方式，重点回答三个问题：

1. 当前项目的“暂停”到底是怎么工作的
2. 它和 UE5 风格“语义真暂停”相比，哪些语义已经做到，哪些还需要额外约束
3. 如果要复用到其他 Godot 项目，应该抽取哪些模式，而不是只抄一段 `get_tree().paused = true`

这份文档刻意不把“暂停”理解成单一 API，而是把它当成一个**运行时协议**：

- 谁负责切换暂停状态
- 谁在暂停时必须继续活着
- 谁在暂停时必须停止
- 输入、UI、音频、对象池如何协同

---

## 2. 结论先行

DreamerHeroines 当前实现的不是“时间缩放式暂停”，而是更接近 **语义暂停（semantic pause）** 的方案：

- 通过 `GameManager` 统一切换状态
- 通过 `get_tree().paused` 冻结游戏世界主树
- 通过 `process_mode` 精确声明哪些节点在暂停时继续运行
- 通过 `EnhancedInput` 切换到 `UI_ONLY`，阻断玩法输入
- 通过专门的暂停 UI 与暂停安全 Tween 保持菜单可交互

也就是说，这套方案的核心不是“让所有东西都停”，而是：

> **让应该停的世界停下来，让必须继续工作的系统继续工作。**

这正是跨项目最值得复用的经验。

---

## 3. 核心入口与控制流

暂停的主入口在 `src/autoload/game_manager.gd`。

### 3.1 状态切换入口

`GameManager` 把暂停视为正式游戏状态，而不是临时标志位。

关键入口：

- `toggle_pause()`
- `set_paused(paused: bool, restore_playing_state: bool = true)`
- `change_state(GameState.PAUSED)`

相关代码位置：

- `src/autoload/game_manager.gd:162`
- `src/autoload/game_manager.gd:166`
- `src/autoload/game_manager.gd:142-157`

状态切换语义：

- `MENU` → 不暂停世界，输入为 `UI_ONLY`
- `PLAYING` → 不暂停世界，输入为 `GAME_ONLY` 或 `GAME_AND_UI`
- `PAUSED` → 暂停世界，输入为 `UI_ONLY`
- `GAME_OVER / VICTORY` → 也使用暂停世界 + `UI_ONLY`

这意味着项目已经把“暂停”“结算”“菜单”统一为一套运行时状态策略，而不是各写各的。

### 3.2 真正生效的运行时切换

真正决定暂停行为的代码在：

- `src/autoload/game_manager.gd:733-737`

```gdscript
func _apply_runtime_state(paused: bool, input_mode: int) -> void:
	is_game_paused = paused
	get_tree().paused = paused
	_set_current_level_processing(paused)
	_set_input_mode(input_mode)
```

这里实际上做了三件不同层级的事：

1. **状态层**：`is_game_paused = paused`
2. **场景树层**：`get_tree().paused = paused`
3. **系统协同层**：调整关卡 `process_mode` 与输入上下文

这三个层次一起，才构成“语义真暂停”。

---

## 4. 当前项目的暂停语义模型

### 4.1 为什么不能只用 `Engine.time_scale = 0`

项目里虽然存在 `GameConfig.cs` 对 `Engine.TimeScale` 的封装能力，但当前暂停实现**并没有**用时间缩放来驱动暂停。

原因很现实：

- `time_scale = 0` 会一起影响大量依赖时间推进的行为
- UI Tween、过场动画、某些计时器可能也一起停掉
- 你很难表达“世界停了，但暂停菜单动画还要播、菜单输入还要响应”

而 DreamerHeroines 的设计目标恰恰是：

- 游戏世界停住
- 菜单继续工作
- 输入切到 UI
- 某些全局系统继续运转

所以它采用的是 **SceneTree pause + process_mode 白名单 + 输入模式切换** 的组合。

### 4.2 这套方案的真实语义

可以把当前实现理解为：

#### 被暂停的部分

- 当前关卡内容
- 关卡内的敌人、玩家、投射物、物理、动画、常规 gameplay 节点

#### 不被暂停的部分

- 游戏状态控制器
- 输入模式切换器
- 暂停 UI 与相关动画
- 某些全局服务（如对象池管理、音频管理、调试命令）

所以这不是“所有节点都一刀切停止”，而是“世界停止、控制层继续”。

这个思路和 UE5 里“停 gameplay world，但保留 pause menu/controller/navigation shell”的设计哲学是一致的。

---

## 5. process_mode 是这套设计的关键

如果只记一条经验，那就是：

> 在 Godot 里，`get_tree().paused` 只是总开关，真正定义暂停语义的是 `process_mode`。

### 5.1 项目里的三种核心模式

#### A. `PROCESS_MODE_ALWAYS`

表示节点在暂停时仍然继续运行。

当前项目中，这类节点主要是“全局控制层”和“运行时服务层”：

- `GameManager`
- `EnhancedInput`
- `AudioManager`
- `ProjectileSpawner`
- `LevelManager` 的 autoload 实例
- `TooltipHost`
- `RuntimeUI` CanvasLayer
- 若干 GUIDE/调试相关节点

这类节点的共同特点不是“它们重要”，而是：

> **暂停期间还有未完成职责。**

例如：

- `GameManager` 还要响应恢复、重开、退出
- `EnhancedInput` 还要接收菜单输入
- `AudioManager` 可能要处理 UI 音效或音乐暂停/恢复
- `ProjectileSpawner` 仍可能负责清理池或清场残留

#### B. `PROCESS_MODE_PAUSABLE`

表示节点属于 gameplay 世界，暂停时应该停止推进。

当前项目里最典型的是：

- 当前关卡节点（由 `GameManager._set_current_level_processing()` 在暂停时设置）
- 已激活投射物
- 非 autoload 的 level 场景实例

对应代码：

- `src/autoload/game_manager.gd:814-826`
- `src/levels/level_manager.gd:40-42`

```gdscript
if paused:
	(level_node as Node).process_mode = Node.PROCESS_MODE_PAUSABLE
else:
	(level_node as Node).process_mode = Node.PROCESS_MODE_INHERIT
```

这个做法非常重要，因为它避免了“所有东西都靠全局暂停猜行为”，而是显式把当前关卡定义成可冻结子树。

#### C. `PROCESS_MODE_WHEN_PAUSED`

表示节点只在暂停时运行，最适合暂停菜单、结算菜单这种“只有暂停态才活跃”的 UI。

当前项目中的典型例子：

- `PauseMenu`
- 某些结算界面

相关代码：

- `src/ui/pause_menu.gd:77`
- `scenes/ui/pause_menu.tscn:10`

```gdscript
process_mode = Node.PROCESS_MODE_WHEN_PAUSED
```

这让暂停菜单天然符合语义：

- 正常游玩时它不处理逻辑
- 一旦进入暂停态，它自动成为活跃 UI

---

## 6. 输入系统：暂停不是禁输入，而是切输入上下文

这部分是当前实现里非常值得复用的一点。

文件：`src/autoload/enhanced_input.gd`

关键接口：

- `set_input_mode(InputMode.GAME_ONLY)`
- `set_input_mode(InputMode.UI_ONLY)`
- `set_input_mode(InputMode.GAME_AND_UI)`

相关代码：

- `src/autoload/enhanced_input.gd:125-153`

```gdscript
match mode:
	InputMode.GAME_ONLY:
		GUIDE.enable_mapping_context(gameplay_context, false, 10)
	InputMode.UI_ONLY:
		GUIDE.enable_mapping_context(ui_context, false, 0)
	InputMode.GAME_AND_UI:
		GUIDE.enable_mapping_context(ui_context, false, 0)
		GUIDE.enable_mapping_context(gameplay_context, false, 10)
```

这里的关键经验是：

### 不要把“暂停”理解成“关掉所有输入”

真正需要的是：

- 停止 gameplay 输入
- 保留 UI 输入
- 某些特殊面板场景下允许 `GAME_AND_UI`

这比直接 `set_process_input(false)` 或硬写一堆 `if is_paused: return` 更干净，也更容易扩展。

### 对其他项目的可复用经验

如果后续项目不使用 GUIDE，也建议保留这个抽象层：

- `GAME_ONLY`
- `UI_ONLY`
- `GAME_AND_UI`

底层可以换实现，但这个语义接口应该保留。

---

## 7. PauseMenu 的实现为什么是对的

文件：

- `src/ui/pause_menu.gd`
- `scenes/ui/pause_menu.tscn`

### 7.1 菜单本体使用 `WHEN_PAUSED`

`PauseMenu` 本体就是典型的暂停态 UI：

- `_ready()` 中显式设置 `process_mode = Node.PROCESS_MODE_WHEN_PAUSED`
- 场景文件中同样写死 `process_mode = 3`

这意味着它不依赖“父节点刚好没停”，而是直接把语义写在自己身上。

### 7.2 RuntimeUI 外壳使用 `ALWAYS`

`GameManager` 会动态创建一个 `RuntimeUI` 的 `CanvasLayer`：

- `src/autoload/game_manager.gd:793-809`

```gdscript
runtime_ui_layer = CanvasLayer.new()
runtime_ui_layer.name = "RuntimeUI"
runtime_ui_layer.layer = 100
runtime_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
```

这一层非常关键。

它的作用不是“方便挂 UI”，而是确保：

- 运行时临时 UI 有稳定挂点
- UI 层级不会被关卡树拖着一起停掉
- 暂停菜单 / GameOver / 其他运行时界面有共同容器

### 7.3 Tween 使用暂停安全模式

`PauseMenu` 里的淡入淡出 Tween 都显式用了：

- `Tween.TWEEN_PAUSE_PROCESS`

相关代码：

- `src/ui/pause_menu.gd:128-140`
- `src/ui/pause_menu.gd:178-193`

```gdscript
var tween = create_tween()
tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
```

这解决了暂停 UI 最常见的坑：

> 你把游戏暂停了，结果暂停菜单自己的动画也停了。

如果未来其他项目要做暂停菜单、设置面板、结算界面，这个约束必须一并复制，而不是只复制 `process_mode`。

---

## 8. LevelManager 的协同方式

`LevelManager` 提供了一个很有价值的模式：

- **autoload 实例** 用 `PROCESS_MODE_ALWAYS`
- **当前关卡场景实例** 在暂停时切成 `PROCESS_MODE_PAUSABLE`

相关代码：

- `src/levels/level_manager.gd:40-42`
- `src/levels/level_manager.gd:59-66`

```gdscript
var is_autoload_instance := get_path() == NodePath("/root/LevelManager")
process_mode = Node.PROCESS_MODE_ALWAYS if is_autoload_instance else Node.PROCESS_MODE_PAUSABLE
```

```gdscript
func _process(delta: float) -> void:
	if GameManager and GameManager.is_game_paused:
		return

	if current_state == LevelState.PLAYING:
		elapsed_time += delta
		_check_objectives()
		_check_time_limit()
```

这体现了两个层次：

1. **结构层**：autoload 自己不暂停，因为它要管全局
2. **逻辑层**：即使 autoload 继续运行，也主动尊重 `GameManager.is_game_paused`

这是个很好的工程经验：

> 不要把暂停完全寄托在引擎隐式行为上，重要系统最好再做一层显式逻辑守卫。

---

## 9. 音频系统的现状与经验

文件：`src/autoload/audio_manager.gd`

项目里已经提供了：

- `pause_music()`
- `resume_music()`

相关代码：

- `src/autoload/audio_manager.gd:306-311`

```gdscript
func pause_music() -> void:
	music_player.stream_paused = true

func resume_music() -> void:
	music_player.stream_paused = false
```

这里有两个重要结论。

### 9.1 项目已经具备“显式音频暂停接口”

这是对的，因为音频通常不应该完全依赖 `tree.paused` 的隐式效果。

### 9.2 但当前 `GameManager.set_paused()` 没有直接调用它

也就是说，现阶段暂停系统的主路径里：

- 世界暂停是显式的
- 输入切换是显式的
- 关卡处理是显式的
- 但音频暂停/恢复还没有完全纳入统一协议

这不是文档层面的错误，而是当前实现的一个可演进点。

### 对其他项目的建议

如果要抽成可复用暂停协议，建议把音频纳入 PauseController 的标准协同流程：

- 进入暂停时：暂停 BGM、保留 UI 音效总线
- 恢复时：恢复 BGM

否则不同项目会各自偷偷处理，最后变成“暂停语义不统一”。

---

## 10. 对象池与投射物：为什么这也是暂停设计的一部分

当前项目里，`ProjectileSpawner` 和 `Projectile` 的 `process_mode` 语义是分开的：

- `ProjectileSpawner` 作为全局对象池服务，应保持 `ALWAYS`
- 激活中的 `Projectile` 应该是 `PAUSABLE`
- 回收到池中的对象可以 `DISABLED`

这种拆分特别值得保留。

很多项目暂停出问题，不是 UI 停了，而是：

- 世界停了，但对象池还在偷偷生成/回收导致状态错乱
- 或者对象池一起停了，恢复时残留对象状态不一致

DreamerHeroines 当前的设计更合理：

> **池管理器是基础设施，池中的活动对象是 gameplay 实体。**

这两个层级不该共用一个暂停策略。

---

## 11. 测试已经覆盖了哪些暂停契约

文件：`tests/unit/test_game_pause_flow.gd`

这份测试很有价值，因为它已经把暂停当作“契约”而不是“视觉效果”。

当前已验证的关键行为包括：

1. 暂停后：
   - `is_game_paused == true`
   - `get_tree().paused == true`
   - 状态切到 `PAUSED`
   - 输入模式切到 `UI_ONLY`
   - 当前关卡变为 `PROCESS_MODE_PAUSABLE`

2. 恢复后：
   - `is_game_paused == false`
   - `get_tree().paused == false`
   - 状态回到 `PLAYING`
   - 输入恢复到 `GAME_ONLY`
   - 当前关卡恢复 `PROCESS_MODE_INHERIT`

3. 暂停状态下重开 / 退出主菜单：
   - 会强制先取消暂停
   - 会清理战斗残留（如 projectile pools）
   - 然后再 reload / change scene

这说明项目已经验证了一个很重要的语义：

> “暂停”不是最终状态，而是一个必须可安全退出、可安全切场景、可安全重开的中间运行态。

如果未来抽象复用，建议把这些测试契约一起迁走。

---

## 12. 当前方案与 UE5 风格“真暂停”的关系

如果把“像 UE5 内置暂停一样的语义真暂停”翻译成工程要求，通常包含几件事：

1. gameplay 世界停止推进
2. 玩家无法继续操作角色
3. 暂停菜单仍可操作
4. 恢复后状态连续，不出现额外一帧脏数据
5. 切关 / 退出 / 重开不会把暂停残留带到下一状态

DreamerHeroines 当前方案已经基本覆盖 1、2、3、5，并且在 4 上也做了相当不错的防守。

### 已经做到的部分

- 明确的状态机切换
- SceneTree 暂停
- gameplay 输入隔离
- UI 在暂停态继续工作
- 重开/退菜单前先解除暂停并清理战斗残留

### 还可以继续加强的部分

- 把音频暂停/恢复纳入统一协议
- 对更多全局服务建立明确的 pause contract（例如网络、录像、统计上报、异步加载）
- 对“允许在暂停期间继续运行”的节点建立统一约定，而不是分散在各自 `_ready()`

所以更准确地说：

> 当前实现已经具备“语义真暂停”的核心骨架，只差把若干外围系统正式纳入协议化管理。

---

## 13. 复用到其他项目时，应该抽什么

### 13.1 优先抽象的不是代码，而是角色分工

建议把暂停系统抽成以下四层：

#### 1. PauseController / GameRuntimeController

职责：

- 统一 `set_paused()`
- 管理 `is_game_paused`
- 广播 `pause_changed`
- 协调世界、输入、音频、UI

#### 2. InputModeController

职责：

- 提供 `GAME_ONLY / UI_ONLY / GAME_AND_UI`
- 对外暴露语义，不泄漏底层输入实现

#### 3. RuntimeUIRoot

职责：

- 提供稳定运行时 UI 根节点
- 统一挂 PauseMenu / GameOver / Modal / Tooltip 等

#### 4. PauseAware Services

职责：

- 明确哪些系统在暂停时继续跑
- 明确哪些系统必须响应 `pause_changed`

### 13.2 推荐的最小抽象接口

可以考虑把未来跨项目复用的接口整理成这样：

```gdscript
class_name PauseController
extends Node

signal pause_changed(paused: bool)

var is_paused: bool = false

func set_paused(paused: bool) -> void:
	if is_paused == paused:
		return

	is_paused = paused
	get_tree().paused = paused
	_configure_gameplay_subtree(paused)
	_configure_input_mode(paused)
	_configure_audio(paused)
	pause_changed.emit(paused)
```

重点不在这段代码本身，而在它明确了暂停是一个协议入口，后续项目都必须往这里挂行为，而不是各系统各搞一套。

---

## 14. 最值得复用的工程经验

### 经验 1：暂停是“协议”，不是“布尔值”

不要只维护 `is_paused`。要同时定义：

- 世界怎么停
- 输入怎么切
- UI 怎么活
- 音频怎么处理
- 切场景前怎么清残留

### 经验 2：`process_mode` 比 `tree.paused` 更重要

`tree.paused` 只是总闸刀，`process_mode` 才是真正的暂停白名单机制。

### 经验 3：把 UI 根节点和 gameplay 世界解耦

暂停菜单最好挂在独立的 `CanvasLayer / RuntimeUIRoot` 上，不要直接寄生在关卡树里。

### 经验 4：输入模式切换比“禁用输入”更好

暂停时不是没输入，而是输入目标变了：从 gameplay 切到 UI。

### 经验 5：全局服务要么显式继续运行，要么显式响应暂停

不要让系统“碰巧在暂停时还能用”。要让它在设计上就属于：

- `ALWAYS`
- `PAUSABLE`
- `WHEN_PAUSED`
- 或收到 `pause_changed` 后主动调整

### 经验 6：重开 / 切场景必须先解除暂停

否则最容易留下“下一场景一进来还是 paused”“池对象状态残留”“输入上下文错位”等隐性 bug。

当前项目的测试已经很好地覆盖了这一点。

---

## 15. 当前项目后续可演进方向

以下是基于现状的自然增强方向：

### 15.1 把音频正式纳入暂停协议

建议在 `GameManager.set_paused()` 或 `_apply_runtime_state()` 的协同路径里显式调用：

- `AudioManager.pause_music()`
- `AudioManager.resume_music()`

并明确 UI 音效是否保留。

### 15.2 建立统一的 Pause-Aware 约定

可考虑增加一个轻量约定，例如：

- `on_game_paused()`
- `on_game_resumed()`

让需要额外处理的系统统一接入，而不是每个系统都自己猜。

### 15.3 把“哪些节点该 ALWAYS / PAUSABLE / WHEN_PAUSED”写成团队规则

这份文档可以作为第一版规则来源，后续如果系统增多，建议在 `docs/TECH_SPEC.md` 或专门架构规范中追加一节统一约束。

---

## 16. 本项目中的关键文件索引

### 核心控制

- `src/autoload/game_manager.gd`

### 输入协同

- `src/autoload/enhanced_input.gd`

### 暂停菜单

- `src/ui/pause_menu.gd`
- `scenes/ui/pause_menu.tscn`

### 关卡协同

- `src/levels/level_manager.gd`

### 音频接口

- `src/autoload/audio_manager.gd`

### 测试契约

- `tests/unit/test_game_pause_flow.gd`

---

## 17. 一句话总结

DreamerHeroines 当前暂停系统最有价值的地方，不是“它能暂停”，而是它已经建立了一个接近 UE5 风格的暂停语义雏形：

> **让 gameplay 世界冻结，让控制层、UI 层和必要服务继续工作。**

以后复用到其他项目时，最该复制的不是某一行 API，而是这套分层语义。
