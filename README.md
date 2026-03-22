# 逐梦少女 (DreamerHeroines)

> **引擎**: Godot 4.6.1  
> **类型**: 2D横板射击  
> **风格**: 硬核动作  
> **版本**: 0.1.0

---

## 项目简介

《逐梦少女》是一款快节奏、高难度的2D横板射击游戏，灵感来源于《战火英雄》(Strike Force Heroes)系列。玩家扮演精英战士，在各种战场环境中与敌军作战，通过精准的射击、灵活的走位和战术决策生存下来。

### 核心体验

- **紧张刺激**: 快节奏战斗，敌人AI具有威胁性
- **技能驱动**: 玩家技术决定成败，而非数值碾压
- **战术深度**: 掩体利用、武器切换、技能配合
- **成长满足**: 角色培养与武器解锁提供长期动力

---

## 文件结构

```
DreamerHeroines/
├── project.godot                 # Godot项目配置文件
├── icon.svg                      # 项目图标
├── DreamerHeroines.csproj        # C#项目文件
├── README.md                     # 项目说明文档
├── .gitignore                    # Git忽略配置
│
├── assets/                       # 资源文件夹
│   ├── sprites/                  # 精灵图资源
│   │   └── icon.svg
│   ├── audio/                    # 音效和音乐
│   ├── fonts/                    # 字体文件
│   ├── animations/               # 动画资源
│   ├── tilesets/                 # 瓦片集
│   ├── particles/                # 粒子材质
│   └── shaders/                  # 着色器
│
├── config/                       # 配置文件
│   ├── gameplay_params.json      # 游戏玩法参数
│   ├── weapon_stats.json         # 武器属性配置
│   └── enemy_stats.json          # 敌人属性配置
│
├── docs/                         # 文档
│   ├── GDD.md                    # 游戏设计文档
│   ├── TECH_SPEC.md              # 技术规范文档
│   └── ASSET_GUIDE.md            # 资源规范指南
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
    │   ├── save_manager.gd       # 存档管理器
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
        │   ├── SaveManager.cs    # 存档系统
        │   └── GameStateManager.cs # 游戏状态管理
        ├── Utils/                # 工具类
        │   └── Extensions.cs     # 扩展方法
        └── Examples/             # 示例代码
            ├── CSharpToGdScript.cs
            ├── GdScriptCaller.cs
            ├── example_csharp_from_gdscript.gd
            └── example_gdscript_caller.gd
```

---

## 技术架构

### 双语言混用架构

本项目采用 **GDScript + C#** 混用架构，充分利用两种语言的优势：

| 语言 | 优势 | 适用场景 |
|------|------|----------|
| **GDScript** | 热重载支持、与引擎深度集成、快速迭代 | UI、关卡逻辑、快速原型 |
| **C#** | 类型安全、性能优异、工具链完善 | 核心计算、数据管理、复杂算法 |

### 核心系统

- **玩家系统** (GDScript): 输入处理、移动控制、动画状态机
- **武器系统** (C#): 伤害计算、弹道模拟、改装系统
- **敌人系统** (GDScript): AI行为树、寻路与战术移动
- **投射物系统** (C#): 物理轨迹、碰撞检测、对象池管理
- **存档系统** (C#): 数据序列化、多存档槽管理

---

## 快速开始

### 环境要求

- Godot 4.6.1 或更高版本
- .NET 8.0 SDK (用于C#编译)

### 运行项目

```bash
# 在Godot编辑器中打开
godot --editor --path .

# 运行主场景
godot --scene scenes/main.tscn

# 运行测试关卡
godot --scene scenes/test_level.tscn

# 构建C#项目
dotnet build DreamerHeroines.csproj
```

### 输入控制

| 动作 | 按键 |
|------|------|
| 移动 | WASD / 方向键 |
| 跳跃 | 空格 |
| 射击 | 鼠标左键 |
| 换弹 | R |
| 交互 | E |
| 下蹲 | Ctrl |
| 冲刺 | Shift |
| 武器切换 | Q |
| 暂停 | Esc |

---

## 物理层设置

| 层 | 名称 | 用途 |
|----|------|------|
| 1 | Player | 玩家角色 |
| 2 | Enemies | 敌人 |
| 3 | World | 地形、墙壁 |
| 4 | Projectiles | 投射物 |
| 5 | Items | 物品 |
| 6 | Platforms | 平台 |

---

## 开发规范

### 命名规范

| 类型 | GDScript | C# |
|------|----------|-----|
| 类名 | PascalCase | PascalCase |
| 方法 | snake_case | PascalCase |
| 变量 | snake_case | camelCase |
| 常量 | UPPER_SNAKE | PascalCase |
| 信号 | snake_case | PascalCase |

### 代码组织

- **GDScript**: `src/` 目录，按功能模块组织
- **C#**: `src/cs/` 目录，使用命名空间 `DreamerHeroines.*`
- **场景**: `scenes/` 目录，按类型分子文件夹
- **资源**: `assets/` 目录，按类型分类

---

## 文档索引

- [游戏设计文档 (GDD)](docs/GDD.md) - 完整的游戏设计规范
- [技术规范文档 (TECH_SPEC)](docs/TECH_SPEC.md) - 架构设计与编码规范
- [资源规范指南 (ASSET_GUIDE)](docs/ASSET_GUIDE.md) - 美术与音频资源规范

---

## 目标平台

| 平台 | 优先级 | 状态 |
|------|--------|------|
| PC (Windows) | P0 | 主要开发平台 |
| PC (Linux) | P1 | 兼容支持 |
| Web (HTML5) | P2 | 可选导出 |

---

## 自动化测试

### 快速运行

```bash
# 运行集成测试（完整游戏环境）
godot tests/scenes/test_launcher.tscn

# 运行单元测试（无需图形界面）
godot --headless -s addons/gut/gut_cmdln.gd -- -gdir=tests -ginclude_subdirs -gexit
```

### 测试类型

| 类型 | 命令 | 说明 |
|------|------|------|
| 集成测试 | `godot tests/scenes/test_launcher.tscn` | 完整功能测试，自动验证 |
| 单元测试 | `godot --headless -s addons/gut/gut_cmdln.gd` | 纯逻辑测试 |
| 编辑器测试 | GUT 面板 | 在 Godot 编辑器中运行 |

### 添加新测试

编辑 `tests/scripts/test_launcher.gd`，在 `_get_test_cases()` 添加：

```gdscript
{
    "name": "test_your_feature",
    "description": "测试描述",
},
```

然后在 `_run_test()` 的 `match` 语句中添加执行逻辑。

### 测试目录

```
tests/
├── scenes/test_launcher.tscn    # 自动化测试场景
├── scripts/test_launcher.gd     # 测试运行器
├── unit/                        # 单元测试
├── integration/                 # 集成测试
└── README.md                    # 详细文档
```

---

## 许可证

本项目为内部开发项目。

---

*最后更新: 2026-03-16*
