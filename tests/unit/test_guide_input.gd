extends GutTest

## GUIDE 输入系统单元测试
## 测试 GUIDE 输入注入基础功能

var _guide_context: GUIDEMappingContext
var _move_action: GUIDEAction
var _jump_action: GUIDEAction


func before_all() -> void:
	# 加载并启用游戏玩法上下文
	_guide_context = load("res://config/input/contexts/gameplay_context.tres")
	if _guide_context:
		GUIDE.enable_mapping_context(_guide_context)

	_move_action = load("res://config/input/actions/move.tres")
	_jump_action = load("res://config/input/actions/jump.tres")
	await get_tree().process_frame


func after_all() -> void:
	if _guide_context:
		GUIDE.disable_mapping_context(_guide_context)


func test_guide_context_loaded() -> void:
	assert_not_null(_guide_context, "Guide context should be loaded")
	assert_not_null(_move_action, "Move action should be loaded")
	assert_not_null(_jump_action, "Jump action should be loaded")


func test_move_action_is_axis_2d() -> void:
	assert_eq(_move_action.action_value_type, GUIDEAction.GUIDEActionValueType.AXIS_2D,
		"Move action should be AXIS_2D type")


func test_enhanced_input_singleton_exists() -> void:
	assert_not_null(EnhancedInput.instance, "EnhancedInput singleton should exist")
	assert_true(EnhancedInput.instance.is_gameplay_context_enabled(),
		"Gameplay context should be enabled")


func test_guide_inject_input_does_not_crash() -> void:
	# 测试 GUIDE.inject_input 不会崩溃
	var event := InputEventKey.new()
	event.keycode = KEY_D
	event.pressed = true

	# 这应该不会抛出异常
	GUIDE.inject_input(event)

	# 如果执行到这里，说明没有崩溃
	assert_true(true, "Inject input completed without crash")


func test_input_event_creation() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = true

	assert_eq(event.keycode, KEY_W, "Keycode should be W")
	assert_true(event.pressed, "Event should be pressed")


func test_just_pressed_is_stable_for_multiple_callers_same_tick() -> void:
	var press_event := InputEventKey.new()
	press_event.keycode = KEY_SPACE
	press_event.physical_keycode = KEY_SPACE
	press_event.pressed = true
	GUIDE.inject_input(press_event)
	await get_tree().process_frame

	var first_read := EnhancedInput.instance.is_action_just_pressed(_jump_action)
	var second_read := EnhancedInput.instance.is_action_just_pressed(_jump_action)

	assert_true(first_read, "First just_pressed read should be true")
	assert_true(second_read, "Second just_pressed read in same tick should also be true")

	var release_event := InputEventKey.new()
	release_event.keycode = KEY_SPACE
	release_event.physical_keycode = KEY_SPACE
	release_event.pressed = false
	GUIDE.inject_input(release_event)
	await get_tree().process_frame
