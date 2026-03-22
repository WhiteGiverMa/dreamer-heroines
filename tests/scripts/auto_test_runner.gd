extends Node

## 自动化集成测试运行器
## 在真实游戏环境中执行测试，支持完全自动化运行
## 
## 用法:
##   godot --path . tests/scenes/auto_test_runner.tscn
## 
## 或在代码中:
##   get_tree().change_scene_to_file("res://tests/scenes/auto_test_runner.tscn")

class_name AutoTestRunner

#region 测试配置
## 是否在测试完成后自动退出
@export var auto_exit: bool = true

## 测试完成后等待时间（秒）
@export var delay_before_exit: float = 1.0

## 测试场景路径（需要测试的场景）
@export var test_scene_path: String = "res://scenes/main.tscn"
#endregion

#region 测试用例定义
var _test_cases: Array[Dictionary] = []
var _test_results: Array[Dictionary] = []
var _current_test: int = 0
var _player: CharacterBody2D = null
#endregion


func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("  自动化集成测试运行器")
	print("=".repeat(60))
	
	# 定义测试用例
	_define_test_cases()
	
	# 延迟启动测试，等待场景完全加载
	await get_tree().create_timer(0.5).timeout
	
	# 开始执行测试
	await _run_all_tests()


func _define_test_cases() -> void:
	_test_cases = [
		{
			"name": "test_move_right_with_d",
			"description": "测试 D 键向右移动",
			"steps": [
				{"action": "wait", "duration": 0.3},
				{"action": "key_down", "key": KEY_D},
				{"action": "wait", "duration": 0.3},
				{"action": "check_velocity", "axis": "x", "condition": "gt", "value": 0},
				{"action": "key_up", "key": KEY_D},
			]
		},
		{
			"name": "test_move_left_with_a",
			"description": "测试 A 键向左移动",
			"steps": [
				{"action": "wait", "duration": 0.3},
				{"action": "key_down", "key": KEY_A},
				{"action": "wait", "duration": 0.3},
				{"action": "check_velocity", "axis": "x", "condition": "lt", "value": 0},
				{"action": "key_up", "key": KEY_A},
			]
		},
		{
			"name": "test_no_movement_without_input",
			"description": "测试无输入时玩家静止",
			"steps": [
				{"action": "wait", "duration": 0.3},
				{"action": "check_velocity", "axis": "x", "condition": "near", "value": 0, "tolerance": 5.0},
			]
		},
		{
			"name": "test_jump_with_space",
			"description": "测试空格键跳跃",
			"steps": [
				{"action": "wait", "duration": 0.3},
				{"action": "key_down", "key": KEY_SPACE},
				{"action": "wait", "duration": 0.2},
				{"action": "check_velocity", "axis": "y", "condition": "lt", "value": 0},
				{"action": "key_up", "key": KEY_SPACE},
			]
		},
	]


func _run_all_tests() -> void:
	print("\n开始执行 %d 个测试用例...\n" % _test_cases.size())
	
	var passed := 0
	var failed := 0
	
	for i in range(_test_cases.size()):
		_current_test = i
		var result = await _run_single_test(_test_cases[i])
		_test_results.append(result)
		
		if result.passed:
			passed += 1
			print("  ✅ PASS: %s" % result.name)
		else:
			failed += 1
			print("  ❌ FAIL: %s - %s" % [result.name, result.message])
	
	_print_summary(passed, failed)
	_save_results_to_file(passed, failed)
	
	if auto_exit:
		await get_tree().create_timer(delay_before_exit).timeout
		get_tree().quit(0 if failed == 0 else 1)


func _run_single_test(test: Dictionary) -> Dictionary:
	var result := {
		"name": test.name,
		"description": test.description,
		"passed": false,
		"message": "",
		"steps_completed": 0,
	}
	
	print("  执行: %s" % test.name)
	
	# 查找玩家节点
	_player = _find_player()
	if _player == null:
		result.message = "无法找到玩家节点"
		return result
	
	# 执行测试步骤
	for step_idx in range(test.steps.size()):
		var step = test.steps[step_idx]
		var step_result = await _execute_step(step)
		
		if not step_result.success:
			result.message = "步骤 %d 失败: %s" % [step_idx + 1, step_result.message]
			return result
		
		result.steps_completed += 1
	
	result.passed = true
	return result


func _execute_step(step: Dictionary) -> Dictionary:
	var result := {"success": false, "message": ""}
	
	match step.action:
		"wait":
			await get_tree().create_timer(step.duration).timeout
			result.success = true
		
		"key_down":
			_simulate_key_down(step.key)
			result.success = true
		
		"key_up":
			_simulate_key_up(step.key)
			result.success = true
		
		"check_velocity":
			result = _check_velocity(step)
		
		_:
			result.message = "未知操作: %s" % step.action
	
	return result


func _simulate_key_down(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	GUIDE.inject_input(event)
	Input.parse_input_event(event)


func _simulate_key_up(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	GUIDE.inject_input(event)
	Input.parse_input_event(event)


func _check_velocity(step: Dictionary) -> Dictionary:
	var result := {"success": false, "message": ""}
	
	if _player == null:
		result.message = "玩家节点为空"
		return result
	
	var velocity: float
	if step.axis == "x":
		velocity = _player.velocity.x
	elif step.axis == "y":
		velocity = _player.velocity.y
	else:
		result.message = "未知轴: %s" % step.axis
		return result
	
	var expected: float = step.value
	var tolerance: float = step.get("tolerance", 0.001)
	
	match step.condition:
		"gt":
			if velocity > expected:
				result.success = true
			else:
				result.message = "velocity.%s = %.2f, 期望 > %.2f" % [step.axis, velocity, expected]
		"lt":
			if velocity < expected:
				result.success = true
			else:
				result.message = "velocity.%s = %.2f, 期望 < %.2f" % [step.axis, velocity, expected]
		"eq":
			if abs(velocity - expected) < tolerance:
				result.success = true
			else:
				result.message = "velocity.%s = %.2f, 期望 = %.2f" % [step.axis, velocity, expected]
		"near":
			if abs(velocity - expected) < tolerance:
				result.success = true
			else:
				result.message = "velocity.%s = %.2f, 期望 ≈ %.2f (容差: %.2f)" % [step.axis, velocity, expected, tolerance]
		_:
			result.message = "未知条件: %s" % step.condition
	
	return result


func _find_player() -> CharacterBody2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as CharacterBody2D
	return null


func _print_summary(passed: int, failed: int) -> void:
	print("\n" + "=".repeat(60))
	print("  测试结果汇总")
	print("=".repeat(60))
	print("  通过: %d" % passed)
	print("  失败: %d" % failed)
	print("  总计: %d" % (passed + failed))
	print("  成功率: %.1f%%" % (100.0 * passed / (passed + failed)))
	print("=".repeat(60))


func _save_results_to_file(passed: int, failed: int) -> void:
	var results := {
		"timestamp": Time.get_datetime_string_from_system(),
		"total": passed + failed,
		"passed": passed,
		"failed": failed,
		"success_rate": 100.0 * passed / (passed + failed) if (passed + failed) > 0 else 0,
		"tests": _test_results,
	}
	
	var file := FileAccess.open("res://tests/test_results.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(results, "  "))
		file.close()
		print("\n结果已保存到: res://tests/test_results.json")
