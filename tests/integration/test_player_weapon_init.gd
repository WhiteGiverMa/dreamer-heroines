extends GutTest

## 玩家武器初始化集成测试
## 测试玩家在 _ready 时正确初始化武器

var _player: Player
var _guide_context: GUIDEMappingContext


func _get_weapon_by_slot(slot_id: int) -> Weapon:
	if slot_id < 0 or slot_id >= _player.weapons.size():
		return null
	return _player.weapons[slot_id] as Weapon


func _retune_weapon_timing(weapon: Weapon, reload_time: float, checkpoint_ratio: float, deploy_time: float) -> void:
	if weapon == null or weapon.stats == null:
		return
	var tuned_stats := weapon.stats.duplicate(true)
	tuned_stats.reload_time = reload_time
	tuned_stats.reload_checkpoint_percent = checkpoint_ratio
	tuned_stats.deploy_time = deploy_time
	weapon.stats = tuned_stats


func _prepare_reloadable_weapon(weapon: Weapon) -> void:
	if weapon == null or weapon.stats == null:
		return
	weapon.set_use_ammo_system(true)
	weapon.current_ammo_in_mag = max(0, weapon.stats.magazine_size - 5)
	weapon.current_reserve_ammo = max(10, weapon.stats.max_ammo)


func before_all() -> void:
	# 加载并启用游戏玩法上下文
	_guide_context = load("res://config/input/contexts/gameplay_context.tres")
	if _guide_context:
		GUIDE.enable_mapping_context(_guide_context)
	await get_tree().process_frame


func before_each() -> void:
	# 每个测试前创建新的玩家实例
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	_player = player_scene.instantiate()
	add_child_autofree(_player)
	await wait_frames(3)  # 等待 _ready 完成


func after_all() -> void:
	if _guide_context:
		GUIDE.disable_mapping_context(_guide_context)


func test_player_has_weapons_array() -> void:
	assert_not_null(_player.weapons, "Player should have weapons array")


func test_player_weapons_array_not_empty() -> void:
	assert_gt(_player.weapons.size(), 0, "Player weapons array should not be empty after _ready")


func test_player_has_current_weapon() -> void:
	assert_not_null(_player.current_weapon, "Player should have current_weapon set")


func test_current_weapon_is_rifle() -> void:
	assert_not_null(_player.current_weapon, "current_weapon should not be null")
	if _player.current_weapon:
		# Check weapon has stats with correct weapon type
		assert_not_null(_player.current_weapon.stats, "Weapon should have stats")
		if _player.current_weapon.stats:
			assert_eq(_player.current_weapon.stats.weapon_name, "rifle_basic", "Weapon name should match rifle stats id")


func test_weapon_has_stats() -> void:
	if _player.current_weapon:
		assert_not_null(_player.current_weapon.stats, "Weapon should have stats resource")


func test_weapon_has_correct_damage_from_config() -> void:
	if _player.current_weapon and _player.current_weapon.stats:
		# 从配置文件期望的伤害值
		var expected_damage := 15.0
		assert_eq(_player.current_weapon.stats.damage, expected_damage,
			"Weapon damage should match config value (15)")


func test_weapon_has_correct_fire_rate_from_config() -> void:
	if _player.current_weapon and _player.current_weapon.stats:
		# 从配置文件期望的射速
		var expected_fire_rate := 0.1
		assert_eq(_player.current_weapon.stats.fire_rate, expected_fire_rate,
			"Weapon fire_rate should match config value (0.1)")


func test_weapon_has_correct_magazine_size_from_config() -> void:
	if _player.current_weapon and _player.current_weapon.stats:
		var expected_magazine := 30
		assert_eq(_player.current_weapon.stats.magazine_size, expected_magazine,
			"Weapon magazine_size should match config value (30)")


func test_weapon_magazine_starts_full() -> void:
	if _player.current_weapon and _player.current_weapon.stats:
		assert_eq(_player.current_weapon.current_ammo_in_mag,
			_player.current_weapon.stats.magazine_size,
			"Weapon magazine should start full")


func test_player_has_weapon_pivot() -> void:
	assert_not_null(_player.weapon_pivot, "Player should have weapon_pivot")


func test_weapon_aim_origin_uses_stable_mount_instead_of_muzzle() -> void:
	var stable_origin := _player.weapon_mount.global_position
	var live_muzzle := _player.get_muzzle_position()

	assert_eq(_player.get_weapon_aim_origin(), stable_origin, "Aim origin should use stable weapon mount position")
	assert_ne(_player.get_weapon_aim_origin(), live_muzzle, "Aim origin should not be derived from live muzzle position")


func test_rifle_recoil_target_uses_weapon_mount_not_weapon_pivot() -> void:
	var rifle := _player.current_weapon as RifleWeapon
	assert_not_null(rifle, "Primary equipped weapon should be a RifleWeapon")
	if rifle == null:
		return

	assert_eq(rifle.get("_recoil_target"), _player.weapon_mount, "Recoil target should be weapon mount to avoid fighting aim pivot rotation")


func test_weapon_is_child_of_weapon_node() -> void:
	var weapon_node := _player.weapon_pivot.get_node_or_null("Weapon")
	assert_not_null(weapon_node, "WeaponPivot should have Weapon child")

	if weapon_node:
		var children := weapon_node.get_children()
		var has_weapon_child := false
		for child in children:
			if child.has_signal("shot_fired"):
				has_weapon_child = true
				break
		assert_true(has_weapon_child, "Weapon node should have a Weapon child with shot_fired signal")


func test_weapon_visible_when_equipped() -> void:
	if _player.current_weapon:
		assert_true(_player.current_weapon.visible, "Equipped weapon should be visible")


func test_switch_weapon_changes_current_weapon() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have at least two weapons for switch test")
	if _player.weapons.size() <= 1:
		return

	var first_weapon = _player.current_weapon
	var first_index := _player.current_weapon_index

	_player.switch_weapon()
	await wait_frames(1)

	assert_ne(_player.current_weapon, first_weapon, "Current weapon should change after switch_weapon")
	assert_ne(_player.current_weapon_index, first_index, "Current weapon index should change after switch_weapon")


func test_switch_weapon_updates_visibility_state() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have at least two weapons for visibility switch test")
	if _player.weapons.size() <= 1:
		return

	_player._equip_weapon(0)
	await wait_frames(1)
	assert_true((_player.weapons[0] as Node2D).visible, "Weapon 0 should be visible when equipped")
	assert_false((_player.weapons[1] as Node2D).visible, "Weapon 1 should be hidden when weapon 0 is equipped")

	_player._equip_weapon(1)
	await wait_frames(1)
	assert_false((_player.weapons[0] as Node2D).visible, "Weapon 0 should be hidden when weapon 1 is equipped")
	assert_true((_player.weapons[1] as Node2D).visible, "Weapon 1 should be visible when equipped")


func test_hk416_texture_is_loaded_after_switch() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have HK416 weapon for texture test")
	if _player.weapons.size() <= 1:
		return

	_player._equip_weapon(1)
	await wait_frames(1)

	var hk_weapon = _player.current_weapon
	assert_not_null(hk_weapon, "Current weapon should not be null after equipping HK416")
	if hk_weapon == null:
		return

	assert_not_null(hk_weapon.stats, "HK416 weapon should have stats")
	if hk_weapon.stats:
		assert_eq(hk_weapon.stats.weapon_id, "hk416", "Equipped weapon should be hk416")

	var sprite := hk_weapon.get_node_or_null("Sprite2D") as Sprite2D
	assert_not_null(sprite, "HK416 should have Sprite2D child")
	if sprite == null:
		return

	assert_not_null(sprite.texture, "HK416 Sprite2D should have a texture")
	if sprite.texture:
		assert_eq(sprite.texture.get_class(), "ImageTexture", "HK416 sprite texture should be loaded from image")
		var size := sprite.texture.get_size()
		assert_eq(size.x, 335.0, "HK416 texture width should match source image")
		assert_eq(size.y, 121.0, "HK416 texture height should match source image")


func test_direct_primary_secondary_selection_sets_slot_and_weapon_ids() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	_player.equip_secondary_weapon()
	await wait_frames(1)

	assert_eq(_player.current_slot_id, _player.secondary_slot_id, "Direct secondary select should set current_slot_id to secondary")
	assert_eq(_player.current_weapon_index, _player.secondary_slot_id, "Current weapon index should match secondary slot")
	assert_not_null(_player.current_weapon.stats, "Secondary weapon should have stats")
	if _player.current_weapon.stats:
		assert_eq(_player.current_weapon.stats.weapon_id, "hk416", "Secondary slot should equip hk416")

	assert_false((_player.weapons[_player.primary_slot_id] as Node2D).visible, "Primary weapon node should be hidden when secondary is active")
	assert_true((_player.weapons[_player.secondary_slot_id] as Node2D).visible, "Secondary weapon node should be visible when active")

	_player.equip_primary_weapon()
	await wait_frames(1)

	assert_eq(_player.current_slot_id, _player.primary_slot_id, "Direct primary select should set current_slot_id to primary")
	assert_eq(_player.current_weapon_index, _player.primary_slot_id, "Current weapon index should match primary slot")
	assert_not_null(_player.current_weapon.stats, "Primary weapon should have stats")
	if _player.current_weapon.stats:
		assert_eq(_player.current_weapon.stats.weapon_id, "rifle_basic", "Primary slot should equip rifle_basic")


func test_selecting_active_slot_does_not_restart_deploy() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	var secondary_weapon := _get_weapon_by_slot(_player.secondary_slot_id)
	_retune_weapon_timing(secondary_weapon, 0.6, 0.5, 1.0)

	_player.equip_secondary_weapon()
	await wait_frames(6)

	assert_true(_player.current_weapon.is_deploying(), "Switching to secondary should start deploy")
	var elapsed_before := float(_player.current_weapon.get("_deploy_elapsed"))

	_player.equip_secondary_weapon()
	await wait_frames(3)

	var elapsed_after := float(_player.current_weapon.get("_deploy_elapsed"))
	assert_eq(_player.current_slot_id, _player.secondary_slot_id, "Current slot should remain secondary when reselecting active slot")
	assert_true(_player.current_weapon.is_deploying(), "Deploy should keep running instead of being restarted")
	assert_gt(elapsed_after, elapsed_before, "Deploy elapsed time should continue increasing on active-slot reselect")


func test_switch_interrupts_reload_before_checkpoint_and_resets_progress() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	var primary_weapon := _get_weapon_by_slot(_player.primary_slot_id)
	_retune_weapon_timing(primary_weapon, 0.6, 0.5, 0.05)
	_prepare_reloadable_weapon(primary_weapon)

	_player.equip_primary_weapon()
	await wait_frames(4)
	primary_weapon.reload()
	await get_tree().create_timer(0.1).timeout

	assert_true(primary_weapon.is_reloading, "Primary weapon should be reloading before switch interrupt")
	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.RELOADING_PRE_CHECKPOINT, "Reload should still be pre-checkpoint")

	_player.equip_secondary_weapon()
	await wait_frames(1)

	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.IDLE, "Switch should cancel reload and return weapon to idle")
	assert_false(primary_weapon.has_reload_checkpoint(), "Pre-checkpoint switch interrupt should not preserve checkpoint")
	assert_almost_eq(primary_weapon.get_reload_progress_ratio(), 0.0, 0.001, "Pre-checkpoint interrupt should reset progress to zero")

	_player.equip_primary_weapon()
	await wait_frames(4)
	primary_weapon.reload()
	await wait_frames(1)

	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.RELOADING_PRE_CHECKPOINT, "Reload should restart from pre-checkpoint after reset")
	assert_lt(
		primary_weapon.get_reload_progress_ratio(),
		primary_weapon.get_reload_checkpoint_ratio(),
		"Restarted reload should remain before checkpoint after reset"
	)


func test_post_checkpoint_switch_interrupt_resumes_from_checkpoint() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	var primary_weapon := _get_weapon_by_slot(_player.primary_slot_id)
	_retune_weapon_timing(primary_weapon, 0.6, 0.5, 0.05)
	_prepare_reloadable_weapon(primary_weapon)

	_player.equip_primary_weapon()
	await wait_frames(4)
	primary_weapon.reload()
	await get_tree().create_timer(0.36).timeout

	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.RELOADING_POST_CHECKPOINT, "Reload should be post-checkpoint before interrupt")

	_player.equip_secondary_weapon()
	await wait_frames(1)

	assert_true(primary_weapon.has_reload_checkpoint(), "Post-checkpoint switch interrupt should preserve checkpoint")
	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.IDLE, "Interrupted weapon should be idle after switch")

	_player.equip_primary_weapon()
	await wait_frames(4)
	primary_weapon.reload()
	await wait_frames(1)

	var checkpoint_ratio := primary_weapon.get_reload_checkpoint_ratio()
	assert_eq(primary_weapon.get_weapon_state(), Weapon.WeaponState.RELOADING_POST_CHECKPOINT, "Reload should resume in post-checkpoint stage")
	assert_gte(
		primary_weapon.get_reload_progress_ratio(),
		checkpoint_ratio,
		"Resumed reload progress should be at or beyond checkpoint ratio"
	)


func test_deploy_blocks_shooting_until_deploy_finishes() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	var secondary_weapon := _get_weapon_by_slot(_player.secondary_slot_id)
	_retune_weapon_timing(secondary_weapon, 0.6, 0.5, 0.4)
	_prepare_reloadable_weapon(secondary_weapon)

	_player.equip_secondary_weapon()
	await wait_frames(1)

	assert_true(_player.current_weapon.is_deploying(), "Equipping secondary should enter deploy state")
	var blocked_shot: bool = _player.current_weapon.try_shoot(_player.get_muzzle_position(), _player.get_aim_direction())
	assert_false(blocked_shot, "Shooting should be blocked while deploy is active")

	await get_tree().create_timer(0.45).timeout

	assert_false(_player.current_weapon.is_deploying(), "Deploy should finish after deploy duration")
	var allowed_shot: bool = _player.current_weapon.try_shoot(_player.get_muzzle_position(), _player.get_aim_direction())
	assert_true(allowed_shot, "Shooting should be allowed after deploy finishes")


func test_repeated_switching_restarts_deploy_timer() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	var primary_weapon := _get_weapon_by_slot(_player.primary_slot_id)
	var secondary_weapon := _get_weapon_by_slot(_player.secondary_slot_id)
	_retune_weapon_timing(primary_weapon, 0.6, 0.5, 1.0)
	_retune_weapon_timing(secondary_weapon, 0.6, 0.5, 1.0)

	_player.equip_secondary_weapon()
	await wait_frames(6)

	var secondary_elapsed := float(secondary_weapon.get("_deploy_elapsed"))
	assert_true(secondary_weapon.is_deploying(), "Secondary deploy should be active before rapid reswitch")
	assert_gt(secondary_elapsed, 0.0, "Secondary deploy should have progressed before second switch")

	_player.equip_primary_weapon()
	await wait_frames(1)

	var primary_elapsed := float(primary_weapon.get("_deploy_elapsed"))
	assert_true(primary_weapon.is_deploying(), "Switching back should start a new primary deploy")
	assert_lte(primary_elapsed, 0.05, "New deploy should restart timer near zero elapsed")
	assert_false(secondary_weapon.is_deploying(), "Outgoing weapon deploy should be canceled when switching away")


func test_dash_interrupts_reload_via_shared_interrupt_path() -> void:
	var active_weapon := _player.current_weapon as Weapon
	assert_not_null(active_weapon, "Current weapon should exist")
	if active_weapon == null:
		return

	_retune_weapon_timing(active_weapon, 0.6, 0.5, 0.05)
	_prepare_reloadable_weapon(active_weapon)

	active_weapon.reload()
	await get_tree().create_timer(0.1).timeout
	assert_true(active_weapon.is_reloading, "Weapon should be reloading before dash interrupt")

	_player._start_dash()
	await wait_physics_frames(1)

	assert_eq(active_weapon.get_weapon_state(), Weapon.WeaponState.IDLE, "Dash should interrupt reload and return weapon to idle")
	assert_false(active_weapon.has_reload_checkpoint(), "Pre-checkpoint dash interrupt should not preserve checkpoint")
	assert_eq(_player.dash_state, Player.DashState.DASHING, "Dash should still enter dashing state after interrupt")


func test_q_cycle_switch_compatibility_keeps_two_slot_flow() -> void:
	assert_gt(_player.weapons.size(), 1, "Player should have two weapon slots")
	if _player.weapons.size() <= 1:
		return

	_player.equip_primary_weapon()
	await wait_frames(1)

	_player.switch_weapon()
	await wait_frames(1)

	assert_eq(_player.current_slot_id, _player.secondary_slot_id, "Q-cycle should move from primary to secondary")
	assert_not_null(_player.current_weapon.stats, "Cycled weapon should have stats")
	if _player.current_weapon.stats:
		assert_eq(_player.current_weapon.stats.weapon_id, "hk416", "First cycle target should be hk416 secondary")

	_player.switch_weapon()
	await wait_frames(1)

	assert_eq(_player.current_slot_id, _player.primary_slot_id, "Q-cycle should wrap from secondary back to primary")
	assert_not_null(_player.current_weapon.stats, "Wrapped weapon should have stats")
	if _player.current_weapon.stats:
		assert_eq(_player.current_weapon.stats.weapon_id, "rifle_basic", "Second cycle target should be rifle_basic primary")
