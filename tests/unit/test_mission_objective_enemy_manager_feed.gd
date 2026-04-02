extends GutTest


const MissionObjectiveClass = preload("res://src/levels/mission_objective.gd")


class EnemyManagerStub:
	extends Node
	signal enemy_died(enemy: Node, enemy_type: String)


class EnemyStub:
	extends Node
	signal died

	func _ready() -> void:
		add_to_group("enemy")


class TestMissionObjective:
	extends MissionObjectiveClass
	var enemy_manager_override: Node = null

	func _get_enemy_manager() -> Node:
		return enemy_manager_override


var _enemy_manager: EnemyManagerStub


func before_each() -> void:
	_enemy_manager = EnemyManagerStub.new()
	_enemy_manager.name = "EnemyManager"
	get_tree().root.add_child(_enemy_manager)


func after_each() -> void:
	if is_instance_valid(_enemy_manager):
		_enemy_manager.queue_free()


func test_enemy_manager_kill_feed_completes_objective() -> void:
	var objective := TestMissionObjective.new()
	objective.auto_start_on_ready = false
	objective.target_kills = 2
	objective.enemy_manager_override = _enemy_manager
	add_child_autofree(objective)

	var enemy_a := EnemyStub.new()
	add_child_autofree(enemy_a)
	var enemy_b := EnemyStub.new()
	add_child_autofree(enemy_b)

	objective.start(true)
	objective.register_enemy(enemy_a)
	objective.register_enemy(enemy_b)

	watch_signals(objective)
	_enemy_manager.enemy_died.emit(enemy_a, "melee_enemy")
	_enemy_manager.enemy_died.emit(enemy_b, "ranged_enemy")

	assert_eq(objective.get_current_kills(), 2, "EnemyManager kill feed should advance mission kills")
	assert_true(objective.is_completed(), "Objective should complete after enough EnemyManager kill events")
	assert_signal_emitted(objective, "objective_complete", "Objective should emit completion when EnemyManager kill feed reaches target")
