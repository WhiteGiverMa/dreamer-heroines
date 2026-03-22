#!/bin/bash
# DreamerHeroines - 代码格式化脚本 (Linux/macOS)
# 支持 GDScript 和 C# 的自动格式化
# 使用方法: ./scripts/format.sh [选项]

set -e

# 颜色定义
COLOR_SUCCESS='\033[0;32m'
COLOR_ERROR='\033[0;31m'
COLOR_WARNING='\033[1;33m'
COLOR_INFO='\033[0;36m'
COLOR_RESET='\033[0m'

# 默认选项
FORMAT_GDSCRIPT=false
FORMAT_CSHARP=false
LINT_ONLY=false
CHECK_ONLY=false
SHOW_HELP=false

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --gdscript|-g)
            FORMAT_GDSCRIPT=true
            shift
            ;;
        --csharp|-c)
            FORMAT_CSHARP=true
            shift
            ;;
        --lint|-l)
            LINT_ONLY=true
            shift
            ;;
        --check|-k)
            CHECK_ONLY=true
            shift
            ;;
        --help|-h)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo -e "${COLOR_ERROR}未知选项: $1${COLOR_RESET}"
            exit 1
            ;;
    esac
done

# 显示帮助
show_help() {
    echo -e "${COLOR_INFO}DreamerHeroines - 代码格式化工具${COLOR_RESET}"
    echo ""
    echo "用法: ./scripts/format.sh [选项]"
    echo ""
    echo "选项:"
    echo "  -g, --gdscript    仅格式化 GDScript 文件"
    echo "  -c, --csharp      仅格式化 C# 文件"
    echo "  -l, --lint        仅运行 linter，不格式化"
    echo "  -k, --check       检查模式，不修改文件，仅报告问题"
    echo "  -h, --help        显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  ./scripts/format.sh              # 格式化所有代码"
    echo "  ./scripts/format.sh -g           # 仅格式化 GDScript"
    echo "  ./scripts/format.sh -c           # 仅格式化 C#"
    echo "  ./scripts/format.sh -l           # 仅运行 linter"
    echo "  ./scripts/format.sh -k           # 检查代码格式"
    exit 0
}

if [ "$SHOW_HELP" = true ]; then
    show_help
fi

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 获取项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${COLOR_INFO}========================================${COLOR_RESET}"
echo -e "${COLOR_INFO}DreamerHeroines - 代码格式化工具${COLOR_RESET}"
echo -e "${COLOR_INFO}========================================${COLOR_RESET}"
echo ""

# 如果没有指定特定语言，则格式化所有
FORMAT_ALL=false
if [ "$FORMAT_GDSCRIPT" = false ] && [ "$FORMAT_CSHARP" = false ]; then
    FORMAT_ALL=true
fi

HAS_ERROR=false

# ========================================
# GDScript 格式化
# ========================================
if [ "$FORMAT_ALL" = true ] || [ "$FORMAT_GDSCRIPT" = true ]; then
    echo -e "${COLOR_INFO}[GDScript] 检查工具...${COLOR_RESET}"

    if ! command_exists gdlint || ! command_exists gdformat; then
        echo -e "${COLOR_WARNING}警告: gdtoolkit 未安装${COLOR_RESET}"
        echo -e "${COLOR_WARNING}  安装命令: pip install gdtoolkit${COLOR_RESET}"
        echo ""
    else
        # 查找所有 GDScript 文件
        GDSCRIPT_FILES=$(find src -name "*.gd" -type f 2>/dev/null || true)

        if [ -z "$GDSCRIPT_FILES" ]; then
            echo -e "${COLOR_WARNING}未找到 GDScript 文件${COLOR_RESET}"
        else
            FILE_COUNT=$(echo "$GDSCRIPT_FILES" | wc -l)
            echo -e "${COLOR_INFO}找到 $FILE_COUNT 个 GDScript 文件${COLOR_RESET}"

            if [ "$LINT_ONLY" = true ] || [ "$CHECK_ONLY" = true ]; then
                # 仅运行 linter
                echo -e "${COLOR_INFO}[GDScript] 运行 gdlint...${COLOR_RESET}"
                if echo "$GDSCRIPT_FILES" | xargs gdlint; then
                    echo -e "${COLOR_SUCCESS}✓ GDScript lint 通过${COLOR_RESET}"
                else
                    echo -e "${COLOR_ERROR}✗ GDScript lint 发现问题${COLOR_RESET}"
                    HAS_ERROR=true
                fi
            else
                # 格式化
                echo -e "${COLOR_INFO}[GDScript] 运行 gdformat...${COLOR_RESET}"
                if echo "$GDSCRIPT_FILES" | xargs gdformat; then
                    echo -e "${COLOR_SUCCESS}✓ GDScript 格式化完成${COLOR_RESET}"
                else
                    echo -e "${COLOR_ERROR}✗ GDScript 格式化失败${COLOR_RESET}"
                    HAS_ERROR=true
                fi

                # 格式化后运行 linter
                echo -e "${COLOR_INFO}[GDScript] 运行 gdlint 检查...${COLOR_RESET}"
                if echo "$GDSCRIPT_FILES" | xargs gdlint; then
                    echo -e "${COLOR_SUCCESS}✓ GDScript lint 通过${COLOR_RESET}"
                else
                    echo -e "${COLOR_ERROR}✗ GDScript lint 发现问题${COLOR_RESET}"
                    HAS_ERROR=true
                fi
            fi
        fi
        echo ""
    fi
fi

# ========================================
# C# 格式化
# ========================================
if [ "$FORMAT_ALL" = true ] || [ "$FORMAT_CSHARP" = true ]; then
    echo -e "${COLOR_INFO}[C#] 检查工具...${COLOR_RESET}"

    if ! command_exists dotnet; then
        echo -e "${COLOR_ERROR}错误: .NET SDK 未安装${COLOR_RESET}"
        echo -e "${COLOR_ERROR}  请安装 .NET 8.0 SDK${COLOR_RESET}"
        exit 1
    fi

    if ! command_exists dotnet-csharpier; then
        echo -e "${COLOR_WARNING}警告: CSharpier 未安装${COLOR_RESET}"
        echo -e "${COLOR_WARNING}  安装命令: dotnet tool install -g csharpier${COLOR_RESET}"
        echo ""
    else
        # 查找所有 C# 文件
        CSHARP_FILES=$(find src/cs -name "*.cs" -type f 2>/dev/null || true)

        if [ -z "$CSHARP_FILES" ]; then
            echo -e "${COLOR_WARNING}未找到 C# 文件${COLOR_RESET}"
        else
            FILE_COUNT=$(echo "$CSHARP_FILES" | wc -l)
            echo -e "${COLOR_INFO}找到 $FILE_COUNT 个 C# 文件${COLOR_RESET}"

            if [ "$LINT_ONLY" = true ] || [ "$CHECK_ONLY" = true ]; then
                # 检查模式
                echo -e "${COLOR_INFO}[C#] 运行 CSharpier 检查...${COLOR_RESET}"
                if dotnet csharpier --check "$PROJECT_ROOT"; then
                    echo -e "${COLOR_SUCCESS}✓ C# 格式检查通过${COLOR_RESET}"
                else
                    echo -e "${COLOR_ERROR}✗ C# 格式检查发现问题${COLOR_RESET}"
                    HAS_ERROR=true
                fi
            else
                # 格式化
                echo -e "${COLOR_INFO}[C#] 运行 CSharpier 格式化...${COLOR_RESET}"
                if dotnet csharpier "$PROJECT_ROOT"; then
                    echo -e "${COLOR_SUCCESS}✓ C# 格式化完成${COLOR_RESET}"
                else
                    echo -e "${COLOR_ERROR}✗ C# 格式化失败${COLOR_RESET}"
                    HAS_ERROR=true
                fi
            fi
        fi
        echo ""
    fi

    # 运行 dotnet format（使用 .editorconfig）
    if [ "$LINT_ONLY" = false ]; then
        echo -e "${COLOR_INFO}[C#] 运行 dotnet format...${COLOR_RESET}"
        if [ "$CHECK_ONLY" = true ]; then
            if dotnet format --verify-no-changes; then
                echo -e "${COLOR_SUCCESS}✓ dotnet format 检查通过${COLOR_RESET}"
            else
                echo -e "${COLOR_ERROR}✗ dotnet format 检查发现问题${COLOR_RESET}"
                HAS_ERROR=true
            fi
        else
            if dotnet format; then
                echo -e "${COLOR_SUCCESS}✓ dotnet format 完成${COLOR_RESET}"
            else
                echo -e "${COLOR_ERROR}✗ dotnet format 失败${COLOR_RESET}"
                HAS_ERROR=true
            fi
        fi
    fi
fi

echo ""
echo -e "${COLOR_INFO}========================================${COLOR_RESET}"

if [ "$HAS_ERROR" = true ]; then
    echo -e "${COLOR_WARNING}格式化完成，但存在一些问题${COLOR_RESET}"
    exit 1
else
    echo -e "${COLOR_SUCCESS}✓ 所有格式化任务完成！${COLOR_RESET}"
    exit 0
fi
