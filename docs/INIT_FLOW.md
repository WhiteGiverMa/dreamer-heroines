# 游戏初始化流程规范

> **版本**: 1.0.0
> **最后更新**: 2026-03-22
> **适用项目**: DreamerHeroines

---

## 概述

本文档定义了游戏启动时的系统初始化流程，确保所有核心系统按正确的依赖顺序加载，提供可控的启动体验。

---

## 设计目标

1. **依赖透明**：明确系统间的初始化依赖关系
2. **顺序可控**：主场景编排初始化顺序，而非依赖 autoload 隐式顺序
3. **进度可视**：支持加载画面显示当前初始化阶段
4. **故障定位**：初始化失败时能快速定位问题系统
5. **灵活扩展**：新增系统只需注册到初始化序列

---

## 系统依赖图

```
启动序列
│
├── Phase 1: 基础设施（无依赖，可并行）
│   ├── CSharpSaveManager (C#)
│   ├── AudioManager
│   └── EffectManager
│
├── Phase 2: 输入系统
│   └── EnhancedInput → 依赖 GUIDE (插件已 autoload)
│
├── Phase 3: 存档系统
│   └── SaveManager → 依赖 CSharpSaveManager
│
├── Phase 4: 游戏管理（有依赖）
│   └── LevelManager → 依赖 SaveManager
│
└── Phase 5: 核心控制器
    └── GameManager → 依赖 SaveManager, LevelManager
```

---

## 初始化顺序表

| 阶段 | 系统 | 依赖 | 初始化方法 | 超时 |
|------|------|------|-----------|------|
| 1 | CSharpSaveManager | 无 | `_initialize()` | 5s |
| 1 | AudioManager | 无 | `initialize()` | 3s |
| 1 | EffectManager | 无 | `initialize()` | 3s |
| 2 | EnhancedInput | GUIDE | `initialize()` | 2s |
| 3 | SaveManager | CSharpSaveManager | `initialize()` | 5s |
| 4 | LevelManager | SaveManager | `initialize()` | 3s |
| 5 | GameManager | SaveManager, LevelManager | `initialize()` | 2s |

---

## 系统基类规范

### GameSystem 基类

所有可初始化系统应继承此基类或实现相同接口：

```gdscript
# src/base/game_system.gd
class_name GameSystem
extends Node

## 系统名称（用于日志和依赖检查）
@export var system_name: String = ""

## 是否已完成初始化
var is_initialized: bool = false

## 初始化完成信号
signal system_ready(system_name: String)

## 初始化方法 - 子类必须重写
func initialize() -> void:
    push_warning("GameSystem.initialize() 未在子类重写: %s" % name)
    _mark_ready()

## 异步初始化版本（用于需要 await 的场景）
func initialize_async() -> void:
    await initialize()

## 标记初始化完成
func _mark_ready() -> void:
    is_initialized = true
    system_ready.emit(system_name)
    print("[GameSystem] %s 初始化完成" % system_name)
```

### 系统实现示例

```gdscript
# src/autoload/save_manager.gd
class_name SaveManager
extends GameSystem

func _ready() -> void:
    system_name = "save_manager"
    # 注意：不在这里做实际初始化，等 initialize() 调用

func initialize() -> void:
    print("[SaveManager] 开始初始化...")
    
    # 等待依赖系统就绪
    var csharp_manager = get_node_or_null("/root/CSharpSaveManager")
    if csharp_manager and not csharp_manager.is_initialized:
        await csharp_manager.system_ready
    
    # 执行初始化
    _initialize_csharp_manager()
    
    print("[SaveManager] 初始化完成")
    _mark_ready()
```

---

## 主场景编排器

### 场景结构

```
Main (主场景)
├── BootSequence (启动序列控制器)
│   └── LoadingScreen (加载画面)
├── Systems (系统容器 - 可选，用于非 autoload 系统)
├── UI
│   ├── HUD
│   ├── PauseMenu
│   └── GameOver
└── World
    └── Level
```

### BootSequence 实现

```gdscript
# src/autoload/boot_sequence.gd
class_name BootSequence
extends Node

## 初始化阶段定义
const INIT_PHASES: Array[Array] = [
    # Phase 1: 基础设施（并行）
    ["CSharpSaveManager", "AudioManager", "EffectManager"],
    # Phase 2: 输入系统
    ["EnhancedInput"],
    # Phase 3: 存档系统
    ["SaveManager"],
    # Phase 4: 关卡管理
    ["LevelManager"],
    # Phase 5: 游戏核心
    ["GameManager"],
]

## 系统路径映射（autoload 名称 -> /root/路径）
const SYSTEM_PATHS: Dictionary = {
    "CSharpSaveManager": "/root/CSharpSaveManager",
    "AudioManager": "/root/AudioManager",
    "EffectManager": "/root/EffectManager",
    "EnhancedInput": "/root/EnhancedInput",
    "SaveManager": "/root/SaveManager",
    "LevelManager": "/root/LevelManager",
    "GameManager": "/root/GameManager",
}

## 初始化超时（秒）
const INIT_TIMEOUT: float = 30.0

## 信号
signal boot_completed
signal boot_failed(system_name: String, error: String)
signal phase_started(phase_index: int, phase_name: String)
signal system_initialized(system_name: String)

## 状态
var current_phase: int = -1
var current_system: String = ""
var initialized_count: int = 0
var total_systems: int = 0

## 引用
@onready var loading_screen: Control = $LoadingScreen

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _calculate_total_systems()
    
    # 开始启动序列
    call_deferred("_run_boot_sequence")

func _calculate_total_systems() -> void:
    for phase in INIT_PHASES:
        total_systems += phase.size()

func _run_boot_sequence() -> void:
    print("=== 游戏启动序列开始 ===")
    
    # 显示加载画面
    if loading_screen:
        loading_screen.show()
    
    var start_time: float = Time.get_ticks_msec() / 1000.0
    
    for phase_idx in INIT_PHASES.size():
        current_phase = phase_idx
        var phase_systems: Array = INIT_PHASES[phase_idx]
        
        phase_started.emit(phase_idx, "Phase %d" % (phase_idx + 1))
        print("[Boot] 开始阶段 %d: %s" % [phase_idx + 1, phase_systems])
        
        # 并行初始化本阶段所有系统
        var pending: Array = []
        for system_name in phase_systems:
            var system = _get_system(system_name)
            if system and system.has_method("initialize"):
                current_system = system_name
                _update_loading_screen()
                system.initialize()
                pending.append(system)
        
        # 等待本阶段所有系统完成
        for system in pending:
            if "is_initialized" in system and not system.is_initialized:
                await system.system_ready
            initialized_count += 1
            system_initialized.emit(system.system_name if "system_name" in system else system.name)
        
        # 更新进度
        _update_loading_screen()
    
    var elapsed: float = Time.get_ticks_msec() / 1000.0 - start_time
    print("=== 启动序列完成 (耗时 %.2fs) ===" % elapsed)
    
    # 隐藏加载画面
    if loading_screen:
        await loading_screen.fade_out()
    
    boot_completed.emit()

func _get_system(system_name: String) -> Node:
    var path: String = SYSTEM_PATHS.get(system_name, "")
    if path.is_empty():
        push_error("[Boot] 未知系统: %s" % system_name)
        return null
    return get_node_or_null(path)

func _update_loading_screen() -> void:
    if not loading_screen:
        return
    
    var progress: float = float(initialized_count) / float(total_systems)
    var status: String = "正在加载: %s" % current_system if current_system else "初始化中..."
    
    if loading_screen.has_method("set_progress"):
        loading_screen.set_progress(progress, status)
```

---

## 加载画面规范

### LoadingScreen 组件

```gdscript
# src/ui/loading_screen.gd
class_name LoadingScreen
extends Control

## 信号
signal fade_complete

## 节点引用
@onready var progress_bar: ProgressBar = $VBox/ProgressBar
@onready var status_label: Label = $VBox/StatusLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

## 配置
@export var fade_duration: float = 0.5

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_progress(progress: float, status: String = "") -> void:
    if progress_bar:
        progress_bar.value = progress * 100.0
    if status_label and not status.is_empty():
        status_label.text = status

func fade_out() -> void:
    var tween := create_tween()
    tween.tween_property(self, "modulate:a", 0.0, fade_duration)
    tween.tween_callback(func():
        hide()
        fade_complete.emit()
    )
```

---

## 系统改造清单

### 需要改造的现有系统

| 系统 | 当前状态 | 改造内容 |
|------|---------|---------|
| SaveManager | 已有 `_ready()` 逻辑 | 移动到 `initialize()`，添加依赖等待 |
| AudioManager | 已有 `_ready()` 逻辑 | 移动到 `initialize()` |
| EffectManager | 已有 `_ready()` 逻辑 | 移动到 `initialize()` |
| EnhancedInput | 已有 `_ready()` 逻辑 | 移动到 `initialize()` |
| LevelManager | 已有 `_ready()` 逻辑 | 移动到 `initialize()`，添加依赖等待 |
| GameManager | 已有 `_ready()` 逻辑 | 移动到 `initialize()`，添加依赖等待 |

### 改造模板

**改造前：**
```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _setup_audio_players()
    _setup_default_bus_volumes()
    print("AudioManager initialized")
```

**改造后：**
```gdscript
func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    system_name = "audio_manager"
    # 不执行初始化，等待 BootSequence 调用

func initialize() -> void:
    print("[AudioManager] 开始初始化...")
    _setup_audio_players()
    _setup_default_bus_volumes()
    print("[AudioManager] 初始化完成")
    _mark_ready()
```

---

## 错误处理

### 初始化失败处理

```gdscript
func _run_boot_sequence() -> void:
    # ... 初始化代码 ...
    
    for system in pending:
        if "is_initialized" in system and not system.is_initialized:
            # 设置超时
            var timeout_timer := get_tree().create_timer(INIT_TIMEOUT)
            var completed := false
            
            system.system_ready.connect(func(): completed = true)
            
            await system.system_ready
            
            if not completed:
                boot_failed.emit(system.system_name, "初始化超时")
                return
```

### 降级策略

当某个系统初始化失败时：

1. **可选系统**：跳过，继续启动，记录警告
2. **核心系统**：显示错误对话框，提供重试或退出选项

```gdscript
func _on_boot_failed(system_name: String, error: String) -> void:
    printerr("[Boot] 系统初始化失败: %s - %s" % [system_name, error])
    
    # 显示错误对话框
    var dialog := AcceptDialog.new()
    dialog.dialog_text = "启动失败: %s\n\n错误: %s" % [system_name, error]
    dialog.title = "初始化错误"
    add_child(dialog)
    dialog.popup_centered()
```

---

## 测试验证

### 单元测试

```gdscript
# tests/unit/test_boot_sequence.gd
extends GutTest

func test_system_initialization_order():
    var boot := BootSequence.new()
    var initialized_order: Array = []
    
    boot.system_initialized.connect(func(name): initialized_order.append(name))
    
    # 模拟运行
    await boot._run_boot_sequence()
    
    # 验证顺序
    assert_true(initialized_order.has("audio_manager"))
    assert_true(initialized_order.find("save_manager") > initialized_order.find("csharp_save_manager"))
```

### 集成测试

在 `tests/scripts/test_launcher.gd` 中添加启动序列测试。

---

## 附录

### A. 系统初始化检查清单

- [ ] 所有系统继承 `GameSystem` 或实现相同接口
- [ ] `_ready()` 中不执行实际初始化逻辑
- [ ] `initialize()` 方法实现完整
- [ ] 依赖系统使用 `await` 等待
- [ ] 初始化完成后调用 `_mark_ready()`

### B. 常见问题

**Q: 为什么不直接在 `_ready()` 中初始化？**

A: `_ready()` 的调用顺序由场景树决定，无法保证跨系统的依赖顺序。通过显式的 `initialize()` 调用，可以在主场景中精确控制初始化顺序。

**Q: Autoload 的顺序还需要关心吗？**

A: 仍然需要。Autoload 顺序决定了节点实例化的顺序，影响 `_init()` 和 `_ready()` 的调用时机。但实际初始化逻辑移到 `initialize()` 后，Autoload 顺序不再影响功能正确性。

### C. 相关文档

- [AGENTS.md](../AGENTS.md) - 项目规范
- [TECH_SPEC.md](./TECH_SPEC.md) - 技术规范
- [GUIDE_CHEAT_SHEET.md](./GUIDE_CHEAT_SHEET.md) - 输入系统

---

*最后更新: 2026-03-22*
