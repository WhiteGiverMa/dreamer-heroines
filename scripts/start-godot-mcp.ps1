# Godot MCP 启动脚本
# 启动 Godot 编辑器并启用 MCP 插件

$GodotPath = "G:\dev\Godot_v4.6.1\godot.bat"
$ProjectPath = "G:\dev\DreamerHeroines"

Write-Host "Starting Godot Editor with MCP enabled..." -ForegroundColor Green
Write-Host "Godot Path: $GodotPath" -ForegroundColor Cyan
Write-Host "Project Path: $ProjectPath" -ForegroundColor Cyan

# 启动 Godot 编辑器
& $GodotPath --editor --path $ProjectPath

Write-Host "`nGodot Editor closed." -ForegroundColor Yellow
