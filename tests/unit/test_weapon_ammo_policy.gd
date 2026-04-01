extends GutTest


const RIFLE_SCENE_PATH := "res://scenes/weapons/rifle.tscn"


func _spawn_rifle() -> Weapon:
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


func test_player_weapon_consumes_ammo() -> void:
	var weapon := await _spawn_rifle()
	if weapon == null:
		return

	weapon.set_use_ammo_system(true)
	var before_mag := weapon.current_ammo_in_mag
	var fired := weapon.try_shoot(weapon.get_muzzle_position(), Vector2.RIGHT)

	assert_true(fired, "weapon should fire in player mode")
	assert_eq(weapon.current_ammo_in_mag, before_mag - 1, "player weapon should consume 1 ammo")


func test_enemy_weapon_does_not_consume_ammo() -> void:
	var weapon := await _spawn_rifle()
	if weapon == null:
		return

	weapon.set_use_ammo_system(false)
	var before_mag := weapon.current_ammo_in_mag
	var fired := weapon.try_shoot(weapon.get_muzzle_position(), Vector2.LEFT)

	assert_true(fired, "weapon should fire in enemy infinite-ammo mode")
	assert_eq(weapon.current_ammo_in_mag, before_mag, "enemy weapon should not consume ammo")


func test_switch_from_enemy_to_player_mode_restores_magazine_bounds() -> void:
	var weapon := await _spawn_rifle()
	if weapon == null:
		return

	weapon.set_use_ammo_system(false)
	assert_eq(weapon.current_ammo_in_mag, 999, "enemy mode uses sentinel ammo")

	weapon.set_use_ammo_system(true)
	var expected_mag := weapon.stats.magazine_size if weapon.stats else 0
	assert_eq(weapon.current_ammo_in_mag, expected_mag, "switching to player mode should clamp to magazine size")
	assert_true(weapon.is_using_ammo_system(), "weapon should report using ammo after switch")


func test_add_ammo_emits_ammo_changed_signal_immediately() -> void:
	var weapon := await _spawn_rifle()
	if weapon == null:
		return

	weapon.set_use_ammo_system(true)
	weapon.current_reserve_ammo = 0
	watch_signals(weapon)

	weapon.add_ammo(10)

	assert_signal_emitted(weapon, "ammo_changed", "add_ammo should emit ammo_changed immediately")
	assert_signal_emitted_with_parameters(
		weapon,
		"ammo_changed",
		[weapon.current_ammo_in_mag, weapon.stats.magazine_size]
	)
