extends Node2D

const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"

var _wave_spawner: Node
var _mission_objective: Node
var _hud: Node
var _room_completion_handled: bool = false


func _ready() -> void:
	_prepare_runtime_state()
	_ensure_core_nodes()
	_wire_signals()
	_sync_hud_initial_state()


func _prepare_runtime_state() -> void:
	_room_completion_handled = false
	LevelManager.current_level = self
	LevelManager.current_state = LevelManager.LevelState.PLAYING


func _ensure_core_nodes() -> void:
	_ensure_player_exists()

	var existing_spawner := get_node_or_null("WaveSpawner")
	if existing_spawner:
		_wave_spawner = existing_spawner
	else:
		_wave_spawner = preload("res://src/levels/wave_spawner.gd").new()
		_wave_spawner.name = "WaveSpawner"
		if "auto_start" in _wave_spawner:
			_wave_spawner.auto_start = false
		add_child(_wave_spawner)

	var existing_objective := get_node_or_null("MissionObjective")
	if existing_objective:
		_mission_objective = existing_objective
	else:
		_mission_objective = preload("res://src/levels/mission_objective.gd").new()
		_mission_objective.name = "MissionObjective"
		add_child(_mission_objective)

	_hud = _resolve_or_spawn_hud()


func _ensure_player_exists() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var existing_player := players[0] as Node2D
		if LevelManager:
			LevelManager.player = existing_player
		if GameManager:
			GameManager.register_player(existing_player)
		return

	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		push_error("Arena01: player scene not found at %s" % PLAYER_SCENE_PATH)
		return

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("Arena01: failed to load player scene")
		return

	var player_instance := player_scene.instantiate() as Node2D
	if player_instance == null:
		push_error("Arena01: failed to instantiate player scene")
		return

	player_instance.name = "Player"
	add_child(player_instance)
	player_instance.global_position = _resolve_player_spawn_position()

	if LevelManager:
		LevelManager.player = player_instance
	if GameManager:
		GameManager.register_player(player_instance)


func _resolve_player_spawn_position() -> Vector2:
	var spawn_marker := get_node_or_null("SpawnPoints/PlayerSpawn") as Marker2D
	if spawn_marker:
		return spawn_marker.global_position

	if LevelManager and LevelManager.current_level_data:
		return LevelManager.current_level_data.player_spawn_position

	return Vector2.ZERO


func _resolve_or_spawn_hud() -> Node:
	if GameManager.hud and is_instance_valid(GameManager.hud):
		return GameManager.hud

	var current_scene := get_tree().current_scene
	if current_scene:
		var scene_hud := current_scene.get_node_or_null("UI/HUD")
		if scene_hud:
			return scene_hud

	if not ResourceLoader.exists(HUD_SCENE_PATH):
		return null

	var hud_scene := load(HUD_SCENE_PATH) as PackedScene
	if hud_scene == null:
		return null

	var hud_instance := hud_scene.instantiate()
	if hud_instance == null:
		return null

	add_child(hud_instance)
	return hud_instance


func _wire_signals() -> void:
	if _hud and _hud.has_method("set_arena_mode"):
		_hud.call("set_arena_mode", true)

	if _wave_spawner:
		var level_id := "arena_01"
		if LevelManager and LevelManager.current_level_data:
			level_id = LevelManager.current_level_data.level_id

		_wave_spawner.wave_config_path = "res://config/waves/%s_waves.json" % level_id
		if _wave_spawner.has_method("_load_wave_config"):
			_wave_spawner.call("_load_wave_config")

		if not _wave_spawner.wave_started.is_connected(_on_wave_started):
			_wave_spawner.wave_started.connect(_on_wave_started)
		if not _wave_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			_wave_spawner.enemy_spawned.connect(_on_enemy_spawned)
		if not _wave_spawner.all_waves_complete.is_connected(_on_all_waves_complete):
			_wave_spawner.all_waves_complete.connect(_on_all_waves_complete)

	if _mission_objective and _wave_spawner:
		if _wave_spawner.has_method("get_target_kills"):
			_mission_objective.target_kills = _wave_spawner.get_target_kills()
		elif _wave_spawner.has_method("get_total_enemy_count"):
			_mission_objective.target_kills = _wave_spawner.get_total_enemy_count()

	if _mission_objective:
		if not _mission_objective.score_changed.is_connected(_on_score_changed):
			_mission_objective.score_changed.connect(_on_score_changed)
		if not _mission_objective.objective_complete.is_connected(_on_objective_complete):
			_mission_objective.objective_complete.connect(_on_objective_complete)

		var complete_callable := Callable(LevelManager, "complete_level")
		if _mission_objective.objective_complete.is_connected(complete_callable):
			_mission_objective.objective_complete.disconnect(complete_callable)

	if _hud:
		if _hud.has_method("connect_wave_spawner"):
			_hud.call("connect_wave_spawner", _wave_spawner)
		if _hud.has_method("connect_mission_objective"):
			_hud.call("connect_mission_objective", _mission_objective)

	_register_existing_enemies()
	call_deferred("_refresh_hud_enemy_count")

	call_deferred("_deferred_start_wave_spawner")


func _sync_hud_initial_state() -> void:
	if _hud and _hud.has_method("update_wave"):
		_hud.call("update_wave", 1)

	if _hud and _hud.has_method("update_enemy_count"):
		_hud.call("update_enemy_count", get_tree().get_nodes_in_group("enemy").size())

	if _hud and _hud.has_method("update_arena_score"):
		_hud.call(
			"update_arena_score",
			_mission_objective.get_current_kills(),
			_mission_objective.target_kills
		)


func _on_wave_started(wave_number: int) -> void:
	if _hud and _hud.has_method("update_wave"):
		_hud.call("update_wave", wave_number)


func _on_enemy_spawned(enemy: Node) -> void:
	if _mission_objective and _mission_objective.has_method("register_enemy"):
		_mission_objective.register_enemy(enemy)

	if _hud and _hud.has_method("update_enemy_count"):
		_hud.call("update_enemy_count", get_tree().get_nodes_in_group("enemy").size())


func _register_existing_enemies() -> void:
	if _mission_objective == null or not _mission_objective.has_method("register_enemy"):
		return

	var existing_enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	for enemy in existing_enemies:
		if is_instance_valid(enemy):
			_mission_objective.register_enemy(enemy)


func _refresh_hud_enemy_count() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	if _hud and _hud.has_method("update_enemy_count"):
		_hud.call("update_enemy_count", tree.get_nodes_in_group("enemy").size())


func _on_score_changed(current_kills: int, target_kills: int) -> void:
	if _hud and _hud.has_method("update_arena_score"):
		_hud.call("update_arena_score", current_kills, target_kills)

	if _hud and _hud.has_method("update_enemy_count"):
		_hud.call("update_enemy_count", get_tree().get_nodes_in_group("enemy").size())


func _on_objective_complete() -> void:
	if _room_completion_handled:
		return

	_room_completion_handled = true

	if _hud and _hud.has_method("update_arena_score"):
		_hud.call(
			"update_arena_score", _mission_objective.target_kills, _mission_objective.target_kills
		)

	if _wave_spawner:
		if _wave_spawner.has_method("stop"):
			_wave_spawner.stop()
		if _wave_spawner.has_method("clear_all_enemies"):
			_wave_spawner.clear_all_enemies()

	if GameManager.roguelike_run_active:
		var level_id := ""
		if LevelManager.current_level_data:
			level_id = LevelManager.current_level_data.level_id
		GameManager.notify_roguelike_room_cleared(level_id)
	else:
		LevelManager.complete_level()


func _on_all_waves_complete() -> void:
	_refresh_hud_enemy_count()


func _deferred_start_wave_spawner() -> void:
	if _wave_spawner == null:
		return

	if not _wave_spawner.is_inside_tree():
		return

	if _wave_spawner.has_method("start"):
		_wave_spawner.call("start")
