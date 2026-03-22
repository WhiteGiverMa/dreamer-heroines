# 碰撞层规范文档 (Collision Layers Specification)

> **引擎**: Godot 4.6.1  
> **类型**: 2D物理  
> **版本**: 1.0  
> **最后更新**: 2026-03-18

---

## 目录

1. [概述](#1-概述)
2. [物理层定义](#2-物理层定义)
3. [碰撞矩阵](#3-碰撞矩阵)
4. [代码中使用](#4-代码中使用)
5. [配置检查清单](#5-配置检查清单)

---

## 1. 概述

本文档定义了《逐梦少女》项目中所有物理碰撞层的标准规范。所有场景中的碰撞体必须遵循此规范设置碰撞层和掩码，确保物理交互行为一致且可预测。

### 关键原则

- **层(Layer)**: 定义物体"是什么"（身份）
- **掩码(Mask)**: 定义物体"能与什么碰撞"（感知）
- 使用常量代替魔法数字，确保代码可读性
- 每个物体只应属于一个层，但可以检测多个层

---

## 2. 物理层定义

### 2.1 层分配表

| 层编号 | 层名称 | 用途 | 典型节点 |
|--------|--------|------|----------|
| 1 | Player | 玩家角色 | CharacterBody2D, 碰撞形状 |
| 2 | Enemies | 敌人 | Enemy 节点, 碰撞形状 |
| 3 | World | 地形、墙壁、障碍物 | StaticBody2D, TileMapLayer |
| 4 | Projectiles | 玩家投射物（子弹等） | Area2D, RigidBody2D |
| 5 | EnemyProjectiles | 敌人投射物 | Area2D, RigidBody2D |
| 6 | Pickups | 可拾取物品（弹药、血包等） | Area2D |
| 7 | Triggers | 触发区域（检查点、事件区域） | Area2D |
| 8 | Platforms | 可跳跃平台、单向平台 | StaticBody2D |

### 2.2 层详细说明

#### Layer 1 - Player
- **用途**: 玩家角色本体
- **碰撞层设置**: `collision_layer = 1 << 0` (第1层)
- **典型掩码**: 世界、敌人、敌人子弹、物品、平台
- **注意**: 玩家不应与友方子弹碰撞

#### Layer 2 - Enemies
- **用途**: 所有敌人类型（近战、远程、飞行）
- **碰撞层设置**: `collision_layer = 1 << 1` (第2层)
- **典型掩码**: 世界、玩家、玩家子弹、平台
- **注意**: 敌人之间通常不互相碰撞

#### Layer 3 - World
- **用途**: 静态地形、墙壁、障碍物
- **碰撞层设置**: `collision_layer = 1 << 2` (第3层)
- **典型掩码**: 所有动态物体（玩家、敌人、子弹）
- **注意**: 世界只作为被碰撞方，通常不主动检测

#### Layer 4 - Projectiles
- **用途**: 玩家发射的子弹、火箭等
- **碰撞层设置**: `collision_layer = 1 << 3` (第4层)
- **典型掩码**: 世界、敌人
- **注意**: 子弹通常不与其他子弹碰撞

#### Layer 5 - EnemyProjectiles
- **用途**: 敌人发射的子弹、投掷物等
- **碰撞层设置**: `collision_layer = 1 << 4` (第5层)
- **典型掩码**: 世界、玩家
- **注意**: 与玩家子弹分层，便于分别处理伤害逻辑

#### Layer 6 - Pickups
- **用途**: 弹药包、医疗包、收集品等
- **碰撞层设置**: `collision_layer = 1 << 5` (第6层)
- **典型掩码**: 玩家（通常只有玩家能拾取）
- **注意**: 使用 Area2D 的 `body_entered` 信号检测

#### Layer 7 - Triggers
- **用途**: 检查点、关卡边界、事件触发区域
- **碰撞层设置**: `collision_layer = 1 << 6` (第7层)
- **典型掩码**: 玩家
- **注意**: 通常设置为非物理碰撞，仅触发事件

#### Layer 8 - Platforms
- **用途**: 可跳跃平台、单向平台、移动平台
- **碰撞层设置**: `collision_layer = 1 << 7` (第8层)
- **典型掩码**: 玩家、敌人
- **注意**: 可与 World 层分离，便于特殊平台逻辑

---

## 3. 碰撞矩阵

### 3.1 完整碰撞关系表

| 对象 \ 检测 | Player | Enemies | World | Projectiles | EnemyProjectiles | Pickups | Triggers | Platforms |
|------------|--------|---------|-------|-------------|------------------|---------|----------|-----------|
| **Player** | ✗ | ✓ | ✓ | ✗ | ✓ | ✓ | ✓ | ✓ |
| **Enemies** | ✓ | ✗ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |
| **World** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Projectiles** | ✗ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **EnemyProjectiles** | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Pickups** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Triggers** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |
| **Platforms** | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ | ✗ |

> **说明**: ✓ = 该对象检测此层（掩码包含）, ✗ = 不检测

### 3.2 碰撞矩阵说明

- **World、Platforms**: 静态物体，只设置层，不设置掩码（被动碰撞）
- **Pickups、Triggers**: 使用 Area2D 的监测机制，非物理碰撞
- **Player vs Enemies**: 双方互相检测，用于近战和接触伤害
- **子弹分层**: 玩家子弹和敌人子弹分属不同层，便于伤害计算

---

## 4. 代码中使用

### 4.1 常量定义

在项目中创建全局常量文件，或在使用脚本中定义：

```gdscript
# src/utils/layers.gd 或直接在脚本中定义
class_name Layers
extends Object

# 物理层常量 (1 << (layer - 1))
const PLAYER := 1 << 0           # Layer 1
const ENEMIES := 1 << 1          # Layer 2
const WORLD := 1 << 2            # Layer 3
const PROJECTILES := 1 << 3      # Layer 4
const ENEMY_PROJECTILES := 1 << 4 # Layer 5
const PICKUPS := 1 << 5          # Layer 6
const TRIGGERS := 1 << 6         # Layer 7
const PLATFORMS := 1 << 7        # Layer 8

# 便捷方法：获取层位掩码
static func get_layer_mask(layer_number: int) -> int:
    return 1 << (layer_number - 1)
```

### 4.2 各类型节点配置示例

#### 玩家节点

```gdscript
# src/characters/player.gd
class_name Player
extends CharacterBody2D

const LAYER_PLAYER := 1 << 0
const MASK_PLAYER := (1 << 2) | (1 << 1) | (1 << 4) | (1 << 5) | (1 << 7)
# World | Enemies | EnemyProjectiles | Pickups | Platforms

func _ready() -> void:
    collision_layer = LAYER_PLAYER
    collision_mask = MASK_PLAYER
```

#### 敌人节点

```gdscript
# src/enemies/enemy_base.gd
class_name Enemy
extends CharacterBody2D

const LAYER_ENEMY := 1 << 1
const MASK_ENEMY := (1 << 2) | (1 << 0) | (1 << 3) | (1 << 7)
# World | Player | Projectiles | Platforms

func _ready() -> void:
    collision_layer = LAYER_ENEMY
    collision_mask = MASK_ENEMY
```

#### 玩家子弹

```gdscript
# src/weapons/projectile.gd
class_name Projectile
extends Area2D

const LAYER_PROJECTILE := 1 << 3
const MASK_PROJECTILE := (1 << 2) | (1 << 1)
# World | Enemies

func _ready() -> void:
    collision_layer = LAYER_PROJECTILE
    collision_mask = MASK_PROJECTILE
```

#### 敌人子弹

```gdscript
# src/weapons/enemy_projectile.gd
class_name EnemyProjectile
extends Area2D

const LAYER_ENEMY_PROJECTILE := 1 << 4
const MASK_ENEMY_PROJECTILE := (1 << 2) | (1 << 0)
# World | Player

func _ready() -> void:
    collision_layer = LAYER_ENEMY_PROJECTILE
    collision_mask = MASK_ENEMY_PROJECTILE
```

#### 可拾取物品

```gdscript
# src/levels/pickup.gd
class_name Pickup
extends Area2D

const LAYER_PICKUP := 1 << 5
const MASK_PICKUP := 1 << 0  # 只检测玩家

func _ready() -> void:
    collision_layer = LAYER_PICKUP
    collision_mask = MASK_PICKUP
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        collect()
```

#### 检查点/触发器

```gdscript
# src/levels/checkpoint.gd
class_name Checkpoint
extends Area2D

const LAYER_TRIGGER := 1 << 6
const MASK_TRIGGER := 1 << 0  # 只检测玩家

func _ready() -> void:
    collision_layer = LAYER_TRIGGER
    collision_mask = MASK_TRIGGER
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player"):
        activate()
```

### 4.3 运行时动态修改

```gdscript
# 临时禁用碰撞（如无敌状态）
func set_invincible(enabled: bool) -> void:
    if enabled:
        # 移除对敌人子弹的检测
        collision_mask &= ~(1 << 4)  # 清除 EnemyProjectiles 层
    else:
        # 恢复检测
        collision_mask |= (1 << 4)

# 完全禁用物理碰撞
func disable_collision() -> void:
    collision_layer = 0
    collision_mask = 0

# 恢复默认碰撞
func enable_collision() -> void:
    collision_layer = LAYER_PLAYER
    collision_mask = MASK_PLAYER
```

---

## 5. 配置检查清单

### 5.1 project.godot 配置

确保 `project.godot` 中包含以下层名称定义：

```ini
[layer_names]
2d_physics/layer_1="Player"
2d_physics/layer_2="Enemies"
2d_physics/layer_3="World"
2d_physics/layer_4="Projectiles"
2d_physics/layer_5="EnemyProjectiles"
2d_physics/layer_6="Pickups"
2d_physics/layer_7="Triggers"
2d_physics/layer_8="Platforms"
```

### 5.2 场景检查清单

创建新场景时，检查以下节点配置：

| 场景类型 | 节点类型 | 碰撞层 | 碰撞掩码 | 所属层 |
|----------|----------|--------|----------|--------|
| Player | CharacterBody2D | Layer 1 | 2,3,5,6,8 | Player |
| Enemy | CharacterBody2D | Layer 2 | 1,3,4,8 | Enemies |
| TileMap | TileMapLayer | Layer 3 | 无 | World |
| Static Wall | StaticBody2D | Layer 3 | 无 | World |
| Player Bullet | Area2D | Layer 4 | 2,3 | Projectiles |
| Enemy Bullet | Area2D | Layer 5 | 1,3 | EnemyProjectiles |
| Ammo Pickup | Area2D | Layer 6 | 1 | Pickups |
| Checkpoint | Area2D | Layer 7 | 1 | Triggers |
| One-way Platform | StaticBody2D | Layer 8 | 无 | Platforms |

### 5.3 调试技巧

```gdscript
# 在 _draw() 中可视化碰撞形状
func _draw() -> void:
    if OS.is_debug_build():
        # 绘制检测范围
        for child in get_children():
            if child is CollisionShape2D:
                var shape = child.shape
                if shape is CircleShape2D:
                    draw_circle(child.position, shape.radius, Color(0, 1, 0, 0.3))
                elif shape is RectangleShape2D:
                    draw_rect(Rect2(child.position - shape.size/2, shape.size), Color(0, 1, 0, 0.3))
```

### 5.4 常见问题排查

| 问题现象 | 可能原因 | 解决方案 |
|----------|----------|----------|
| 子弹穿过敌人 | 掩码未包含 Enemies 层 | 检查 `collision_mask` 是否包含第2层 |
| 玩家穿过墙壁 | 掩码未包含 World 层 | 检查 `collision_mask` 是否包含第3层 |
| 拾取物无响应 | 碰撞层设置错误 | 确保 Pickup 在 Layer 6，掩码包含 Layer 1 |
| 敌人互相碰撞 | 掩码包含 Enemies 层 | 移除敌人对 Layer 2 的检测 |
| 子弹与子弹碰撞 | 掩码设置过宽 | 子弹通常只检测 World 和对应目标层 |

---

## 附录

### A. 位运算速查表

```gdscript
# 设置单个层
layer = 1 << (n - 1)  # 设置第 n 层

# 组合多个层
mask = (1 << 0) | (1 << 2) | (1 << 4)  # 第1、3、5层

# 添加层
mask |= (1 << 3)  # 添加第4层

# 移除层
mask &= ~(1 << 3)  # 移除第4层

# 检查是否包含某层
if mask & (1 << 2):  # 检查是否包含第3层
    pass

# 层编号到位掩码
func layer_to_bit(layer_number: int) -> int:
    return 1 << (layer_number - 1)
```

### B. 相关文档

- [Godot 物理教程 - 碰撞层与掩码](https://docs.godotengine.org/en/stable/tutorials/physics/physics_introduction.html#collision-layers-and-masks)
- [TECH_SPEC.md](./TECH_SPEC.md) - 技术规范总览
- [GDD.md](./GDD.md) - 游戏设计文档

---

*本文档应与项目同步更新。修改物理层配置时，必须同步更新此文档。*
