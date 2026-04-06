extends GutTest


const RIFLE_SCENE_PATH := "res://scenes/weapons/rifle.tscn"


func _spawn_rifle_with_fast_reload() -> Weapon:
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

	var tuned_stats := weapon.stats.duplicate(true)
	tuned_stats.reload_time = 0.4
	tuned_stats.reload_checkpoint_percent = 0.5
	tuned_stats.deploy_time = 0.1
	weapon.stats = tuned_stats
	weapon.set_use_ammo_system(true)
	weapon.current_ammo_in_mag = max(0, tuned_stats.magazine_size - 5)
	weapon.current_reserve_ammo = max(5, tuned_stats.max_ammo)

	return weapon


func test_reload_cancel_before_checkpoint_restarts_from_zero() -> void:
	var weapon := await _spawn_rifle_with_fast_reload()
	if weapon == null:
		return

	weapon.reload()
	weapon._physics_process(0.08)
	weapon.cancel_reload("pre_checkpoint_interrupt")

	assert_false(weapon.has_reload_checkpoint(), "cancel before checkpoint should not preserve checkpoint")
	assert_eq(weapon.get_weapon_state(), Weapon.WeaponState.IDLE, "weapon should return idle after cancel")

	weapon.reload()

	assert_eq(
		weapon.get_weapon_state(),
		Weapon.WeaponState.RELOADING_PRE_CHECKPOINT,
		"reload should restart from pre-checkpoint stage"
	)
	assert_almost_eq(
		weapon.get_reload_progress_ratio(),
		0.0,
		0.001,
		"restart after pre-checkpoint cancel should begin from 0 progress"
	)


func test_reload_cancel_after_checkpoint_resumes_from_checkpoint() -> void:
	var weapon := await _spawn_rifle_with_fast_reload()
	if weapon == null:
		return

	weapon.reload()
	weapon._physics_process(0.26)
	weapon.cancel_reload("post_checkpoint_interrupt")

	assert_true(weapon.has_reload_checkpoint(), "cancel after checkpoint should preserve checkpoint")
	assert_eq(weapon.get_weapon_state(), Weapon.WeaponState.IDLE, "weapon should return idle after cancel")

	weapon.reload()

	var checkpoint_ratio := weapon.get_reload_checkpoint_ratio()
	assert_eq(
		weapon.get_weapon_state(),
		Weapon.WeaponState.RELOADING_POST_CHECKPOINT,
		"reload should resume from post-checkpoint stage"
	)
	assert_almost_eq(
		weapon.get_reload_progress_ratio(),
		checkpoint_ratio,
		0.001,
		"restart after post-checkpoint cancel should resume from checkpoint progress"
	)
