extends GutTest


func should_skip_script():
	if DisplayServer.get_name() == "headless":
		return "Skip integration tests in headless mode; this suite depends on runtime arena flow and scene transitions"
	return false


const ArenaScript = preload("res://src/levels/arena_01.gd")


class FakeWaveSpawner:
	extends Node

	signal wave_started(wave_number: int)
	signal enemy_spawned(enemy: Node)
	signal all_waves_complete

	var wave_config_path: String = ""
	var target_kills: int = 25
	var load_wave_config_calls: int = 0
	var start_calls: int = 0
	var stop_calls: int = 0
	var clear_all_enemies_calls: int = 0

	func _load_wave_config() -> void:
		load_wave_config_calls += 1

	func get_target_kills() -> int:
		return target_kills

	func start() -> void:
		start_calls += 1

	func stop() -> void:
		stop_calls += 1

	func clear_all_enemies() -> void:
		clear_all_enemies_calls += 1


class FakeMissionObjective:
	extends Node

	signal score_changed(current: int, target: int)
	signal objective_complete

	var target_kills: int = 0
	var current_kills: int = 0
	var register_enemy_calls: int = 0

	func get_current_kills() -> int:
		return current_kills

	func register_enemy(_enemy: Node) -> void:
		register_enemy_calls += 1


class FakeHud:
	extends Node

	var arena_mode_enabled: bool = false
	var connected_wave_spawner: Node = null
	var connected_mission_objective: Node = null
	var wave_updates: Array[int] = []
	var enemy_count_updates: Array[int] = []
	var arena_score_updates: Array[Array] = []

	func set_arena_mode(enabled: bool) -> void:
		arena_mode_enabled = enabled

	func connect_wave_spawner(spawner: Node) -> void:
		connected_wave_spawner = spawner

	func connect_mission_objective(objective: Node) -> void:
		connected_mission_objective = objective

	func update_wave(wave_number: int) -> void:
		wave_updates.append(wave_number)

	func update_enemy_count(count: int) -> void:
		enemy_count_updates.append(count)

	func update_arena_score(current_kills: int, target_kills: int) -> void:
		arena_score_updates.append([current_kills, target_kills])


class FakeGameOverScreen:
	extends Control

	signal restart_requested
	signal quit_to_menu_requested
	signal continue_requested

	var victory_calls: int = 0
	var defeat_calls: int = 0

	func show_victory() -> void:
		victory_calls += 1
		show()

	func show_defeat() -> void:
		defeat_calls += 1
		show()


class TestableArena:
	extends ArenaScript

	var injected_hud: Node = null

	func _ensure_player_exists() -> void:
		pass

	func _resolve_or_spawn_hud() -> Node:
		return injected_hud


var _arena: TestableArena
var _wave_spawner: FakeWaveSpawner
var _objective: FakeMissionObjective
var _hud: FakeHud
var _game_over_screen: FakeGameOverScreen
var _previous_hud: Node = null
var _previous_game_over_screen: Control = null
var _previous_level: Node = null
var _previous_level_data = null
var _previous_level_state: int = -1
var _previous_game_state: int = -1
var _previous_roguelike_active: bool = false
var _previous_reward_active: bool = false
var _previous_transition_in_flight: bool = false


func before_all() -> void:
	await _wait_for_autoloads()


func before_each() -> void:
	_previous_hud = GameManager.hud
	_previous_game_over_screen = GameManager.game_over_screen
	_previous_level = LevelManager.current_level
	_previous_level_data = LevelManager.current_level_data
	_previous_level_state = LevelManager.current_state
	_previous_game_state = GameManager.current_state
	_previous_roguelike_active = GameManager.roguelike_run_active
	_previous_reward_active = GameManager.roguelike_reward_active
	_previous_transition_in_flight = GameManager.roguelike_transition_in_flight

	GameManager.reset_minimal_roguelike_run()
	GameManager.hud = null
	GameManager.current_state = GameManager.GameState.PLAYING

	var level_data := LevelData.new()
	level_data.level_id = "arena_02"
	LevelManager.current_level_data = level_data
	LevelManager.current_state = LevelManager.LevelState.READY

	_wave_spawner = FakeWaveSpawner.new()
	_wave_spawner.name = "WaveSpawner"

	_objective = FakeMissionObjective.new()
	_objective.name = "MissionObjective"

	_hud = FakeHud.new()
	_game_over_screen = FakeGameOverScreen.new()
	add_child_autofree(_game_over_screen)
	GameManager.register_game_over_screen(_game_over_screen)

	_arena = TestableArena.new()
	_arena.name = "ArenaUnderTest"
	_arena.injected_hud = _hud
	_arena.add_child(_hud)
	_arena.add_child(_wave_spawner)
	_arena.add_child(_objective)
	add_child_autofree(_arena)

	await wait_physics_frames(2)


func after_each() -> void:
	GameManager.reset_minimal_roguelike_run()
	GameManager.hud = _previous_hud
	GameManager.game_over_screen = _previous_game_over_screen
	GameManager.current_state = _previous_game_state
	GameManager.roguelike_run_active = _previous_roguelike_active
	GameManager.roguelike_reward_active = _previous_reward_active
	GameManager.roguelike_transition_in_flight = _previous_transition_in_flight

	LevelManager.current_level = _previous_level
	LevelManager.current_level_data = _previous_level_data
	LevelManager.current_state = _previous_level_state


func test_all_waves_complete_only_refreshes_arena_state() -> void:
	watch_signals(LevelManager)
	watch_signals(GameManager)

	_wave_spawner.all_waves_complete.emit()
	await wait_physics_frames(1)

	assert_false(
		is_instance_valid(LevelManager) and get_signal_emit_count(LevelManager, "level_completed") > 0,
		"all_waves_complete should not complete the level"
	)
	assert_false(
		is_instance_valid(GameManager) and get_signal_emit_count(GameManager, "level_completed") > 0,
		"all_waves_complete should not drive GameManager victory"
	)
	assert_eq(_wave_spawner.stop_calls, 0, "Spawner should keep running after authored waves are exhausted")
	assert_eq(_wave_spawner.clear_all_enemies_calls, 0, "Arena should not clear enemies when authored waves run out")
	assert_gt(_hud.enemy_count_updates.size(), 0, "Arena should still refresh HUD enemy count on all_waves_complete")


func test_objective_complete_clears_room_and_completes_non_roguelike_level() -> void:
	watch_signals(LevelManager)
	var previous_game_state := GameManager.current_state

	_objective.objective_complete.emit()
	await wait_physics_frames(1)

	assert_eq(_wave_spawner.stop_calls, 1, "Objective completion should stop the spawner exactly once")
	assert_eq(_wave_spawner.clear_all_enemies_calls, 1, "Objective completion should clear remaining enemies")
	assert_signal_emitted(LevelManager, "level_completed", "Objective completion should complete the level")
	assert_eq(LevelManager.current_state, LevelManager.LevelState.COMPLETED, "LevelManager should enter COMPLETED state")
	assert_ne(GameManager.current_state, previous_game_state, "Objective completion should advance GameManager state away from the pre-clear state")
	assert_eq(_game_over_screen.victory_calls, 1, "Objective completion should route through the victory presentation once")


func test_objective_complete_routes_roguelike_rooms_to_reward_flow() -> void:
	watch_signals(LevelManager)
	watch_signals(GameManager)
	GameManager.start_minimal_roguelike_run("arena_02")
	LevelManager.current_level_data.level_id = "arena_02"

	_objective.objective_complete.emit()
	await wait_physics_frames(1)

	assert_eq(_wave_spawner.stop_calls, 1, "Roguelike objective completion should still stop the spawner")
	assert_eq(_wave_spawner.clear_all_enemies_calls, 1, "Roguelike objective completion should still clear enemies")
	assert_false(
		is_instance_valid(LevelManager) and get_signal_emit_count(LevelManager, "level_completed") > 0,
		"Roguelike room clear should not use LevelManager.complete_level"
	)
	assert_false(
		is_instance_valid(GameManager) and get_signal_emit_count(GameManager, "level_completed") > 0,
		"Roguelike room clear should not enter GameManager victory flow"
	)
	assert_true(GameManager.roguelike_reward_active, "Roguelike room clear should open reward flow")
	assert_ne(GameManager.current_state, GameManager.GameState.VICTORY, "Roguelike room clear should not switch to VICTORY")


func _wait_for_autoloads() -> void:
	var max_wait := 30
	var waited := 0

	while waited < max_wait:
		var gm_ready := GameManager != null and GameManager.is_initialized
		var lm_ready := LevelManager != null and LevelManager.is_initialized
		if gm_ready and lm_ready:
			return

		await get_tree().create_timer(0.1).timeout
		waited += 1

	assert_true(GameManager != null, "GameManager should be available")
	assert_true(LevelManager != null, "LevelManager should be available")
