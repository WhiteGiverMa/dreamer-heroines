# 武器系统架构文档

> 本文档沉淀武器系统设计与实现经验，供后续开发复用

## 一、架构概述

### 1.1 设计目标

- **可复用性**：同一武器组件可被玩家、敌人、炮台等任意实体持有
- **可测试性**：通过信号驱动，便于单元测试验证
- **可配置性**：数值与逻辑分离，支持非程序员调参
- **性能优化**：对象池避免频繁创建/销毁

### 1.2 核心架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                      武器系统架构                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    @export     ┌──────────────┐               │
│  │   Weapon    │ ──────────────▶│ WeaponStats  │               │
│  │ (Node2D)    │                │  (Resource)  │               │
│  └──────┬──────┘                └──────────────┘               │
│         │                                                       │
│         │ 继承                                                   │
│         ▼                                                       │
│  ┌─────────────┐  ┌───────────────┐  ┌────────────────┐        │
│  │RifleWeapon  │  │ShotgunWeapon  │  │ HK416Weapon    │        │
│  └─────────────┘  └───────────────┘  └────────────────┘        │
│         │                                                       │
│         │ 信号 shot_fired                                       │
│         ▼                                                       │
│  ┌─────────────────────────────────────────────┐               │
│  │           ProjectileSpawner (Autoload)       │               │
│  └──────────────────────┬──────────────────────┘               │
│                         ▼                                       │
│  ┌─────────────────────────────────────────────┐               │
│  │              Projectile (Area2D)             │               │
│  └─────────────────────────────────────────────┘               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 1.3 文件结构

```
src/weapons/
├── weapon.gd              # 武器基类（核心，585行）
├── weapon_stats.gd        # 武器数据资源（53行）
├── rifle_weapon.gd        # 步枪武器（78行）
├── hk416_weapon.gd        # HK416突击步枪，@tool编辑器预览（203行）
├── shotgun_weapon.gd      # 霰弹枪武器（97行）
├── projectile.gd          # 投射物基类（298行）
├── weapon_lighting.gd     # 武器手电筒组件（345行）
├── tracer_effect.gd       # 弹道追踪光效（109行）
└── effects/
    ├── hit_effect.gd      # 命中特效
    └── impact_effect.gd   # 撞击特效

src/autoload/
└── projectile_spawner.gd  # 投射物对象池管理器

src/utils/
├── faction.gd             # 阵营工具类
├── layers.gd              # 碰撞层常量
└── damage_data.gd         # 伤害数据结构
```

---

## 二、核心设计模式

### 2.1 信号驱动组件 ⭐ 推荐复用

**问题**：传统设计中武器持有玩家引用，导致玩家/敌人无法复用同一武器代码

**解决方案**：武器不持有任何持有者引用，通过信号通知外部

```gdscript
# weapon.gd - 零依赖设计
class_name Weapon
extends Node2D

# === 信号定义 ===
signal shot_fired(position: Vector2, direction: Vector2, faction: String)
signal reload_started
signal reload_finished
signal ammo_changed(current: int, max: int)
signal out_of_ammo
signal spread_changed(current_spread: float, base_spread: float)

# 阵营标识（由持有者设置）
var faction: String = "player"
```

**持有者连接方式**：

```gdscript
# player.gd
func _setup_weapon_signals(weapon: Weapon) -> void:
    weapon.shot_fired.connect(_on_weapon_shot_fired)
    weapon.ammo_changed.connect(_on_weapon_ammo_changed)

func _on_weapon_shot_fired(pos: Vector2, dir: Vector2, faction: String) -> void:
    # 玩家决定如何生成投射物
    ProjectileSpawner.spawn_projectile(pos, dir, weapon.stats, faction_type)

# enemy_base.gd - 敌人同样可以持有武器
func _setup_weapon_signals(weapon: Weapon) -> void:
    weapon.shot_fired.connect(_on_weapon_shot_fired)
    weapon.faction = "enemy"  # 设置阵营
```

**优点**：
- 武器可被任意实体复用
- 便于单元测试（监听信号验证行为）
- 解耦持有者和武器实现

---

### 2.2 数据与逻辑分离 ⭐ 推荐复用

**问题**：数值硬编码在脚本中，策划调参需改代码

**解决方案**：使用 `Resource` 子类存储数据，通过 `@export` 注入

```gdscript
# weapon_stats.gd
class_name WeaponStats
extends Resource

@export_group("Combat Stats")
@export var damage: float = 10.0
@export var fire_rate: float = 1.0
@export var magazine_size: int = 30
@export var spread: float = 0.0
@export var is_automatic: bool = false

@export_group("Advanced")
@export var pierce_count: int = 0  # 穿透次数
@export var pellet_count: int = 1  # 弹丸数量（霰弹枪）
@export var use_ammo_system: bool = true  # 弹药系统开关
```

**使用方式**：

```gdscript
# weapon.gd
@export var stats: WeaponStats  # Inspector拖入.tres资源

func _fire(muzzle_pos: Vector2, aim_dir: Vector2) -> void:
    var damage = stats.damage  # 从数据读取
    var fire_interval = stats.fire_rate
```

**优点**：
- 非程序员可在 Inspector 调参
- `.tres` 是文本格式，支持版本控制
- 同一数据可被多个武器复用

---

### 2.3 对象池模式 ⭐ 推荐复用

**问题**：频繁创建/销毁投射物导致性能问题

**解决方案**：预创建对象池，复用实例

```gdscript
# projectile.gd - 投射物生命周期
var _is_active: bool = false

## 激活并发射（从池中取出时调用）
func fire() -> void:
    _is_active = true
    visible = true
    velocity = direction * speed
    _update_collision_mask()

## 回收到池（禁用但不销毁）
func deactivate_for_pool() -> void:
    _is_active = false
    visible = false
    velocity = Vector2.ZERO
    set_deferred("monitoring", false)

## 池可用性检查
func is_available_for_pool() -> bool:
    return is_inside_tree() and not _is_active
```

```gdscript
# projectile_spawner.gd - 对象池管理
var _projectile_pools: Dictionary[String, Array] = {}

func spawn_projectile(...) -> Node:
    var projectile = _get_from_pool(scene_path)
    projectile.fire()  # 激活
    return projectile

func _get_from_pool(scene_path: String) -> Node:
    var pool = _projectile_pools[scene_path]
    for p in pool:
        if p.is_available_for_pool():
            return p
    # 池中没有可用实例，创建新的
    var new_p = scene.instantiate()
    pool.append(new_p)
    return new_p

func return_to_pool(projectile: Node) -> void:
    projectile.deactivate_for_pool()
```

**优点**：
- 避免频繁 `instantiate()` / `queue_free()`
- 内存占用稳定
- 预热池可消除首次创建延迟

---

### 2.4 阵营碰撞系统

**问题**：玩家子弹、敌人子弹需要命中不同目标

**解决方案**：投射物根据阵营动态设置碰撞掩码

```gdscript
# faction.gd
class_name Faction
extends RefCounted

enum Type { UNKNOWN = 0, PLAYER = 1, ENEMY = 2 }

## 获取投射物碰撞掩码
static func get_projectile_collision_mask(faction_type: int) -> int:
    match faction_type:
        Type.ENEMY:  return 1 << 0  # 命中 Player 层
        Type.PLAYER: return 1 << 1  # 命中 Enemies 层
        _:          return (1 << 0) | (1 << 1)
```

```gdscript
# projectile.gd
var faction_type: int = Faction.Type.PLAYER

func _update_collision_mask() -> void:
    collision_mask = Faction.get_projectile_collision_mask(faction_type)
```

**优点**：
- 同一投射物代码适配所有阵营
- 新增阵营只需扩展枚举

---

### 2.5 检查点换弹机制

**问题**：换弹中途取消，进度如何处理？

**解决方案**：设置检查点，区分可取消/不可取消阶段

```gdscript
# weapon.gd
enum WeaponState { 
    IDLE, 
    RELOADING_PRE_CHECKPOINT,   # 换弹前半段（可取消，进度重置）
    RELOADING_POST_CHECKPOINT,  # 换弹后半段（取消后保留进度）
    DEPLOYING 
}

@export_range(0.0, 1.0, 0.01) var reload_checkpoint_percent: float = 0.5

func cancel_reload(reason: String = "") -> void:
    var checkpoint_elapsed = reload_time * reload_checkpoint_percent
    
    if _reload_elapsed >= checkpoint_elapsed:
        # 已过检查点，保留进度
        _checkpoint_reached = true
        _reload_elapsed = checkpoint_elapsed
    else:
        # 未过检查点，进度归零
        _reload_elapsed = 0.0
    
    _weapon_state = WeaponState.IDLE
```

**优点**：
- 类似《使命召唤》的换弹取消体验
- 避免换弹被打断后完全重来

---

### 2.6 测试钩子注入

**问题**：单元测试需要控制时间流逝

**解决方案**：注入可替换的时间提供器

```gdscript
# weapon.gd
var _time_provider: Callable = Callable()

func _get_now_usec() -> int:
    if _time_provider.is_valid():
        return int(_time_provider.call())
    return Time.get_ticks_usec()

func set_time_provider(provider: Callable) -> void:
    _time_provider = provider
```

**测试中使用**：

```gdscript
# test_weapon.gd
var mock_time: int = 0
weapon.set_time_provider(func(): return mock_time)

# 控制时间流逝
mock_time += 100000  # 前进 100ms
```

---

## 三、数据流

### 3.1 射击流程

```
玩家输入                    武器系统                    投射物系统
   │                          │                           │
   │ try_shoot(pos, dir)      │                           │
   ├─────────────────────────▶│                           │
   │                          │ 检查: 冷却、弹药、状态    │
   │                          │                           │
   │                          │ shot_fired.emit()         │
   │                          ├──────────────────────────▶│
   │                          │                           │ ProjectileSpawner.spawn()
   │                          │                           │    ↓
   │                          │                           │ 从池获取/创建
   │                          │                           │    ↓
   │                          │                           │ fire() 激活
   │                          │                           │    ↓
   │                          │                           │ 物理移动
   │                          │                           │    ↓
   │                          │                           │ 碰撞检测 → DamageSystem
   │                          │                           │    ↓
   │                          │                           │ deactivate_for_pool()
   │                          │                           │    ↓
   │                          │                           │ return_to_pool()
```

### 3.2 信号连接关系

| 信号 | 发射者 | 接收者 | 作用 |
|------|--------|--------|------|
| `shot_fired` | Weapon | Player/Enemy | 生成投射物 |
| `ammo_changed` | Weapon | HUD | 更新弹药显示 |
| `reload_started` | Weapon | HUD | 显示换弹进度条 |
| `reload_finished` | Weapon | HUD | 隐藏换弹进度条 |
| `out_of_ammo` | Weapon | AudioManager | 播放空仓音效 |
| `spread_changed` | Weapon | HUD | 更新准星扩散UI |

---

## 四、扩展指南

### 4.1 新增武器类型

```gdscript
# 1. 继承 Weapon 或其子类
class_name RocketLauncher
extends Weapon

# 2. 重写 _fire() 添加特殊行为
func _fire(muzzle_pos: Vector2, aim_dir: Vector2, fired_at_usec: int = -1) -> void:
    super._fire(muzzle_pos, aim_dir, fired_at_usec)
    
    # 添加后坐力、特殊弹丸等
    _apply_heavy_recoil()
    _spawn_rocket_trail(muzzle_pos)
```

### 4.2 新增投射物类型

```gdscript
# 1. 继承 Projectile
class_name HomingMissile
extends Projectile

@export var turn_rate: float = 5.0
var target: Node2D = null

# 2. 重写物理更新
func _physics_process(delta: float) -> void:
    if target and is_instance_valid(target):
        var to_target = (target.global_position - global_position).normalized()
        direction = direction.lerp(to_target, turn_rate * delta)
        velocity = direction * speed
    
    position += velocity * delta
```

### 4.3 新增阵营

```gdscript
# faction.gd
enum Type { 
    UNKNOWN = 0, 
    PLAYER = 1, 
    ENEMY = 2,
    NEUTRAL = 3,    # 新增中立阵营
    ALLY = 4        # 新增友军阵营
}

static func get_projectile_collision_mask(faction_type: int) -> int:
    match faction_type:
        Type.ENEMY:   return Layers.PLAYER | Layers.ALLY
        Type.PLAYER: return Layers.ENEMIES
        Type.ALLY:   return Layers.ENEMIES
        Type.NEUTRAL: return 0  # 不命中任何目标
        _: return Layers.PLAYER | Layers.ENEMIES
```

---

## 五、最佳实践

### 5.1 数据源选择

| 数据源 | 推荐场景 |
|--------|----------|
| `.tres` (Resource) | ✅ 实际游戏数据，唯一真源 |
| `.json` | ⚠️ 仅作为设计文档/参考值，不运行时加载 |

### 5.2 组件设计原则

1. **零持有者依赖**：组件不引用持有者，通过信号通信
2. **数据注入**：数值通过 `@export var stats: Resource` 注入
3. **测试友好**：提供可替换的依赖（如时间提供器）
4. **单一职责**：武器只管射击逻辑，投射物生成由外部决定

### 5.3 性能优化

1. **对象池**：高频创建/销毁的对象必须使用池
2. **屏幕剔除**：投射物离开屏幕自动回收
3. **生命周期限制**：设置 `lifetime` 防止无限飞行

---

## 六、相关文档

- [碰撞层规范](COLLISION_LAYERS.md)
- [技术规范](TECH_SPEC.md)
- [游戏设计文档](GDD.md)

---

*文档版本: 2026-04-10*
*基于武器系统审查经验沉淀*
