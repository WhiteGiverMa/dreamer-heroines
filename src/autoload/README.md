# src/autoload/ — 自动加载单例

全局可访问的游戏管理器，在项目启动时自动加载，生命周期贯穿整个游戏运行。

---

## 职责

本目录存放 Godot autoload 单例脚本，提供全局服务：

- **启动编排** — 统一管理各系统初始化顺序
- **游戏状态** — 管理游戏流程、分数、暂停
- **音频系统** — BGM/SFX 播放、音量控制
- **存档系统** — GDScript 包装器，调用 C# 实现
- **特效管理** — 粒子效果创建、缓存、对象池
- **投射物池** — 子弹等投射物的生成与回收
- **本地化** — 多语言文本翻译
- **输入包装** — G.U.I.D.E 插件的便捷接口

---

## 文件

| 文件 | 单例名 | 职责 | 依赖 |
|------|--------|------|------|
| `boot_sequence.gd` | BootSequence | 启动序列编排器，按阶段初始化所有系统 | 无 |
| `boot_sequence.tscn` | — | 启动场景，含 LoadingScreen | — |
| `game_manager.gd` | GameManager | 游戏状态、分数、暂停、关卡切换 | SaveManager, LevelManager |
| `audio_manager.gd` | AudioManager | 音效/音乐播放、音量控制 | 无 |
| `save_manager.gd` | SaveManager | GDScript 存档包装器 | CSharpSaveManager |
| `effect_manager.gd` | EffectManager | 特效创建、缓存、对象池 | 无 |
| `projectile_spawner.gd` | ProjectileSpawner | 投射物生成与对象池 | 无 |
| `localization_manager.gd` | LocalizationManager | 多语言翻译管理 | 无 |
| `enhanced_input.gd` | EnhancedInput | G.U.I.D.E 输入包装器 | GUIDE |

> **外部 autoload**: `GameStateManager.cs` 和 `CSharpSaveManager.cs` 位于 `src/cs/Systems/`，`LevelManager.gd` 位于 `src/levels/`，`GUIDE` 来自插件 `addons/guide/`。

---

## 架构设计

### 初始化顺序

`BootSequence` 使用分阶段初始化策略，确保依赖关系正确：

```
Phase 1 (并行): CSharpSaveManager, AudioManager, EffectManager, ProjectileSpawner, LocalizationManager
Phase 2:        EnhancedInput (依赖 GUIDE)
Phase 3:        SaveManager (依赖 CSharpSaveManager)
Phase 4:        LevelManager (依赖 SaveManager)
Phase 5:        GameManager (依赖 SaveManager, LevelManager)
```

每个阶段内的系统并行初始化，阶段间串行执行。系统通过 `system_ready` 信号通知初始化完成。

### 基类约定

所有管理器继承 `res://src/base/game_system.gd`，提供统一的初始化接口：

- `initialize()` — 由 BootSequence 调用，执行实际初始化
- `_mark_ready()` — 子类调用，标记初始化完成并发射 `system_ready`
- `is_initialized` — 只读属性，供外部检查就绪状态

### 通信风格

- **信号优先** — 状态变化通过信号广播（如 `state_changed`, `locale_changed`）
- **直接调用** — 查询和命令操作直接调用方法
- **避免循环依赖** — 通过 `get_node_or_null()` 按需获取其他管理器

### GDScript / C# 分工

| 模块 | 语言 | 原因 |
|------|------|------|
| SaveManager (包装器) | GDScript | 与场景脚本无缝互操作 |
| CSharpSaveManager (实现) | C# | 类型安全、序列化性能 |
| GameStateManager | C# | 状态机逻辑清晰 |
| 其他管理器 | GDScript | 热重载、快速迭代 |
