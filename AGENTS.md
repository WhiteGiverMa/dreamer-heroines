# AGENTS.md - Godot 4.6.1 项目规范

> **项目**: DreamerHeroines - 2D横板射击游戏
> **引擎**: Godot 4.6.1
> **语言**: GDScript + C# (混用架构)
> **版本**: 0.1.0-undone

---

## 构建与运行

```bash
# 打开编辑器
godot --editor --path .

# 运行场景
godot --scene scenes/main.tscn
godot --scene scenes/test_level.tscn

# C# 构建
dotnet build DreamerHeroines.csproj

# 导出
godot --export-release "Windows Desktop" ./build/
```

> ⚠️ **重要提醒**: 使用 Godot MCP 调试工具时，必须通过 `run_project` 启动游戏（而非手动启动）。MCP Server 在 Godot 内部作为 autoload 运行，监听 TCP 端口 **9090**。正确流程：
> 1. `godot-mcp_run_project` 启动游戏
> 2. `godot-mcp_game_*` 工具进行运行时调试
> 3. `godot-mcp_stop_project` 停止游戏

---

## 代码风格

遵循 [Godot 官方风格指南](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)。

### GDScript

**缩进**: 使用 **Tab**（非空格），编辑器显示为 4 个空格宽度。

**命名约定**:

| 类型 | 规范 | 示例 |
|------|------|------|
| 类名 | `PascalCase` | `class_name Player` |
| 函数 | `snake_case` | `func handle_input():` |
| 变量 | `snake_case` | `var max_speed: float` |
| 常量 | `UPPER_SNAKE_CASE` | `const MAX_SPEED = 300.0` |
| 信号 | `snake_case`（过去式） | `signal health_changed` |
| 私有成员 | `_snake_case`（下划线前缀） | `var _internal_counter` |
| 布尔变量 | `is_` / `can_` / `has_` 前缀 | `var is_active: bool` |

**代码示例**:

```gdscript
class_name Player
extends CharacterBody2D

const MAX_SPEED := 300.0
@export var max_speed: float = 300.0

var health: int = 100
signal health_changed(current: int, max: int)

func _ready() -> void:
func _handle_input() -> void:
```

### C#

**缩进**: 使用 **4 个空格**。

**命名约定**:

| 类型 | 规范 | 示例 |
|------|------|------|
| 命名空间 | `PascalCase` | `namespace DreamerHeroines.Core` |

**代码示例**:

```csharp
namespace DreamerHeroines.Core
{
    public class PlayerData     // 类名: PascalCase
    {
        private int _health;    // 私有字段: _camelCase
        public int Health { get; set; }  // 公共属性: PascalCase
    }
}
```

### 语言选择

| 场景 | 语言 | 原因 |
|------|------|------|
| 玩家/敌人/武器逻辑 | GDScript | 热重载，便于调优 |
| 数据类 (存档/玩家数据) | C# | 类型安全 |
| 数学工具类 | C# | 性能优势 |
| UI/场景逻辑 | GDScript | 与 Godot 集成更好 |

---

## 项目结构

```
config/             # 配置文件 (JSON)
├── gameplay_params.json
├── weapon_stats.json
└── enemy_stats.json

scenes/             # 场景文件
├── main.tscn       # 主场景
├── player.tscn     # 玩家
├── levels/         # 关卡
├── ui/             # UI
├── weapons/        # 武器
└── enemies/        # 敌人

src/                # 源代码
├── autoload/       # 单例
├── characters/     # 角色
├── weapons/        # 武器系统
├── enemies/        # 敌人AI
├── levels/         # 关卡管理
├── ui/             # UI脚本
├── utils/          # 工具类
└── cs/             # C# 代码
```

---

## 核心约定

### 物理层级

| 层级 | 名称 | 用途 |
|------|------|------|
| 1 | Player | 玩家 |
| 2 | Enemies | 敌人 |
| 3 | World | 世界 |
| 4 | Projectiles | 投射物 |
| 5 | Items | 物品 |
| 6 | Platforms | 平台 |

### 自动加载单例

- GameManager
- AudioManager
- InputManager
- SaveManager (C#)
- LevelManager

### 错误处理

- GDScript: `push_error()`, `push_warning()`
- C#: `GD.PushError()`, try-catch

---

## 代码格式化

```bash
# 安装工具
pip install gdtoolkit
dotnet tool install -g csharpier

# 格式化脚本
.\scripts\format.ps1              # 全部格式化
.\scripts\format.ps1 -GDScript    # 仅 GDScript
.\scripts\format.ps1 -CSharp      # 仅 C#
.\scripts\format.ps1 -Lint        # 仅检查
```

**风格规则**:
- 缩进: Tab (GDScript) / 4空格 (C#)
- 行长: 120字符
- 引号: 双引号

---

## 输入系统 (G.U.I.D.E)

本项目使用 G.U.I.D.E 插件管理输入。详细用法请参考：

**[GUIDE_CHEAT_SHEET.md](docs/GUIDE_CHEAT_SHEET.md)**

资源位置:
- 动作定义: `config/input/actions/*.tres`
- 映射上下文: `config/input/contexts/*.tres`

---

## 自动化测试

### Agent 快速使用

```bash
# 运行自动化集成测试
godot tests/scenes/test_launcher.tscn

# 运行单元测试 (headless)
godot --headless -s addons/gut/gut_cmdln.gd -- -gdir=tests -ginclude_subdirs -gexit
```

### 添加测试用例

编辑 `tests/scripts/test_launcher.gd`:

1. 在 `_get_test_cases()` 添加测试定义
2. 在 `_run_test()` 添加执行逻辑

### 测试文件位置

| 类型 | 路径 |
|------|------|
| 测试场景 | `tests/scenes/test_launcher.tscn` |
| 测试脚本 | `tests/scripts/test_launcher.gd` |
| 单元测试 | `tests/unit/*.gd` |
| 集成测试 | `tests/integration/*.gd` |
| Godot exe | `G:\dev\Godot_v4.6.1\godot.exe` |
---

## 文档索引

- [游戏设计文档](docs/GDD.md)
- [技术规范](docs/TECH_SPEC.md) 
- [资源规范](docs/ASSET_GUIDE.md)
- [输入系统速查](docs/GUIDE_CHEAT_SHEET.md)
- [G.U.I.D.E 文档](https://godotneers.github.io/G.U.I.D.E/)
- [初始化流程规范](docs/INIT_FLOW.md)

---

## Git

**频繁提交**: 每完成一个功能单元或修复一个bug立即提交