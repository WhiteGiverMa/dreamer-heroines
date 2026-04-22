class_name LockIndicator
extends CanvasLayer

## LockIndicator - 锁定反馈 UI 组件
## 显示锁定框（目标高亮边框）和瞄准线（从角色到目标的连线）

# ============================================
# Exports
# ============================================

@export var lock_frame_color: Color = Color(1.0, 0.8, 0.0, 0.8)
@export var aim_line_color: Color = Color(1.0, 0.8, 0.0, 0.6)
@export var aim_line_width: float = 2.0
@export var frame_padding: float = 10.0
@export var fade_duration: float = 0.15

# ============================================
# Onready References
# ============================================

@onready var lock_frame: ColorRect = $LockFrame
@onready var aim_line: Line2D = $AimLine

# ============================================
# Private Fields
# ============================================

var _target_acquisition: TargetAcquisition = null
var _player: Node2D = null
var _current_target: Node2D = null

# ============================================
# Lifecycle
# ============================================

func _ready() -> void:
	_find_target_acquisition()
	_find_player()
	_initialize_visuals()


func _initialize_visuals() -> void:
	if lock_frame:
		lock_frame.visible = false
		lock_frame.color = lock_frame_color

	if aim_line:
		aim_line.visible = false
		aim_line.default_color = aim_line_color
		aim_line.width = aim_line_width


# ============================================
# Target Acquisition Discovery
# ============================================

func _find_target_acquisition() -> void:
	# 优先从 autoload 查找
	var ta := get_node_or_null("/root/TargetAcquisition")
	if ta is TargetAcquisition:
		_target_acquisition = ta

	# 回退：从玩家节点查找
	if _target_acquisition == null:
		var players := get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			var p := players[0]
			ta = p.get_node_or_null("TargetAcquisition")
			if ta is TargetAcquisition:
				_target_acquisition = ta

	if _target_acquisition:
		if not _target_acquisition.target_locked.is_connected(_on_target_locked):
			_target_acquisition.target_locked.connect(_on_target_locked)
		if not _target_acquisition.target_unlocked.is_connected(_on_target_unlocked):
			_target_acquisition.target_unlocked.connect(_on_target_unlocked)


func _find_player() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


# ============================================
# Signal Callbacks
# ============================================

func _on_target_locked(target: Node2D) -> void:
	var is_switch := (_current_target != null and _current_target != target)
	_current_target = target
	_show_indicator()
	_play_lock_sound(is_switch)


func _on_target_unlocked() -> void:
	_current_target = null
	_hide_indicator()


func _play_lock_sound(is_switch: bool = false) -> void:
	if not AudioManager:
		return

	var settings := SaveManager.load_settings()
	var sound_enabled: bool = settings.get("mobile_lock_on_sound_enabled", true)
	if not sound_enabled:
		return

	var sound_key := "target_switch" if is_switch else "lock_on"
	AudioManager.play_sfx(sound_key)


# ============================================
# Visual Transitions
# ============================================

func _show_indicator() -> void:
	if lock_frame:
		lock_frame.visible = true
		lock_frame.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(lock_frame, "modulate:a", 1.0, fade_duration)

	if aim_line:
		aim_line.visible = true
		aim_line.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(aim_line, "modulate:a", 1.0, fade_duration)


func _hide_indicator() -> void:
	if lock_frame:
		var tween := create_tween()
		tween.tween_property(lock_frame, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(func():
			if lock_frame:
				lock_frame.visible = false
		)

	if aim_line:
		var tween := create_tween()
		tween.tween_property(aim_line, "modulate:a", 0.0, fade_duration)
		tween.tween_callback(func():
			if aim_line:
				aim_line.visible = false
		)


# ============================================
# Per-frame Updates
# ============================================

func _process(_delta: float) -> void:
	if not is_instance_valid(_current_target):
		if lock_frame and lock_frame.visible:
			_hide_indicator()
		return

	_update_lock_frame()
	_update_aim_line()


# ============================================
# Coordinate Conversion
# ============================================

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos


# ============================================
# Target Size Detection
# ============================================

func _get_target_size() -> Vector2:
	if not is_instance_valid(_current_target):
		return Vector2(32, 32)

	# 尝试从碰撞形状获取大小
	var collision := _current_target.get_node_or_null("CollisionShape2D")
	if collision:
		var shape := collision.shape
		if shape is RectangleShape2D:
			return shape.size
		elif shape is CircleShape2D:
			return Vector2(shape.radius * 2, shape.radius * 2)
		elif shape is CapsuleShape2D:
			return Vector2(shape.radius * 2, shape.height)

	# 尝试从 Sprite2D 获取大小
	var sprite := _current_target.get_node_or_null("Sprite2D")
	if sprite and sprite.texture:
		return sprite.texture.get_size() * sprite.scale

	return Vector2(32, 32)


# ============================================
# Lock Frame Update
# ============================================

func _update_lock_frame() -> void:
	if not _current_target or not lock_frame:
		return

	var screen_pos := _world_to_screen(_current_target.global_position)
	var target_size := _get_target_size()
	var frame_size := target_size + Vector2(frame_padding * 2, frame_padding * 2)

	lock_frame.position = screen_pos - frame_size * 0.5
	lock_frame.size = frame_size


# ============================================
# Aim Line Update
# ============================================

func _update_aim_line() -> void:
	if not _current_target or not _player or not aim_line:
		return

	var player_screen_pos := _world_to_screen(_player.global_position)
	var target_screen_pos := _world_to_screen(_current_target.global_position)

	aim_line.points = PackedVector2Array([player_screen_pos, target_screen_pos])
