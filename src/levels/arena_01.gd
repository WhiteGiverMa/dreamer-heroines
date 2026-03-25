extends Node2D

const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

var _wave_spawner: Node
var _mission_objective: Node
var _hud: Node


func _ready() -> void:
	_prepare_runtime_state()
	_ensure_core_nodes()
	_wire_signals()
	_sync_hud_initial_state()


func _prepare_runtime_state() -> void:
	LevelManager.current_level = self
	LevelManager.current_state = LevelManager.LevelState.PLAYING


func _ensure_core_nodes() -> void:
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
		if not _wave_spawner.wave_started.is_connected(_on_wave_started):
			_wave_spawner.wave_started.connect(_on_wave_started)
		if not _wave_spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			_wave_spawner.enemy_spawned.connect(_on_enemy_spawned)

	if _mission_objective:
		if not _mission_objective.score_changed.is_connected(_on_score_changed):
			_mission_objective.score_changed.connect(_on_score_changed)
		if not _mission_objective.objective_complete.is_connected(_on_objective_complete):
			_mission_objective.objective_complete.connect(_on_objective_complete)

		var complete_callable := Callable(LevelManager, "complete_level")
		if not _mission_objective.objective_complete.is_connected(complete_callable):
			_mission_objective.objective_complete.connect(complete_callable)

	if _hud:
		if _hud.has_method("connect_wave_spawner"):
			_hud.call("connect_wave_spawner", _wave_spawner)
		if _hud.has_method("connect_mission_objective"):
			_hud.call("connect_mission_objective", _mission_objective)

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


func _on_score_changed(current_kills: int, target_kills: int) -> void:
	if _hud and _hud.has_method("update_arena_score"):
		_hud.call("update_arena_score", current_kills, target_kills)

	if _hud and _hud.has_method("update_enemy_count"):
		_hud.call("update_enemy_count", get_tree().get_nodes_in_group("enemy").size())


func _on_objective_complete() -> void:
	if _hud and _hud.has_method("update_arena_score"):
		_hud.call(
			"update_arena_score", _mission_objective.target_kills, _mission_objective.target_kills
		)


func _deferred_start_wave_spawner() -> void:
	if _wave_spawner == null:
		return

	if not _wave_spawner.is_inside_tree():
		return

	if _wave_spawner.has_method("start"):
		_wave_spawner.call("start")
