class_name EnemyIndicator
extends Control

# EnemyIndicator - 屏幕边缘敌人方向指示器
# 在屏幕边缘显示指向屏幕外敌人的箭头

# ============================================
# Exports
# ============================================

@export var max_enemies_for_display: int = 3
@export var enemy_arrow_scene: PackedScene

# ============================================
# Signals
# ============================================

signal indicator_enabled(enemy_count: int)
signal indicator_disabled(enemy_count: int)

# ============================================
# Private Fields
# ============================================

var _active_arrows: Dictionary = {}
var _arrow_indicators: Dictionary = {}
var _wave_spawner: Node
var _camera: Camera2D
var _viewport_bounds: Rect2
var _ui_margin: float = 50.0
var _overhead_offset: float = -50.0
var _threshold_armed: bool = false
var _pending_enemies: Array[Node] = []
var _removing_enemies: Dictionary = {}
var _rescan_interval: float = 0.5
var _rescan_elapsed: float = 0.0

# ============================================
# Lifecycle
# ============================================


func _ready() -> void:
	_wave_spawner = _find_wave_spawner()
	if _wave_spawner and not _wave_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
		_wave_spawner.enemy_spawned.connect(_on_enemy_spawned)

	_camera = get_viewport().get_camera_2d()
	_viewport_bounds = get_viewport().get_visible_rect()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_register_existing_enemies()
	call_deferred("_register_existing_enemies")
	_check_threshold()


func _register_existing_enemies() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	var existing_enemies: Array[Node] = tree.get_nodes_in_group("enemy")
	for enemy in existing_enemies:
		if not is_instance_valid(enemy):
			continue

		var enemy_id: int = enemy.get_instance_id()
		if _active_arrows.has(enemy_id):
			continue
		if _removing_enemies.has(enemy_id):
			continue

		_connect_enemy_signals(enemy)
		_active_arrows[enemy_id] = enemy
		if not _pending_enemies.has(enemy):
			_pending_enemies.append(enemy)

	_check_threshold()


func _find_wave_spawner() -> Node:
	var spawners: Array[Node] = get_tree().get_nodes_in_group("wave_spawner")
	if spawners.is_empty():
		return null
	return spawners[0]


func _connect_enemy_signals(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id: int = enemy.get_instance_id()
	if enemy.has_signal("died"):
		var on_enemy_died_callable := _on_enemy_died.bind(enemy_id)
		if not enemy.died.is_connected(on_enemy_died_callable):
			enemy.died.connect(on_enemy_died_callable, CONNECT_ONE_SHOT)
	var on_enemy_removed_callable := _on_enemy_removed.bind(enemy_id)
	if not enemy.tree_exiting.is_connected(on_enemy_removed_callable):
		enemy.tree_exiting.connect(on_enemy_removed_callable, CONNECT_ONE_SHOT)


func _on_enemy_spawned(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var enemy_id: int = enemy.get_instance_id()
	if _active_arrows.has(enemy_id):
		return
	if _removing_enemies.has(enemy_id):
		return
	_connect_enemy_signals(enemy)
	_active_arrows[enemy_id] = enemy
	if not _pending_enemies.has(enemy):
		_pending_enemies.append(enemy)
	_check_threshold()


func _on_enemy_died(enemy_instance_id: int) -> void:
	_removing_enemies[enemy_instance_id] = true
	_active_arrows.erase(enemy_instance_id)
	_remove_arrow_for_enemy(enemy_instance_id)
	_check_threshold()


func _on_enemy_removed(enemy_instance_id: int) -> void:
	_removing_enemies.erase(enemy_instance_id)
	_active_arrows.erase(enemy_instance_id)
	_remove_arrow_for_enemy(enemy_instance_id)
	_check_threshold()


func _check_threshold() -> void:
	var enemy_count: int = _active_arrows.size()
	if enemy_count <= max_enemies_for_display and not _threshold_armed:
		indicator_enabled.emit(enemy_count)
		_threshold_armed = true
	elif enemy_count > max_enemies_for_display and _threshold_armed:
		indicator_disabled.emit(enemy_count)
		_threshold_armed = false


func _world_to_screen(world_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return world_pos

	var viewport := get_viewport()
	if viewport == null:
		return world_pos

	# CanvasTransform already includes active Camera2D transform.
	return viewport.get_canvas_transform() * world_pos


func _is_on_screen(screen_pos: Vector2) -> bool:
	var expanded_bounds := _viewport_bounds.expand(_viewport_bounds.position - Vector2(5, 5))
	expanded_bounds = expanded_bounds.expand(_viewport_bounds.end + Vector2(5, 5))
	return expanded_bounds.has_point(screen_pos)


func _get_edge_position(screen_pos: Vector2) -> Vector2:
	if _is_on_screen(screen_pos):
		return screen_pos
	var viewport_center := _viewport_bounds.position + _viewport_bounds.size / 2
	var direction := (screen_pos - viewport_center).normalized()
	var margin := Vector2(_ui_margin, _ui_margin)
	var edge_min := _viewport_bounds.position + margin
	var edge_max := _viewport_bounds.end - margin
	var t := INF
	if direction.x != 0:
		var tx_right := (edge_max.x - viewport_center.x) / direction.x
		var tx_left := (edge_min.x - viewport_center.x) / direction.x
		t = min(t, tx_right if tx_right > 0 else INF)
		t = min(t, tx_left if tx_left > 0 else INF)
	if direction.y != 0:
		var ty_bottom := (edge_max.y - viewport_center.y) / direction.y
		var ty_top := (edge_min.y - viewport_center.y) / direction.y
		t = min(t, ty_bottom if ty_bottom > 0 else INF)
		t = min(t, ty_top if ty_top > 0 else INF)
	return viewport_center + direction * max(0, t)


func _on_viewport_size_changed() -> void:
	_viewport_bounds = get_viewport().get_visible_rect()


func _process(delta: float) -> void:
	_rescan_elapsed += delta
	if _rescan_elapsed >= _rescan_interval:
		_rescan_elapsed = 0.0
		_register_existing_enemies()

	# Clean up stale enemy references first
	var stale_enemies: Array = []
	for enemy_id in _active_arrows:
		var enemy = instance_from_id(enemy_id)
		if not is_instance_valid(enemy):
			stale_enemies.append(enemy_id)

	for enemy_id in stale_enemies:
		_active_arrows.erase(enemy_id)
		_remove_arrow_for_enemy(enemy_id)

	# Process pending enemies queue
	for enemy in _pending_enemies:
		if is_instance_valid(enemy):
			_update_arrow_for_enemy(enemy)
	_pending_enemies.clear()

	# Update positions for valid enemies
	for enemy_id in _active_arrows:
		var enemy = instance_from_id(enemy_id)
		if is_instance_valid(enemy):
			_update_arrow_for_enemy(enemy)


func _create_arrow_for_enemy(enemy: Node) -> void:
	if enemy_arrow_scene == null:
		return
	var arrow: EnemyArrow = enemy_arrow_scene.instantiate()
	add_child(arrow)
	arrow.set_state(EnemyArrow.ArrowState.HIDDEN)
	arrow.fade_in()
	_arrow_indicators[enemy.get_instance_id()] = arrow


func _remove_arrow_for_enemy(enemy_instance_id: int) -> void:
	if not _arrow_indicators.has(enemy_instance_id):
		return
	var arrow: EnemyArrow = _arrow_indicators[enemy_instance_id]
	_arrow_indicators.erase(enemy_instance_id)
	if not is_instance_valid(arrow):
		return
	arrow.fade_out()
	await arrow.fade_out_complete
	if is_instance_valid(arrow):
		arrow.queue_free()


func _update_arrow_for_enemy(enemy: Node) -> void:
	var enemy_id: int = enemy.get_instance_id()

	if not _arrow_indicators.has(enemy_id):
		_create_arrow_for_enemy(enemy)

	var arrow: EnemyArrow = _arrow_indicators[enemy_id]
	var screen_pos: Vector2 = _world_to_screen(enemy.global_position)

	if _is_on_screen(screen_pos):
		arrow.set_state(EnemyArrow.ArrowState.OVERHEAD)
		arrow.set_target_position(enemy.global_position)
		var display_pos := screen_pos + Vector2(0, _overhead_offset)
		arrow.global_position = display_pos - arrow.get_visual_size() * 0.5
	else:
		var edge_pos: Vector2 = _get_edge_position(screen_pos)
		arrow.set_state(EnemyArrow.ArrowState.EDGE)
		arrow.set_target_position(screen_pos)
		arrow.global_position = edge_pos - arrow.get_visual_size() * 0.5
