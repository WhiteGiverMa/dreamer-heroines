# Godot MCP 配置指南

## 概述

本项目已配置 [Godot MCP](https://github.com/tugcantopaloglu/godot-mcp) - 一个 Model Context Protocol (MCP) 服务器，提供 149+ 个工具用于 AI 驱动的 Godot 游戏开发。

## 安装状态

✅ **已完成配置**:
1. Godot MCP 服务器已安装到 `~/godot-mcp`
2. Godot MCP 插件已安装到 `addons/godot_mcp/`
3. MCP 配置已添加到 `~/.config/opencode/opencode.json`
4. 项目已启用 Godot MCP 插件

## 使用方法

### 1. 启动 Godot 编辑器

```powershell
# 使用脚本启动
.\scripts\start-godot-mcp.ps1

# 或直接启动
godot --editor --path .
```

### 2. 验证插件启用

在 Godot 编辑器中:
- 进入 **项目 > 项目设置 > 插件**
- 确认 "Godot MCP" 插件已启用

### 3. 测试 MCP 连接

插件会自动在端口 9090 启动 TCP 服务器。MCP 服务器通过 stdio 与 Godot 通信。

## 可用工具 (149+)

### 项目管理
- `launch_editor` - 启动 Godot 编辑器
- `run_project` - 运行项目
- `get_project_info` - 获取项目信息
- `read_project_settings` - 读取项目设置

### 场景管理
- `create_scene` - 创建新场景
- `add_node` - 添加节点
- `read_scene` - 读取场景结构
- `modify_scene_node` - 修改场景节点
- `save_scene` - 保存场景

### 运行时控制
- `game_eval` - 执行 GDScript 代码
- `game_get_property` / `game_set_property` - 读写节点属性
- `game_call_method` - 调用节点方法
- `game_click` / `game_key_press` - 模拟输入
- `game_screenshot` - 捕获屏幕截图
- `game_pause` - 暂停/继续游戏

### 文件操作
- `read_file` / `write_file` - 读写文件
- `create_directory` - 创建目录
- `create_script` - 创建 GDScript 文件

### 高级功能
- `game_animation_tree` - 控制动画状态机
- `game_raycast` - 物理射线检测
- `game_http_request` - HTTP 请求
- `game_multiplayer` - 多人网络
- `export_project` - 导出项目

## 配置详情

### MCP 服务器配置

位置: `~/.config/opencode/opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "godot-mcp": {
      "type": "local",
      "command": [
        "node",
        "C:/Users/A1337/godot-mcp/build/index.js"
      ],
      "environment": {
        "GODOT_PATH": "G:\\dev\\Godot_v4.6.1\\godot.bat",
        "GODOT_PROJECT_PATH": "G:\\dev\\DreamerHeroines"
      },
      "enabled": true
    }
  }
}
```

### 插件配置

位置: `addons/godot_mcp/plugin.cfg`

```ini
[plugin]
name="Godot MCP"
description="Model Context Protocol (MCP) server integration for Godot 4.x"
author="tugcantopaloglu"
version="2.0.0"
script="mcp_interaction_server.gd"
```

## 故障排除

### 插件未启用
- 检查 `project.godot` 中的 `editor_plugins/enabled` 是否包含 `res://addons/godot_mcp/plugin.cfg`

### MCP 服务器连接失败
- 确认 Godot 编辑器已启动
- 检查插件是否已启用
- 查看 Godot 输出面板是否有错误信息

### 端口冲突
- 插件默认使用端口 9090
- 如需更改，修改 `mcp_interaction_server.gd` 中的 `PORT` 常量

## 参考链接

- [Godot MCP GitHub](https://github.com/tugcantopaloglu/godot-mcp)
- [MCP 协议文档](https://modelcontextprotocol.io/introduction)
- [Godot 4.6 文档](https://docs.godotengine.org/en/4.6/)
