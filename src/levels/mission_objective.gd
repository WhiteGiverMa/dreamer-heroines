class_name MissionObjective
extends Node

signal score_changed(current: int, target: int)
signal objective_complete
signal objective_failed(reason: String)

@export var target_kills: int = 25
@export var auto_start_on_ready: bool = true

var _current_kills: int = 0
var _is_active: bool = false
var _is_completed: bool = false
var _tracked_enemy_ids := {}


func _ready() -> void:
	if auto_start_on_ready:
		start(true)


func _exit_tree() -> void:
	_set_tree_tracking_enabled(false)


func start(reset_progress: bool = true) -> void:
	if reset_progress:
		reset()

	_is_active = true
	_set_tree_tracking_enabled(true)
	_track_existing_enemies()


func stop() -> void:
	_is_active = false
	_set_tree_tracking_enabled(false)


func reset() -> void:
	_current_kills = 0
	_is_completed = false
	_tracked_enemy_ids.clear()


func add_kill(amount: int = 1) -> void:
	if not _is_active or _is_completed:
		return

	if amount <= 0:
		return

	_current_kills += amount
	score_changed.emit(_current_kills, target_kills)

	if _current_kills >= target_kills:
		_is_completed = true
		_is_active = false
		_set_tree_tracking_enabled(false)
		objective_complete.emit()


func fail(reason: String) -> void:
	if reason.is_empty():
		reason = "unknown"

	if not _is_completed:
		_is_active = false
		_set_tree_tracking_enabled(false)
		objective_failed.emit(reason)


func register_enemy(enemy: Node) -> bool:
	if enemy == null:
		return false

	if not enemy.has_signal("died"):
		return false

	var enemy_id: int = enemy.get_instance_id()
	if _tracked_enemy_ids.has(enemy_id):
		return false

	_tracked_enemy_ids[enemy_id] = true
	var on_died: Callable = _on_enemy_died.bind(enemy_id)
	if not enemy.is_connected("died", on_died):
		enemy.connect("died", on_died, CONNECT_ONE_SHOT)

	var on_tree_exiting: Callable = _on_enemy_tree_exiting.bind(enemy_id)
	if not enemy.is_connected("tree_exiting", on_tree_exiting):
		enemy.connect("tree_exiting", on_tree_exiting, CONNECT_ONE_SHOT)
	return true


func track_enemies(enemies: Array[Node]) -> void:
	for enemy in enemies:
		register_enemy(enemy)


func track_tree_enemies(root: Node = null) -> void:
	var tree_ref: SceneTree = get_tree()
	if tree_ref == null:
		return

	if root == null:
		for node in tree_ref.get_nodes_in_group("enemy"):
			if node is Node:
				register_enemy(node)
		return

	for child in root.get_children():
		if child is Node:
			if child.is_in_group("enemy") and child.has_signal("died"):
				register_enemy(child)
			track_tree_enemies(child)


func get_current_kills() -> int:
	return _current_kills


func is_completed() -> bool:
	return _is_completed


func is_active() -> bool:
	return _is_active


func _track_existing_enemies() -> void:
	track_tree_enemies()


func _set_tree_tracking_enabled(enabled: bool) -> void:
	var tree_ref: SceneTree = get_tree()
	if tree_ref == null:
		return

	var callable_ref: Callable = Callable(self, "_on_tree_node_added")
	var is_connected_now: bool = tree_ref.node_added.is_connected(callable_ref)

	if enabled and not is_connected_now:
		tree_ref.node_added.connect(callable_ref)
	elif not enabled and is_connected_now:
		tree_ref.node_added.disconnect(callable_ref)


func _on_tree_node_added(node: Node) -> void:
	if not _is_active or _is_completed:
		return

	call_deferred("_deferred_try_register_enemy", node)


func _deferred_try_register_enemy(node: Node) -> void:
	if not _is_active or _is_completed:
		return

	if node == null:
		return

	if node.is_in_group("enemy") and node.has_signal("died"):
		register_enemy(node)


func _on_enemy_died(enemy_id: int) -> void:
	if not _tracked_enemy_ids.has(enemy_id):
		return

	_tracked_enemy_ids.erase(enemy_id)
	add_kill(1)


func _on_enemy_tree_exiting(enemy_id: int) -> void:
	if _tracked_enemy_ids.has(enemy_id):
		_tracked_enemy_ids.erase(enemy_id)
