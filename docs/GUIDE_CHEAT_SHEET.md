# G.U.I.D.E 速查表

快速参考 G.U.I.D.E (Godot Universal Input Definition Engine) 的常用 API 和用法。

---

## 官方文档链接

- [G.U.I.D.E 文档](https://godotneers.github.io/G.U.I.D.E/)
- [GitHub 仓库](https://github.com/godotneers/G.U.I.D.E)
- [触发器参考](https://godotneers.github.io/G.U.I.D.E/reference/triggers)
- [修饰器参考](https://godotneers.github.io/G.U.I.D.E/reference/modifiers)

---

## EnhancedInput 单例 API

EnhancedInput 是 G.U.I.D.E 的核心单例，用于检测输入动作。

### 基础检测方法

| 方法 | 说明 | 示例 |
|------|------|------|
| `is_action_pressed(action)` | 持续按下状态 | `EnhancedInput.is_action_pressed(shoot_action)` |
| `is_action_just_pressed(action)` | 刚按下（一帧） | `EnhancedInput.is_action_just_pressed(jump_action)` |
| `is_action_just_released(action)` | 刚释放（一帧） | `EnhancedInput.is_action_just_released(jump_action)` |
| `get_action_strength(action)` | 获取动作强度 (0-1) | `EnhancedInput.get_action_strength(move_action)` |

### 2D 轴输入

| 方法 | 说明 | 示例 |
|------|------|------|
| `get_vector(negative_x, positive_x, negative_y, positive_y)` | 获取 2D 向量 | `EnhancedInput.get_vector("move_left", "move_right", "move_up", "move_down")` |

### 瞄准方向

| 方法 | 说明 | 示例 |
|------|------|------|
| `get_aim_direction()` | 获取瞄准方向（相对于玩家） | `EnhancedInput.get_aim_direction()` |

---

## 常见用法示例

### 移动处理

```gdscript
# 在 _physics_process 中处理移动
func _physics_process(delta: float) -> void:
    # 获取移动输入向量
    var input_vector := EnhancedInput.get_vector(
        "move_left",
        "move_right",
        "move_up",
        "move_down"
    )

    # 应用移动
    velocity = input_vector * move_speed
    move_and_slide()
```

### 跳跃处理

```gdscript
# 检测跳跃输入
func _process(delta: float) -> void:
    if EnhancedInput.is_action_just_pressed("jump"):
        jump()

    # 持续检测跳跃键（用于可变跳跃高度）
    if EnhancedInput.is_action_pressed("jump"):
        apply_jump_force()
```

### 射击处理

```gdscript
# 自动射击（按住时持续）
func _process(delta: float) -> void:
    if EnhancedInput.is_action_pressed("shoot"):
        try_shoot()

# 单发射击（每次按下触发一次）
func _process(delta: float) -> void:
    if EnhancedInput.is_action_just_pressed("shoot"):
        fire_single_shot()
```

---

## 资源结构

### InputAction 资源

InputAction 定义单个输入动作及其触发条件。

```
res://input/actions/
├── move_left.input_action
├── move_right.input_action
├── jump.input_action
└── shoot.input_action
```

**关键属性**:

| 属性 | 说明 |
|------|------|
| `Trigger` | 触发器类型（Pressed, Released, Hold, Tap 等） |
| `Modifiers` | 修饰器列表（DeadZone, Scale, SwizzleAxis 等） |

### MappingContext 资源

MappingContext 将 InputAction 映射到具体的输入设备。

```
res://input/mapping_contexts/
├── gameplay.context.tres
├── menu.context.tres
└── vehicle.context.tres
```

**关键属性**:

| 属性 | 说明 |
|------|------|
| `Mappings` | 动作到输入的映射列表 |
| `Priority` | 上下文优先级（高优先级覆盖低优先级） |

---

## 快速参考：触发器类型

| 触发器 | 说明 |
|--------|------|
| `Pressed` | 按下时触发 |
| `Released` | 释放时触发 |
| `Hold` | 按住持续触发 |
| `Tap` | 快速点击触发 |
| `DoubleTap` | 双击触发 |
| `Chord` | 组合键触发 |

---

## 快速参考：常用修饰器

| 修饰器 | 说明 |
|--------|------|
| `DeadZone` | 设置死区阈值 |
| `Scale` | 缩放输入值 |
| `SwizzleAxis` | 交换/重排轴 |
| `Negate` | 反转输入值 |

---

## 上下文切换示例

```gdscript
# 切换到游戏玩法输入上下文
EnhancedInput.push_context(gameplay_context)

# 切换到菜单输入上下文
EnhancedInput.push_context(menu_context)

# 移除当前上下文
EnhancedInput.pop_context()
```

---

## 提示

1. **缓存 InputAction 引用**: 在 `_ready()` 中缓存动作引用，避免每帧查找
2. **使用 `_process` 或 `_physics_process`**: 根据需要在不同回调中检测输入
3. **组合修饰器**: 可以链式组合多个修饰器实现复杂输入处理
