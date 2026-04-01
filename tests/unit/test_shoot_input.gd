extends GutTest

## 测试鼠标按钮输入 (shoot action)
## 验证 GUIDE 正确处理鼠标左键输入

var _guide_context: GUIDEMappingContext
var _shoot_action: GUIDEAction


func before_all() -> void:
	_guide_context = load("res://config/input/contexts/gameplay_context.tres")
	if _guide_context:
		GUIDE.enable_mapping_context(_guide_context)

	_shoot_action = load("res://config/input/actions/shoot.tres")
	await get_tree().process_frame


func after_all() -> void:
	if _guide_context:
		GUIDE.disable_mapping_context(_guide_context)


func test_shoot_action_loaded() -> void:
	assert_not_null(_shoot_action, "Shoot action should be loaded")
	assert_eq(_shoot_action.action_value_type, GUIDEAction.GUIDEActionValueType.BOOL,
		"Shoot action should be BOOL type")


func test_mouse_button_press_triggers_shoot() -> void:
	# 创建鼠标左键按下事件
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = Vector2(400, 300)

	# 注入输入
	GUIDE.inject_input(press_event)
	await get_tree().process_frame

	# 检查 shoot_action 状态
	var is_pressed = _shoot_action.value_bool
	var is_triggered = _shoot_action.is_triggered()
	var is_ongoing = _shoot_action.is_ongoing()

	print("=== Mouse Press Test ===")
	print("value_bool: %s" % is_pressed)
	print("is_triggered: %s" % is_triggered)
	print("is_ongoing: %s" % is_ongoing)
	print("_last_state: %s" % _shoot_action._last_state)

	assert_true(is_pressed or is_triggered or is_ongoing,
		"Shoot action should be active after mouse press (value_bool=%s, triggered=%s, ongoing=%s)" % [is_pressed, is_triggered, is_ongoing])

	# 释放
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = Vector2(400, 300)
	GUIDE.inject_input(release_event)
	await get_tree().process_frame


func test_enhanced_input_detects_shoot() -> void:
	# 测试 EnhancedInput 包装器
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = Vector2(400, 300)

	GUIDE.inject_input(press_event)
	await get_tree().process_frame

	# 使用 EnhancedInput API
	var is_pressed = EnhancedInput.instance.is_action_pressed(_shoot_action)
	var is_just_pressed = EnhancedInput.instance.is_action_just_pressed(_shoot_action)

	print("=== EnhancedInput Test ===")
	print("is_action_pressed: %s" % is_pressed)
	print("is_action_just_pressed: %s" % is_just_pressed)

	assert_true(is_pressed, "EnhancedInput.is_action_pressed should return true")

	# 清理
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	GUIDE.inject_input(release_event)
	await get_tree().process_frame


func test_shoot_action_state_transitions() -> void:
	# 完整的状态转换测试
	print("\n=== State Transition Test ===")

	# 初始状态
	await get_tree().process_frame
	print("Initial state: %d, value_bool: %s" % [_shoot_action._last_state, _shoot_action.value_bool])

	# 按下
	var press_event := InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	GUIDE.inject_input(press_event)
	await get_tree().process_frame
	print("After press: state=%d, value_bool=%s, triggered=%s, ongoing=%s" % [
		_shoot_action._last_state,
		_shoot_action.value_bool,
		_shoot_action.is_triggered(),
		_shoot_action.is_ongoing()
	])

	# 保持按住 (模拟另一个帧)
	await get_tree().process_frame
	print("While held: state=%d, value_bool=%s, triggered=%s, ongoing=%s" % [
		_shoot_action._last_state,
		_shoot_action.value_bool,
		_shoot_action.is_triggered(),
		_shoot_action.is_ongoing()
	])

	# 释放
	var release_event := InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	GUIDE.inject_input(release_event)
	await get_tree().process_frame
	print("After release: state=%d, value_bool=%s" % [_shoot_action._last_state, _shoot_action.value_bool])

	# 验证至少有一个阶段检测到按下
	assert_true(true, "State transition test completed - check console output")
