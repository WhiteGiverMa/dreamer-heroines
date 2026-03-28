extends GutTest


## TDD Tests for Fire Rate Accumulator
## These tests define expected behavior for the fire rate accumulator feature.


const RIFLE_SCENE_PATH := "res://scenes/weapons/rifle.tscn"


func _spawn_weapon() -> Weapon:
	var scene: PackedScene = load(RIFLE_SCENE_PATH)
	assert_not_null(scene, "rifle.tscn should load")
	if scene == null:
		return null

	var weapon := scene.instantiate() as Weapon
	assert_not_null(weapon, "rifle should instantiate as Weapon")
	if weapon == null:
		return null

	add_child_autofree(weapon)
	await get_tree().process_frame
	return weapon


func _create_fire_rate_stats(fire_rate: float) -> WeaponStats:
	var stats := WeaponStats.new()
	stats.fire_rate = fire_rate
	stats.is_automatic = true
	stats.use_ammo_system = false  # Infinite ammo for testing
	return stats


func _setup_weapon(weapon: Weapon, fire_rate: float) -> void:
	var stats := _create_fire_rate_stats(fire_rate)
	weapon.stats = stats
	weapon.set_use_ammo_system(false)
	weapon._initialize_stats()  # Force re-initialization with new stats
	# Set default aim parameters (required for accumulator mode)
	weapon._aim_muzzle_pos = Vector2(100, 100)
	weapon._aim_direction = Vector2.RIGHT


func test_fire_rate_accuracy_10_shots_per_second() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	_setup_weapon(weapon, 0.1)  # 10 shots/sec

	var shot_count := {count = 0}  # Use dict for mutable capture in lambda
	weapon.shot_fired.connect(func(_pos, _dir, _fac): shot_count.count += 1)

	# Simulate 1 second of continuous fire input
	var delta := 0.016  # ~60fps
	var total_time := 1.0
	var frames := int(total_time / delta)

	# Set input held ONCE at start, keep it held throughout
	weapon.set_fire_input(true)
	for i in frames:
		weapon._physics_process(delta)
	weapon.set_fire_input(false)

	# Due to floating point precision, expect 9-11 shots
	assert_between(shot_count.count, 9, 11,
		"Continuous 1 second fire at 0.1s fire_rate should produce ~10 shots (got %d)" % shot_count.count
	)


func test_max_3_shots_per_frame() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	_setup_weapon(weapon, 0.01)  # 100 shots/sec = 0.01s between shots

	var max_shots_in_frame := 0
	var current_frame_shots := 0

	weapon.shot_fired.connect(func(_pos, _dir, _fac):
		current_frame_shots += 1
		max_shots_in_frame = maxi(max_shots_in_frame, current_frame_shots)
	)

	# Simulate multiple frames of firing
	var delta := 0.016  # ~60fps
	for i in 10:
		current_frame_shots = 0
		weapon.set_fire_input(true)
		weapon._physics_process(delta)
		weapon.set_fire_input(false)

	assert_lt(max_shots_in_frame, 4,
		"Should never fire more than 3 shots per single frame"
	)


func test_pause_burst_protection() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	_setup_weapon(weapon, 0.1)  # 10 shots/sec

	var shot_count := {count = 0}  # Use dict for mutable capture in lambda
	weapon.shot_fired.connect(func(_pos, _dir, _fac): shot_count.count += 1)

	# Simulate a large delta (e.g., 1 second pause)
	var large_delta := 1.0
	weapon.set_fire_input(true)
	weapon._physics_process(large_delta)
	weapon.set_fire_input(false)

	# With 1 second delta and 0.1s fire_rate, should get ~10 shots but clamped
	assert_lt(shot_count.count, 4,
		"Large delta should not cause burst - max 3 shots regardless of delta size"
	)


func test_accumulator_reset_on_deploy() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	_setup_weapon(weapon, 0.1)  # 10 shots/sec
	weapon.stats.deploy_time = 0.2

	var shot_count := {count = 0}  # Use dict for mutable capture in lambda
	weapon.shot_fired.connect(func(_pos, _dir, _fac): shot_count.count += 1)

	# Fire a shot - need to accumulate enough time first
	weapon.set_fire_input(true)
	weapon._physics_process(0.15)  # 0.15 > 0.1 fire_rate, should fire 1 shot
	weapon.set_fire_input(false)

	var shots_before_deploy: int = shot_count.count
	assert_gt(shots_before_deploy, 0, "Should have fired at least one shot before deploy (got %d)" % shots_before_deploy)

	# Start deploy (switching weapons)
	weapon.start_deploy()
	weapon._physics_process(0.1)  # Partway through deploy

	# Resume firing after deploy
	weapon._physics_process(0.05)  # Deploy finishes
	weapon.set_fire_input(true)
	weapon._physics_process(0.15)  # Fire for a bit
	weapon.set_fire_input(false)

	# Accumulator should have been reset, so first few shots may be spaced normally
	# The key test: deploy interruption should not cause double-fire
	var shots_after_deploy: int = shot_count.count - shots_before_deploy
	assert_lt(shots_after_deploy, 6,
		"Accumulator reset on deploy should prevent burst after deploy completes"
	)


func test_input_release_stops_firing() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	_setup_weapon(weapon, 0.1)  # 10 shots/sec

	var shot_count := {count = 0}  # Use dict for mutable capture in lambda
	weapon.shot_fired.connect(func(_pos, _dir, _fac): shot_count.count += 1)

	# Press and hold
	weapon.set_fire_input(true)
	weapon._physics_process(0.1)

	var shots_while_held: int = shot_count.count

	# Release input
	weapon.set_fire_input(false)

	# Continue physics processing (accumulator still has time)
	weapon._physics_process(0.5)  # This should NOT produce shots

	assert_eq(
		shot_count.count,
		shots_while_held,
		"After input release, no more shots should fire even with accumulated time"
	)
