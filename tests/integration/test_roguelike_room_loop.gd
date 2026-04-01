extends GutTest

## Roguelike Room Loop Integration Test
## Tests the complete roguelike room transition cycle:
## arena_01 -> reward -> arena_02 -> reward -> arena_01

var _initial_max_health: int = 100


func before_all() -> void:
	# Ensure autoloads are ready
	await _wait_for_autoloads()


func before_each() -> void:
	# Reset roguelike state
	if GameManager:
		GameManager.reset_minimal_roguelike_run()
		GameManager.roguelike_selected_blessings.clear()


func after_all() -> void:
	# Cleanup
	if GameManager:
		GameManager.reset_minimal_roguelike_run()


func _wait_for_autoloads() -> void:
	# Wait for GameManager and LevelManager to be ready
	var max_wait := 30
	var waited := 0

	while waited < max_wait:
		var gm_ready := GameManager != null and GameManager.is_initialized
		var lm_ready := LevelManager != null and LevelManager.is_initialized

		if gm_ready and lm_ready:
			break

		await get_tree().create_timer(0.1).timeout
		waited += 1

	assert_true(GameManager != null, "GameManager should be available")
	assert_true(LevelManager != null, "LevelManager should be available")


func test_roguelike_room_loop() -> void:
	# Step 1: Start roguelike run
	GameManager.start_minimal_roguelike_run("arena_01")
	assert_true(GameManager.roguelike_run_active, "Roguelike run should be active")
	assert_eq(GameManager.roguelike_level_index, 0, "Should start at level index 0")

	# Step 2: Load arena_01
	var load_success := LevelManager.load_level("arena_01")
	assert_true(load_success, "Level arena_01 should load successfully")

	# Wait for level to fully load
	await wait_seconds(1.0)
	await _wait_for_level_ready()
	await _wait_for_transition_complete()

	# Verify player exists and capture initial health
	var player := _get_player()
	assert_not_null(player, "Player should exist in arena_01")

	if player:
		_initial_max_health = int(player.get("max_health"))
		assert_eq(_initial_max_health, 100, "Initial max_health should be 100")

	# Step 3: Trigger reward for clearing arena_01
	GameManager.notify_roguelike_room_cleared("arena_01")
	await wait_seconds(0.5)

	# Step 4: Verify reward modal is visible
	var reward_modal := _get_reward_modal()
	assert_not_null(reward_modal, "Reward modal should exist")
	if reward_modal:
		assert_true(reward_modal.visible, "Reward modal should be visible after room cleared")

	# Step 5: Select Option1Button (vitality_boost)
	# Emit signal directly to bypass tween timing issues
	if reward_modal:
		reward_modal.option_selected.emit("vitality_boost")
		await wait_seconds(0.5)

	# Manually emit level_loaded signal to trigger _on_roguelike_level_loaded
	# (In headless test mode, LevelManager.load_level() may not trigger the signal properly)
	if LevelManager and LevelManager.current_level_data:
		LevelManager.level_loaded.emit(LevelManager.current_level_data)
		await wait_seconds(0.3)

	# Step 6: Verify transition to arena_02
	await _wait_for_level_ready()
	await _wait_for_transition_complete()
	await wait_seconds(0.3)

	# CRITICAL: Verify transition flag is reset before continuing
	assert_false(GameManager.roguelike_transition_in_flight,
		"Transition should be complete before second reward")

	# Verify arena_02 loaded
	assert_eq(GameManager.roguelike_level_index, 1, "Should now be at level index 1 (arena_02)")

	# Step 7: Verify blessing was applied (max_health should be 120)
	player = _get_player()
	assert_not_null(player, "Player should exist in arena_02")

	if player:
		var new_max_health := int(player.get("max_health"))
		assert_eq(new_max_health, 120, "Player max_health should be 120 after vitality_boost")

		# Verify blessing is tracked
		assert_true(GameManager.roguelike_selected_blessings.has("vitality_boost"),
			"vitality_boost should be in selected blessings")

	# Step 8: Trigger second reward for clearing arena_02
	GameManager.notify_roguelike_room_cleared("arena_02")
	await wait_seconds(0.5)

	# Verify reward modal again
	reward_modal = _get_reward_modal()
	assert_not_null(reward_modal, "Reward modal should exist for second reward")
	if reward_modal:
		assert_true(reward_modal.visible, "Reward modal should be visible for second room")

	# Step 9: Select Option2Button (swift_step)
	# Emit signal directly to bypass tween timing issues
	if reward_modal:
		reward_modal.option_selected.emit("swift_step")
		await wait_seconds(0.5)

	# Manually emit level_loaded signal to trigger _on_roguelike_level_loaded
	# (In headless test mode, LevelManager.load_level() may not trigger the signal properly)
	if LevelManager and LevelManager.current_level_data:
		LevelManager.level_loaded.emit(LevelManager.current_level_data)
		await wait_seconds(0.3)

	# Step 10: Verify back to arena_01 (loop)
	await _wait_for_level_ready()
	await _wait_for_transition_complete()
	await wait_seconds(0.3)

	# Should loop back to arena_01 (index wraps to 0)
	assert_eq(GameManager.roguelike_level_index, 0, "Should loop back to level index 0 (arena_01)")

	# Verify both blessings are tracked
	assert_true(GameManager.roguelike_selected_blessings.has("vitality_boost"),
		"vitality_boost should still be tracked")
	assert_true(GameManager.roguelike_selected_blessings.has("swift_step"),
		"swift_step should be tracked")

	# Final player check
	player = _get_player()
	assert_not_null(player, "Player should exist back in arena_01")

	if player:
		var final_max_health := int(player.get("max_health"))
		assert_eq(final_max_health, 120, "Player should retain blessing (max_health 120)")


func _get_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _get_reward_modal() -> Control:
	# Reward modal is created under RuntimeUI in current scene
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return null

	var runtime_ui := current_scene.get_node_or_null("RuntimeUI")
	if runtime_ui == null:
		return null

	return runtime_ui.get_node_or_null("RoguelikeRewardSelection") as Control


func _get_option_button(option_num: int) -> Button:
	var modal := _get_reward_modal()
	if modal == null:
		return null

	var button_path := "CenterContainer/VBoxContainer/Options/Option%dButton" % option_num
	return modal.get_node_or_null(button_path) as Button


func _wait_for_level_ready() -> void:
	# Wait for LevelManager to report READY state
	var max_wait := 50
	var waited := 0

	while waited < max_wait:
		if LevelManager and LevelManager.current_state == LevelManager.LevelState.READY:
			break

		await get_tree().create_timer(0.1).timeout
		waited += 1


func _wait_for_transition_complete() -> void:
	# Wait for roguelike transition to complete
	var max_wait := 30
	var waited := 0

	while waited < max_wait:
		if GameManager and not GameManager.roguelike_transition_in_flight:
			break

		await get_tree().create_timer(0.1).timeout
		waited += 1
