# Scripts

本项目开发辅助脚本。

## 脚本说明

| 脚本 | 用途 |
|------|------|
| `format.ps1` | Windows 代码格式化（GDScript + C#） |
| `format.sh` | Linux/macOS 代码格式化（GDScript + C#） |
| `fix-trailing-whitespace.ps1` | 检测并修复 Git 暂存区的尾随空格 |
| `git-wrapper.ps1` | Git 命令包装器，阻止绕过 pre-commit hooks |
| `start-godot-mcp.ps1` | 启动 Godot 编辑器并启用 MCP 调试 |

## 使用示例

```powershell
# 格式化所有代码
.\scripts\format.ps1

# 仅格式化 GDScript
.\scripts\format.ps1 -GDScript

# 仅检查，不修改文件
.\scripts\format.ps1 -Check

# 修复尾随空格并重新暂存
.\scripts\fix-trailing-whitespace.ps1 -Restage

# 使用 Git 包装器提交（推荐）
.\scripts\git-wrapper.ps1 commit -m "your message"
```
