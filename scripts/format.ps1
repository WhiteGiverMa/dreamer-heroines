# DreamerHeroines - 代码格式化脚本
# 支持 GDScript 和 C# 的自动格式化
# 使用方法: .\scripts\format.ps1 [选项]

param(
    [switch]$GDScript,    # 仅格式化 GDScript
    [switch]$CSharp,      # 仅格式化 C#
    [switch]$Lint,        # 仅运行 linter（不格式化）
    [switch]$Check,       # 检查模式（不修改文件，仅报告问题）
    [switch]$Help         # 显示帮助
)

# 颜色定义
$ColorSuccess = "Green"
$ColorError = "Red"
$ColorWarning = "Yellow"
$ColorInfo = "Cyan"

# 显示帮助
function Show-Help {
Write-Host "DreamerHeroines - 代码格式化工具" -ForegroundColor $ColorInfo
    Write-Host ""
    Write-Host "用法: .\scripts\format.ps1 [选项]"
    Write-Host ""
    Write-Host "选项:"
    Write-Host "  -GDScript    仅格式化 GDScript 文件"
    Write-Host "  -CSharp      仅格式化 C# 文件"
    Write-Host "  -Lint        仅运行 linter，不格式化"
    Write-Host "  -Check       检查模式，不修改文件，仅报告问题"
    Write-Host "  -Help        显示此帮助信息"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\scripts\format.ps1              # 格式化所有代码"
    Write-Host "  .\scripts\format.ps1 -GDScript    # 仅格式化 GDScript"
    Write-Host "  .\scripts\format.ps1 -CSharp      # 仅格式化 C#"
    Write-Host "  .\scripts\format.ps1 -Lint        # 仅运行 linter"
    Write-Host "  .\scripts\format.ps1 -Check       # 检查代码格式"
    exit 0
}

if ($Help) {
    Show-Help
}

# 检查工具是否安装
function Test-Command($Command) {
    return [bool](Get-Command -Name $Command -ErrorAction SilentlyContinue)
}

# 获取项目根目录
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

Write-Host "========================================" -ForegroundColor $ColorInfo
Write-Host "DreamerHeroines - 代码格式化工具" -ForegroundColor $ColorInfo
Write-Host "========================================" -ForegroundColor $ColorInfo
Write-Host ""

# 如果没有指定特定语言，则格式化所有
$FormatAll = -not ($GDScript -or $CSharp)
$HasError = $false

# ========================================
# GDScript 格式化
# ========================================
if ($FormatAll -or $GDScript) {
    Write-Host "[GDScript] 检查工具..." -ForegroundColor $ColorInfo

    $HasGDToolkit = Test-Command "gdlint"
    $HasGDFormat = Test-Command "gdformat"

    if (-not $HasGDToolkit -or -not $HasGDFormat) {
        Write-Host "警告: gdtoolkit 未安装" -ForegroundColor $ColorWarning
        Write-Host "  安装命令: pip install gdtoolkit" -ForegroundColor $ColorWarning
        Write-Host ""
    } else {
        $GDScriptFiles = Get-ChildItem -Path "src" -Filter "*.gd" -Recurse | Select-Object -ExpandProperty FullName

        if ($GDScriptFiles.Count -eq 0) {
            Write-Host "未找到 GDScript 文件" -ForegroundColor $ColorWarning
        } else {
            Write-Host "找到 $($GDScriptFiles.Count) 个 GDScript 文件" -ForegroundColor $ColorInfo

            if ($Lint -or $Check) {
                # 仅运行 linter
                Write-Host "[GDScript] 运行 gdlint..." -ForegroundColor $ColorInfo
                try {
                    $Output = gdlint $GDScriptFiles 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ GDScript lint 通过" -ForegroundColor $ColorSuccess
                    } else {
                        Write-Host "✗ GDScript lint 发现问题:" -ForegroundColor $ColorError
                        Write-Host $Output
                        $HasError = $true
                    }
                } catch {
                    Write-Host "错误: gdlint 执行失败 - $_" -ForegroundColor $ColorError
                    $HasError = $true
                }
            } else {
                # 格式化
                Write-Host "[GDScript] 运行 gdformat..." -ForegroundColor $ColorInfo
                try {
                    $Output = gdformat $GDScriptFiles 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ GDScript 格式化完成" -ForegroundColor $ColorSuccess
                    } else {
                        Write-Host "✗ GDScript 格式化失败:" -ForegroundColor $ColorError
                        Write-Host $Output
                        $HasError = $true
                    }
                } catch {
                    Write-Host "错误: gdformat 执行失败 - $_" -ForegroundColor $ColorError
                    $HasError = $true
                }

                # 格式化后运行 linter
                Write-Host "[GDScript] 运行 gdlint 检查..." -ForegroundColor $ColorInfo
                try {
                    $Output = gdlint $GDScriptFiles 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ GDScript lint 通过" -ForegroundColor $ColorSuccess
                    } else {
                        Write-Host "✗ GDScript lint 发现问题:" -ForegroundColor $ColorError
                        Write-Host $Output
                        $HasError = $true
                    }
                } catch {
                    Write-Host "错误: gdlint 执行失败 - $_" -ForegroundColor $ColorError
                    $HasError = $true
                }
            }
        }
        Write-Host ""
    }
}

# ========================================
# C# 格式化
# ========================================
if ($FormatAll -or $CSharp) {
    Write-Host "[C#] 检查工具..." -ForegroundColor $ColorInfo

    $HasDotNet = Test-Command "dotnet"

    if (-not $HasDotNet) {
        Write-Host "错误: .NET SDK 未安装" -ForegroundColor $ColorError
        Write-Host "  请安装 .NET 8.0 SDK" -ForegroundColor $ColorError
        exit 1
    }

    $HasCSharpier = Test-Command "dotnet-csharpier"

    if (-not $HasCSharpier) {
        Write-Host "警告: CSharpier 未安装" -ForegroundColor $ColorWarning
        Write-Host "  安装命令: dotnet tool install -g csharpier" -ForegroundColor $ColorWarning
        Write-Host ""
    } else {
        $CSharpFiles = Get-ChildItem -Path "src/cs" -Filter "*.cs" -Recurse | Select-Object -ExpandProperty FullName

        if ($CSharpFiles.Count -eq 0) {
            Write-Host "未找到 C# 文件" -ForegroundColor $ColorWarning
        } else {
            Write-Host "找到 $($CSharpFiles.Count) 个 C# 文件" -ForegroundColor $ColorInfo

            if ($Lint -or $Check) {
                # 检查模式
                Write-Host "[C#] 运行 CSharpier 检查..." -ForegroundColor $ColorInfo
                try {
                    $Output = dotnet csharpier --check $ProjectRoot 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ C# 格式检查通过" -ForegroundColor $ColorSuccess
                    } else {
                        Write-Host "✗ C# 格式检查发现问题" -ForegroundColor $ColorError
                        Write-Host $Output
                        $HasError = $true
                    }
                } catch {
                    Write-Host "错误: CSharpier 执行失败 - $_" -ForegroundColor $ColorError
                    $HasError = $true
                }
            } else {
                # 格式化
                Write-Host "[C#] 运行 CSharpier 格式化..." -ForegroundColor $ColorInfo
                try {
                    $Output = dotnet csharpier $ProjectRoot 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "✓ C# 格式化完成" -ForegroundColor $ColorSuccess
                    } else {
                        Write-Host "✗ C# 格式化失败:" -ForegroundColor $ColorError
                        Write-Host $Output
                        $HasError = $true
                    }
                } catch {
                    Write-Host "错误: CSharpier 执行失败 - $_" -ForegroundColor $ColorError
                    $HasError = $true
                }
            }
        }
        Write-Host ""
    }

    # 运行 dotnet format（使用 .editorconfig）
    if (-not $Lint) {
        Write-Host "[C#] 运行 dotnet format..." -ForegroundColor $ColorInfo
        try {
            if ($Check) {
                $Output = dotnet format --verify-no-changes 2>&1
            } else {
                $Output = dotnet format 2>&1
            }

            if ($LASTEXITCODE -eq 0) {
                if ($Check) {
                    Write-Host "✓ dotnet format 检查通过" -ForegroundColor $ColorSuccess
                } else {
                    Write-Host "✓ dotnet format 完成" -ForegroundColor $ColorSuccess
                }
            } else {
                if ($Check) {
                    Write-Host "✗ dotnet format 检查发现问题" -ForegroundColor $ColorError
                } else {
                    Write-Host "✗ dotnet format 失败" -ForegroundColor $ColorError
                }
                Write-Host $Output
                $HasError = $true
            }
        } catch {
            Write-Host "错误: dotnet format 执行失败 - $_" -ForegroundColor $ColorError
            $HasError = $true
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor $ColorInfo

if ($HasError) {
    Write-Host "格式化完成，但存在一些问题" -ForegroundColor $ColorWarning
    exit 1
} else {
    Write-Host "✓ 所有格式化任务完成！" -ForegroundColor $ColorSuccess
    exit 0
}
