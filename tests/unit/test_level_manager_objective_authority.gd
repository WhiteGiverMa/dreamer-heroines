extends GutTest


const LevelManagerScript = preload("res://src/levels/level_manager.gd")
const LevelDataScript = preload("res://src/levels/level_data.gd")


class TestLevelManager:
	extends LevelManagerScript

	var complete_level_calls: int = 0

	func complete_level() -> void:
		complete_level_calls += 1


class MissionObjectiveStub:
	extends Node

	signal objective_complete
	var target_kills: int = 25
	var current_kills: int = 0

	func get_current_kills() -> int:
		return current_kills


var _manager: TestLevelManager


func before_each() -> void:
	_manager = TestLevelManager.new()
	add_child_autofree(_manager)
	_manager.current_level_data = LevelDataScript.new()
	_manager.current_level_data.primary_objective = LevelDataScript.ObjectiveType.ELIMINATE_ALL


func test_eliminate_all_uses_scene_mission_objective_progress_without_auto_completing() -> void:
	watch_signals(_manager)

	var current_level := Node2D.new()
	current_level.name = "ArenaUnderTest"
	var mission_objective := MissionObjectiveStub.new()
	mission_objective.name = "MissionObjective"
	mission_objective.target_kills = 25
	mission_objective.current_kills = 10
	current_level.add_child(mission_objective)
	add_child_autofree(current_level)

	_manager.current_level = current_level
	_manager.total_enemies = 25
	_manager.enemies_killed = 0

	_manager._check_objectives()

	assert_eq(_manager.complete_level_calls, 0, "LevelManager should not auto-complete when a scene MissionObjective owns eliminate-all progress")
	assert_signal_emitted(_manager, "objective_updated", "LevelManager should still publish objective progress")
	assert_eq(
		get_signal_parameters(_manager, "objective_updated", 0),
		[LevelDataScript.ObjectiveType.ELIMINATE_ALL, 0.4],
		"Objective progress should come from MissionObjective current_kills/target_kills"
	)


func test_eliminate_all_falls_back_to_enemy_count_when_no_mission_objective_exists() -> void:
	var current_level := Node2D.new()
	current_level.name = "PlainLevel"
	add_child_autofree(current_level)

	_manager.current_level = current_level
	_manager.total_enemies = 5
	_manager.enemies_killed = 5

	_manager._check_objectives()

	assert_eq(_manager.complete_level_calls, 1, "LevelManager should still auto-complete eliminate-all levels that do not use MissionObjective")
