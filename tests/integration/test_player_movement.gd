extends GutTest

## 玩家移动集成测试
## 测试 GUIDE 输入系统与玩家移动的集成

var _player: CharacterBody2D
var _move_action: GUIDEAction
var _jump_action: GUIDEAction
var _guide_context: GUIDEMappingContext


func before_all() -> void:
	# 加载并启用游戏玩法上下文
	_guide_context = load("res://config/input/contexts/gameplay_context.tres")
	if _guide_context:
		GUIDE.enable_mapping_context(_guide_context)

	_move_action = load("res://config/input/actions/move.tres")
	_jump_action = load("res://config/input/actions/jump.tres")
	await get_tree().process_frame


func before_each() -> void:
	# 每个测试前创建新的玩家实例
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_player = player_scene.instantiate()
	add_child_autofree(_player)
	await wait_frames(2)  # 等待 _ready


func after_all() -> void:
	if _guide_context:
		GUIDE.disable_mapping_context(_guide_context)


## 模拟按键按下
func simulate_key_down(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	GUIDE.inject_input(event)
	await get_tree().process_frame


## 模拟按键释放
func simulate_key_up(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = false
	GUIDE.inject_input(event)
	await get_tree().process_frame


func test_move_right_with_d_key() -> void:
	# 按下 D 键
	await simulate_key_down(KEY_D)
	await wait_frames(5)

	# 验证玩家有向右速度
	assert_gt(_player.velocity.x, 0, "Player should have positive X velocity when D is pressed")

	# 释放 D 键
	await simulate_key_up(KEY_D)


func test_move_left_with_a_key() -> void:
	await simulate_key_down(KEY_A)
	await wait_frames(5)

	assert_lt(_player.velocity.x, 0, "Player should have negative X velocity when A is pressed")

	await simulate_key_up(KEY_A)


func test_no_movement_without_input() -> void:
	await wait_frames(5)

	assert_almost_eq(_player.velocity.x, 0.0, 5.0, "Player should have near-zero X velocity without input")


func test_move_action_axis_2d_value() -> void:
	await simulate_key_down(KEY_D)
	await wait_frames(3)

	# 验证 move_action 的 2D 轴值
	var axis_value := _move_action.value_axis_2d
	assert_gt(axis_value.x, 0, "Move action should have positive X axis value")

	await simulate_key_up(KEY_D)


func test_jump_triggers_when_coyote_time_available() -> void:
	assert_not_null(_jump_action, "Jump action should be loaded")

	# 在无地面测试场景中，手动提供可用土狼时间来验证跳跃链路
	_player.coyote_timer = 0.1
	_player.jump_buffer_timer = 0.0
	_player.velocity = Vector2.ZERO

	await simulate_key_down(KEY_SPACE)
	await wait_frames(2)

	assert_lt(_player.velocity.y, 0.0, "Player should receive upward velocity when jump is pressed")

	await simulate_key_up(KEY_SPACE)
