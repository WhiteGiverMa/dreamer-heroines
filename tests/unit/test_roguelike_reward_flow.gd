extends GutTest


const GameManagerClass = preload("res://src/autoload/game_manager.gd")
const LevelDataClass = preload("res://src/levels/level_data.gd")


# Test doubles/stubs
class LevelManagerStub:
	extends Node
	signal level_loaded(level_data)
	var load_level_calls: Array[String] = []
	var current_level_data: MockLevelData = null

	func load_level(level_id: String) -> bool:
		load_level_calls.append(level_id)
		if current_level_data == null:
			current_level_data = MockLevelData.new()
		current_level_data.level_id = level_id
		return true


class MockLevelData:
	var level_id: String = "arena_01"


class MockPlayer:
	extends Node2D
	var max_health: int = 100
	var max_speed: float = 300.0
	var dash_cooldown: float = 1.5
	var current_health: int = 100


class RoguelikeRewardModalStub:
	extends Control
	signal option_selected(blessing_id: String)

	func show_rewards(options: Array) -> void:
		# Accept untyped Array to satisfy the call from notify_roguelike_room_cleared
		pass


class TestableGameManager:
	extends GameManagerClass

	func _get_level_manager_node() -> Node:
		return _level_manager_override

	func expose_reset_stale_roguelike_ui_refs(current_scene: Node = null) -> void:
		_reset_stale_roguelike_ui_refs(current_scene)

	func _ensure_roguelike_reward_modal() -> void:
		# Override to use stub instead of instantiating real scene
		if roguelike_reward_modal and is_instance_valid(roguelike_reward_modal):
			return

		roguelike_reward_modal = RoguelikeRewardModalStub.new()
		roguelike_reward_modal.name = "RoguelikeRewardSelection"
		add_child(roguelike_reward_modal)

	func _on_reward_option_selected(blessing_id: String) -> void:
		# Override to use stub's load_level instead of global LevelManager
		if roguelike_transition_in_flight:
			return

		roguelike_transition_in_flight = true
		roguelike_reward_active = false

		if not roguelike_selected_blessings.has(blessing_id):
			roguelike_selected_blessings.append(blessing_id)

		if player_instance and is_instance_valid(player_instance):
			_reapply_roguelike_blessings_to_player(player_instance)

		if roguelike_reward_modal:
			roguelike_reward_modal.visible = false

		var next_level_id := _get_next_roguelike_level_id()
		_level_manager_override.load_level(next_level_id)


var _manager: TestableGameManager
var _level_manager_stub: LevelManagerStub


func before_each() -> void:
	_manager = TestableGameManager.new()
	add_child_autofree(_manager)

	_level_manager_stub = LevelManagerStub.new()
	_level_manager_stub.current_level_data = MockLevelData.new()
	_manager._level_manager_override = _level_manager_stub
	add_child_autofree(_level_manager_stub)


func after_each() -> void:
	if _manager:
		_manager.queue_free()


func test_notify_roguelike_room_cleared_opens_reward_without_victory() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")

	assert_true(_manager.roguelike_reward_active, "Reward should be active after room cleared")
	assert_ne(_manager.current_state, _manager.GameState.VICTORY, "State should NOT be VICTORY after room cleared")
	assert_true(_manager.roguelike_run_active, "Roguelike run should still be active")


func test_choosing_option_calls_load_level_exactly_once() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")

	_manager._on_reward_option_selected("vitality_boost")

	assert_eq(_level_manager_stub.load_level_calls.size(), 1, "load_level should be called exactly once")
	assert_true(_manager.roguelike_transition_in_flight, "Transition should be in flight")


func test_duplicate_option_presses_do_not_duplicate_transition() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")

	_manager._on_reward_option_selected("vitality_boost")
	_manager._on_reward_option_selected("vitality_boost")

	assert_eq(_level_manager_stub.load_level_calls.size(), 1, "load_level should be called only once despite duplicate presses")


func test_register_player_reapply_is_idempotent() -> void:
	# Setup roguelike run with one blessing selected
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")
	_manager._on_reward_option_selected("vitality_boost")  # max_health +20

	# Create mock player with base stats
	var mock_player := MockPlayer.new()
	add_child_autofree(mock_player)

	# Register player first time
	_manager.register_player(mock_player)

	# Capture stats after first registration
	var health_after_first := mock_player.max_health
	assert_eq(health_after_first, 120, "First registration should apply +20 max_health blessing (100 + 20)")

	# Register player second time (idempotency check)
	_manager.register_player(mock_player)

	# Stats should be unchanged after second registration
	assert_eq(mock_player.max_health, health_after_first, "Second registration should NOT change stats (idempotent)")


func test_register_player_reapply_on_new_player_instance() -> void:
	# Setup roguelike run with blessings selected
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")
	_manager._on_reward_option_selected("vitality_boost")  # +20 max_health
	_manager._on_reward_option_selected("swift_step")  # +30 max_speed

	# Create first player and register
	var player1 := MockPlayer.new()
	add_child_autofree(player1)
	_manager.register_player(player1)

	var health_p1 := player1.max_health
	var speed_p1 := player1.max_speed

	# Create second player and register
	var player2 := MockPlayer.new()
	add_child_autofree(player2)
	_manager.register_player(player2)

	# Second player should have same accumulated blessings applied
	assert_eq(player2.max_health, health_p1, "Second player should have same health blessing applied")
	assert_eq(player2.max_speed, speed_p1, "Second player should have same speed blessing applied")


func test_reset_minimal_roguelike_run_clears_state() -> void:
	# Setup roguelike run with blessings
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")
	_manager._on_reward_option_selected("vitality_boost")

	# Verify state before reset
	assert_true(_manager.roguelike_run_active, "Run should be active before reset")
	assert_false(_manager.roguelike_selected_blessings.is_empty(), "Blessings should exist before reset")
	assert_gt(_manager.roguelike_level_index, 0, "Level index should be > 0 before reset")

	# Reset
	_manager.reset_minimal_roguelike_run()

	# Verify clean state after reset
	assert_false(_manager.roguelike_run_active, "Run should be inactive after reset")
	assert_true(_manager.roguelike_selected_blessings.is_empty(), "Blessings should be cleared after reset")
	assert_eq(_manager.roguelike_level_index, 0, "Level index should be 0 after reset")
	assert_false(_manager.roguelike_reward_active, "Reward should be inactive after reset")
	assert_false(_manager.roguelike_transition_in_flight, "Transition should be cleared after reset")


func test_notify_roguelike_room_cleared_ignores_stale_level_id() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_level_manager_stub.current_level_data.level_id = "arena_02"

	_manager.notify_roguelike_room_cleared("arena_01")

	assert_false(_manager.roguelike_reward_active, "Stale room-clear event should not reopen reward")
	assert_null(_manager.roguelike_reward_modal, "Reward modal should not be created for stale room-clear events")


func test_notify_roguelike_room_cleared_ignores_reentry_during_transition() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_level_manager_stub.current_level_data.level_id = "arena_01"
	_manager.roguelike_transition_in_flight = true

	_manager.notify_roguelike_room_cleared("arena_01")

	assert_false(_manager.roguelike_reward_active, "Room-clear event should be ignored while transition is in flight")
	assert_null(_manager.roguelike_reward_modal, "Reward modal should not be created during transition")


func test_level_loaded_clears_dirty_reward_gate_state() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.notify_roguelike_room_cleared("arena_01")
	assert_not_null(_manager.roguelike_reward_modal, "Reward modal should exist after room clear")
	_manager.roguelike_transition_in_flight = true
	_manager.roguelike_reward_active = true
	_manager.roguelike_reward_modal.visible = true

	var level_data := LevelDataClass.new()
	level_data.level_id = "arena_02"
	_manager._on_roguelike_level_loaded(level_data)

	assert_false(_manager.roguelike_transition_in_flight, "Level load should clear in-flight transition state")
	assert_false(_manager.roguelike_reward_active, "Level load should clear stale reward-active state")
	if _manager.roguelike_reward_modal:
		assert_false(_manager.roguelike_reward_modal.visible, "Level load should hide any stale reward modal")
	else:
		pass_test("Level load may fully discard stale reward modal references after scene transition")


func test_reset_stale_ui_refs_drops_reward_modal_from_previous_scene() -> void:
	var old_scene := Node2D.new()
	old_scene.name = "OldArena"
	add_child_autofree(old_scene)

	var stale_runtime_ui := CanvasLayer.new()
	stale_runtime_ui.name = "RuntimeUI"
	old_scene.add_child(stale_runtime_ui)

	var stale_modal := RoguelikeRewardModalStub.new()
	stale_modal.name = "RoguelikeRewardSelection"
	stale_runtime_ui.add_child(stale_modal)

	_manager.runtime_ui_layer = stale_runtime_ui
	_manager.roguelike_reward_modal = stale_modal

	var new_scene := Node2D.new()
	new_scene.name = "NewArena"
	add_child_autofree(new_scene)

	_manager.expose_reset_stale_roguelike_ui_refs(new_scene)

	assert_null(_manager.runtime_ui_layer, "Runtime UI reference should be cleared when it belongs to an old scene")
	assert_null(_manager.roguelike_reward_modal, "Reward modal reference should be cleared when it belongs to an old scene")


func test_register_player_clears_stuck_transition_gate_for_arrived_scene() -> void:
	_manager.start_minimal_roguelike_run("arena_01")
	_manager.roguelike_transition_in_flight = true
	_manager.roguelike_reward_active = true

	var stale_modal := RoguelikeRewardModalStub.new()
	stale_modal.visible = true
	add_child_autofree(stale_modal)
	_manager.roguelike_reward_modal = stale_modal

	var mock_player := MockPlayer.new()
	add_child_autofree(mock_player)

	_manager.register_player(mock_player)

	assert_false(_manager.roguelike_transition_in_flight, "Registering the new player should clear a stale transition gate once the new scene has arrived")
	assert_false(_manager.roguelike_reward_active, "Registering the new player should clear stale reward-active state")
	assert_false(stale_modal.visible, "Registering the new player should hide any stale reward modal")
