# EnemyManager 架构设计文档

> **版本**: 1.0
> **日期**: 2026-03-30
> **作者**: Sisyphus Agent
> **状态**: 已实施

---

## 1. 背景与动机

### 1.1 问题描述

在原有架构中，HUD 的敌人计数器通过 `get_tree().get_nodes_in_group("enemy")` 实时查询场景树获取敌人数量。这种方式存在以下问题：

1. **时序不一致**：敌人调用 `die()` 发射 `died` 信号时，节点仍在场景树中（`queue_free()` 延迟执行），导致计数滞后
2. **批量击杀延迟**：开发者模式的 "Kill All" 命令同时击杀多个敌人，每个敌人都触发信号，但 HUD 查询时所有敌人仍在场景中
3. **职责分散**：敌人计数逻辑分散在 WaveSpawner、MissionObjective、HUD 等多个组件中

### 1.2 解决目标

- **即时更新**：敌人死亡时计数立即减少
- **集中管理**：单一真实来源管理敌人生命周期
- **可扩展性**：支持未来的敌人池、成就系统、统计功能

---

## 2. 架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                      Godot Scene Tree                        │
│                                                              │
│  ┌─────────────────┐      ┌─────────────────────────────┐   │
│  │   HUD (Canvas)  │      │       WaveSpawner           │   │
│  │                 │      │                             │   │
│  │  Enemy Count    │◄─────│  Spawns enemies             │   │
│  │  Display        │      │  Tracks wave completion     │   │
│  └─────────────────┘      └─────────────────────────────┘   │
│           ▲                            │                     │
│           │                            │                     │
│    ┌──────┴─────────────────────────────┴──────┐              │
│    │                                           │              │
│    │  ┌──────────────────────────────────┐   │              │
│    │  │      EnemyManager (autoload)     │   │              │
│    │  │                                  │   │              │
│    │  │  ┌─────────────────────────┐     │   │              │
│    │  │  │ _active_enemies: {}     │◄──┼───┘              │
│    │  │  │                         │   │                    │
│    │  │  │ register_enemy()       │   │                    │
│    │  │  │ unregister_enemy()     │   │                    │
│    │  │  │                         │   │                    │
│    │  │  │ Signal:                 │   │                    │
│    │  │  │ enemy_count_changed    │───┘                    │
│    │  │  │                        │                        │
│    │  │  └─────────────────────────┘                        │
│    │  └──────────────────────────────────┘                    │
│    │                                                         │
│    │                                                         │
│    └─────────────────────────────────────────────────────────┘
│                              │
│                    ┌─────────┴──────────┐
│                    │                    │
│            ┌───────▼──────┐    ┌──────▼──────┐
│            │  EnemyBase   │    │  EnemyBase  │
│            │  (Melee)     │    │  (Ranged)   │
│            │              │    │             │
│            │ _ready():    │    │ _ready():   │
│            │  register()  │    │  register() │
│            │              │    │             │
│            │ _die():      │    │ _die():     │
│            │  unregister()│    │  unregister()│
│            └──────────────┘    └─────────────┘
└─────────────────────────────────────────────────────────────┘
```

### 2.2 职责边界

| 组件 | 职责 | 不做什么 |
|------|------|----------|
| **EnemyManager** | 全局敌人注册/注销、实时计数、发射计数变化信号 | 不管理波次逻辑、不处理敌人行为 |
| **WaveSpawner** | 波次生成、波次完成判定 | 不再管理全局敌人计数 |
| **EnemyBase** | 注册自己到 EnemyManager、注销自己 | 不直接更新 HUD |
| **HUD** | 监听 EnemyManager 信号、显示计数 | 不直接查询场景树 |

---

## 3. 实现细节

### 3.1 EnemyManager (新增 autoload)

**文件**: `src/autoload/enemy_manager.gd`

**核心功能**:

```gdscript
# 信号
signal enemy_registered(enemy: Node)
signal enemy_unregistered(enemy: Node)
signal enemy_count_changed(count: int)
signal enemy_died(enemy: Node, enemy_type: String)
signal all_enemies_cleared

# 注册/注销
func register_enemy(enemy: Node)     # 由 EnemyBase._ready() 调用
func unregister_enemy(enemy: Node)  # 由 EnemyBase._die() 调用

# 查询
func get_active_enemy_count() -> int
func get_enemy_count_by_type(type: String) -> int
func get_active_enemies() -> Array[Node]

# 操作
func kill_all_enemies() -> int        # 开发者命令
func clear_all_enemies()              # 关卡切换
```

**关键设计决策**:

1. **立即注销**: 敌人在 `_die()` 中**立即**调用 `unregister_enemy()`，而不是等待 `tree_exiting` 信号
2. **双重保险**: 同时连接 `died` 和 `tree_exiting` 信号，确保任何情况都能正确注销
3. **类型统计**: 维护 `_enemy_type_counts` 字典，支持按类型统计

### 3.2 EnemyBase 修改

**文件**: `src/enemies/enemy_base.gd`

**修改点**:

```gdscript
func _ready():
    add_to_group("enemy")
    # ... 原有代码 ...

    # 新增: 注册到全局敌人管理器
    if EnemyManager:
        EnemyManager.register_enemy(self)

func _die() -> void:
    # ... 原有代码 ...

    # 新增: 发射死亡信号并注销（在 queue_free 之前）
    died.emit()
    if EnemyManager:
        EnemyManager._on_enemy_died(self)
        EnemyManager.unregister_enemy(self)

    await animation_player.animation_finished
    queue_free()
```

### 3.3 HUD 修改

**文件**: `src/ui/hud.gd`

**修改点**:

```gdscript
func _ready() -> void:
    # ... 原有代码 ...

    # 新增: 连接敌人管理器信号
    if EnemyManager and not EnemyManager.enemy_count_changed.is_connected(_on_enemy_count_changed):
        EnemyManager.enemy_count_changed.connect(_on_enemy_count_changed)

    # 修改: 从 EnemyManager 获取初始计数
    if EnemyManager:
        update_enemy_count(EnemyManager.get_active_enemy_count())
    else:
        update_enemy_count(0)

# 新增: 敌人计数变化回调
func _on_enemy_count_changed(new_count: int) -> void:
    update_enemy_count(new_count)

# 修改: 简化敌人生成回调
func _on_enemy_spawned(_enemy: Node) -> void:
    # 敌人由 EnemyManager 追踪，无需手动更新
    pass
```

---

## 4. 信号流时序

### 4.1 敌人生成时序

```
WaveSpawner._spawn_enemy()
    │
    ▼
add_child(enemy) ──► enemy._ready()
                         │
                         ▼
                    EnemyManager.register_enemy(enemy)
                         │
                         ├──► _active_enemies[enemy_id] = enemy
                         ├──► enemy_count_changed.emit(count)
                         │
                         ▼
                    HUD._on_enemy_count_changed(count)
                         │
                         ▼
                    update_enemy_count(count) [立即更新显示]
```

### 4.2 敌人死亡时序（关键改进）

```
DeveloperMode.kill_all_enemies() / 玩家击杀
    │
    ▼
enemy.die()
    │
    ▼
change_state(DEAD)
    │
    ├──► _enter_state(DEAD)
    │       │
    │       ├──► died.emit() [旧信号]
    │       └──► _die()
    │               │
    │               ├──► animation_player.play("death")
    │               ├──► died.emit() [新增: 确保信号发射]
    │               ├──► EnemyManager._on_enemy_died(enemy) [记录击杀]
    │               ├──► EnemyManager.unregister_enemy(enemy) [★立即注销]
    │               │       │
    │               │       ├──► _active_enemies.erase(enemy_id)
    │               │       └──► enemy_count_changed.emit(new_count)
    │               │               │
    │               │               ▼
    │               │           HUD._on_enemy_count_changed(new_count)
    │               │               │
    │               │               ▼
    │               │           update_enemy_count(new_count) [★即时更新]
    │               │
    │               └──► await animation_player.animation_finished
    │                       │
    │                       ▼
    │                   queue_free() [敌人实际移除]
    │
    ▼
下一个敌人...
```

**时序优势**：
- 敌人在动画播放**前**就已从 EnemyManager 注销
- HUD 在动画期间就看到计数减少
- 不存在 "敌人在场景树中但已死亡" 的模糊状态

---

## 5. 扩展性设计

### 5.1 未来功能支持

| 功能 | 实现方式 |
|------|----------|
| **敌人池** | `register_enemy()` 优先返回池化对象，`unregister_enemy()` 将对象回收到池中 |
| **成就系统** | 监听 `enemy_died` 信号，统计击杀类型、连杀数 |
| **战斗统计** | 在 `_on_enemy_died` 中记录伤害来源、击杀时间、敌人类型分布 |
| **热图系统** | 在 `enemy_died` 回调中记录死亡位置 |
| **波次分析** | `reset_wave_kills()` + `get_wave_kills()` 追踪每波表现 |

### 5.2 类型统计 API

```gdscript
# 获取特定类型敌人数量
var melee_count := EnemyManager.get_enemy_count_by_type("melee")
var ranged_count := EnemyManager.get_enemy_count_by_type("ranged")

# 类型通过 enemy.get_class_name() 或脚本路径自动识别
```

---

## 6. 调试与监控

### 6.1 内置调试功能

```gdscript
# 打印当前状态
EnemyManager.print_status()
# 输出:
# [EnemyManager] Status:
#   Active enemies: 5
#   Wave kills: 12
#   Total kills: 156
#   Enemy types: { "melee": 3, "ranged": 2 }
```

### 6.2 日志输出

所有关键操作都有日志：
```
[EnemyManager] Enemy registered: melee (ID: 123456, Total: 5)
[EnemyManager] Enemy died: ranged (Wave kills: 13, Total kills: 157)
[EnemyManager] Enemy unregistered: ranged (ID: 123457, Remaining: 4)
[EnemyManager] Kill all executed: 5 enemies
```

---

## 7. 兼容性说明

### 7.1 向后兼容

- **WaveSpawner**: 保留 `_active_wave_enemy_ids` 用于波次完成判定，与 EnemyManager 并存
- **EnemyIndicator**: 屏幕边缘箭头指示器继续独立工作，使用自己的追踪逻辑
- **MissionObjective**: 击杀分数统计继续通过 `died` 信号工作

### 7.2 依赖关系

```
EnemyManager
├── 依赖: 无（纯 GDScript，无外部引用）
├── 被 EnemyBase 依赖: register/unregister
├── 被 HUD 依赖: enemy_count_changed 信号
└── 被 DeveloperMode 依赖: kill_all_enemies()
```

---

## 8. 性能考量

### 8.1 时间复杂度

| 操作 | 复杂度 | 说明 |
|------|--------|------|
| `register_enemy()` | O(1) | 字典插入 + 类型计数更新 |
| `unregister_enemy()` | O(1) | 字典删除 + 类型计数更新 |
| `get_active_enemy_count()` | O(1) | 直接返回字典大小 |
| `get_active_enemies()` | O(n) | 遍历字典生成数组，n = 敌人数量 |

### 8.2 内存占用

- 每个活跃敌人占用 1 个字典条目（instance_id → Node 引用）
- 100 个敌人约占用 ~50KB（包含字典开销）
- 敌人死亡后立即释放，无内存泄漏

---

## 9. 实施检查清单

- [x] 创建 `src/autoload/enemy_manager.gd`
- [x] 修改 `src/enemies/enemy_base.gd` 添加注册/注销
- [x] 修改 `src/ui/hud.gd` 连接 EnemyManager 信号
- [x] 修改 `project.godot` 添加 EnemyManager autoload
- [x] 创建本文档
- [x] 验证语法检查通过
- [ ] 运行游戏测试计数器即时更新
- [ ] 测试开发者模式 Kill All 功能

---

## 10. 参考

- **相关文件**:
  - `src/autoload/enemy_manager.gd`
  - `src/enemies/enemy_base.gd`
  - `src/ui/hud.gd`
  - `src/levels/wave_spawner.gd`

- **设计模式**:
  - [Godot 信号文档](https://docs.godotengine.org/en/stable/tutorials/scripting/signals.html)
  - [Autoload 单例模式](https://docs.godotengine.org/en/stable/tutorials/scripting/singletons_autoload.html)

---

*文档结束*