# 自动化测试方案

## 方案一：Godot 编辑器内运行（推荐）

### 步骤
1. 打开 Godot 编辑器
2. 点击顶部 "GUT" 标签页
3. 点击 "Run Tests" 按钮

### 优点
- ✅ 输入系统完全工作
- ✅ 可视化结果
- ✅ 支持断点调试

---

## 方案二：命令行 + 游戏进程（CI/CD）

### 需要用户配合的部分

由于 GUIDE 输入系统需要 Godot 的渲染循环，headless 模式无法处理输入。

#### 手动执行流程：

**终端 1 - 启动游戏：**
```bash
cd G:\dev\DreamerHeroines
G:\dev\Godot_v4.6.1\godot.bat --scene scenes/main.tscn
```

**终端 2 - 运行测试（使用 MCP）：**
```bash
# 等待游戏启动后，使用 MCP 工具执行测试
# 这些命令通过 Godot MCP 发送到运行中的游戏

# 测试 D 键移动
godot-mcp game_key_press key=D
sleep 0.5
godot-mcp game_get_property nodePath="/root/Main/Player" property="velocity.x"
# 验证返回值 > 0

godot-mcp game_key_press key=D pressed=false
```

---

## 方案三：完全自动化（需要开发）

### 实现思路

创建一个 **测试场景** (`tests/scenes/test_runner.tscn`)：

```gdscript
# tests/scripts/auto_test_runner.gd
extends Node

## 自动化测试运行器
## 在真实游戏环境中执行测试

@export var tests: Array[TestCase]

func _ready():
    await get_tree().create_timer(1.0).timeout
    run_all_tests()

func run_all_tests():
    var passed = 0
    var failed = 0
    
    for test in tests:
        if await run_test(test):
            passed += 1
        else:
            failed += 1
    
    print(f"测试结果: {passed}/{passed+failed}")
    
    # 导出结果到文件
    save_results(passed, failed)
    
    # 自动退出
    get_tree().quit(0 if failed == 0 else 1)

func run_test(test: TestCase) -> bool:
    print(f"运行测试: {test.name}")
    
    for step in test.steps:
        match step.action:
            "key_down":
                simulate_key_down(step.key)
            "key_up":
                simulate_key_up(step.key)
            "wait":
                await get_tree().create_timer(step.duration).timeout
            "assert_velocity":
                var velocity = player.velocity
                if not check_condition(velocity, step):
                    return false
    
    return true
```

### 使用方式

```bash
# 启动测试场景（自动运行测试并退出）
godot --path . tests/scenes/test_runner.tscn

# 或者导出为独立可执行文件后运行
./test_runner.exe --auto-exit
```

---

## 当前状态

| 方案 | 状态 | 自动化程度 |
|------|------|-----------|
| 编辑器内 GUT | ✅ 可用 | 半自动 |
| 命令行 headless | ⚠️ 单元测试可用 | 全自动 |
| 命令行 + 游戏进程 | 🚧 需要 MCP 配合 | 半自动 |
| 专用测试场景 | 📝 待实现 | 全自动 |

---

## 建议

### 短期（现在就能用）
1. **单元测试**：使用 `godot --headless -s addons/gut/gut_cmdln.gd`
2. **集成测试**：在 Godot 编辑器中点击 GUT 面板运行

### 中期（需要开发）
实现 **方案三** 的专用测试场景，支持：
- 完全自动化运行
- 无需人工干预
- CI/CD 集成
- 生成测试报告

### 需要你的决策

你希望优先实现哪个方案？

- **A**: 保持现状，手动在编辑器运行集成测试
- **B**: 开发专用测试场景，实现完全自动化
- **C**: 使用现有 MCP 工具，编写 Python 测试脚本
