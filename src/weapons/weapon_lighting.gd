@tool
class_name WeaponLighting
extends Node2D

# WeaponLighting - 武器手电筒组件
# 通过 LightBudgetManager 管理光源预算，使用 Tween 做平滑开关

const TRANSITION_DURATION := 0.1
const BUDGET_RETRY_INTERVAL := 0.15
const DEFAULT_CONE_TEXTURE_SIZE := Vector2i(512, 256)
const DEFAULT_CONE_LENGTH_RATIO := 0.92
const DEFAULT_CONE_HALF_WIDTH_RATIO := 0.28
const DEFAULT_CONE_SOFTNESS_RATIO := 0.08

@export var config: LightSettings = null:
	set(value):
		config = value
		_queue_refresh_light_setup()

@export var preview_in_editor: bool = true:
	set(value):
		preview_in_editor = value
		_queue_refresh_light_setup()

var light_node: PointLight2D = null
var is_on: bool = false

var _has_budget_slot: bool = false
var _is_waiting_for_budget: bool = false
var _budget_retry_cooldown: float = 0.0
var _tween: Tween = null
var _setup_refresh_queued: bool = false


func _enter_tree() -> void:
	_ensure_light_node()
	_queue_refresh_light_setup()


func _ready() -> void:
	if config == null:
		config = null

	_ensure_light_node()
	_queue_refresh_light_setup()
	set_process(false)


func _process(delta: float) -> void:
	if not _is_waiting_for_budget:
		return

	if not is_on:
		_is_waiting_for_budget = false
		set_process(false)
		return

	_budget_retry_cooldown -= delta
	if _budget_retry_cooldown > 0.0:
		return

	_budget_retry_cooldown = BUDGET_RETRY_INTERVAL
	if _request_budget_slot():
		_is_waiting_for_budget = false
		set_process(false)
		_animate_turn_on()


func toggle() -> void:
	if is_on:
		turn_off()
	else:
		turn_on()


func turn_on() -> void:
	if is_on:
		return

	is_on = true

	if _has_budget_slot:
		_animate_turn_on()
		return

	if _request_budget_slot():
		_animate_turn_on()
		return

	_queue_for_budget()


func turn_off() -> void:
	if not is_on and not _is_waiting_for_budget and not _has_budget_slot:
		return

	is_on = false
	_is_waiting_for_budget = false
	set_process(false)

	if not _has_budget_slot:
		_stop_tween_if_needed()
		if light_node:
			light_node.enabled = false
			light_node.energy = 0.0
		return

	_animate_turn_off_and_release()


func set_config(new_config: LightSettings) -> void:
	if new_config == null:
		return

	config = new_config
	_queue_refresh_light_setup()

	# 已开启状态下，平滑过渡到新的目标亮度
	if is_on and _has_budget_slot:
		_animate_turn_on()


func _refresh_light_setup() -> void:
	_setup_refresh_queued = false

	if not is_inside_tree():
		return

	if config == null:
		config = null

	_ensure_light_node()
	_apply_config_to_light()
	_apply_light_enabled_state()


func _queue_refresh_light_setup() -> void:
	if not is_inside_tree():
		return

	if _setup_refresh_queued:
		return

	_setup_refresh_queued = true
	call_deferred("_refresh_light_setup")


func _ensure_light_node() -> void:
	if light_node and is_instance_valid(light_node):
		return

	light_node = get_node_or_null("WeaponFlashlight") as PointLight2D
	if light_node:
		return

	light_node = PointLight2D.new()
	light_node.name = "WeaponFlashlight"
	light_node.position = Vector2.ZERO
	add_child(light_node)


func _apply_light_enabled_state() -> void:
	if light_node == null:
		return

	if Engine.is_editor_hint():
		light_node.enabled = preview_in_editor
		light_node.energy = _get_target_energy() if preview_in_editor else 0.0
		return

	light_node.enabled = false
	light_node.energy = 0.0


func _apply_config_to_light() -> void:
	if light_node == null:
		return

	var texture_to_use: Texture2D = null
	var using_default_cone := false
	if config and config.texture:
		texture_to_use = config.texture
	else:
		texture_to_use = _create_default_cone_texture()
		using_default_cone = true

	light_node.texture = texture_to_use

	if config:
		light_node.color = config.color
		light_node.texture_scale = maxf(config.light_range / float(DEFAULT_CONE_TEXTURE_SIZE.x), 0.01)
		light_node.shadow_enabled = config.shadows_enabled
	else:
		light_node.color = Color.WHITE
		light_node.texture_scale = 1.0
		light_node.shadow_enabled = false

	light_node.position = _get_light_local_offset(using_default_cone)


func _request_budget_slot() -> bool:
	if _has_budget_slot:
		return true

	var manager := _get_budget_manager()
	if manager == null:
		push_warning("[WeaponLighting] LightBudgetManager 不可用，无法申请光源预算")
		return false

	var priority := LightBudgetManager.Priority.HIGH
	if config:
		priority = (
			clampi(config.priority, LightBudgetManager.Priority.HIGH, LightBudgetManager.Priority.LOW)
			as LightBudgetManager.Priority
		)

	if manager.request_light(priority):
		_has_budget_slot = true
		return true

	return false


func _queue_for_budget() -> void:
	_is_waiting_for_budget = true
	_budget_retry_cooldown = 0.0
	set_process(true)


func _release_budget_slot() -> void:
	if not _has_budget_slot:
		return

	var manager := _get_budget_manager()
	if manager:
		manager.release_light()

	_has_budget_slot = false


func _animate_turn_on() -> void:
	if light_node == null:
		return

	_stop_tween_if_needed()

	light_node.enabled = true
	_tween = create_tween()
	_tween.tween_property(light_node, "energy", _get_target_energy(), TRANSITION_DURATION)


func _animate_turn_off_and_release() -> void:
	if light_node == null:
		_release_budget_slot()
		return

	_stop_tween_if_needed()

	_tween = create_tween()
	_tween.tween_property(light_node, "energy", 0.0, TRANSITION_DURATION)
	_tween.tween_callback(_on_turn_off_finished)


func _on_turn_off_finished() -> void:
	if light_node:
		light_node.enabled = false
	_release_budget_slot()


func _get_target_energy() -> float:
	if config:
		return config.energy
	return 1.0


func _get_light_local_offset(using_default_cone: bool) -> Vector2:
	var offset := Vector2.ZERO

	if config:
		offset += config.local_offset

	if using_default_cone:
		offset.x += (float(DEFAULT_CONE_TEXTURE_SIZE.x) * 0.5) * light_node.texture_scale

	return offset


func _get_budget_manager() -> Node:
	return get_node_or_null("/root/LightBudgetManager")


func _stop_tween_if_needed() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _create_default_cone_texture() -> Texture2D:
	var image := Image.create(
		DEFAULT_CONE_TEXTURE_SIZE.x, DEFAULT_CONE_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8
	)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	var origin := Vector2(0.0, DEFAULT_CONE_TEXTURE_SIZE.y * 0.5)
	var max_distance := DEFAULT_CONE_TEXTURE_SIZE.x * DEFAULT_CONE_LENGTH_RATIO
	var half_width := DEFAULT_CONE_TEXTURE_SIZE.y * DEFAULT_CONE_HALF_WIDTH_RATIO
	var edge_softness := maxf(DEFAULT_CONE_TEXTURE_SIZE.y * DEFAULT_CONE_SOFTNESS_RATIO, 1.0)

	for y in range(DEFAULT_CONE_TEXTURE_SIZE.y):
		for x in range(DEFAULT_CONE_TEXTURE_SIZE.x):
			var pixel_pos := Vector2(float(x), float(y))
			var local := pixel_pos - origin

			if local.x < 0.0 or local.x > max_distance:
				continue

			var distance_ratio := local.x / max_distance
			var allowed_half_width := maxf(distance_ratio * half_width, 1.0)
			var vertical_distance := absf(local.y)
			var edge_alpha := (
				1.0
				- smoothstep(
					allowed_half_width - edge_softness, allowed_half_width, vertical_distance
				)
			)
			if edge_alpha <= 0.0:
				continue

			var distance_alpha := 1.0 - pow(distance_ratio, 1.35)
			var alpha := clampf(edge_alpha * distance_alpha, 0.0, 1.0)
			if alpha <= 0.0:
				continue

			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)


func _exit_tree() -> void:
	_stop_tween_if_needed()
	_release_budget_slot()
