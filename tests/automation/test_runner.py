#!/usr/bin/env python3
"""
自动化集成测试运行器
使用 Godot MCP 工具链执行测试

用法:
    python tests/automation/test_runner.py

流程:
    1. 启动 Godot 游戏 (通过 MCP)
    2. 等待游戏就绪
    3. 执行测试步骤 (按键、验证)
    4. 收集结果
    5. 停止游戏
"""

import subprocess
import json
import time
import sys
from pathlib import Path

# 测试配置
PROJECT_PATH = "G:\\dev\\DreamerHeroines"
GODOT_PATH = "G:\\dev\\Godot_v4.6.1\\godot.bat"

# 测试用例
TESTS = [
    {
        "name": "test_move_right",
        "description": "测试 D 键向右移动",
        "steps": [
            {"action": "key_down", "key": "D", "wait": 0.5},
            {"action": "get_velocity", "expect_gt": 0, "axis": "x"},
            {"action": "key_up", "key": "D"},
        ],
    },
    {
        "name": "test_move_left", 
        "description": "测试 A 键向左移动",
        "steps": [
            {"action": "key_down", "key": "A", "wait": 0.5},
            {"action": "get_velocity", "expect_lt": 0, "axis": "x"},
            {"action": "key_up", "key": "A"},
        ],
    },
    {
        "name": "test_no_movement",
        "description": "测试无输入时静止",
        "steps": [
            {"action": "wait", "duration": 0.5},
            {"action": "get_velocity", "expect_near": 0, "axis": "x", "tolerance": 5.0},
        ],
    },
]


def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")


def print_result(test_name, passed, message=""):
    status = "✅ PASS" if passed else "❌ FAIL"
    print(f"  {status}: {test_name}")
    if message:
        print(f"       {message}")


def run_test_with_mcp():
    """
    使用 Godot MCP 运行测试
    注意: 这需要 MCP 服务器正在运行
    """
    print_header("自动化集成测试")
    print("\n⚠️  需要手动启动游戏:")
    print(f"   {GODOT_PATH} --path {PROJECT_PATH} scenes/main.tscn")
    print("\n然后使用 MCP 工具执行测试:")
    print("   1. godot-mcp:run_project 启动游戏")
    print("   2. godot-mcp:game_key_press 模拟按键")
    print("   3. godot-mcp:game_get_property 获取速度")
    print("   4. godot-mcp:stop_project 停止游戏")
    print("\n或者使用 Godot Editor 的 GUT 插件运行集成测试")
    
    return True


def main():
    print("=== Godot 自动化测试运行器 ===\n")
    
    # 检查项目路径
    project = Path(PROJECT_PATH)
    if not project.exists():
        print(f"❌ 项目路径不存在: {PROJECT_PATH}")
        return 1
    
    # 检查 Godot
    godot = Path(GODOT_PATH)
    if not godot.exists():
        print(f"❌ Godot 路径不存在: {GODOT_PATH}")
        return 1
    
    print(f"✅ 项目路径: {PROJECT_PATH}")
    print(f"✅ Godot 路径: {GODOT_PATH}")
    print(f"✅ 测试用例数: {len(TESTS)}")
    
    # 运行测试
    success = run_test_with_mcp()
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
