# 技术规范文档 (TECH_SPEC)

> **引擎**: Godot 4.6.1  
> **语言**: GDScript + C# (混用架构)  
> **渲染器**: Forward+ (Desktop) / Compatibility (Web)  
> **版本**: 1.1  
> **最后更新**: 2026-03-15

---

## 目录

1. [项目架构 Overview](#1-项目架构-overview)
2. [核心系统类图](#2-核心系统类图)
3. [数据驱动设计规范](#3-数据驱动设计规范)
4. [性能优化指南](#4-性能优化指南)
5. [编码规范](#5-编码规范)
6. [GDScript 与 C# 混用架构](#6-gdscript-与-c-混用架构)

---

## 1. 项目架构 Overview

### 1.1 目录结构

```
project/
├── project.godot              # 项目配置文件
├── icon.svg                   # 项目图标
├── README.md                  # 项目说明
│
├── assets/                    # 资源文件夹
│   ├── sprites/               # 精灵图
│   ├── animations/            # 动画资源
│   ├── audio/                 # 音效和音乐
│   ├── fonts/                 # 字体文件
│   ├── tilesets/              # 瓦片集
│   ├── particles/             # 粒子材质
│   └── shaders/               # 着色器
│
├── resources/                 # Godot资源文件
│   ├── weapons/               # 武器数据 (.tres)
│   ├── enemies/               # 敌人数据 (.tres)
│   ├── items/                 # 道具数据 (.tres)
│   ├── skills/                # 技能数据 (.tres)
│   └── levels/                # 关卡数据 (.tres)
│
├── src/                       # 源代码
│   ├── autoload/              # 自动加载脚本 (Singletons)
│   ├── characters/            # 角色相关
│   ├── weapons/               # 武器系统
│   ├── enemies/               # 敌人系统
│   ├── levels/                # 关卡系统
│   ├── ui/                    # UI系统
│   ├── effects/               # 特效系统
│   ├── utils/                 # 工具类
│   └── data/                  # 数据定义
│
├── scenes/                    # 场景文件
│   ├── levels/                # 关卡场景
│   ├── ui/                    # UI场景
│   ├── characters/            # 角色场景
│   ├── enemies/               # 敌人场景
│   ├── weapons/               # 武器场景
│   └── props/                 # 道具/环境场景
│
└── docs/                      # 文档
    ├── GDD.md
    ├── TECH_SPEC.md
    └── ASSET_GUIDE.md
```

### 1.2 核心系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                        GameManager                          │
│                    (全局状态管理)                            │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  LevelManager │    │  PlayerManager│    │  UIManager    │
│   (关卡管理)   │    │   (玩家管理)   │    │   (UI管理)    │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│  EnemyManager │    │ WeaponManager │    │ AudioManager  │
│   (敌人管理)   │    │   (武器管理)   │    │   (音频管理)   │
└───────────────┘    └───────────────┘    └───────────────┘
```

### 1.3 场景树结构

```
Main (Node)
├── GameManager (AutoLoad)
├── AudioManager (AutoLoad)
├── SaveManager (AutoLoad)
│
└── CurrentScene (Node)
    ├── World (Node2D)
    │   ├── Background (ParallaxBackground)
    │   ├── TileMap (TileMapLayer)
    │   ├── Props (Node2D)
    │   ├── Enemies (Node2D)
    │   ├── Pickups (Node2D)
    │   └── Player (CharacterBody2D)
    │       ├── Sprite2D
    │       ├── CollisionShape2D
    │       ├── WeaponPivot (Marker2D)
    │       │   └── CurrentWeapon (Node2D)
    │       └── StateMachine (Node)
    │
    ├── CanvasLayer (CanvasLayer)
    │   └── HUD (Control)
    │
    └── Camera2D (Camera2D)
```

---

## 2. 核心系统类图

### 2.1 角色系统

```gdscript
# 基础角色类
class_name Character
extends CharacterBody2D

# 属性
var max_health: float
var current_health: float
var max_armor: float
var current_armor: float
var move_speed: float
var is_dead: bool

# 组件引用
@onready var sprite: Sprite2D
@onready var animation_player: AnimationPlayer
@onready var state_machine: StateMachine
@onready var hitbox: Hitbox
@onready var hurtbox: Hurtbox

# 方法
func take_damage(damage: float, source: Node) -> void
func heal(amount: float) -> void
func die() -> void
func apply_knockback(force: Vector2) -> void

# 信号
signal health_changed(new_health: float, max_health: float)
signal armor_changed(new_armor: float, max_armor: float)
signal died
```

```gdscript
# 玩家类
class_name Player
extends Character

# 玩家特有属性
var experience: int
var level: int
var skill_points: int
var current_weapon_index: int
var weapons: Array[Weapon]

# 输入状态
var input_direction: Vector2
var is_aiming: bool
var aim_direction: Vector2

# 方法
func _input(event: InputEvent) -> void
func _physics_process(delta: float) -> void
func switch_weapon(index: int) -> void
func add_experience(amount: int) -> void
func level_up() -> void
```

### 2.2 武器系统

```gdscript
# 武器数据资源
class_name WeaponData
extends Resource

@export var weapon_name: String
@export var category: WeaponCategory
@export var damage: float
@export var fire_rate: float  # 发/分钟
@export var accuracy: float   # 0-100
@export var recoil: float
@export var magazine_size: int
@export var reload_time: float
@export var range: float
@export var mobility: float   # 移速倍率
@export var penetration: int
@export var projectile_scene: PackedScene
@export var muzzle_flash: PackedScene
@export var shell_ejection: PackedScene
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
```

```gdscript
# 武器控制器
class_name Weapon
extends Node2D

# 属性
var data: WeaponData
var current_ammo: int
var reserve_ammo: int

### 2.3 武器场景结构约定

武器 scene 统一遵循以下层级契约：

```text
WeaponRoot (Node2D)
├── Sprite2D
├── Muzzle (Marker2D)
├── EjectionPort (Marker2D)
└── Muzzle/WeaponLighting (optional, Node2D + weapon_lighting.gd)
```

约定说明：

- `Sprite2D`：只负责武器视觉表现（贴图、缩放、偏移）
- `Muzzle`：只负责枪口锚点与射击/火光发射位置
- `EjectionPort`：只负责弹壳抛出口锚点
- `WeaponLighting`：可选组件；只有带手电/武器灯的武器才挂载，固定作为 `Muzzle` 子节点

职责边界：

- **节点位置负责安装点**：`Muzzle.position`、`EjectionPort.position`、`Muzzle/WeaponLighting.position`
- **资源负责视觉补偿**：`LightSettings.local_offset` 只用于修正光锥视觉起点，不用于表达安装位置
- **组件脚本负责运行时行为**：`weapon_lighting.gd` 管理 `PointLight2D`、预算申请、开关与编辑器预览
- **武器脚本不应特判手电安装点**：不要在具体武器脚本里再维护 `flashlight_offset` 一类与场景节点重复的导出字段

对无手电武器：

- 保留 `Sprite2D / Muzzle / EjectionPort`
- 不挂 `WeaponLighting`
- `Weapon._resolve_weapon_lighting()` 返回 `null`，其余系统无需特殊处理

对有手电武器：

- 在 `Muzzle` 下挂 `WeaponLighting`
- 用场景节点位置表达手电安装点
- 用 `LightSettings` 表达亮度、范围、阴影、视觉偏移等参数
var is_reloading: bool
var last_fire_time: float
var current_recoil: float

# 组件
@onready var muzzle: Marker2D
@onready var sprite: Sprite2D
@onready var animation_player: AnimationPlayer

# 方法
func fire(aim_direction: Vector2) -> void
func reload() -> void
func can_fire() -> bool
func get_spread_angle() -> float
func spawn_projectile(direction: Vector2) -> void

# 信号
signal fired
signal reloaded
signal ammo_changed(current: int, reserve: int)
signal out_of_ammo
```

### 2.3 敌人AI系统

```gdscript
# 敌人数据资源
class_name EnemyData
extends Resource

@export var enemy_name: String
@export var max_health: float
@export var move_speed: float
@export var weapon_data: WeaponData
@export var detection_range: float
@export var attack_range: float
@export var exp_reward: int
@export var gold_reward: int
@export var loot_table: LootTable
@export var ai_difficulty: AIDifficulty
```

```gdscript
# AI控制器
class_name AIController
extends Node

enum State { IDLE, ALERT, COMBAT, SEARCH, RETURN }

var current_state: State
var target: Node2D
var last_known_position: Vector2
var home_position: Vector2
var patrol_points: Array[Vector2]

# 感知
var vision_range: float
var hearing_range: float
var field_of_view: float

# 方法
func _physics_process(delta: float) -> void
func change_state(new_state: State) -> void
func update_perception() -> void
func find_cover() -> Vector2
func attack_target() -> void
func move_to_position(pos: Vector2) -> void
```

### 2.4 状态机系统

```gdscript
# 状态机
class_name StateMachine
extends Node

@export var initial_state: State
var current_state: State
var states: Dictionary[String, State]

func _ready() -> void:
    for child in get_children():
        if child is State:
            states[child.name.to_lower()] = child
            child.state_machine = self
    
    if initial_state:
        change_state(initial_state.name.to_lower())

func change_state(state_name: String) -> void:
    if current_state:
        current_state.exit()
    
    current_state = states.get(state_name)
    if current_state:
        current_state.enter()

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_process(delta)
```

```gdscript
# 基础状态类
class_name State
extends Node

var state_machine: StateMachine
var character: Character

func enter() -> void:
    pass

func exit() -> void:
    pass

func process(delta: float) -> void:
    pass

func physics_process(delta: float) -> void:
    pass

func handle_input(event: InputEvent) -> void:
    pass
```

### 2.5 伤害系统

```gdscript
# 伤害数据
class_name DamageInfo
extends RefCounted

var damage: float
var damage_type: DamageType
var source: Node
var hit_position: Vector2
var hit_normal: Vector2
var is_critical: bool
var critical_multiplier: float

enum DamageType { KINETIC, EXPLOSIVE, FIRE, ELECTRIC }
```

```gdscript
# 受击框
class_name Hitbox
extends Area2D

@export var damage_multiplier: float = 1.0
@export var is_headshot: bool = false

signal hit_received(damage_info: DamageInfo)

func receive_damage(damage_info: DamageInfo) -> void:
    damage_info.damage *= damage_multiplier
    if is_headshot:
        damage_info.is_critical = true
        damage_info.critical_multiplier = 2.0
    hit_received.emit(damage_info)
```

```gdscript
# 伤害框
class_name Hurtbox
extends Area2D

@export var damage: float
@export var damage_type: DamageInfo.DamageType
@export var one_shot: bool = false

signal damage_dealt(target: Node, damage_info: DamageInfo)

func deal_damage(target: Hitbox) -> void:
    var damage_info = DamageInfo.new()
    damage_info.damage = damage
    damage_info.damage_type = damage_type
    damage_info.source = owner
    target.receive_damage(damage_info)
    damage_dealt.emit(target.owner, damage_info)
```

---

## 3. 数据驱动设计规范

### 3.1 资源数据格式

#### 武器数据 (JSON格式参考)

```json
{
  "weapons": [
    {
      "id": "ak47",
      "name": "AK-47",
      "category": "assault_rifle",
      "stats": {
        "damage": 35,
        "fire_rate": 600,
        "accuracy": 70,
        "recoil": 6.5,
        "magazine_size": 30,
        "reload_time": 2.5,
        "range": 800,
        "mobility": 0.9,
        "penetration": 2
      },
      "assets": {
        "sprite": "res://assets/sprites/weapons/ak47.png",
        "muzzle_flash": "res://assets/particles/muzzle_flash.tscn",
        "fire_sound": "res://assets/audio/weapons/ak47_fire.wav",
        "reload_sound": "res://assets/audio/weapons/ak47_reload.wav"
      }
    }
  ]
}
```

#### 敌人数据 (JSON格式参考)

```json
{
  "enemies": [
    {
      "id": "assault_soldier",
      "name": "突击兵",
      "stats": {
        "max_health": 80,
        "move_speed": 150,
        "detection_range": 600,
        "attack_range": 500,
        "exp_reward": 50,
        "gold_reward": 10
      },
      "ai": {
        "aggression": 0.6,
        "cover_seek_chance": 0.4,
        "reaction_time": 0.5
      },
      "equipment": {
        "weapon": "assault_rifle_tier1",
        "armor": "light_armor"
      },
      "loot": {
        "table": "standard_soldier",
        "drop_chance": 0.3
      }
    }
  ]
}
```

### 3.2 Godot资源文件 (.tres)

#### 武器资源定义

```gdscript
# src/data/weapon_data.gd
class_name WeaponData
extends Resource

@export_category("Basic Info")
@export var id: StringName
@export var display_name: String
@export var description: String
@export var category: WeaponCategory

@export_category("Combat Stats")
@export var damage: float = 10.0
@export var fire_rate: float = 600.0  # RPM
@export var accuracy: float = 70.0
@export var recoil: float = 5.0
@export var magazine_size: int = 30
@export var reload_time: float = 2.0
@export var effective_range: float = 500.0
@export var mobility_multiplier: float = 1.0
@export var penetration_count: int = 1

@export_category("Assets")
@export var icon: Texture2D
@export var world_sprite: Texture2D
@export var muzzle_flash: PackedScene
@export var shell_ejection: PackedScene
@export var projectile: PackedScene

@export_category("Audio")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream

enum WeaponCategory {
    ASSAULT_RIFLE,
    SMG,
    LMG,
    SNIPER,
    SHOTGUN,
    PISTOL,
    MELEE,
    SPECIAL
}
```

#### 创建武器资源实例

```gdscript
# resources/weapons/ak47.tres
[gd_resource type="Resource" script_class="WeaponData" load_steps=5 format=3]

[ext_resource type="Script" path="res://src/data/weapon_data.gd" id="1_ak47"]
[ext_resource type="Texture2D" uid="uid://..." path="res://assets/sprites/weapons/ak47.png" id="2_ak47"]
[ext_resource type="AudioStream" uid="uid://..." path="res://assets/audio/weapons/ak47_fire.wav" id="3_ak47"]
[ext_resource type="PackedScene" uid="uid://..." path="res://scenes/effects/muzzle_flash.tscn" id="4_flash"]

[resource]
script = ExtResource("1_ak47")
id = &"ak47"
display_name = "AK-47"
description = "经典突击步枪，威力大但后坐力明显"
category = 0
damage = 35.0
fire_rate = 600.0
accuracy = 70.0
recoil = 6.5
magazine_size = 30
reload_time = 2.5
effective_range = 800.0
mobility_multiplier = 0.9
penetration_count = 2
icon = ExtResource("2_ak47")
world_sprite = ExtResource("2_ak47")
muzzle_flash = ExtResource("4_flash")
fire_sound = ExtResource("3_ak47")
```

### 3.3 数据加载器

```gdscript
# src/autoload/data_manager.gd
extends Node

const WEAPON_DATA_PATH = "res://resources/weapons/"
const ENEMY_DATA_PATH = "res://resources/enemies/"

var weapons: Dictionary[StringName, WeaponData]
var enemies: Dictionary[StringName, EnemyData]

func _ready() -> void:
    _load_all_weapons()
    _load_all_enemies()

func _load_all_weapons() -> void:
    var dir = DirAccess.open(WEAPON_DATA_PATH)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".tres"):
                var weapon = load(WEAPON_DATA_PATH + file_name) as WeaponData
                if weapon:
                    weapons[weapon.id] = weapon
            file_name = dir.get_next()
    print("Loaded ", weapons.size(), " weapons")

func get_weapon(id: StringName) -> WeaponData:
    return weapons.get(id)

func get_all_weapons_by_category(category: WeaponData.WeaponCategory) -> Array[WeaponData]:
    var result: Array[WeaponData]
    for weapon in weapons.values():
        if weapon.category == category:
            result.append(weapon)
    return result
```

### 3.4 存档系统

```gdscript
# src/autoload/save_manager.gd
extends Node

const SAVE_PATH = "user://saves/"
const SAVE_EXTENSION = ".save"

var current_save: SaveData

func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(SAVE_PATH)

func save_game(slot: int = 0) -> void:
    var save_data = SaveData.new()
    save_data.player_data = _collect_player_data()
    save_data.level_progress = _collect_level_progress()
    save_data.unlocks = _collect_unlocks()
    save_data.timestamp = Time.get_unix_time_from_system()
    
    var file_path = SAVE_PATH + "save_" + str(slot) + SAVE_EXTENSION
    var result = ResourceSaver.save(save_data, file_path)
    if result == OK:
        print("Game saved to ", file_path)
    else:
        push_error("Failed to save game")

func load_game(slot: int = 0) -> bool:
    var file_path = SAVE_PATH + "save_" + str(slot) + SAVE_EXTENSION
    if not FileAccess.file_exists(file_path):
        return false
    
    current_save = load(file_path) as SaveData
    if current_save:
        _apply_save_data(current_save)
        return true
    return false

func _collect_player_data() -> PlayerSaveData:
    var data = PlayerSaveData.new()
    var player = get_tree().get_first_node_in_group("player")
    if player:
        data.level = player.level
        data.experience = player.experience
        data.skill_points = player.skill_points
        data.equipped_weapons = player.get_weapon_ids()
        data.inventory = player.inventory.get_save_data()
    return data
```

---

## 4. 性能优化指南

### 4.1 渲染优化

#### 2D渲染最佳实践

```gdscript
# 使用CanvasLayer组织UI
# 避免在_process中修改可见性

# 好的做法：使用信号驱动
func _on_health_changed(new_health: float) -> void:
    health_bar.visible = new_health < max_health * 0.3

# 避免：每帧检查
func _process(delta: float) -> void:
    if player.health < player.max_health * 0.3:  # 不要这样做
        health_bar.visible = true
```

#### 对象池模式

```gdscript
# src/utils/object_pool.gd
class_name ObjectPool
extends Node

var pool: Array[Node]
var scene: PackedScene
var max_size: int

func _init(p_scene: PackedScene, p_max_size: int = 100) -> void:
    scene = p_scene
    max_size = p_max_size
    _prewarm()

func _prewarm() -> void:
    for i in range(max_size / 2):
        var obj = scene.instantiate()
        obj.process_mode = Node.PROCESS_MODE_DISABLED
        obj.visible = false
        pool.append(obj)
        add_child(obj)

func acquire() -> Node:
    if pool.is_empty():
        return scene.instantiate()
    
    var obj = pool.pop_back()
    obj.process_mode = Node.PROCESS_MODE_INHERIT
    obj.visible = true
    return obj

func release(obj: Node) -> void:
    if pool.size() >= max_size:
        obj.queue_free()
        return
    
    obj.process_mode = Node.PROCESS_MODE_DISABLED
    obj.visible = false
    pool.append(obj)
```

#### 粒子优化

```gdscript
# 使用GPUParticles2D代替CPUParticles2D
# 限制同时存在的粒子数量

# 在Projectile类中
func spawn_impact_effect() -> void:
    var effect = ImpactEffectPool.acquire()
    effect.global_position = global_position
    effect.restart()
    
    # 自动回收
    await effect.finished
    ImpactEffectPool.release(effect)
```

### 4.2 物理优化

#### 碰撞层设置

```gdscript
# 项目设置 -> 层名称
# Layer 1: World (地形、墙壁)
# Layer 2: Player
# Layer 3: Enemies
# Layer 4: Projectiles (玩家子弹)
# Layer 5: EnemyProjectiles (敌人子弹)
# Layer 6: Pickups
# Layer 7: Triggers

# 在代码中使用
const LAYER_WORLD = 1
const LAYER_PLAYER = 2
const LAYER_ENEMY = 3
const LAYER_PROJECTILE = 4
const LAYER_ENEMY_PROJECTILE = 5

# 设置碰撞层和掩码
func _ready() -> void:
    collision_layer = 1 << (LAYER_PLAYER - 1)
    collision_mask = (1 << (LAYER_WORLD - 1)) | (1 << (LAYER_ENEMY - 1))
```

#### 物理过程优化

```gdscript
# 使用_timer代替每帧检查
var check_timer: Timer

func _ready() -> void:
    check_timer = Timer.new()
    check_timer.wait_time = 0.1  # 每100ms检查一次，而非每帧
    check_timer.timeout.connect(_check_nearby_enemies)
    add_child(check_timer)
    check_timer.start()

func _check_nearby_enemies() -> void:
    # 批量处理敌人检测
    pass
```

### 4.3 内存管理

#### 资源加载策略

```gdscript
# src/autoload/resource_manager.gd
extends Node

var loaded_resources: Dictionary[String, Resource]
var loading_queue: Array[String]

func get_resource(path: String, cache: bool = true) -> Resource:
    if loaded_resources.has(path):
        return loaded_resources[path]
    
    var resource = load(path)
    if cache and resource:
        loaded_resources[path] = resource
    
    return resource

func preload_level_resources(level_id: String) -> void:
    var level_data = DataManager.get_level(level_id)
    for enemy in level_data.enemy_spawn_list:
        get_resource(enemy.scene_path, true)
    
    # 预加载完成后发送信号
    resources_preloaded.emit()

func unload_unused_resources() -> void:
    # 关卡切换时调用
    loaded_resources.clear()
```

#### 节点生命周期管理

```gdscript
# 使用queue_free而不是直接free
# 确保在退出树时清理连接

func _exit_tree() -> void:
    # 断开所有信号连接
    for connection in get_signal_connection_list("body_entered"):
        body_entered.disconnect(connection.callable)
    
    # 清理引用
    target = null
    weapon = null
```

### 4.4 性能监控

```gdscript
# debug工具
class_name PerformanceMonitor
extends CanvasLayer

@onready var fps_label: Label = $FPSLabel
@onready var object_count_label: Label = $ObjectCountLabel
@onready var draw_calls_label: Label = $DrawCallsLabel

var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5

func _process(delta: float) -> void:
    update_timer += delta
    if update_timer >= UPDATE_INTERVAL:
        update_timer = 0.0
        _update_stats()

func _update_stats() -> void:
    fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
    object_count_label.text = "Objects: " + str(get_tree().get_node_count())
    
    var rs = RenderingServer
    draw_calls_label.text = "Draw Calls: " + str(rs.get_rendering_info(rs.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
```

---

## 5. 编码规范

### 5.1 命名规范

#### 文件命名

| 类型 | 命名方式 | 示例 |
|------|----------|------|
| 场景文件 | snake_case.tscn | `player.tscn`, `main_menu.tscn` |
| 脚本文件 | snake_case.gd | `player.gd`, `weapon_data.gd` |
| 资源文件 | snake_case.tres | `ak47_data.tres`, `enemy_soldier.tres` |
| 材质文件 | snake_case.tres | `muzzle_flash_material.tres` |
| 着色器 | snake_case.gdshader | `hit_flash.gdshader` |

#### 代码命名

```gdscript
# 类名: PascalCase
class_name PlayerController
class_name WeaponData
class_name EnemyAI

# 常量: UPPER_SNAKE_CASE
const MAX_HEALTH: float = 100.0
const DEFAULT_FIRE_RATE: float = 600.0
const LAYER_PLAYER: int = 2

# 变量: snake_case
var current_health: float
var is_reloading: bool
var weapon_inventory: Array[Weapon]
var target_enemy: Enemy

# 私有变量: 下划线前缀
var _internal_counter: int
var _cached_position: Vector2

# 函数: snake_case
func take_damage(amount: float) -> void
func calculate_trajectory() -> Vector2
func can_fire() -> bool

# 信号: snake_case
signal health_changed(new_health: float)
signal weapon_switched(new_weapon: Weapon)
signal died

# 枚举: PascalCase, 成员: UPPER_SNAKE_CASE
enum WeaponCategory { ASSAULT_RIFLE, SMG, LMG, SNIPER }
enum AIState { IDLE, ALERT, COMBAT, SEARCH }
```

### 5.2 代码组织

#### 脚本结构模板

```gdscript
class_name MyClass
extends BaseClass

# ============================================
# 常量定义
# ============================================
const MAX_VALUE: int = 100

# ============================================
# 导出变量 (可在编辑器中调整)
# ============================================
@export var speed: float = 100.0
@export var damage: int = 10

# ============================================
# 公共变量
# ============================================
var current_health: float
var is_active: bool = true

# ============================================
# 私有变量
# ============================================
var _velocity: Vector2
var _state_machine: StateMachine

# ============================================
# 节点引用 (@onready)
# ============================================
@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

# ============================================
# 信号
# ============================================
signal health_changed(new_health: float)
signal died

# ============================================
# 内置虚函数
# ============================================
func _init() -> void:
    pass

func _ready() -> void:
    _setup_connections()
    _initialize_state()

func _process(delta: float) -> void:
    _update_animation()

func _physics_process(delta: float) -> void:
    _handle_movement(delta)

func _input(event: InputEvent) -> void:
    _handle_input(event)

# ============================================
# 公共方法
# ============================================
func take_damage(amount: float) -> void:
    current_health -= amount
    health_changed.emit(current_health)
    
    if current_health <= 0:
        die()

func die() -> void:
    is_active = false
    died.emit()
    queue_free()

# ============================================
# 私有方法
# ============================================
func _setup_connections() -> void:
    body_entered.connect(_on_body_entered)

func _initialize_state() -> void:
    current_health = MAX_VALUE

func _handle_movement(delta: float) -> void:
    pass

func _update_animation() -> void:
    pass

func _handle_input(event: InputEvent) -> void:
    pass

# ============================================
# 信号回调
# ============================================
func _on_body_entered(body: Node) -> void:
    pass
```

### 5.3 注释规范

```gdscript
# 单行注释用于简单说明
var speed: float = 100.0  # 移动速度，单位：像素/秒

# 多行注释用于复杂逻辑
# 计算弹道下坠时需要考虑：
# 1. 重力加速度
# 2. 初始速度
# 3. 发射角度
# 4. 空气阻力（可选）
func calculate_trajectory() -> Vector2:
    pass

# 文档注释（用于类和方法）
## 处理角色受到伤害
## [param damage] 伤害数值
## [param source] 伤害来源
## [param hit_position] 受击位置
func take_damage(damage: float, source: Node = null, hit_position: Vector2 = Vector2.ZERO) -> void:
    pass
```

### 5.4 最佳实践

#### 使用类型提示

```gdscript
# 好的做法：使用类型提示
func calculate_damage(base_damage: float, multiplier: float) -> float:
    var result: float = base_damage * multiplier
    return result

var weapon_list: Array[WeaponData]
var enemy_dict: Dictionary[StringName, EnemyData]

# 避免：无类型
func calculate_damage(base_damage, multiplier):  # 不要这样做
    return base_damage * multiplier
```

#### 避免魔法数字

```gdscript
# 好的做法：使用常量
const INVINCIBILITY_DURATION: float = 0.5
const KNOCKBACK_FORCE: float = 200.0
const CRITICAL_MULTIPLIER: float = 2.0

func apply_hit() -> void:
    start_invincibility(INVINCIBILITY_DURATION)
    apply_knockback(KNOCKBACK_FORCE)

# 避免：直接使用数字
func apply_hit() -> void:  # 不要这样做
    start_invincibility(0.5)
    apply_knockback(200.0)
```

#### 使用信号进行解耦

```gdscript
# Player.gd
signal health_changed(new_health: float, max_health: float)

func take_damage(amount: float) -> void:
    current_health -= amount
    health_changed.emit(current_health, max_health)

# HUD.gd
func _ready() -> void:
    player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(new_health: float, max_health: float) -> void:
    health_bar.value = new_health / max_health
```

#### 错误处理

```gdscript
func load_weapon_data(path: String) -> WeaponData:
    if not FileAccess.file_exists(path):
        push_error("Weapon data not found: " + path)
        return null
    
    var data = load(path) as WeaponData
    if not data:
        push_error("Failed to load weapon data: " + path)
        return null
    
    return data
```

### 5.5 项目设置规范

#### 推荐的项目设置

```gdscript
# project.godot 关键配置

[application]
config/name="DreamerHeroines"
config/version="0.1.0"
run/main_scene="res://scenes/ui/main_menu.tscn"
config/features=PackedStringArray("4.6", "Forward Plus")
boot_splash/bg_color=Color(0.141176, 0.141176, 0.141176, 1)

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/size/mode=3  # 全屏
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[layer_names]
2d_physics/layer_1="World"
2d_physics/layer_2="Player"
2d_physics/layer_3="Enemies"
2d_physics/layer_4="Projectiles"
2d_physics/layer_5="EnemyProjectiles"
2d_physics/layer_6="Pickups"
2d_physics/layer_7="Triggers"

[rendering]
textures/canvas_textures/default_texture_filter=0  # Nearest (像素风)
renderer/rendering_method="forward_plus"
anti_aliasing/quality/msaa_2d=0
```

### 5.6 Git版本控制

#### .gitignore 模板

```gitignore
# Godot 4+ specific ignores
.godot/
android/
.import/
export.cfg
export_presets.cfg

# Imported translations (automatically generated from CSV files)
*.translation

# Mono-specific ignores
.mono/
data_*/
mono_crash.*.json

# System/tool-specific ignores
.DS_Store
Thumbs.db
*.tmp
*.bak
*.swp
*~

# Build outputs
build/
dist/
exports/

# IDE
.vscode/
.idea/
*.csproj.user
```

#### 提交规范

```
类型: 简短描述（50字符以内）

详细描述（可选，每行72字符以内）

- 使用现在时态
- 首字母大写
- 结尾不加句号

类型说明：
- feat: 新功能
- fix: 修复
- docs: 文档
- style: 格式（不影响代码运行的变动）
- refactor: 重构
- perf: 性能优化
- test: 测试
- chore: 构建过程或辅助工具的变动
```

---

## 附录

### A. 常用代码片段

#### 平滑跟随相机

```gdscript
extends Camera2D

@export var target: Node2D
@export var follow_speed: float = 5.0
@export var lookahead_distance: float = 50.0

func _physics_process(delta: float) -> void:
    if not target:
        return
    
    var target_pos = target.global_position
    # 根据鼠标位置添加预判
    var mouse_offset = (get_global_mouse_position() - target_pos).normalized() * lookahead_distance
    target_pos += mouse_offset * 0.3
    
    global_position = global_position.lerp(target_pos, follow_speed * delta)
```

#### 简单的对象抖动

```gdscript
func shake(intensity: float, duration: float) -> void:
    var original_pos = position
    var elapsed: float = 0.0
    
    while elapsed < duration:
        var offset = Vector2(
            randf_range(-intensity, intensity),
            randf_range(-intensity, intensity)
        )
        position = original_pos + offset
        
        elapsed += get_process_delta_time()
        intensity = lerp(intensity, 0.0, elapsed / duration)
        await get_tree().process_frame
    
    position = original_pos
```

### B. 调试工具

```gdscript
# 绘制调试信息
func _draw() -> void:
    if not Engine.is_editor_hint() and not OS.is_debug_build():
        return
    
    # 绘制检测范围
    draw_circle(Vector2.ZERO, detection_range, Color(1, 0, 0, 0.1))
    
    # 绘制视线
    if target:
        draw_line(Vector2.ZERO, to_local(target.global_position), Color.green)
```

---

## 6. GDScript 与 C# 混用架构

本项目采用 GDScript 与 C# 双语言混用架构，充分发挥两种语言的优势。

### 6.1 语言选择策略

#### 混用方案概述

| 维度 | GDScript | C# |
|------|----------|-----|
| 开发效率 | 高 (热重载、快速迭代) | 中 (需编译) |
| 类型安全 | 动态类型 | 强类型 |
| 性能 | 良好 | 优秀 (JIT编译) |
| IDE支持 | 基础 | 优秀 (Rider/VS) |
| 学习曲线 | 平缓 | 中等 |
| 与引擎集成 | 原生支持 | 良好 |

#### 选择依据和权衡

**使用 GDScript 的场景:**
- 需要频繁修改和热重载的游戏逻辑
- 与 Godot 节点系统深度交互的代码
- 快速原型开发阶段
- 动画、特效、UI 等视觉相关脚本

**使用 C# 的场景:**
- 需要强类型保证的数据管理
- 复杂算法和数学计算
- 性能敏感的计算密集型任务
- 需要良好 IDE 支持的大型系统

**核心原则:**
```
热重载需求高  →  GDScript
类型安全要求高 →  C#
性能瓶颈       →  C#
快速原型       →  GDScript
```

### 6.2 GDScript 使用范围

#### 核心玩法系统

所有与游戏核心玩法直接相关的系统使用 GDScript:

```gdscript
# src/characters/player.gd
class_name Player
extends CharacterBody2D

# 玩家输入处理、移动、射击等高频迭代逻辑
func _physics_process(delta: float) -> void:
    _handle_input()
    _handle_movement(delta)
    _handle_weapon(delta)
```

**包含系统:**
- Player 控制器 (输入、移动、动画)
- Weapon 系统 (射击、换弹、后坐力)
- Enemy AI 行为树
- Projectile 弹道计算
- 碰撞检测与物理交互

#### 需要热重载快速迭代的系统

```gdscript
# src/weapons/weapon.gd
# 调整射击手感时可热重载，无需重新编译

@export var fire_rate: float = 600.0  # 可实时调整
@export var recoil_pattern: Array[Vector2]  # 可快速迭代

func fire(direction: Vector2) -> void:
    # 修改后立即生效
    spawn_projectile(direction + _get_recoil_offset())
```

#### 与 Godot 节点树紧密集成的逻辑

```gdscript
# src/effects/particle_manager.gd
# 直接使用 Godot 的节点系统

@onready var particle_system: GPUParticles2D = $GPUParticles2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func play_impact_effect() -> void:
    # 直接操作 Godot 节点
    particle_system.restart()
    animation_player.play("impact")
```

#### 动画、特效、场景逻辑

```gdscript
# src/effects/screen_shake.gd
# 视觉反馈类脚本

func shake(intensity: float, duration: float) -> void:
    var tween = create_tween()
    tween.tween_method(_apply_shake, intensity, 0.0, duration)

func _apply_shake(amount: float) -> void:
    offset = Vector2(
        randf_range(-amount, amount),
        randf_range(-amount, amount)
    )
```

### 6.3 C# 使用范围

#### 数据管理

所有数据管理类使用 C#，利用强类型保证数据一致性:

```csharp
// src/cs/Data/PlayerData.cs
using Godot;
using System;

namespace DreamerHeroines.Data
{
    [GlobalClass]
    public partial class PlayerData : Resource
    {
        [Export] public string PlayerId { get; set; }
        [Export] public int Level { get; set; } = 1;
        [Export] public int Experience { get; set; }
        [Export] public float MaxHealth { get; set; } = 100f;
        [Export] public float CurrentHealth { get; set; } = 100f;
        [Export] public Godot.Collections.Array<string> UnlockedWeapons { get; set; } = new();
        
        public void AddExperience(int amount)
        {
            Experience += amount;
            CheckLevelUp();
        }
        
        private void CheckLevelUp()
        {
            int requiredExp = Level * 100;
            while (Experience >= requiredExp)
            {
                Experience -= requiredExp;
                Level++;
                requiredExp = Level * 100;
            }
        }
    }
}
```

**包含系统:**
- 存档系统 (SaveData、SaveManager)
- 配置数据 (游戏设置、键位绑定)
- 玩家数据 (进度、解锁内容)
- 游戏平衡数据 (武器参数、敌人属性)

#### 工具类

```csharp
// src/cs/Utils/MathUtils.cs
using Godot;

namespace DreamerHeroines.Utils
{
    public static class MathUtils
    {
        /// <summary>
        /// 计算弹道预测，考虑重力和初速度
        /// </summary>
        public static Vector2 CalculateBallisticTrajectory(
            Vector2 start, 
            Vector2 target, 
            float initialSpeed,
            float gravity)
        {
            Vector2 displacement = target - start;
            float distance = displacement.Length();
            
            // 使用抛体运动公式计算发射角度
            float angle = CalculateLaunchAngle(distance, displacement.Y, initialSpeed, gravity);
            
            return new Vector2(
                Mathf.Cos(angle) * initialSpeed,
                Mathf.Sin(angle) * initialSpeed
            );
        }
        
        public static float CalculateLaunchAngle(float distance, float height, float speed, float gravity)
        {
            float speedSq = speed * speed;
            float discriminant = speedSq * speedSq - gravity * (gravity * distance * distance + 2 * height * speedSq);
            
            if (discriminant < 0) return Mathf.Pi / 4; // 默认45度
            
            return Mathf.Atan((speedSq - Mathf.Sqrt(discriminant)) / (gravity * distance));
        }
    }
}
```

**包含工具:**
- 数学辅助类 (向量计算、插值、随机)
- 数据结构 (对象池、优先队列、网格)
- 算法 (路径查找、空间分区)

#### 游戏状态管理

```csharp
// src/cs/Managers/GameStateManager.cs
using Godot;
using System;
using DreamerHeroines.Data;

namespace DreamerHeroines.Managers
{
    [GlobalClass]
    public partial class GameStateManager : Node
    {
        public static GameStateManager Instance { get; private set; }
        
        public GameState CurrentState { get; private set; }
        public PlayerData CurrentPlayer { get; private set; }
        
        public enum GameState
        {
            MainMenu,
            Playing,
            Paused,
            GameOver,
            LevelComplete
        }
        
        public override void _Ready()
        {
            Instance = this;
            CurrentState = GameState.MainMenu;
        }
        
        public void ChangeState(GameState newState)
        {
            if (CurrentState == newState) return;
            
            GameState previousState = CurrentState;
            CurrentState = newState;
            
            EmitSignal(SignalName.StateChanged, (int)previousState, (int)newState);
            
            HandleStateEnter(newState);
        }
        
        [Signal]
        public delegate void StateChangedEventHandler(int fromState, int toState);
        
        private void HandleStateEnter(GameState state)
        {
            switch (state)
            {
                case GameState.Paused:
                    GetTree().Paused = true;
                    break;
                case GameState.Playing:
                    GetTree().Paused = false;
                    break;
            }
        }
    }
}
```

#### 网络相关 (预留)

```csharp
// src/cs/Network/NetworkManager.cs
// 为未来多人模式预留的网络管理器

namespace DreamerHeroines.Network
{
    public partial class NetworkManager : Node
    {
        // 网络同步、房间管理、延迟补偿等
    }
}
```

#### 性能敏感计算

```csharp
// src/cs/Systems/SpatialHashGrid.cs
// 空间哈希网格用于高效碰撞检测

using Godot;
using System.Collections.Generic;

namespace DreamerHeroines.Systems
{
    public class SpatialHashGrid
    {
        private Dictionary<Vector2I, List<Node2D>> _cells;
        private float _cellSize;
        
        public SpatialHashGrid(float cellSize)
        {
            _cellSize = cellSize;
            _cells = new Dictionary<Vector2I, List<Node2D>>();
        }
        
        public void Insert(Node2D entity)
        {
            Vector2I cell = GetCell(entity.GlobalPosition);
            if (!_cells.ContainsKey(cell))
                _cells[cell] = new List<Node2D>();
            _cells[cell].Add(entity);
        }
        
        public List<Node2D> Query(Vector2 position, float radius)
        {
            List<Node2D> results = new List<Node2D>();
            Vector2I centerCell = GetCell(position);
            int cellRadius = Mathf.CeilToInt(radius / _cellSize);
            
            for (int x = -cellRadius; x <= cellRadius; x++)
            {
                for (int y = -cellRadius; y <= cellRadius; y++)
                {
                    Vector2I cell = centerCell + new Vector2I(x, y);
                    if (_cells.TryGetValue(cell, out var entities))
                    {
                        foreach (var entity in entities)
                        {
                            if (entity.GlobalPosition.DistanceTo(position) <= radius)
                                results.Add(entity);
                        }
                    }
                }
            }
            
            return results;
        }
        
        private Vector2I GetCell(Vector2 position)
        {
            return new Vector2I(
                Mathf.FloorToInt(position.X / _cellSize),
                Mathf.FloorToInt(position.Y / _cellSize)
            );
        }
    }
}
```

### 6.4 混用架构规范

#### 项目目录结构

```
project/
├── project.godot              # 项目配置文件
├── DreamerHeroines.csproj     # C# 项目文件
├── icon.svg
├── README.md
│
├── assets/                    # 资源文件夹
│   ├── sprites/
│   ├── animations/
│   ├── audio/
│   └── ...
│
├── resources/                 # Godot资源文件 (.tres)
│   ├── weapons/
│   ├── enemies/
│   └── ...
│
├── src/                       # GDScript 源代码
│   ├── autoload/              # 自动加载脚本
│   │   ├── game_manager.gd
│   │   └── audio_manager.gd
│   ├── characters/            # 角色相关 (GDScript)
│   │   ├── player.gd
│   │   └── enemy.gd
│   ├── weapons/               # 武器系统 (GDScript)
│   ├── enemies/               # 敌人系统 (GDScript)
│   ├── ui/                    # UI系统 (GDScript)
│   ├── effects/               # 特效系统 (GDScript)
│   └── utils/                 # GDScript 工具类
│
├── src/cs/                    # C# 源代码
│   ├── Data/                  # 数据定义
│   │   ├── PlayerData.cs
│   │   ├── WeaponData.cs
│   │   └── SaveData.cs
│   ├── Managers/              # 管理器
│   │   ├── GameStateManager.cs
│   │   └── SaveManager.cs
│   ├── Utils/                 # 工具类
│   │   ├── MathUtils.cs
│   │   └── SpatialHashGrid.cs
│   ├── Systems/               # 核心系统
│   │   └── InventorySystem.cs
│   └── Network/               # 网络相关 (预留)
│
├── scenes/                    # 场景文件
│   ├── levels/
│   ├── ui/
│   └── ...
│
└── docs/                      # 文档
    ├── GDD.md
    ├── TECH_SPEC.md
    └── ...
```

#### 命名空间规范

```csharp
// C# 命名空间结构
namespace DreamerHeroines          // 根命名空间
{
    namespace Data                 // 数据相关
    {
        public class PlayerData { }
    }
    
    namespace Managers             // 管理器
    {
        public class GameStateManager { }
    }
    
    namespace Utils                // 工具类
    {
        public static class MathUtils { }
    }
    
    namespace Systems              // 游戏系统
    {
        public class InventorySystem { }
    }
    
    namespace Network              // 网络
    {
        public class NetworkManager { }
    }
}
```

#### 跨语言调用约定

**GDScript 调用 C#:**

```gdscript
# src/characters/player.gd
# GDScript 调用 C# 数据管理器

@onready var game_state_manager: Node = get_node("/root/GameStateManager")

func _ready() -> void:
    # 调用 C# 方法
    game_state_manager.ChangeState(1)  # GameState.Playing = 1
    
    # 访问 C# 属性
    var current_state = game_state_manager.CurrentState
    
    # 获取 C# 返回的数据对象
    var player_data = game_state_manager.CurrentPlayer
    var player_level = player_data.Level
    var player_exp = player_data.Experience

func add_experience(amount: int) -> void:
    var player_data = game_state_manager.CurrentPlayer
    # 调用 C# 方法
    player_data.AddExperience(amount)
```

**C# 调用 GDScript:**

```csharp
// src/cs/Utils/GDScriptInterop.cs
using Godot;

namespace DreamerHeroines.Utils
{
    public static class GDScriptInterop
    {
        /// <summary>
        /// 安全地调用 GDScript 节点的方法
        /// </summary>
        public static Variant CallGDScriptMethod(Node target, string methodName, params Variant[] args)
        {
            if (target == null)
            {
                GD.PushError($"Cannot call {methodName} on null target");
                return default;
            }
            
            if (target.HasMethod(methodName))
            {
                return target.Call(methodName, args);
            }
            
            GD.PushError($"Method {methodName} not found on {target.Name}");
            return default;
        }
        
        /// <summary>
        /// 获取 GDScript 节点的属性
        /// </summary>
        public static T GetGDScriptProperty<T>(Node target, string propertyName)
        {
            if (target == null) return default;
            
            var value = target.Get(propertyName);
            if (value.VariantType == Variant.Type.Nil)
            {
                GD.PushError($"Property {propertyName} not found on {target.Name}");
                return default;
            }
            
            return value.As<T>();
        }
    }
}
```

```csharp
// src/cs/Managers/GameStateManager.cs
// C# 调用 GDScript 节点的示例

public void OnPlayerDeath()
{
    // 获取 GDScript 编写的 Player 节点
    var player = GetTree().GetFirstNodeInGroup("player");
    if (player != null)
    {
        // 调用 GDScript 方法
        GDScriptInterop.CallGDScriptMethod(player, "play_death_animation");
        
        // 获取 GDScript 属性
        float health = GDScriptInterop.GetGDScriptProperty<float>(player, "current_health");
    }
    
    ChangeState(GameState.GameOver);
}
```

#### 信号/事件通信规范

**C# 定义信号，GDScript 连接:**

```csharp
// src/cs/Managers/GameStateManager.cs
public partial class GameStateManager : Node
{
    [Signal]
    public delegate void StateChangedEventHandler(int fromState, int toState);
    
    [Signal]
    public delegate void PlayerDataUpdatedEventHandler(Resource playerData);
}
```

```gdscript
# src/ui/hud.gd
# GDScript 连接 C# 信号

@onready var game_state_manager = get_node("/root/GameStateManager")

func _ready() -> void:
    # 连接 C# 信号到 GDScript 方法
    game_state_manager.StateChanged.connect(_on_state_changed)
    game_state_manager.PlayerDataUpdated.connect(_on_player_data_updated)

func _on_state_changed(from_state: int, to_state: int) -> void:
    match to_state:
        0: # MainMenu
            hide_hud()
        1: # Playing
            show_hud()
        4: # GameOver
            show_game_over()

func _on_player_data_updated(player_data: Resource) -> void:
    # 访问 C# Resource 的属性
    health_bar.value = player_data.CurrentHealth / player_data.MaxHealth
    level_label.text = str(player_data.Level)
```

**GDScript 定义信号，C# 连接:**

```gdscript
# src/characters/player.gd

signal health_changed(new_health: float, max_health: float)
signal died
signal weapon_switched(weapon_data: Resource)
```

```csharp
// src/cs/Managers/UIManager.cs
public partial class UIManager : Node
{
    public override void _Ready()
    {
        // 获取 GDScript Player 并连接信号
        var player = GetTree().GetFirstNodeInGroup("player");
        if (player != null)
        {
            player.Connect("health_changed", Callable.From((float newHealth, float maxHealth) =>
            {
                OnPlayerHealthChanged(newHealth, maxHealth);
            }));
            
            player.Connect("died", Callable.From(OnPlayerDied));
        }
    }
    
    private void OnPlayerHealthChanged(float newHealth, float maxHealth)
    {
        // 更新 UI
    }
    
    private void OnPlayerDied()
    {
        // 显示死亡界面
    }
}
```

#### 资源引用规范

**C# Resource 类定义:**

```csharp
// src/cs/Data/WeaponData.cs
using Godot;

namespace DreamerHeroines.Data
{
    [GlobalClass]
    [Icon("res://assets/icons/weapon_icon.svg")]
    public partial class WeaponData : Resource
    {
        [ExportCategory("Basic Info")]
        [Export] public string WeaponId { get; set; }
        [Export] public string DisplayName { get; set; }
        [Export(PropertyHint.MultilineText)] public string Description { get; set; }
        
        [ExportCategory("Combat Stats")]
        [Export] public float Damage { get; set; } = 10f;
        [Export] public float FireRate { get; set; } = 600f;
        [Export] public int MagazineSize { get; set; } = 30;
        
        [ExportCategory("Assets")]
        [Export] public Texture2D Icon { get; set; }
        [Export] public PackedScene ProjectileScene { get; set; }
        [Export] public AudioStream FireSound { get; set; }
        
        // 计算属性
        public float FireInterval => 60f / FireRate;
    }
}
```

**GDScript 加载 C# Resource:**

```gdscript
# src/weapons/weapon.gd

var weapon_data: Resource  # 可以是 C# WeaponData

func _ready() -> void:
    # 加载 C# 定义的资源
    weapon_data = load("res://resources/weapons/ak47.tres")
    
    # 访问 C# 属性
    damage = weapon_data.Damage
    fire_rate = weapon_data.FireRate
    fire_interval = weapon_data.FireInterval  # 计算属性
```

### 6.5 代码示例

#### GDScript 调用 C# 类

```gdscript
# src/characters/player.gd - 使用 C# 存档系统

class_name Player
extends CharacterBody2D

@onready var save_manager: Node = get_node("/root/SaveManager")

func _ready() -> void:
    # 检查是否有存档
    if save_manager.HasSave(0):
        save_manager.LoadGame(0)
        apply_loaded_data()

func apply_loaded_data() -> void:
    var player_data = save_manager.CurrentSave.PlayerData
    
    # 从 C# 对象读取数据
    level = player_data.Level
    experience = player_data.Experience
    max_health = player_data.MaxHealth
    current_health = player_data.CurrentHealth

func save_progress() -> void:
    # 更新 C# 对象
    var player_data = save_manager.CurrentSave.PlayerData
    player_data.Level = level
    player_data.Experience = experience
    player_data.CurrentHealth = current_health
    
    # 调用 C# 保存方法
    save_manager.SaveGame(0)
```

#### C# 调用 GDScript 节点

```csharp
// src/cs/Systems/EnemySpawner.cs
using Godot;
using DreamerHeroines.Utils;

namespace DreamerHeroines.Systems
{
    [GlobalClass]
    public partial class EnemySpawner : Node
    {
        [Export] public PackedScene EnemyScene { get; set; }
        [Export] public int MaxEnemies { get; set; } = 50;
        
        private int _currentEnemyCount = 0;
        
        public void SpawnEnemy(Vector2 position)
        {
            if (_currentEnemyCount >= MaxEnemies) return;
            
            var enemy = EnemyScene.Instantiate<Node2D>();
            enemy.GlobalPosition = position;
            
            // 调用 GDScript 初始化方法
            GDScriptInterop.CallGDScriptMethod(enemy, "initialize", 
                _currentEnemyCount * 10); // 随关卡增加难度
            
            // 连接 GDScript 信号
            enemy.Connect("died", Callable.From(() => OnEnemyDied(enemy)));
            
            GetParent().AddChild(enemy);
            _currentEnemyCount++;
        }
        
        private void OnEnemyDied(Node enemy)
        {
            _currentEnemyCount--;
            
            // 调用 GDScript 掉落方法
            GDScriptInterop.CallGDScriptMethod(enemy, "drop_loot");
        }
    }
}
```

#### 信号跨语言连接

```gdscript
# src/weapons/projectile.gd
# GDScript 发射信号

class_name Projectile
extends Area2D

signal hit(target: Node, damage: float)
signal expired

func _on_body_entered(body: Node) -> void:
    hit.emit(body, damage)
    explode()
```

```csharp
// src/cs/Systems/CombatTracker.cs
// C# 监听 GDScript 信号

using Godot;
using System.Collections.Generic;

namespace DreamerHeroines.Systems
{
    [GlobalClass]
    public partial class CombatTracker : Node
    {
        private Dictionary<string, int> _hitCount = new();
        private float _totalDamage = 0f;
        
        public void TrackProjectile(Node projectile)
        {
            // 连接 GDScript 信号
            projectile.Connect("hit", Callable.From((Node target, float damage) =>
            {
                OnProjectileHit(target, damage);
            }));
            
            projectile.Connect("expired", Callable.From(() =>
            {
                OnProjectileExpired(projectile);
            }));
        }
        
        private void OnProjectileHit(Node target, float damage)
        {
            string targetName = target.Name;
            if (!_hitCount.ContainsKey(targetName))
                _hitCount[targetName] = 0;
            _hitCount[targetName]++;
            
            _totalDamage += damage;
            
            GD.Print($"Hit {targetName} for {damage} damage. Total: {_totalDamage}");
        }
        
        private void OnProjectileExpired(Node projectile)
        {
            // 清理
        }
    }
}
```

#### 共享数据类型定义

```csharp
// src/cs/Data/Enums.cs
// C# 定义枚举，GDScript 使用数值对应

namespace DreamerHeroines.Data
{
    public enum DamageType
    {
        Kinetic = 0,      // 动能
        Explosive = 1,    // 爆炸
        Fire = 2,         // 火焰
        Electric = 3,     // 电击
        Poison = 4        // 毒素
    }
    
    public enum WeaponCategory
    {
        AssaultRifle = 0,
        SMG = 1,
        LMG = 2,
        Sniper = 3,
        Shotgun = 4,
        Pistol = 5,
        Melee = 6,
        Special = 7
    }
}
```

```gdscript
# src/data/damage_info.gd
# GDScript 使用对应的枚举值

class_name DamageInfo
extends RefCounted

# 与 C# DamageType 对应
enum DamageType {
    KINETIC = 0,
    EXPLOSIVE = 1,
    FIRE = 2,
    ELECTRIC = 3,
    POISON = 4
}

var damage: float
var damage_type: int  # 使用 DamageType 枚举值
var source: Node
var hit_position: Vector2

func _init(p_damage: float, p_type: int, p_source: Node) -> void:
    damage = p_damage
    damage_type = p_type
    source = p_source
```

### 6.6 编译与构建

#### .csproj 配置

```xml
<!-- DreamerHeroines.csproj -->
<Project Sdk="Godot.NET.Sdk/4.6.1">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <TargetFramework Condition=" '$(GodotTargetPlatform)' == 'android' ">net8.0</TargetFramework>
    <TargetFramework Condition=" '$(GodotTargetPlatform)' == 'ios' ">net8.0</TargetFramework>
    <EnableDynamicLoading>true</EnableDynamicLoading>
    <RootNamespace>DreamerHeroines</RootNamespace>
    <AssemblyName>DreamerHeroines</AssemblyName>
    <LangVersion>12.0</LangVersion>
    <Nullable>enable</Nullable>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
  </PropertyGroup>
  
  <ItemGroup>
    <!-- 项目引用 -->
    <Compile Include="src/cs/**/*.cs" />
  </ItemGroup>
  
  <ItemGroup>
    <!-- 包引用 (如需要) -->
    <!-- <PackageReference Include="SomePackage" Version="1.0.0" /> -->
  </ItemGroup>
</Project>
```

#### 调试设置

**VS Code 配置 (.vscode/launch.json):**

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Play in Editor",
            "type": "godot-mono",
            "request": "launch",
            "mode": "playInEditor",
            "project": "${workspaceFolder}"
        },
        {
            "name": "Launch",
            "type": "godot-mono",
            "request": "launch",
            "mode": "executable",
            "preLaunchTask": "build",
            "executable": "${env:GODOT4}\godot.exe",
            "executableArguments": [
                "--path",
                "${workspaceRoot}"
            ]
        },
        {
            "name": "Attach",
            "type": "godot-mono",
            "request": "attach",
            "address": "localhost",
            "port": 23685
        }
    ]
}
```

**VS Code 任务配置 (.vscode/tasks.json):**

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "build",
            "command": "dotnet",
            "type": "process",
            "args": [
                "build",
                "${workspaceFolder}/DreamerHeroines.csproj"
            ],
            "problemMatcher": "$msCompile",
            "group": {
                "kind": "build",
                "isDefault": true
            }
        },
        {
            "label": "clean",
            "command": "dotnet",
            "type": "process",
            "args": [
                "clean",
                "${workspaceFolder}/DreamerHeroines.csproj"
            ],
            "problemMatcher": []
        }
    ]
}
```

**Rider 调试配置:**

1. 安装 Godot 插件
2. 配置 Godot 可执行文件路径: `Settings -> Languages & Frameworks -> Godot Engine`
3. 使用预设的 "Run" 和 "Debug" 配置

#### 发布构建流程

**Windows 桌面版:**

```bash
# 1. 构建 C# 项目
dotnet build DreamerHeroines.csproj -c Release

# 2. 导出 (通过 Godot CLI)
# 需要先在编辑器中创建导出预设
godot --headless --export-release "Windows Desktop" ./build/windows/DreamerHeroines.exe

# 或手动导出:
# 编辑器 -> 项目 -> 导出 -> Windows Desktop -> 导出项目
```

**Web 版 (注意: C# 在 Web 导出有限制):**

```bash
# Web 导出仅支持 GDScript
# C# 代码需要在导出前转换为 GDScript 或条件编译排除

# 条件编译示例 (C#):
#if !WEB_EXPORT
// C# 特定代码
#endif
```

**导出预设配置 (export_presets.cfg):**

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="./build/windows/DreamerHeroines.exe"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false

[preset.0.options]
custom_template/debug=""
custom_template/release=""
debug/export_console_wrapper=1
binary_format/embed_pck=false
texture_format/bptc=true
texture_format/s3tc=true
texture_format/etc=false
texture_format/etc2=false
binary_format/architecture="x86_64"
codesign/enable=false
```

**CI/CD 构建脚本 (GitHub Actions):**

```yaml
# .github/workflows/build.yml
name: Build

on: [push, pull_request]

jobs:
  build-windows:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
        with:
          version: 4.6.1
          use-dotnet: true
      
      - name: Build C#
        run: dotnet build DreamerHeroines.csproj -c Release
      
      - name: Export Windows
        run: |
          mkdir -p build/windows
          godot --headless --export-release "Windows Desktop" build/windows/DreamerHeroines.exe
      
      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: windows-build
          path: build/windows/
```

### 6.7 混用最佳实践

1. **避免循环依赖**: GDScript 和 C# 之间不要形成循环引用
2. **接口清晰**: C# 暴露给 GDScript 的方法使用简单类型 (int, float, string, Resource)
3. **错误处理**: 跨语言调用时做好 null 检查和异常处理
4. **性能考虑**: 高频调用的逻辑尽量保持在同一种语言内
5. **文档同步**: 修改 C# API 时同步更新 GDScript 调用代码
6. **版本一致**: 确保 Godot 编辑器版本与 .csproj 中的 SDK 版本一致

---

*文档结束*
