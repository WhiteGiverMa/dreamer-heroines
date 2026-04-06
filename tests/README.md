# 自动化测试使用指南

> 适用于人类开发者 和 AI Agent

---

## 快速开始

### 方式一：命令行运行（推荐）

```bash
# 进入项目目录
cd G:\dev\DreamerHeroines

# 运行自动化集成测试
G:\dev\Godot_v4.6.1\godot.bat tests/scenes/test_launcher.tscn
```

**预期输出：**
```
════════════════════════════════════════════════════════════
  🎮 自动化集成测试启动器
════════════════════════════════════════════════════════════
  游戏场景: res://scenes/main.tscn
  等待时间: 2.0 秒
════════════════════════════════════════════════════════════

📂 加载游戏场景...
⏳ 等待游戏初始化 (2.0 秒)...
✅ 游戏加载完成，找到玩家节点

🧪 执行 5 个测试用例...

  ✅ test_player_exists
  ✅ test_guide_context_enabled
  ✅ test_move_right
  ✅ test_move_left
  ✅ test_no_input_stationary

════════════════════════════════════════════════════════════
  📊 测试结果汇总
════════════════════════════════════════════════════════════
  ✅ 通过: 5
  ❌ 失败: 0
  📈 成功率: 100.0%
════════════════════════════════════════════════════════════

💾 结果已保存: user://test_results.json
```

### 方式二：Godot 编辑器运行

1. 打开 Godot 编辑器
2. 按 `F5` 运行场景
3. 选择 `tests/scenes/test_launcher.tscn`
4. 观察测试输出

### 方式三：Headless 模式（仅单元测试）

```bash
# 仅运行单元测试（不需要图形界面）
G:\dev\Godot_v4.6.1\godot.bat --headless -s addons/gut/gut_cmdln.gd -- -gdir=tests/unit -ginclude_subdirs -gexit
```

---

## 测试类型对比

| 类型 | 文件位置 | 运行方式 | 用途 |
|------|----------|----------|------|
| **单元测试** | `tests/unit/` | Headless | 测试纯逻辑，不需要游戏运行 |
| **集成测试** | `tests/integration/` | GUT 编辑器 | 测试组件交互 |
| **自动化测试** | `tests/scenes/test_launcher.tscn` | 命令行 | 完整功能测试，自动验证 |

---

## Agent 使用指南

### 当需要验证功能时

```bash
# 直接运行测试
godot tests/scenes/test_launcher.tscn
```

### 当需要添加新测试时

编辑 `tests/scripts/test_launcher.gd`，在 `_get_test_cases()` 中添加：

```gdscript
{
    "name": "test_your_feature",
    "description": "测试描述",
    "execute": func() -> Dictionary:
        # 执行测试逻辑
        _press_key(KEY_YOUR_KEY)
        await get_tree().create_timer(0.3).timeout
        
        # 验证结果
        if not _your_condition:
            return {"passed": false, "error": "错误信息"}
        return {"passed": true, "error": ""}
},
```

### 当需要通过 MCP 运行测试时

```bash
# 1. 启动游戏
godot-mcp run_project --projectPath G:\dev\DreamerHeroines

# 2. 等待游戏就绪

# 3. 执行测试操作
godot-mcp game_key_press --key D
godot-mcp game_get_property --nodePath /root/Main/Player --property velocity

# 4. 停止游戏
godot-mcp stop_project
```

---

## 人类开发者指南

### 添加新测试用例

1. 打开 `tests/scripts/test_launcher.gd`
2. 找到 `_get_test_cases()` 函数
3. 添加新的测试字典：

```gdscript
{
    "name": "test_shoot",
    "description": "测试射击功能",
    "execute": func() -> Dictionary:
        _press_key(KEY_SPACE)  # 假设空格是射击
        await get_tree().create_timer(0.2).timeout
        
        # 验证子弹是否生成
        var bullets = get_tree().get_nodes_in_group("bullets")
        if bullets.size() == 0:
            return {"passed": false, "error": "没有生成子弹"}
        
        _release_key(KEY_SPACE)
        return {"passed": true, "error": ""
},
```

### 运行特定测试

修改 `_get_test_cases()` 返回特定测试，或使用 GUT 框架：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -- -gdir=tests/unit -gselect=test_move_right -gexit
```

### 查看测试结果

测试结果保存在：
- `user://test_results.json` - JSON 格式，便于程序解析
- 控制台输出 - 人类可读格式

---

## 常见问题

### Q: 测试失败怎么办？

1. 检查错误信息
2. 确认游戏场景正确加载
3. 验证输入系统（GUIDE 上下文）是否启用
4. 增加等待时间 `delay_before_tests`

### Q: 如何调试失败的测试？

1. 在 Godot 编辑器中运行测试场景
2. 使用 `print()` 输出中间状态
3. 检查玩家节点路径是否正确

### Q: 测试在 CI/CD 中如何运行？

```yaml
# GitHub Actions 示例
- name: Run Tests
  run: |
    godot --headless tests/scenes/test_launcher.tscn
    # 检查退出码
```

### Q: 为什么不要在 headless 下跑 `tests/integration/`？

- `tests/integration/` 里的 GUT 用例依赖场景切换、运行时 UI 或 GUIDE 输入注入。
- 这些路径更适合在 Godot 编辑器或完整运行时里验证，不适合作为默认 headless 命令的一部分。
- 如果需要跑集成测试，请优先使用 `godot tests/scenes/test_launcher.tscn` 或在 GUT 编辑器面板中执行。

---

## 文件结构

```
tests/
├── automation/           # 自动化脚本
│   ├── README.md        # 本文档
│   └── test_runner.py   # Python 运行器（可选）
├── integration/          # GUT 集成测试
│   └── test_player_movement.gd
├── unit/                 # GUT 单元测试
│   └── test_guide_input.gd
├── scenes/               # 测试场景
│   ├── test_launcher.tscn    # 主测试启动器
│   └── auto_test_runner.tscn # 备用测试场景
├── scripts/              # 测试脚本
│   ├── test_launcher.gd      # 测试启动器逻辑
│   └── auto_test_runner.gd   # 自动化测试逻辑
├── test_guide_base.gd    # GUT 测试基类
└── gut_config.gf         # GUT 配置
```

---

## 下一步

- 添加更多测试用例覆盖更多功能
- 集成到 CI/CD 流程
- 创建性能测试
- 添加可视化测试报告
