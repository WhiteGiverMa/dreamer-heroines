extends GutTest


const RIFLE_SCENE_PATH := "res://scenes/weapons/rifle.tscn"
const SHOTGUN_SCENE_PATH := "res://scenes/weapons/shotgun.tscn"


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


func _spawn_shotgun() -> ShotgunWeapon:
	var scene: PackedScene = load(SHOTGUN_SCENE_PATH)
	assert_not_null(scene, "shotgun.tscn should load")
	if scene == null:
		return null

	var weapon := scene.instantiate() as ShotgunWeapon
	assert_not_null(weapon, "shotgun should instantiate as ShotgunWeapon")
	if weapon == null:
		return null

	add_child_autofree(weapon)
	await get_tree().process_frame
	return weapon


func _create_fire_rate_stats(fire_rate: float) -> WeaponStats:
	var stats := WeaponStats.new()
	stats.weapon_name = "test_weapon"
	stats.fire_rate = fire_rate
	stats.is_automatic = true
	stats.use_ammo_system = false
	stats.spread = 0.0
	return stats


func _setup_weapon(weapon: Weapon, fire_rate: float) -> Dictionary:
	var stats := _create_fire_rate_stats(fire_rate)
	weapon.stats = stats
	weapon.set_use_ammo_system(false)
	weapon._initialize_stats()

	var clock := {"now_usec": 0}
	weapon.set_time_provider(func() -> int: return clock.now_usec)
	return clock


func test_scheduler_preserves_interval_after_small_late_frame() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "first shot should fire immediately")

	clock.now_usec = 66_000
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "late frame should still fire when overdue")

	clock.now_usec = 99_000
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "scheduler should not drift to now+interval after a small late frame")

	clock.now_usec = 100_000
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "third shot should stay aligned to the original cadence grid")


func test_scheduler_resets_after_large_gap_instead_of_bursting() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "first shot should fire immediately")

	clock.now_usec = 5_000_000
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "shot after a long pause should still fire")

	clock.now_usec = 5_010_000
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "large lateness should reset cadence instead of allowing immediate catch-up burst")

	clock.now_usec = 5_050_000
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "after reset, next shot should be one full interval later")


func test_can_shoot_tracks_absolute_cooldown_window() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.1)

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "shot should fire immediately")
	assert_false(weapon.can_shoot, "weapon should report cooldown immediately after firing")

	clock.now_usec = 99_000
	weapon._physics_process(0.099)
	assert_false(weapon.can_shoot, "weapon should still be cooling down just before the fire window reopens")

	clock.now_usec = 100_000
	weapon._physics_process(0.001)
	assert_true(weapon.can_shoot, "weapon should become shootable exactly when the absolute cooldown expires")


func test_out_of_ammo_does_not_shift_fire_schedule() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)
	weapon.set_use_ammo_system(true)
	weapon.current_ammo_in_mag = 1
	weapon.current_reserve_ammo = 0

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "last bullet should fire")

	clock.now_usec = 50_000
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "empty magazine should block firing when the window reopens")
	assert_true(weapon.can_shoot, "empty magazine should not leave the debug-ready flag stuck false once the cooldown window is open")


func test_reload_state_keeps_weapon_unshootable_until_finished() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)
	weapon.set_use_ammo_system(true)
	weapon.current_ammo_in_mag = max(0, weapon.stats.magazine_size - 1)
	weapon.current_reserve_ammo = 10
	weapon.stats.reload_time = 0.2
	weapon.reload()

	clock.now_usec = 1_000_000
	weapon._physics_process(0.05)
	assert_false(weapon.can_shoot, "reload should override an open fire window")
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "weapon must not shoot while reloading")

	weapon._physics_process(0.2)
	assert_true(weapon.can_shoot, "weapon should become shootable again after reload finishes and no cooldown is pending")


func test_same_timestamp_allows_only_one_successful_shot() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "first shot at a timestamp should fire")
	clock.now_usec = 0
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "second shot at the same timestamp must stay blocked")


func test_deploy_state_blocks_and_then_reopens_on_schedule_boundary() -> void:
	var weapon := await _spawn_weapon()
	if weapon == null:
		return

	var clock := _setup_weapon(weapon, 0.05)
	weapon.stats.deploy_time = 0.1

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "first shot should fire before deploy")
	assert_true(weapon.start_deploy(), "weapon should enter deploy state")

	clock.now_usec = 50_000
	weapon._physics_process(0.05)
	assert_false(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "deploy should block firing even when cooldown window reopens")
	assert_false(weapon.can_shoot, "debug-ready flag should remain false while deploying")

	clock.now_usec = 100_000
	weapon._physics_process(0.05)
	assert_true(weapon.can_shoot, "weapon should become shootable once deploy finishes and cooldown window is open")
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "weapon should fire immediately after deploy completes on an open window")


func test_shotgun_runtime_ammo_toggle_matches_scheduler_behavior() -> void:
	var weapon := await _spawn_shotgun()
	if weapon == null:
		return

	var clock := {"now_usec": 0}
	weapon.set_time_provider(func() -> int: return clock.now_usec)
	weapon.stats.fire_rate = 0.8

	weapon.set_use_ammo_system(false)
	var enemy_before_mag := weapon.current_ammo_in_mag
	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "shotgun should fire in infinite-ammo mode")
	assert_eq(weapon.current_ammo_in_mag, enemy_before_mag, "infinite-ammo shotgun should not consume ammo")

	clock.now_usec = 800_000
	weapon._physics_process(0.8)
	weapon.set_use_ammo_system(true)
	weapon.current_ammo_in_mag = 2
	weapon.current_reserve_ammo = 0
	assert_true(weapon.can_shoot, "scheduler should reopen correctly before player-ammo verification")

	assert_true(weapon.try_shoot(Vector2.ZERO, Vector2.RIGHT), "shotgun should still fire after switching back to ammo mode")
	assert_eq(weapon.current_ammo_in_mag, 1, "player-ammo shotgun should consume exactly one shell per shot")

	clock.now_usec = 1_600_000
	weapon._physics_process(0.8)
	assert_true(weapon.can_shoot, "shotgun cooldown should reopen on the absolute scheduler boundary")
