class_name WaveSpawner
extends Node

signal wave_started(wave_number: int)
signal wave_complete(wave_number: int)
signal enemy_spawned(enemy: Node)
signal all_waves_complete

@export_file("*.json") var wave_config_path: String = "res://config/waves/arena_01_waves.json"
@export var spawn_points_path: NodePath = NodePath("SpawnPoints")
@export var auto_start: bool = true

const ENEMY_KEY_ALIASES := {
	"melee_grunt": "melee",
	"melee_fast": "melee",
	"melee_tank": "melee",
	"ranged_grunt": "ranged_basic",
	"ranged_basic": "ranged_basic",
	"flying_drone": "flying_basic",
	"flying_basic": "flying_basic"
}

const ENEMY_SCENE_BY_KEY := {
	"melee": "res://scenes/enemies/melee_enemy.tscn",
	"ranged_basic": "res://scenes/enemies/ranged_enemy.tscn",
	"flying_basic": "res://scenes/enemies/flying_enemy.tscn"
}

var _rng := RandomNumberGenerator.new()
var _spawn_timer: Timer
var _wave_timer: Timer

var _waves: Array[Dictionary] = []
var _wave_interval: float = 3.0
var _max_concurrent_enemies: int = 10
var _spawn_points: Array[Marker2D] = []

var _is_running: bool = false
var _current_wave_index: int = -1
var _pending_enemy_keys: Array[String] = []
var _active_wave_enemy_ids := {}


func _ready() -> void:
	_rng.randomize()
	_create_timers()
	_load_wave_config()
	_collect_spawn_points()

	if auto_start:
		call_deferred("start")


func start() -> void:
	if _is_running:
		return

	if _waves.is_empty():
		push_error("WaveSpawner: no waves loaded from %s" % wave_config_path)
		return

	if _spawn_points.is_empty():
		push_error("WaveSpawner: no Marker2D spawn points found under SpawnPoints")
		return

	_is_running = true
	_current_wave_index = -1
	_start_next_wave()


func stop() -> void:
	_is_running = false
	if _spawn_timer:
		_spawn_timer.stop()
	if _wave_timer:
		_wave_timer.stop()


func _create_timers() -> void:
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	_spawn_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	_wave_timer = Timer.new()
	_wave_timer.one_shot = true
	_wave_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(_wave_timer)
	_wave_timer.timeout.connect(_on_wave_interval_timeout)


func _load_wave_config() -> void:
	if not FileAccess.file_exists(wave_config_path):
		push_error("WaveSpawner: config file missing: %s" % wave_config_path)
		return

	var file: FileAccess = FileAccess.open(wave_config_path, FileAccess.READ)
	if file == null:
		push_error("WaveSpawner: failed to open config: %s" % wave_config_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		push_error("WaveSpawner: invalid JSON object in %s" % wave_config_path)
		return

	var waves_data: Variant = parsed.get("waves", [])
	if not (waves_data is Array):
		push_error("WaveSpawner: waves field is not an array")
		return

	_waves.clear()
	for wave_entry in waves_data:
		if wave_entry is Dictionary:
			_waves.append(wave_entry)

	_wave_interval = float(parsed.get("wave_interval", 3.0))
	_max_concurrent_enemies = int(parsed.get("max_concurrent_enemies", 10))


func _collect_spawn_points() -> void:
	_spawn_points.clear()

	var spawn_points_node: Node = _resolve_spawn_points_node()
	if spawn_points_node == null:
		return

	for child in spawn_points_node.get_children():
		if child is Marker2D and child.name.begins_with("EnemySpawn"):
			_spawn_points.append(child)

	if _spawn_points.is_empty():
		for child in spawn_points_node.get_children():
			if child is Marker2D:
				_spawn_points.append(child)


func _resolve_spawn_points_node() -> Node:
	var node: Node = get_node_or_null(spawn_points_path)
	if node:
		return node

	if get_parent() and get_parent().has_node("SpawnPoints"):
		return get_parent().get_node("SpawnPoints")

	if has_node("SpawnPoints"):
		return get_node("SpawnPoints")

	var current_scene: Node = get_tree().current_scene
	if current_scene and current_scene.has_node("SpawnPoints"):
		return current_scene.get_node("SpawnPoints")

	if current_scene:
		return _find_node_by_name(current_scene, "SpawnPoints")

	return null


func _find_node_by_name(root: Node, target_name: String) -> Node:
	if root.name == target_name:
		return root

	for child in root.get_children():
		var result: Node = _find_node_by_name(child, target_name)
		if result:
			return result

	return null


func _start_next_wave() -> void:
	_current_wave_index += 1
	if _current_wave_index >= _waves.size():
		_is_running = false
		all_waves_complete.emit()
		return

	var wave_data: Dictionary = _waves[_current_wave_index]
	var enemies_data: Variant = wave_data.get("enemies", [])
	_pending_enemy_keys.clear()
	if enemies_data is Array:
		for enemy_key in enemies_data:
			_pending_enemy_keys.append(String(enemy_key))

	_active_wave_enemy_ids.clear()

	var wave_number: int = int(wave_data.get("wave", _current_wave_index + 1))
	wave_started.emit(wave_number)

	var first_delay: float = max(0.01, float(wave_data.get("spawn_delay", 1.0)))
	_spawn_timer.start(first_delay)


func _on_wave_interval_timeout() -> void:
	if not _is_running:
		return
	_start_next_wave()


func _on_spawn_timer_timeout() -> void:
	if not _is_running:
		return

	if _pending_enemy_keys.is_empty():
		_check_wave_completion()
		return

	if get_tree().get_nodes_in_group("enemy").size() >= _max_concurrent_enemies:
		_spawn_timer.start(0.2)
		return

	var enemy_key: String = _pending_enemy_keys.pop_front()
	var enemy: Node = _spawn_enemy(enemy_key)
	if enemy:
		enemy_spawned.emit(enemy)

	if _pending_enemy_keys.is_empty():
		_check_wave_completion()
		return

	var wave_data: Dictionary = _waves[_current_wave_index]
	var spawn_delay: float = max(0.05, float(wave_data.get("spawn_delay", 1.0)))
	_spawn_timer.start(spawn_delay)


func _spawn_enemy(raw_enemy_key: String) -> Node:
	var enemy_key: String = _resolve_enemy_key(raw_enemy_key)
	var scene_path: String = ENEMY_SCENE_BY_KEY.get(enemy_key, "")
	if scene_path.is_empty():
		push_warning("WaveSpawner: unsupported enemy key '%s'" % raw_enemy_key)
		return null

	var enemy_scene: PackedScene = load(scene_path) as PackedScene
	if enemy_scene == null:
		push_error("WaveSpawner: failed to load enemy scene: %s" % scene_path)
		return null

	if _spawn_points.is_empty():
		push_warning("WaveSpawner: no spawn points available")
		return null

	var spawn_point: Marker2D = _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
	var enemy: Node = enemy_scene.instantiate()
	if enemy == null:
		return null

	if enemy is Node2D:
		enemy.global_position = spawn_point.global_position

	var spawn_parent: Node = (
		get_tree().current_scene if get_tree() and get_tree().current_scene else self
	)
	spawn_parent.add_child(enemy)

	_track_wave_enemy(enemy, _current_wave_index)
	return enemy


func _resolve_enemy_key(raw_enemy_key: String) -> String:
	if ENEMY_KEY_ALIASES.has(raw_enemy_key):
		return String(ENEMY_KEY_ALIASES[raw_enemy_key])
	return raw_enemy_key


func _track_wave_enemy(enemy: Node, wave_index: int) -> void:
	var enemy_id: int = enemy.get_instance_id()
	_active_wave_enemy_ids[enemy_id] = true

	if enemy.has_signal("died"):
		enemy.died.connect(_on_tracked_enemy_removed.bind(enemy_id, wave_index), CONNECT_ONE_SHOT)

	enemy.tree_exiting.connect(
		_on_tracked_enemy_removed.bind(enemy_id, wave_index), CONNECT_ONE_SHOT
	)


func _on_tracked_enemy_removed(enemy_id: int, wave_index: int) -> void:
	if wave_index != _current_wave_index:
		return

	if not _active_wave_enemy_ids.has(enemy_id):
		return

	_active_wave_enemy_ids.erase(enemy_id)
	_check_wave_completion()


func _check_wave_completion() -> void:
	if _current_wave_index < 0 or _current_wave_index >= _waves.size():
		return

	if not _pending_enemy_keys.is_empty():
		return

	if not _active_wave_enemy_ids.is_empty():
		return

	var wave_number: int = int(_waves[_current_wave_index].get("wave", _current_wave_index + 1))
	wave_complete.emit(wave_number)

	if _current_wave_index >= _waves.size() - 1:
		_is_running = false
		all_waves_complete.emit()
		return

	_wave_timer.start(max(0.05, _wave_interval))
