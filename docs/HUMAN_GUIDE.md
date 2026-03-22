# 逐梦少女 - 人类开发者指南

> **项目**: DreamerHeroines (逐梦少女)  
> **引擎**: Godot 4.6.1  
> **架构**: GDScript + C# 混用  
> **版本**: 1.0  
> **最后更新**: 2026-03-16

---

## 1. 项目概述

### 1.1 游戏类型

《逐梦少女》是一款快节奏、高难度的2D横板射击游戏，灵感来源于《战火英雄》(Strike Force Heroes)系列。核心体验包括：

- **紧张刺激**: 快节奏战斗，敌人AI具有威胁性
- **技能驱动**: 玩家技术决定成败，而非数值碾压
- **战术深度**: 掩体利用、武器切换、技能配合
- **成长满足**: 角色培养与武器解锁提供长期动力

### 1.2 技术栈

| 组件 | 技术 | 用途 |
|------|------|------|
| 游戏引擎 | Godot 4.6.1 | 核心引擎 |
| 脚本语言 | GDScript | 玩家、敌人、UI、关卡逻辑 |
| 脚本语言 | C# (.NET 8.0) | 数据管理、存档、工具类 |
| 渲染器 | GL Compatibility | 2D渲染，支持Web导出 |
| 物理引擎 | Godot Physics 2D | 碰撞检测、刚体模拟 |

### 1.3 核心特性

- **双语言混用架构**: GDScript负责快速迭代的游戏逻辑，C#负责类型安全的数据管理
- **数据驱动设计**: 武器、敌人参数通过JSON配置，支持运行时调整
- **对象池系统**: 特效和投射物使用对象池，避免频繁实例化
- **Fallback资源系统**: 特效支持多级fallback，确保资源缺失时游戏仍可运行

---

## 2. 项目结构

### 2.1 完整目录树

```
DreamerHeroines/
├── project.godot                 # Godot项目配置文件
├── DreamerHeroines.csproj        # C#项目文件
├── README.md                     # 项目说明文档
├── AGENTS.md                     # 编码规范文档
│
├── assets/                       # 资源文件夹
│   ├── sprites/                  # 精灵图资源
│   ├── audio/                    # 音效和音乐
│   ├── fonts/                    # 字体文件
│   ├── animations/               # 动画资源
│   ├── tilesets/                 # 瓦片集
│   ├── particles/                # 粒子材质
│   └── shaders/                  # 着色器
│
├── config/                       # 配置文件（需人工调优）
│   ├── gameplay_params.json      # 游戏玩法参数
│   ├── weapon_stats.json         # 武器属性配置
│   └── enemy_stats.json          # 敌人属性配置
│
├── docs/                         # 文档
│   ├── GDD.md                    # 游戏设计文档
│   ├── TECH_SPEC.md              # 技术规范文档
│   ├── ASSET_GUIDE.md            # 资源规范指南
│   └── HUMAN_GUIDE.md            # 本文件
│
├── resources/                    # Godot资源文件
│   └── default_bus_layout.tres   # 音频总线布局
│
├── scenes/                       # 场景文件
│   ├── main.tscn                 # 主场景
│   ├── test_level.tscn           # 测试关卡
│   ├── player.tscn               # 玩家场景
│   ├── levels/                   # 关卡场景
│   ├── ui/                       # UI场景
│   │   ├── main_menu.tscn        # 主菜单
│   │   └── hud.tscn              # HUD界面
│   ├── weapons/                  # 武器场景
│   │   ├── rifle.tscn            # 步枪
│   │   └── shotgun.tscn          # 霰弹枪
│   └── enemies/                  # 敌人场景
│       ├── flying_enemy.tscn     # 飞行敌人
│       ├── melee_enemy.tscn      # 近战敌人
│       └── ranged_enemy.tscn     # 远程敌人
│
└── src/                          # 源代码
    ├── autoload/                 # 自动加载脚本 (单例)
    │   ├── game_manager.gd       # 游戏管理器
    │   ├── audio_manager.gd      # 音频管理器
    │   ├── input_manager.gd      # 输入管理器
    │   ├── save_manager.gd       # 存档管理器(GDScript包装)
    │   └── effect_manager.gd     # 特效管理器
    │
    ├── characters/               # 角色相关
    │   └── player.gd             # 玩家控制器
    │
    ├── weapons/                  # 武器系统
    │   ├── weapon_base.gd        # 武器基类
    │   ├── rifle.gd              # 步枪逻辑
    │   ├── shotgun.gd            # 霰弹枪逻辑
    │   ├── projectile.gd         # 投射物
    │   └── effects/              # 武器特效
    │       ├── hit_effect.tscn
    │       └── impact_effect.tscn
    │
    ├── enemies/                  # 敌人系统
    │   ├── enemy_base.gd         # 敌人基类
    │   ├── flying_enemy.gd       # 飞行敌人AI
    │   ├── melee_enemy.gd        # 近战敌人AI
    │   └── ranged_enemy.gd       # 远程敌人AI
    │
    ├── levels/                   # 关卡系统
    │   ├── level_manager.gd      # 关卡管理器
    │   ├── level_data.gd         # 关卡数据
    │   └── checkpoint.gd         # 检查点
    │
    ├── ui/                       # UI系统
    │   ├── main_menu.gd          # 主菜单逻辑
    │   ├── hud.gd                # HUD逻辑
    │   ├── pause_menu.gd         # 暂停菜单
    │   └── game_over.gd          # 游戏结束
    │
    ├── utils/                    # 工具类
    │   ├── state_machine.gd      # 状态机
    │   ├── health_component.gd   # 生命值组件
    │   ├── hitbox.gd             # 伤害框
    │   ├── hurtbox.gd            # 受击框
    │   └── resource_loader_utils.gd  # 资源加载工具
    │
    └── cs/                       # C#源代码
        ├── Core/                 # 核心工具
        │   ├── MathUtils.cs      # 数学工具
        │   ├── ObjectPool.cs     # 对象池
        │   └── SpatialHashGrid.cs # 空间哈希网格
        ├── Data/                 # 数据定义
        │   ├── PlayerData.cs     # 玩家数据
        │   ├── WeaponData.cs     # 武器数据
        │   ├── SaveData.cs       # 存档数据
        │   └── GameConfig.cs     # 游戏配置
        ├── Systems/              # 核心系统
        │   ├── SaveManager.cs    # 存档系统(C#)
        │   └── GameStateManager.cs # 游戏状态管理
        ├── Utils/                # 工具类
        │   └── Extensions.cs     # 扩展方法
        └── Examples/             # 示例代码
            ├── CSharpToGdScript.cs
            └── GdScriptCaller.cs
```

### 2.2 关键文件说明

| 文件路径 | 说明 | 语言 |
|----------|------|------|
| `src/autoload/game_manager.gd` | 游戏状态、分数、关卡切换管理 | GDScript |
| `src/autoload/audio_manager.gd` | 音效播放、音乐管理、音量控制 | GDScript |
| `src/autoload/input_manager.gd` | 输入处理、控制方案切换 | GDScript |
| `src/autoload/effect_manager.gd` | 特效创建、缓存、对象池 | GDScript |
| `src/autoload/save_manager.gd` | 存档管理器GDScript包装 | GDScript |
| `src/characters/player.gd` | 玩家移动、射击、受伤逻辑 | GDScript |
| `src/cs/Systems/SaveManager.cs` | C#存档系统实现 | C# |

---

## 3. 混用架构说明

### 3.1 GDScript/C# 分工原则

| 使用场景 | 语言 | 理由 |
|----------|------|------|
| 玩家/敌人/武器逻辑 | GDScript | 热重载支持，快速迭代 |
| 数据类（Save/PlayerData） | C# | 类型安全，IDE支持好 |
| 数学/工具函数 | C# | 性能更好 |
| UI/场景逻辑 | GDScript | 与Godot集成更紧密 |
| 状态机 | GDScript | 易于调试和修改 |
| 存档系统 | C# | 复杂数据结构，需要强类型 |

### 3.2 互操作方式

#### GDScript 调用 C#

```gdscript
# 获取C#单例
@onready var save_manager: Node = get_node("/root/CSharpSaveManager")

func _ready() -> void:
    # 调用C#方法
    if save_manager.HasSave(0):
        save_manager.LoadGame(0)
    
    # 访问C#属性
    var player_data = save_manager.CurrentPlayer
    var level = player_data.Level
```

#### C# 调用 GDScript

```csharp
// C#调用GDScript方法
var player = GetTree().GetFirstNodeInGroup("player");
if (player != null)
{
    // 调用GDScript方法（使用snake_case）
    player.Call("take_damage", 10);
    
    // 连接GDScript信号
    player.Connect("health_changed", 
        Callable.From((float newHealth, float maxHealth) => 
        {
            OnPlayerHealthChanged(newHealth, maxHealth);
        }));
}
```

### 3.3 跨语言信号通信

```gdscript
# GDScript定义信号 (player.gd)
signal health_changed(current: int, max: int)
signal died
```

```csharp
// C#连接GDScript信号
public override void _Ready()
{
    var player = GetNode<Node>("/root/Main/Player");
    player.Connect("health_changed", 
        Callable.From<int, int>(OnHealthChanged));
}

private void OnHealthChanged(int current, int max)
{
    GD.Print($"Health: {current}/{max}");
}
```

---

## 4. 物理碰撞层配置

### 4.1 层定义（project.godot）

```ini
[layer_names]
2d_physics/layer_1="Player"
2d_physics/layer_2="Enemies"
2d_physics/layer_3="World"
2d_physics/layer_4="Projectiles"
2d_physics/layer_5="Items"
2d_physics/layer_6="Platforms"
```

| 层 | 名称 | 用途 | 碰撞掩码建议 |
|----|------|------|--------------|
| 1 | Player | 玩家角色 | World, Enemies, Items, Platforms |
| 2 | Enemies | 敌人 | World, Player, Projectiles, Platforms |
| 3 | World | 地形、墙壁 | 所有（作为障碍物） |
| 4 | Projectiles | 玩家投射物 | Enemies, World |
| 5 | Items | 道具、拾取物 | Player |
| 6 | Platforms | 平台（可单向通过） | Player, Enemies |

### 4.2 代码中配置碰撞层

```gdscript
# 玩家设置（Layer 1）
func _ready():
    collision_layer = 1 << 0  # Layer 1
    collision_mask = (1 << 2) | (1 << 1) | (1 << 4)  # World, Enemies, Items

# 敌人设置（Layer 2）
func _ready():
    collision_layer = 1 << 1  # Layer 2
    collision_mask = (1 << 2) | (1 << 0) | (1 << 3)  # World, Player, Projectiles

# 投射物设置（Layer 4）
func _ready():
    collision_layer = 1 << 3  # Layer 4
    collision_mask = (1 << 2) | (1 << 1)  # World, Enemies
```

### 4.3 常见问题

**问题1: 投射物不命中敌人**
- 检查投射物的`collision_mask`是否包含敌人层
- 检查敌人的`collision_layer`是否正确设置

**问题2: 玩家穿过地面**
- 确保地面物体在World层（Layer 3）
- 检查玩家的`collision_mask`包含World层

**问题3: 道具无法拾取**
- 道具应在Items层（Layer 5）
- 玩家的`collision_mask`需要包含Layer 5

---

## 5. 需要人工调优的配置

### 5.1 gameplay_params.json

位于 `config/gameplay_params.json`，包含所有影响游戏手感的参数。

#### 关键参数说明

**玩家移动参数**:
```json
"max_speed": { "value": 300.0, "recommended_range": "250-400" }
"acceleration": { "value": 2000.0, "recommended_range": "1500-3000" }
"deceleration": { "value": 1500.0, "recommended_range": "1000-2000" }
"sprint_multiplier": { "value": 1.5, "recommended_range": "1.3-2.0" }
```

**跳跃参数**:
```json
"jump_velocity": { "value": -600.0, "recommended_range": "-500 ~ -800" }
"coyote_time": { "value": 0.1, "recommended_range": "0.05-0.15" }
"jump_buffer_time": { "value": 0.1, "recommended_range": "0.05-0.15" }
```

**硬核风格建议**:
- `enable_double_jump`: false（关闭二段跳）
- `max_health`: 80-100（较低生命值）
- `aim_assist`: 0.0（无瞄准辅助）
- `checkpoint_heal`: false（检查点不回血）

### 5.2 weapon_stats.json

位于 `config/weapon_stats.json`，定义所有武器数值。

#### 武器平衡参考

| 武器 | 伤害 | 射速 | 弹匣 | 特点 |
|------|------|------|------|------|
| rifle_basic | 15 | 0.1s | 30 | 均衡型 |
| shotgun_basic | 12x8 | 0.8s | 6 | 近战爆发 |
| sniper_basic | 80 | 1.5s | 5 | 高伤害低射速 |
| smg_basic | 8 | 0.05s | 45 | 高射速低伤害 |

**调优提示**:
- DPS = damage / fire_rate
- 霰弹枪实际伤害 = damage * pellet_count
- 建议每次只调整一个参数，测试后再继续

### 5.3 enemy_stats.json

位于 `config/enemy_stats.json`，定义所有敌人数值。

#### 敌人类型参考

| 敌人类型 | 生命值 | 速度 | 伤害 | 特点 |
|----------|--------|------|------|------|
| melee_grunt | 30 | 120 | 15 | 基础杂兵 |
| melee_fast | 20 | 220 | 10 | 快速突击 |
| melee_tank | 120 | 80 | 35 | 重装肉盾 |
| ranged_basic | 25 | 100 | 12 | 远程射手 |
| flying_basic | 20 | 140 | 8 | 飞行单位 |

**调优提示**:
- 敌人速度建议不超过玩家速度的80%
- 检测范围决定AI的主动性
- 击退抗性影响武器控制效果

---

## 6. 占位符资源策略

### 6.1 Fallback系统说明

`EffectManager`实现了三级fallback系统：

1. **正式资源**: `assets/effects/` 下的完整特效
2. **占位符资源**: `src/weapons/effects/` 下的简化特效
3. **运行时创建**: 代码动态生成的基本特效

### 6.2 配置示例

```gdscript
# src/autoload/effect_manager.gd
const EFFECT_PATHS = {
    "hit_bullet": {
        "primary": "res://assets/effects/hit_bullet.tscn",
        "placeholder": "res://src/weapons/effects/hit_effect.tscn",
        "type": "hit_effect"
    },
    "explosion_small": {
        "primary": "res://assets/effects/explosion_small.tscn",
        "placeholder": "",  # 无占位符，使用运行时创建
        "type": "explosion"
    }
}
```

### 6.3 运行时占位符

当没有可用资源时，`EffectManager`会创建简单的ColorRect作为占位符：

```gdscript
# 创建自定义特效
EffectManager.create_custom_effect(
    position,           # 位置
    Color.RED,          # 颜色
    Vector2(10, 10),    # 大小
    0.5,                # 持续时间
    "fade_out"          # 动画类型
)
```

### 6.4 开发工作流

1. **早期开发**: 使用运行时占位符，快速验证玩法
2. **原型阶段**: 创建简单的占位符场景
3. **美术阶段**: 替换为正式资源，保持相同接口

---

## 7. 常见开发问题

### 7.1 解析错误

**问题**: `Parse Error: Unexpected token`

**解决**:
```gdscript
# 检查JSON文件格式
# 确保最后一项没有逗号
{
    "key1": "value1",
    "key2": "value2"  # 正确：无逗号
}
```

### 7.2 信号问题

**问题**: 信号连接了但不触发

**解决**:
```gdscript
# 确保在_ready()中连接
func _ready():
    # 正确
    body_entered.connect(_on_body_entered)

# 检查信号名拼写（GDScript使用snake_case）
signal health_changed  # 定义
health_changed.emit()  # 发射

# C#中连接GDScript信号
player.Connect("health_changed", Callable.From(...))
```

### 7.3 C#互操作问题

**问题**: C#调用GDScript方法失败

**解决**:
```csharp
// 方法名使用snake_case
player.Call("take_damage", 10);

// 检查节点是否存在
if (player == null)
{
    GD.PushError("Player node not found");
    return;
}

// 检查方法是否存在
if (player.HasMethod("take_damage"))
{
    player.Call("take_damage", 10);
}
```

**问题**: 类型转换失败

**解决**:
```csharp
// 使用Variant转换
var value = player.Get("current_health");
if (value.VariantType == Variant.Type.Int)
{
    int health = value.As<int>();
}
```

### 7.4 热重载失效

**问题**: 修改GDScript后没有生效

**解决**:
- 确保Godot编辑器处于运行状态
- 检查是否有语法错误（红色波浪线）
- 保存文件（Ctrl+S）后等待1-2秒
- 某些修改（如导出变量）需要重启场景

---

## 8. 调试技巧

### 8.1 日志输出

```gdscript
# GDScript
print("普通日志")
push_warning("警告信息")
push_error("错误信息")

# 带格式的输出
print("Player health: %d/%d" % [current_health, max_health])
```

```csharp
// C#
GD.Print("普通日志");
GD.PrintErr("错误信息");
GD.Print($"Player position: {Position}");
```

### 8.2 运行时检查

```gdscript
# 检查节点是否存在
if not is_instance_valid(node):
    push_error("Node is null or freed")
    return

# 检查是否在树中
if not is_inside_tree():
    return

# 检查属性是否存在
if player.has_method("take_damage"):
    player.take_damage(10)
```

### 8.3 命令行运行

```bash
# 打开编辑器
godot --editor --path .

# 运行主场景
godot --scene scenes/main.tscn

# 运行测试关卡
godot --scene scenes/test_level.tscn

# 调试模式运行
godot --debug --scene scenes/test_level.tscn
```

### 8.4 性能监控

```gdscript
# 简单的性能监控
var start_time = Time.get_ticks_msec()
# ... 执行代码 ...
var elapsed = Time.get_ticks_msec() - start_time
print("Operation took %d ms" % elapsed)
```

---

## 9. 扩展开发

### 9.1 添加新武器

1. **创建武器数据**（`config/weapon_stats.json`）:
```json
"my_new_weapon": {
    "weapon_name": "新武器",
    "damage": { "value": 25 },
    "fire_rate": { "value": 0.15 },
    "magazine_size": { "value": 20 }
}
```

2. **创建武器场景**（`scenes/weapons/my_weapon.tscn`）

3. **创建武器脚本**（`src/weapons/my_weapon.gd`）:
```gdscript
extends "weapon_base.gd"

func _init():
    weapon_id = "my_new_weapon"
```

### 9.2 添加新敌人

1. **创建敌人数据**（`config/enemy_stats.json`）

2. **创建敌人场景**（`scenes/enemies/my_enemy.tscn`）

3. **创建敌人脚本**（`src/enemies/my_enemy.gd`）:
```gdscript
extends "enemy_base.gd"

func _ready():
    super._ready()
    enemy_type = "my_enemy"
```

### 9.3 添加新特效

1. **创建特效场景**（`src/weapons/effects/my_effect.tscn`）

2. **注册到EffectManager**:
```gdscript
# 在effect_manager.gd的EFFECT_PATHS中添加
"my_effect": {
    "primary": "res://assets/effects/my_effect.tscn",
    "placeholder": "res://src/weapons/effects/my_effect.tscn",
    "type": "custom"
}
```

3. **播放特效**:
```gdscript
EffectManager.play_effect("my_effect", global_position)
```

---

## 10. 构建与发布

### 10.1 构建检查清单

- [ ] C#项目编译通过 (`dotnet build`)
- [ ] 所有场景可正常加载
- [ ] 配置文件JSON格式正确
- [ ] 无缺失的资源引用（检查输出日志）
- [ ] 物理层配置正确
- [ ] Autoload单例配置完整

### 10.2 导出配置

```bash
# 构建C#项目
dotnet build DreamerHeroines.csproj

# 导出Windows版本
godot --export-release "Windows Desktop" ./build/

# 导出Web版本
godot --export-release "Web" ./build/web/
```

### 10.3 平台支持

| 平台 | C#支持 | 状态 |
|------|--------|------|
| Windows | 完整 | P0 - 主要平台 |
| Linux | 完整 | P1 - 兼容支持 |
| macOS | 完整 | P1 - 兼容支持 |
| Web | 实验性 | P2 - 可选导出 |

---

## 11. 参考文档

### 11.1 项目文档

| 文档 | 路径 | 内容 |
|------|------|------|
| 游戏设计文档 | `docs/GDD.md` | 完整的游戏设计规范、玩法机制 |
| 技术规范文档 | `docs/TECH_SPEC.md` | 架构设计、编码规范、API参考 |
| 资源规范指南 | `docs/ASSET_GUIDE.md` | 美术与音频资源规范 |
| 编码规范 | `AGENTS.md` | 代码风格、命名规范 |

### 11.2 外部参考

- [Godot 4.6 官方文档](https://docs.godotengine.org/en/4.6/)
- [GDScript 参考](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdscript/index.html)
- [C# in Godot](https://docs.godotengine.org/en/4.6/tutorials/scripting/c_sharp/index.html)

### 11.3 配置文件索引

| 文件 | 路径 | 说明 |
|------|------|------|
| 游戏参数 | `config/gameplay_params.json` | 移动、跳跃、战斗参数 |
| 武器数值 | `config/weapon_stats.json` | 所有武器的属性配置 |
| 敌人数值 | `config/enemy_stats.json` | 所有敌人的属性配置 |
| 项目配置 | `project.godot` | 物理层、Autoload、输入映射 |

---

*文档结束 - 祝开发顺利！*
