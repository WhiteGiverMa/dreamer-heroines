extends Node

# InputManager - 输入管理器
# 处理输入设备、控制方案切换、输入缓冲等

signal control_scheme_changed(scheme: ControlScheme)
signal aim_direction_changed(direction: Vector2)

enum ControlScheme { KEYBOARD_MOUSE, GAMEPAD }

var current_scheme: ControlScheme = ControlScheme.KEYBOARD_MOUSE
var aim_direction: Vector2 = Vector2.RIGHT
var mouse_position: Vector2 = Vector2.ZERO

# 输入缓冲
var input_buffer: Dictionary = {}
var buffer_duration: float = 0.1  # 100ms缓冲

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("InputManager initialized")

func _process(delta):
	_update_aim_direction()
	_process_input_buffer(delta)
	_detect_control_scheme()

func _update_aim_direction() -> void:
	match current_scheme:
		ControlScheme.KEYBOARD_MOUSE:
			# 鼠标瞄准
			if get_viewport():
				var player = _get_player()
				if player:
					mouse_position = get_viewport().get_mouse_position()
					aim_direction = (mouse_position - player.global_position).normalized()
				else:
					aim_direction = Vector2.RIGHT
		
		ControlScheme.GAMEPAD:
			# 手柄右摇杆瞄准
			var right_stick = Vector2(
				Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
				Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
			)
			
			if right_stick.length() > 0.2:
				aim_direction = right_stick.normalized()
	
	aim_direction_changed.emit(aim_direction)

func _detect_control_scheme() -> void:
	var previous_scheme = current_scheme
	
	# 检测手柄输入
	for i in range(JOY_BUTTON_MAX):
		if Input.is_joy_button_pressed(0, i):
			current_scheme = ControlScheme.GAMEPAD
			break
	
	for i in range(JOY_AXIS_MAX):
		if abs(Input.get_joy_axis(0, i)) > 0.5:
			current_scheme = ControlScheme.GAMEPAD
			break
	
	# 检测键盘/鼠标输入
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
	   Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or \
	   Input.is_anything_pressed():
		# 检查是否是键盘按键
		for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_R, KEY_E]:
			if Input.is_physical_key_pressed(key):
				current_scheme = ControlScheme.KEYBOARD_MOUSE
				break
	
	if current_scheme != previous_scheme:
		control_scheme_changed.emit(current_scheme)
		print("Control scheme changed to: " + ("Gamepad" if current_scheme == ControlScheme.GAMEPAD else "Keyboard/Mouse"))

func _process_input_buffer(delta: float) -> void:
	# 减少缓冲时间
	for action in input_buffer.keys():
		input_buffer[action] -= delta
		if input_buffer[action] <= 0:
			input_buffer.erase(action)

func buffer_action(action: String) -> void:
	input_buffer[action] = buffer_duration

func is_action_buffered(action: String) -> bool:
	return input_buffer.has(action)

func get_movement_input() -> Vector2:
	var input = Vector2.ZERO
	input.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	return input

func get_aim_direction() -> Vector2:
	return aim_direction

func get_mouse_world_position() -> Vector2:
	if get_viewport():
		return get_viewport().get_camera_2d().get_global_mouse_position()
	return Vector2.ZERO

func is_aiming_up() -> bool:
	return aim_direction.y < -0.3

func is_aiming_down() -> bool:
	return aim_direction.y > 0.3

func set_control_scheme(scheme: ControlScheme) -> void:
	if current_scheme != scheme:
		current_scheme = scheme
		control_scheme_changed.emit(scheme)

func vibrate_gamepad(weak_magnitude: float, strong_magnitude: float, duration: float = 0.2) -> void:
	if current_scheme == ControlScheme.GAMEPAD:
		Input.start_joy_vibration(0, weak_magnitude, strong_magnitude, duration)

func _get_player() -> Node2D:
	# 获取场景中的玩家节点
	var tree = get_tree()
	if tree:
		var players = tree.get_nodes_in_group("player")
		if players.size() > 0:
			return players[0] as Node2D
	return null
