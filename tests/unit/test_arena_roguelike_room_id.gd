extends GutTest


const ArenaSceneScript = preload("res://src/levels/arena_01.gd")


class LevelManagerStub:
	extends Node
	class LevelStateStub:
		const PLAYING := 2

	var current_level = null
	var current_state: int = 0
	var current_level_data: MockLevelData = null
	var complete_level_called: bool = false

	func complete_level() -> void:
		complete_level_called = true


class MockLevelData:
	var level_id: String = "arena_01"


class GameManagerStub:
	extends Node
	var roguelike_run_active: bool = true
	var notified_level_ids: Array[String] = []

	func notify_roguelike_room_cleared(level_id: String) -> void:
		notified_level_ids.append(level_id)


class MissionObjectiveStub:
	extends Node
	signal score_changed(current: int, target: int)
	signal objective_complete
	var target_kills: int = 16

	func get_current_kills() -> int:
		return target_kills


class WaveSpawnerStub:
	extends Node
	signal wave_started(wave_number: int)
	signal enemy_spawned(enemy: Node)
	signal all_waves_complete
	var wave_config_path: String = ""
	var stopped: bool = false

	func _load_wave_config() -> void:
		pass

	func get_target_kills() -> int:
		return 16

	func stop() -> void:
		stopped = true

	func clear_all_enemies() -> void:
		pass

	func start() -> void:
		pass


class HudStub:
	extends Node

	func set_arena_mode(_enabled: bool) -> void:
		pass

	func update_arena_score(_current: int, _target: int) -> void:
		pass

	func connect_wave_spawner(_wave_spawner: Node) -> void:
		pass

	func connect_mission_objective(_mission_objective: Node) -> void:
		pass


class TestArenaScene:
	extends ArenaSceneScript
	var notified_level_ids: Array[String] = []

	func _ensure_player_exists() -> void:
		pass

	func _resolve_or_spawn_hud() -> Node:
		return _hud

	func _register_existing_enemies() -> void:
		pass

	func _refresh_hud_enemy_count() -> void:
		pass

	func _sync_hud_initial_state() -> void:
		pass

	func _notify_roguelike_room_cleared() -> void:
		notified_level_ids.append(_level_id)

	func _is_roguelike_run_active() -> bool:
		return true


var _arena: TestArenaScene
var _level_manager_stub: LevelManagerStub
var _game_manager_stub: GameManagerStub


func before_each() -> void:
	_level_manager_stub = LevelManagerStub.new()
	_level_manager_stub.name = "LevelManager"
	_level_manager_stub.current_level_data = MockLevelData.new()
	_level_manager_stub.current_level_data.level_id = "arena_01"
	get_tree().root.add_child(_level_manager_stub)

	_game_manager_stub = GameManagerStub.new()
	_game_manager_stub.name = "GameManager"
	get_tree().root.add_child(_game_manager_stub)

	_arena = TestArenaScene.new()
	_arena.name = "Arena02"
	_arena._wave_spawner = WaveSpawnerStub.new()
	_arena._wave_spawner.name = "WaveSpawner"
	_arena.add_child(_arena._wave_spawner)
	_arena._mission_objective = MissionObjectiveStub.new()
	_arena._mission_objective.name = "MissionObjective"
	_arena.add_child(_arena._mission_objective)
	_arena._hud = HudStub.new()
	_arena.add_child(_arena._hud)
	add_child_autofree(_arena)


func after_each() -> void:
	if is_instance_valid(_level_manager_stub):
		_level_manager_stub.queue_free()
	if is_instance_valid(_game_manager_stub):
		_game_manager_stub.queue_free()


func test_objective_complete_uses_scene_level_id_in_roguelike_mode() -> void:
	_arena._prepare_runtime_state()
	_arena._wire_signals()

	# Simulate mutable global state drift after arena_02 has already initialized.
	_level_manager_stub.current_level_data.level_id = "arena_01"

	_arena._on_objective_complete()

	assert_eq(_arena.notified_level_ids, ["arena_02"], "Arena scene should report its own scene-derived level id")


func test_wire_signals_uses_scene_level_id_for_wave_config() -> void:
	_arena._prepare_runtime_state()
	_arena._wire_signals()

	assert_eq(_arena._wave_spawner.wave_config_path, "res://config/waves/arena_02_waves.json", "Arena scene should load wave config based on scene level id")


func test_resolve_target_kills_prefers_wave_config_quota() -> void:
	_arena._prepare_runtime_state()

	assert_eq(_arena._resolve_target_kills(), 25, "Arena scene should read target_kills from the wave config even if WaveSpawner runtime API drifts")
