# godot_mcp/

这是项目内置的 Godot MCP 插件目录。

## 来源

本目录中的运行时脚本不是在本项目里独立维护，而是 **vendor** 自以下 fork 的构建产物：

- Fork 仓库：`https://github.com/WhiteGiverMa/godot-mcp-full-control-adaptive`
- 本地工作目录：`G:\dev\godot-mcp-fc-a`

当前主要同步的文件是：

- `godot_operations.gd`
- `mcp_interaction_server.gd`

## 本地保留文件

以下文件属于项目本地插件壳或项目文档，不应被 fork 整目录覆盖：

- `plugin.cfg`
- `mcp_editor_plugin.gd`
- `*.uid`
- 本目录 README / 其他项目本地说明

## 如何同步

推荐从 fork 仓库执行同步脚本：

```powershell
cd G:\dev\godot-mcp-fc-a
.\scripts\sync-downstream.ps1
```

脚本会：

1. 运行 `npm run build`
2. 将 `build/scripts/*.gd` 复制到下游项目
3. 输出同步结果与文件哈希

## 注意

- 如果修改了本目录中的 `godot_operations.gd` 或 `mcp_interaction_server.gd`，请优先把修改回收到 fork 仓库，而不是继续在项目内分叉维护。
- 本项目还保留项目特定的 MCP 配置与命令扩展，例如：
  - `config/mcp_server.json`
  - `src/autoload/project_mcp_commands.gd`

详细维护流程见 fork 仓库：`docs/upstream-sync.md`
