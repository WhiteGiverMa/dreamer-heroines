extends PanelContainer

## InputDebugWidget - 输入调试控件
## 实时显示玩家输入状态，帮助调试输入问题

# 颜色配置
const COLOR_OFF: Color = Color(0.2, 0.2, 0.2, 1.0)
const COLOR_PRESSED: Color = Color(0.2, 0.8, 0.2, 1.0)  # 绿色 - 按下
const COLOR_JUST_PRESSED: Color = Color(0.8, 0.8, 0.2, 1.0)  # 黄色 - 刚按下
const COLOR_COOLDOWN: Color = Color(0.4, 0.2, 0.2, 1.0)  # 暗红色 - 冷却

# UI 引用
@onready var jump_state: ColorRect = $VBox/KeyContainer/JumpSection/JumpState
@onready var jump_label: Label = $VBox/KeyContainer/JumpSection/JumpState/JumpLabel
@onready var jump_timer_label: Label = $VBox/KeyContainer/JumpSection/JumpTimerLabel
@onready var dash_state_ui: ColorRect = $VBox/KeyContainer/DashSection/DashState
@onready var dash_label: Label = $VBox/KeyContainer/DashSection/DashState/DashLabel
@onready var dash_timer_label: Label = $VBox/KeyContainer/DashSection/DashTimerLabel
@onready var move_state: ColorRect = $VBox/KeyContainer/MoveSection/MoveState
@onready var move_label: Label = $VBox/KeyContainer/MoveSection/MoveState/MoveLabel
@onready var move_dir_label: Label = $VBox/KeyContainer/MoveSection/MoveDirLabel
@onready var shoot_state: ColorRect = $VBox/KeyContainer/ShootSection/ShootState
@onready var shoot_label: Label = $VBox/KeyContainer/ShootSection/ShootState/ShootLabel
@onready var shoot_info_label: Label = $VBox/KeyContainer/ShootSection/ShootInfoLabel
@onready var grounded_label: Label = $VBox/StatusSection/GroundedLabel
@onready var vel_label: Label = $VBox/StatusSection/VelLabel
@onready var enhanced_input_label: Label = $VBox/EnhancedInputLabel

# 玩家引用
var _player: Node2D = null

# 输入状态跟踪
var _jump_just_pressed_frame: int = -1

func _ready() -> void:
	# 延迟查找玩家，确保场景已加载
	call_deferred("_find_player")
	print("InputDebugWidget initialized")


func _find_player() -> void:
	var tree = get_tree()
	if tree:
		var players = tree.get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
			print("InputDebugWidget: Found player")
		else:
			# 继续尝试查找
			await get_tree().create_timer(0.5).timeout
			_find_player()


func _process(delta: float) -> void:
	_update_debug_display(delta)


func _update_debug_display(delta: float) -> void:
	# 更新跳跃状态
	_update_jump_display()
	
	# 更新冲刺状态
	_update_dash_display()
	
	# 更新移动状态
	_update_move_display()
	
	# 更新射击状态
	_update_shoot_display()
	
	# 更新玩家状态
	_update_player_status()
	
	# 更新EnhancedInput状态
	_update_enhanced_input_status()

func _update_jump_display() -> void:
	if not EnhancedInput.instance:
		jump_label.text = "NO EI"
		jump_state.color = COLOR_COOLDOWN
		return
	
	var jump_action = _get_player_jump_action()
	if not jump_action:
		jump_label.text = "NULL"
		jump_state.color = COLOR_COOLDOWN
		jump_timer_label.text = "action not set"
		return
	
	# 检测刚按下 (使用帧号检测)
	var is_pressed = EnhancedInput.instance.is_action_pressed(jump_action)
	var is_just_pressed = EnhancedInput.instance.is_action_just_pressed(jump_action)
	
	# 更新状态显示
	if is_just_pressed:
		_jump_just_pressed_frame = Engine.get_process_frames()
		jump_state.color = COLOR_JUST_PRESSED
		jump_label.text = "JUST!"
	elif is_pressed:
		jump_state.color = COLOR_PRESSED
		jump_label.text = "HELD"
	else:
		jump_state.color = COLOR_OFF
		jump_label.text = "OFF"
	
	# 显示计时器值
	if _player:
		var buf = _player.get("jump_buffer_timer")
		var coy = _player.get("coyote_timer")
		var var_timer = _player.get("_var_jump_timer")
		var jump_held = _player.get("_jump_held")
		if buf != null and coy != null:
			var held_str = "H" if jump_held else "h"
			jump_timer_label.text = "buf:%.2f coy:%.2f var:%.2f [%s]" % [buf, coy, var_timer, held_str]


func _update_dash_display() -> void:
	if not _player:
		dash_label.text = "NO PLY"
		dash_state_ui.color = COLOR_COOLDOWN
		dash_timer_label.text = "player not found"
		return
	
	var dash_state_val: int = _player.get("dash_state") if _player else -1
	var dash_cooldown: float = _player.get("_dash_cooldown_timer") if _player else 0.0
	var air_dashes: int = _player.get("_air_dashes_used") if _player else 0
	var max_air: int = _player.get("max_air_dashes") if _player else 1
	
	# 更新状态显示
	match dash_state_val:
		0:  # DashState.IDLE
			dash_label.text = "IDLE"
			dash_state_ui.color = COLOR_OFF
		1:  # DashState.DASHING
			dash_label.text = "DASHING"
			dash_state_ui.color = COLOR_PRESSED
		2:  # DashState.COOLDOWN
			dash_label.text = "COOLDOWN"
			dash_state_ui.color = COLOR_COOLDOWN
		_:
			dash_label.text = "?"
			dash_state_ui.color = COLOR_COOLDOWN
	
	dash_timer_label.text = "cd:%.1f air:%d/%d" % [dash_cooldown, air_dashes, max_air]


func _update_move_display() -> void:
	if not EnhancedInput.instance:
		move_label.text = "NO EI"
		move_state.color = COLOR_COOLDOWN
		return
	
	var move_action = _get_player_move_action()
	if not move_action:
		move_label.text = "NULL"
		move_state.color = COLOR_COOLDOWN
		move_dir_label.text = "action not set"
		return
	
	var move_vec = EnhancedInput.instance.get_axis_2d(move_action)
	var move_x = move_vec.x
	
	# 更新状态显示
	if abs(move_x) > 0.1:
		move_state.color = COLOR_PRESSED
	else:
		move_state.color = COLOR_OFF
	
	move_label.text = "%.2f" % move_x
	
	# 方向指示
	var left_str = "LEFT" if move_x < -0.1 else "left"
	var right_str = "RIGHT" if move_x > 0.1 else "right"
	move_dir_label.text = "%s | %s" % [left_str, right_str]


func _update_player_status() -> void:
	if not _player:
		grounded_label.text = "[GROUND: ?]"
		vel_label.text = "[VEL: ?, ?]"
		return
	
	var is_grounded = _player.get("is_grounded")
	var vel = _player.get("velocity") if _player.get("velocity") else Vector2.ZERO
	
	grounded_label.text = "[GROUND: %s]" % ["YES" if is_grounded else "NO"]
	vel_label.text = "[VEL: %.0f, %.0f]" % [vel.x, vel.y]


func _update_enhanced_input_status() -> void:
	if EnhancedInput.instance:
		var ctx_enabled = EnhancedInput.instance.is_gameplay_context_enabled()
		enhanced_input_label.text = "EnhancedInput: %s" % ["ACTIVE" if ctx_enabled else "INACTIVE"]
		enhanced_input_label.modulate = Color.GREEN if ctx_enabled else Color.RED
	else:
		enhanced_input_label.text = "EnhancedInput: MISSING!"
		enhanced_input_label.modulate = Color.RED


func _get_player_jump_action() -> Resource:
	if _player and _player.get("jump_action"):
		return _player.jump_action
	return null


func _get_player_dash_action() -> Resource:
	if _player and _player.get("dash_action"):
		return _player.dash_action
	return null


func _get_player_move_action() -> Resource:
	if _player and _player.get("move_action"):
		return _player.move_action
	return null


func _get_player_shoot_action() -> Resource:
	if _player and _player.get("shoot_action"):
		return _player.shoot_action
	return null


func _update_shoot_display() -> void:
	if not EnhancedInput.instance:
		shoot_label.text = "NO EI"
		shoot_state.color = COLOR_COOLDOWN
		return
	
	var shoot_action = _get_player_shoot_action()
	if not shoot_action:
		shoot_label.text = "NULL"
		shoot_state.color = COLOR_COOLDOWN
		shoot_info_label.text = "action not set"
		return
	
	# 检测输入状态
	var is_pressed = EnhancedInput.instance.is_action_pressed(shoot_action)
	var is_just_pressed = EnhancedInput.instance.is_action_just_pressed(shoot_action)
	
	# 更新状态显示
	if is_just_pressed:
		shoot_state.color = COLOR_JUST_PRESSED
		shoot_label.text = "JUST!"
	elif is_pressed:
		shoot_state.color = COLOR_PRESSED
		shoot_label.text = "HELD"
	else:
		shoot_state.color = COLOR_OFF
		shoot_label.text = "OFF"
	
	# 显示武器信息
	if _player:
		var current_weapon = _player.get("current_weapon")
		if current_weapon:
			var ammo_value = current_weapon.get("current_ammo_in_mag")
			var mag_size_value = current_weapon.get("magazine_size")
			var can_shoot_value = current_weapon.get("can_shoot")
			var is_reloading_value = current_weapon.get("is_reloading")

			var ammo: int = int(ammo_value) if ammo_value != null else 0
			var mag_size: int = int(mag_size_value) if mag_size_value != null else 0
			var can_shoot: bool = bool(can_shoot_value) if can_shoot_value != null else false
			var is_reloading: bool = bool(is_reloading_value) if is_reloading_value != null else false
			var status = "R" if is_reloading else ("✓" if can_shoot else "✗")
			shoot_info_label.text = "ammo:%d/%d [%s]" % [ammo, mag_size, status]
		else:
			shoot_info_label.text = "no weapon"
	else:
		shoot_info_label.text = "no player"
