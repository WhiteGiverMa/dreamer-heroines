extends GutTest


const WaveSpawnerClass = preload("res://src/levels/wave_spawner.gd")


func test_get_target_kills_prefers_wave_config_quota() -> void:
	var spawner := WaveSpawnerClass.new()
	spawner.auto_start = false
	spawner.wave_config_path = "res://config/waves/arena_01_waves.json"
	add_child_autofree(spawner)

	assert_eq(spawner.get_total_enemy_count(), 16, "Arena 01 authored waves should still total 16 enemies")
	assert_eq(spawner.get_target_kills(), 25, "WaveSpawner should expose the configured kill quota instead of authored enemy total")


func test_check_wave_completion_keeps_spawner_running_after_last_authored_wave() -> void:
	var spawner := WaveSpawnerClass.new()
	spawner.auto_start = false
	add_child_autofree(spawner)

	spawner._waves = [
		{"wave": 1, "enemies": ["melee_grunt"], "spawn_delay": 0.1}
	]
	spawner._wave_interval = 0.1
	spawner._extension_wave_cycle = [0]
	spawner._is_running = true
	spawner._current_wave_index = 0
	spawner._current_wave_data = {"wave": 1, "enemies": ["melee_grunt"], "spawn_delay": 0.1}
	spawner._pending_enemy_keys.clear()
	spawner._active_wave_enemy_ids.clear()

	watch_signals(spawner)

	spawner._check_wave_completion()

	assert_true(spawner._is_running, "Spawner should stay running so extension waves can continue after authored waves end")
	assert_signal_emitted(spawner, "all_waves_complete", "Spawner should still emit all_waves_complete once when authored content is exhausted")
	assert_false(spawner._wave_timer.is_stopped(), "Spawner should queue the next extension wave instead of halting")


func test_get_wave_data_for_index_cycles_extension_wave_sources() -> void:
	var spawner := WaveSpawnerClass.new()
	spawner.auto_start = false
	add_child_autofree(spawner)

	spawner._waves = [
		{"wave": 1, "enemies": ["melee_grunt"], "spawn_delay": 1.0},
		{"wave": 2, "enemies": ["ranged_grunt"], "spawn_delay": 0.5},
		{"wave": 3, "enemies": ["flying_drone"], "spawn_delay": 0.25}
	]
	spawner._extension_wave_cycle = [1, 2]

	var first_extension := spawner._get_wave_data_for_index(3)
	var second_extension := spawner._get_wave_data_for_index(4)

	assert_eq(first_extension.get("wave"), 4, "First extension wave should continue authored numbering")
	assert_eq(first_extension.get("enemies"), ["ranged_grunt"], "First extension wave should use the first configured cycle source")
	assert_eq(second_extension.get("wave"), 5, "Second extension wave should continue numbering")
	assert_eq(second_extension.get("enemies"), ["flying_drone"], "Second extension wave should advance through the configured extension cycle")


func test_spawn_enemy_now_resolves_enemy_aliases() -> void:
	var spawner := WaveSpawnerClass.new()
	spawner.auto_start = false
	add_child_autofree(spawner)

	var enemy := spawner.spawn_enemy_now("ranged")

	assert_not_null(enemy, "spawn_enemy_now should accept developer-facing alias keys")
	assert_true(is_instance_valid(enemy), "Resolved alias spawn should instantiate a live enemy node")
	assert_eq(enemy.scene_file_path, "res://scenes/enemies/ranged_enemy.tscn", "Alias 'ranged' should resolve to the canonical ranged enemy scene")


func test_spawn_enemy_now_tracks_enemy_during_active_wave() -> void:
	var spawner := WaveSpawnerClass.new()
	spawner.auto_start = false
	add_child_autofree(spawner)

	spawner._is_running = true
	spawner._current_wave_index = 2

	var enemy := spawner.spawn_enemy_now("melee")
	assert_not_null(enemy, "Developer spawn should instantiate an enemy during active waves")

	var enemy_id := enemy.get_instance_id()
	assert_true(spawner._active_wave_enemy_ids.has(enemy_id), "Developer-spawned enemies should join active wave tracking during an active wave")
