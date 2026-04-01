extends GutTest

var LevelDataScript = preload("res://src/levels/level_data.gd")
var LevelManagerClass = preload("res://src/levels/level_manager.gd")


func test_level_data_resource_loads_with_registered_script_class() -> void:
	var level_data := load("res://config/levels/arena_01.tres")

	assert_not_null(level_data, "arena_01.tres should load")
	assert_true(level_data is LevelData, "arena_01.tres should resolve to LevelData")
	assert_eq(level_data.get_script(), LevelDataScript, "Loaded resource should keep the LevelData script attached")


func test_level_manager_load_path_returns_level_data_resource() -> void:
	var level_manager := LevelManagerClass.new()
	add_child_autofree(level_manager)

	var level_data := level_manager._load_level_data("arena_01")

	assert_not_null(level_data, "LevelManager should load existing level config")
	assert_true(level_data is LevelData, "LevelManager load path should return LevelData")
	assert_eq(level_data.level_id, "arena_01", "Loaded LevelData should preserve the configured level id")


func test_level_manager_create_path_builds_default_level_data() -> void:
	var level_manager := LevelManagerClass.new()
	add_child_autofree(level_manager)

	var level_data := level_manager._load_level_data("missing_level")

	assert_not_null(level_data, "LevelManager should create fallback LevelData when config is missing")
	assert_true(level_data is LevelData, "Fallback load path should still create LevelData")
	assert_eq(level_data.level_id, "missing_level", "Fallback LevelData should copy the requested id")
	assert_eq(level_data.level_name, "Missing Level", "Fallback LevelData should derive a display name from the level id")


func test_create_default_checkpoints_preserves_start_checkpoint_behavior() -> void:
	var level_data := LevelData.new()
	level_data.player_spawn_position = Vector2(128, 256)

	level_data.create_default_checkpoints()

	assert_eq(level_data.checkpoints.size(), 1, "Default checkpoint creation should create exactly one checkpoint")

	var checkpoint = level_data.get_starting_checkpoint()
	assert_not_null(checkpoint, "Default checkpoint creation should produce an unlocked starting checkpoint")
	assert_eq(checkpoint.checkpoint_id, "start", "Starting checkpoint id should remain stable")
	assert_eq(checkpoint.position, Vector2(128, 256), "Starting checkpoint should use player spawn position")
	assert_true(checkpoint.is_unlocked, "Starting checkpoint should begin unlocked")


func test_unlock_checkpoint_mutates_existing_checkpoint() -> void:
	var level_data := LevelData.new()
	var checkpoint := LevelData.CheckpointData.new()
	checkpoint.checkpoint_id = "mid"
	level_data.checkpoints.append(checkpoint)

	assert_true(level_data.unlock_checkpoint("mid"), "unlock_checkpoint should return true for a locked existing checkpoint")
	assert_true(checkpoint.is_unlocked, "unlock_checkpoint should mutate the matched checkpoint resource")
	assert_false(level_data.unlock_checkpoint("missing"), "unlock_checkpoint should return false for unknown checkpoint ids")
