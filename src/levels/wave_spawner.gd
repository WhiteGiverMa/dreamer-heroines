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
	"melee": "melee",
	"ranged_grunt": "ranged_basic",
	"ranged_basic": "ranged_basic",
	"ranged": "ranged_basic",
	"flying_drone": "flying_basic",
	"flying_basic": "flying_basic",
	"flying": "flying_basic"
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
var _target_kills: int = -1
var _extension_wave_cycle: Array[int] = []
var _spawn_points: Array[Marker2D] = []

var _is_running: bool = false
var _current_wave_index: int = -1
var _current_wave_data: Dictionary = {}
var _pending_enemy_keys: Array[String] = []
var _active_wave_enemy_ids := {}
var _extension_wave_cursor: int = 0
var _has_emitted_all_waves_complete: bool = false


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
	_current_wave_data.clear()
	_pending_enemy_keys.clear()
	_active_wave_enemy_ids.clear()
	_extension_wave_cursor = 0
	_has_emitted_all_waves_complete = false
	_start_next_wave()


func stop() -> void:
	_is_running = false
	_current_wave_data.clear()
	_pending_enemy_keys.clear()
	_active_wave_enemy_ids.clear()
	if _spawn_timer:
		_spawn_timer.stop()
	if _wave_timer:
		_wave_timer.stop()


## 立即生成指定敌人
func spawn_enemy_now(enemy_key: String, position: Vector2 = Vector2.ZERO) -> Node:
	if not ENEMY_SCENE_BY_KEY.has(enemy_key):
		push_error("WaveSpawner: unknown enemy key: " + enemy_key)
		return null

	var scene_path: String = ENEMY_SCENE_BY_KEY[enemy_key]
	var enemy_scene: PackedScene = load(scene_path) as PackedScene
	if enemy_scene == null:
		push_error("WaveSpawner: failed to load enemy scene: %s" % scene_path)
		return null

	var enemy: Node = enemy_scene.instantiate()
	if enemy == null:
		return null

	if enemy is Node2D:
		if position != Vector2.ZERO:
			enemy.global_position = position
		elif not _spawn_points.is_empty():
			var spawn_point: Marker2D = _spawn_points[_rng.randi_range(0, _spawn_points.size() - 1)]
			enemy.global_position = spawn_point.global_position

	var spawn_parent: Node = (
		get_tree().current_scene if get_tree() and get_tree().current_scene else self
	)
	spawn_parent.add_child(enemy)
	enemy_spawned.emit(enemy)
	return enemy


## 跳转到指定波次
func skip_to_wave(wave_number: int) -> void:
	var total: int = _waves.size()
	if wave_number < 1 or wave_number > total:
		push_error("WaveSpawner: invalid wave number %d (valid range: 1-%d)" % [wave_number, total])
		return

	_current_wave_index = wave_number - 1
	_pending_enemy_keys.clear()
	_active_wave_enemy_ids.clear()
	_is_running = true

	if _spawn_timer:
		_spawn_timer.stop()
	if _wave_timer:
		_wave_timer.stop()

	var wave_data: Dictionary = _waves[_current_wave_index]
	_current_wave_data = wave_data.duplicate(true)
	var enemies_data: Variant = wave_data.get("enemies", [])
	if enemies_data is Array:
		for enemy_key in enemies_data:
			_pending_enemy_keys.append(String(enemy_key))

	var actual_wave_number: int = int(wave_data.get("wave", _current_wave_index + 1))
	wave_started.emit(actual_wave_number)

	var first_delay: float = max(0.01, float(wave_data.get("spawn_delay", 1.0)))
	_spawn_timer.start(first_delay)


## 获取当前波次号（从1开始）
func get_current_wave() -> int:
	return _current_wave_index + 1


## 获取总波次数
func get_total_waves() -> int:
	return _waves.size()


func get_total_enemy_count() -> int:
	var total := 0
	for wave in _waves:
		var enemies = wave.get("enemies", [])
		if enemies is Array:
			total += enemies.size()
	return total


func get_target_kills() -> int:
	if _target_kills > 0:
		return _target_kills
	return get_total_enemy_count()


## 清除所有当前敌人
func clear_all_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if enemy and enemy.has_method("die"):
			enemy.die()


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
	_target_kills = int(parsed.get("target_kills", -1))

	_extension_wave_cycle.clear()
	var extension_cycle_data: Variant = parsed.get("extension_wave_cycle", [])
	if extension_cycle_data is Array:
		for wave_number in extension_cycle_data:
			var zero_based_index := int(wave_number) - 1
			if zero_based_index >= 0 and zero_based_index < _waves.size():
				_extension_wave_cycle.append(zero_based_index)

	if _extension_wave_cycle.is_empty() and not _waves.is_empty():
		_extension_wave_cycle.append(_waves.size() - 1)


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
	_current_wave_data = _get_wave_data_for_index(_current_wave_index)
	if _current_wave_data.is_empty():
		_is_running = false
		push_warning("WaveSpawner: unable to build wave data for wave %d" % (_current_wave_index + 1))
		return

	var enemies_data: Variant = _current_wave_data.get("enemies", [])
	_pending_enemy_keys.clear()
	if enemies_data is Array:
		for enemy_key in enemies_data:
			_pending_enemy_keys.append(String(enemy_key))

	_active_wave_enemy_ids.clear()

	var wave_number: int = int(_current_wave_data.get("wave", _current_wave_index + 1))
	wave_started.emit(wave_number)

	var first_delay: float = max(0.01, float(_current_wave_data.get("spawn_delay", 1.0)))
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

	var spawn_delay: float = max(0.05, float(_current_wave_data.get("spawn_delay", 1.0)))
	_spawn_timer.start(spawn_delay)


func _get_wave_data_for_index(wave_index: int) -> Dictionary:
	if wave_index >= 0 and wave_index < _waves.size():
		return _waves[wave_index].duplicate(true)

	if _waves.is_empty():
		return {}

	var extension_source_index := _get_extension_source_wave_index()
	if extension_source_index < 0 or extension_source_index >= _waves.size():
		return {}

	var extension_wave_data := _waves[extension_source_index].duplicate(true)
	extension_wave_data["wave"] = wave_index + 1
	return extension_wave_data


func _get_extension_source_wave_index() -> int:
	if _extension_wave_cycle.is_empty():
		if _waves.is_empty():
			return -1
		return _waves.size() - 1

	var cycle_index := _extension_wave_cursor % _extension_wave_cycle.size()
	_extension_wave_cursor += 1
	return _extension_wave_cycle[cycle_index]


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
	if not _is_running:
		return

	if _current_wave_index < 0:
		return

	if not _pending_enemy_keys.is_empty():
		return

	if not _active_wave_enemy_ids.is_empty():
		return

	var wave_number: int = int(_current_wave_data.get("wave", _current_wave_index + 1))
	wave_complete.emit(wave_number)

	if _current_wave_index >= _waves.size() - 1 and not _has_emitted_all_waves_complete:
		_has_emitted_all_waves_complete = true
		all_waves_complete.emit()

	_wave_timer.start(max(0.05, _wave_interval))
