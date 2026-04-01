extends GutTest


const CommandHandlerClass = preload("res://addons/developer_commands/command_handler.gd")
const DeveloperModeClass = preload("res://src/autoload/developer_mode.gd")
const WaveSpawnerClass = preload("res://src/levels/wave_spawner.gd")


class FakeEnemy:
	extends Node


class FakeSpawner:
	extends Node

	var spawnable_enemy_keys: Array[String] = ["flying_basic", "melee", "ranged_basic"]
	var spawned_keys: Array[String] = []
	var spawned_positions: Array[Vector2] = []

	func get_spawnable_enemy_keys() -> Array[String]:
		return spawnable_enemy_keys

	func spawn_enemy_now(enemy_key: String, position: Vector2 = Vector2.ZERO) -> Node:
		spawned_keys.append(enemy_key)
		spawned_positions.append(position)
		var enemy := FakeEnemy.new()
		add_child(enemy)
		return enemy


func test_parse_spawn_batch_count_accepts_enemy_x10() -> void:
	var handler := CommandHandlerClass.new()
	add_child_autofree(handler)

	assert_eq(handler._parse_spawn_batch_count(["enemy", "x10"]), 10, "spawn enemy x10 should parse as random batch count")
	assert_eq(handler._parse_spawn_batch_count(["enemy", "x001"]), 1, "spawn enemy x001 should still parse as a positive batch count")


func test_parse_spawn_batch_count_rejects_invalid_forms() -> void:
	var handler := CommandHandlerClass.new()
	add_child_autofree(handler)

	assert_eq(handler._parse_spawn_batch_count(["melee", "x10"]), -1, "Specific enemy spawns should not be treated as random batch syntax")
	assert_eq(handler._parse_spawn_batch_count(["enemy", "10"]), -1, "Batch syntax should require an x<count> token")
	assert_eq(handler._parse_spawn_batch_count(["enemy", "x0"]), -1, "Batch syntax should reject non-positive counts")


func test_parse_spawn_position_supports_optional_coordinates() -> void:
	var handler := CommandHandlerClass.new()
	add_child_autofree(handler)

	assert_eq(handler._parse_spawn_position(["enemy", "x10"], 2), {"valid": true, "x": 0.0, "y": 0.0}, "Random spawn without coordinates should keep using default spawn points")
	assert_eq(handler._parse_spawn_position(["enemy", "x10", "12", "34"], 2), {"valid": true, "x": 12.0, "y": 34.0}, "Random spawn should accept explicit coordinates after the batch token")
	assert_eq(handler._parse_spawn_position(["enemy", "x10", "12"], 2), {"valid": false, "x": 0.0, "y": 0.0}, "Spawn position parsing should reject incomplete coordinate pairs")


func test_spawn_random_enemies_with_spawner_uses_available_enemy_keys() -> void:
	var developer_mode := DeveloperModeClass.new()
	var spawner := FakeSpawner.new()
	add_child_autofree(spawner)

	var enemies := developer_mode._spawn_random_enemies_with_spawner(spawner, 10, Vector2(320, 180))

	assert_eq(enemies.size(), 10, "Random batch spawn should create one enemy per requested count when keys are available")
	assert_eq(spawner.spawned_keys.size(), 10, "Spawner should be called once for each requested random enemy")
	for enemy_key in spawner.spawned_keys:
		assert_true(spawner.spawnable_enemy_keys.has(enemy_key), "Random batch spawn should only choose keys exposed by the WaveSpawner")
	for position in spawner.spawned_positions:
		assert_eq(position, Vector2(320, 180), "Batch random spawns should forward the requested position to the spawner")
	developer_mode.free()


func test_wave_spawner_get_spawnable_enemy_keys_returns_sorted_keys() -> void:
	var spawner := WaveSpawnerClass.new()
	add_child_autofree(spawner)
	var keys := spawner.get_spawnable_enemy_keys()

	assert_eq(keys, ["flying_basic", "melee", "ranged_basic"], "WaveSpawner should expose a stable canonical key list for random developer spawns")
