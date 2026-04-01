extends GutTest


const GameManagerClass = preload("res://src/autoload/game_manager.gd")


class EnhancedInputStub:
	extends Node

	var last_mode: int = -1

	func set_input_mode(mode: int) -> void:
		last_mode = mode


class ProjectileSpawnerStub:
	extends Node

	var clear_calls: int = 0

	func clear_pools() -> void:
		clear_calls += 1


class LevelManagerStub:
	extends Node

	var current_level: Node = null


class TreeSpy:
	extends RefCounted

	var reloaded: bool = false
	var changed_scene_path: String = ""

	func reload_current_scene() -> void:
		reloaded = true

	func change_scene_to_file(path: String) -> void:
		changed_scene_path = path


class PauseFlowGameManagerMock:
	extends GameManagerClass

	var tree_spy := TreeSpy.new()

	func reload_current_scene() -> void:
		tree_spy.reload_current_scene()

	func change_scene(scene_path: String) -> void:
		tree_spy.change_scene_to_file(scene_path)

	func _show_pause_menu() -> void:
		# 单元测试中不实例化真实 UI，避免额外场景副作用
		pass


var _manager: PauseFlowGameManagerMock
var _enhanced_input: EnhancedInputStub
var _projectile_spawner: ProjectileSpawnerStub
var _level_manager: LevelManagerStub


func before_each() -> void:
	_manager = PauseFlowGameManagerMock.new()
	add_child_autofree(_manager)

	_enhanced_input = EnhancedInputStub.new()
	_manager._enhanced_input_override = _enhanced_input

	_projectile_spawner = ProjectileSpawnerStub.new()
	_manager._projectile_spawner_override = _projectile_spawner

	_level_manager = LevelManagerStub.new()
	_level_manager.current_level = Node.new()
	_level_manager.add_child(_level_manager.current_level)
	_manager._level_manager_override = _level_manager


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()

	if _enhanced_input and is_instance_valid(_enhanced_input):
		_enhanced_input.free()

	if _projectile_spawner and is_instance_valid(_projectile_spawner):
		_projectile_spawner.free()

	if _level_manager and is_instance_valid(_level_manager):
		_level_manager.free()


func test_pause_freezes_runtime_and_sets_ui_input_mode() -> void:
	_manager.current_state = _manager.GameState.PLAYING
	_manager.set_paused(true)

	assert_true(_manager.is_game_paused, "Game should mark paused")
	assert_true(get_tree().paused, "SceneTree should be paused")
	assert_eq(_manager.current_state, _manager.GameState.PAUSED, "State should switch to PAUSED")
	assert_eq(_enhanced_input.last_mode, _manager.INPUT_MODE_UI_ONLY, "Pause should switch to UI-only input")
	assert_eq(
		_level_manager.current_level.process_mode,
		Node.PROCESS_MODE_PAUSABLE,
		"Current level should become pausable while game is paused"
	)


func test_resume_restores_playing_state_processing_and_input() -> void:
	_manager.current_state = _manager.GameState.PLAYING
	_manager.set_paused(true)

	_manager.set_paused(false)

	assert_false(_manager.is_game_paused, "Game should clear paused flag")
	assert_false(get_tree().paused, "SceneTree should resume")
	assert_eq(_manager.current_state, _manager.GameState.PLAYING, "State should return to PLAYING")
	assert_eq(_enhanced_input.last_mode, _manager.INPUT_MODE_GAME_ONLY, "Resume should restore gameplay input")
	assert_eq(
		_level_manager.current_level.process_mode,
		Node.PROCESS_MODE_INHERIT,
		"Current level process mode should be restored after resume"
	)


func test_restart_while_paused_unpauses_then_clears_combat_artifacts() -> void:
	_manager.current_state = _manager.GameState.PLAYING
	_manager.set_paused(true)

	watch_signals(_manager)
	_manager.restart_game()

	assert_false(_manager.is_game_paused, "Restart should force unpause")
	assert_false(get_tree().paused, "Restart should leave SceneTree unpaused before reload")
	assert_eq(_projectile_spawner.clear_calls, 1, "Restart should clear projectile pools exactly once")
	assert_true(_manager.tree_spy.reloaded, "Restart should request scene reload")
	assert_signal_emitted(_manager, "game_restarted", "Restart should emit game_restarted signal")


func test_quit_to_menu_while_paused_unpauses_and_clears_combat_residue() -> void:
	_manager.current_state = _manager.GameState.PLAYING
	_manager.set_paused(true)

	_manager.quit_to_menu()

	assert_false(_manager.is_game_paused, "Quit to menu should force unpause")
	assert_false(get_tree().paused, "Quit to menu should leave SceneTree unpaused")
	assert_eq(_projectile_spawner.clear_calls, 1, "Quit to menu should clear projectile pools")
	assert_eq(_manager.current_state, _manager.GameState.MENU, "Quit to menu should set MENU state")
	assert_eq(
		_manager.tree_spy.changed_scene_path,
		"res://scenes/ui/main_menu.tscn",
		"Quit to menu should request main menu scene"
	)
