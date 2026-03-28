# AGENTS.md - DreamerHeroines 执行手册

> 项目：DreamerHeroines / 逐梦少女
> 引擎：Godot 4.6.1
> 架构：GDScript + C# 混用
> 目标：让 Agent 快速找到入口、遵守约束、完成验证

## 先看这里

- 本文件里的入口路径、autoload 顺序、端口等属于**当前项目事实**；改启动/全局系统前，先回查 `project.godot` 的 `[autoload]` 与相关配置
- 这是 **2D 横板射击** Godot 项目，主入口不是 `scenes/main.tscn`，而是 `project.godot` 中配置的 `res://scenes/ui/main_menu.tscn`
- 运行时初始化核心在 `src/autoload/boot_sequence.tscn` + `src/autoload/boot_sequence.gd`
- 全局系统大量依赖 **autoload**；改启动、存档、输入、关卡流程时，先看 `project.godot` 的 `[autoload]`
- 输入系统不是原生直连，项目通过 **G.U.I.D.E + `EnhancedInput` 包装层**工作
- 测试分两套：`tests/scenes/test_launcher.tscn`（集成/自动化入口）和 GUT headless（单元测试）

## 高优先级定位

| 任务 | 优先查看 | 说明 |
|---|---|---|
| 启动失败 / 初始化顺序 | `src/autoload/boot_sequence.gd` | 5 阶段启动链，很多问题都在依赖顺序 |
| 主流程 / 暂停 / 分数 / 死亡 | `src/autoload/game_manager.gd` | 核心状态协调器 |
| 关卡加载 / 进度 / checkpoint | `src/levels/level_manager.gd` | 不在 `autoload/`，但被 autoload 使用 |
| 存档 | `src/autoload/save_manager.gd`, `src/cs/Systems/SaveManager.cs` | GDScript 包装 C# 实现 |
| 输入 | `src/autoload/enhanced_input.gd`, `config/input/` | 先看 wrapper，再看 GUIDE 资源 |
| UI / 设置 / 准星 | `src/ui/`, `scenes/ui/`, `src/data/crosshair_settings.gd` | UI 逻辑和场景分离 |
| 武器系统 | `src/weapons/`, `config/weapon_stats.json` | 优先围绕 `weapon.gd` 与配置数据排查 |
| 测试新增/修复 | `tests/scripts/test_launcher.gd`, `tests/unit/`, `tests/integration/` | 集成测试入口不是 GUT 本身 |
| MCP 调试 | `config/mcp_server.json`, `project.godot` | 依赖 autoload 的 MCP server |

## 项目特有约定

### 语言分工

- 仓库当前偏向 **GDScript 主流程 + C# 补强**；不要随意把现有 GDScript 主流程迁到 C#

### 输入系统

- 优先使用 `EnhancedInput`，不要直接把新逻辑耦合到 GUIDE 底层 API
- 输入资源在：
  - `config/input/actions/*.tres`
  - `config/input/contexts/*.tres`
- 输入/菜单切换问题，优先排查 context 是否启停正确

### 启动链路

`BootSequence` 按阶段初始化：

1. `CSharpSaveManager`, `AudioManager`, `EffectManager`, `ProjectileSpawner`, `LocalizationManager`
2. `EnhancedInput`
3. `SaveManager`
4. `LevelManager`
5. `GameManager`

- 改初始化逻辑时，先确认依赖在哪个 phase；不要只在单个 manager 内“补救”顺序问题
- 全局系统基类是 `src/base/game_system.gd`

### 武器系统

- 武器主逻辑优先看 `src/weapons/weapon.gd`
- 武器数值配置来自 `config/weapon_stats.json`
- 新功能优先沿着 `weapon.gd` / `WeaponStats` 方向扩展，不要在别处重复堆武器状态机

### 配置与数据

- 可调参数优先看 `config/`，不要先在脚本里硬编码
- 常见入口：
  - `config/gameplay_params.json`
  - `config/weapon_stats.json`
  - `config/enemy_stats.json`
  - `config/levels/`
  - `config/waves/`

### 碰撞层

项目固定使用以下 2D physics layer：

1. Player
2. Enemies
3. World
4. Projectiles
5. Items
6. Platforms

改碰撞时同时核对：`project.godot`、`src/utils/layers.gd`、相关 scene/body mask。

## 代码风格：只保留会踩坑的部分

- GDScript **必须使用 Tab 缩进**，不是空格；C# 使用 4 空格
- `.editorconfig` 是实际落地规则；`pyproject.toml` 约束 gdtoolkit

## 常用命令

```bash
# 打开编辑器
godot --editor --path .

# 运行项目主入口（项目配置）
godot --path .

# 直接运行测试关卡
godot --scene scenes/test_level.tscn

# C# 构建
dotnet build DreamerHeroines.csproj

# GUT 单元测试（headless）
godot --headless -s addons/gut/gut_cmdln.gd -- -gdir=tests -ginclude_subdirs -gexit

# 自动化/集成测试入口
godot tests/scenes/test_launcher.tscn

# 格式化 / 检查
.\scripts\format.ps1
.\scripts\format.ps1 -Check
.\scripts\format.ps1 -GDScript
.\scripts\format.ps1 -CSharp
```

## MCP / 运行时调试

- 使用 Godot MCP 调试时，**必须通过 `run_project` 启动**，不要手动开游戏再假设 MCP 已挂上
- 默认配置在 `config/mcp_server.json`，首选端口 `9090`，允许向上回退
- 启动后会输出：`MCP_SERVER_ENDPOINT <host> <port>`
- 运行时端口文件：`user://mcp_server_runtime.json`

常用开发命令：

```bash
curl -X POST localhost:9090 -d '{"command":"dev_mode","params":{"enabled":true}}'
curl -X POST localhost:9090 -d '{"command":"dev_cmd","params":{"cmd":"god_mode on"}}'
curl -X POST localhost:9090 -d '{"command":"dev_cmd","params":{"cmd":"spawn melee"}}'
curl -X POST localhost:9090 -d '{"command":"dev_cmd","params":{"cmd":"wave next"}}'
```

## 测试工作流

- **单元测试**：`tests/unit/`，主要走 GUT headless
- **集成测试**：`tests/integration/`，仍通过 GUT 体系组织
- **自动化入口**：`tests/scenes/test_launcher.tscn` + `tests/scripts/test_launcher.gd`
- 新增自动化用例时：
  1. 在 `_get_test_cases()` 注册
  2. 在对应执行逻辑里补分支

如果测试和输入相关：

- 先确认 GUIDE context 是否启用
- headless 不能覆盖所有依赖渲染循环的输入行为
- 需要真实运行时交互时，优先 MCP + `run_project`

## 不要这样做

- 不要绕过 `EnhancedInput` 直接散落调用底层输入实现
- 不要在不检查 phase 依赖的前提下修改启动顺序
- 不要绕开 `weapon.gd` / `config/weapon_stats.json`，在别处重复实现武器主逻辑
- 不要绕过 hooks：禁止 `git commit --no-verify` / `-n`
- 不要忘记修复尾随空格；仓库已有 `scripts/fix-trailing-whitespace.ps1 -Restage`
- 不要默认 headless 可以验证所有输入行为

## 提交与验证

- 改代码后先验证，再提交
- 推荐 Git 包装器：

```powershell
.\scripts\git-wrapper.ps1 status
.\scripts\git-wrapper.ps1 commit -m "message"
```

- 若提交被尾随空格拦截：

```powershell
.\scripts\fix-trailing-whitespace.ps1 -Restage
```

## 相关文档

- 需要补背景时，再看：`docs/GDD.md`、`docs/TECH_SPEC.md`、`docs/INIT_FLOW.md`、`docs/GUIDE_CHEAT_SHEET.md`、`tests/README.md`

## 参考项目

参考项目地址：`G:\dev\godot-references`