extends GutTest

## 武器场景和脚本单元测试
## 测试武器组件基础功能（避免实例化）

const RIFLE_SCENE_PATH := "res://scenes/weapons/rifle.tscn"
const SHOTGUN_SCENE_PATH := "res://scenes/weapons/shotgun.tscn"
const RIFLE_STATS_PATH := "res://resources/weapon_stats/rifle.tres"
const SHOTGUN_STATS_PATH := "res://resources/weapon_stats/shotgun.tres"


# ============================================
# 场景加载测试
# ============================================

func test_rifle_scene_loads() -> void:
	var scene = load(RIFLE_SCENE_PATH)
	assert_not_null(scene, "rifle.tscn should load")


func test_shotgun_scene_loads() -> void:
	var scene = load(SHOTGUN_SCENE_PATH)
	assert_not_null(scene, "shotgun.tscn should load")


# ============================================
# 脚本类定义测试
# ============================================

func test_rifle_weapon_script_exists() -> void:
	var script = load("res://src/weapons/rifle_weapon.gd")
	assert_not_null(script, "rifle_weapon.gd should exist")


func test_shotgun_weapon_script_exists() -> void:
	var script = load("res://src/weapons/shotgun_weapon.gd")
	assert_not_null(script, "shotgun_weapon.gd should exist")


func test_weapon_script_exists() -> void:
	var script = load("res://src/weapons/weapon.gd")
	assert_not_null(script, "weapon.gd should exist")


# ============================================
# 脚本方法存在性测试（通过源码检查）
# ============================================

func test_rifle_weapon_has_fire_method() -> void:
	var script = load("res://src/weapons/rifle_weapon.gd")
	assert_true(script.source_code.contains("func _fire"), "RifleWeapon should have _fire method")


func test_rifle_weapon_has_recoil_animation() -> void:
	var script = load("res://src/weapons/rifle_weapon.gd")
	assert_true(script.source_code.contains("func _play_recoil_animation"), "RifleWeapon should have recoil animation")


func test_rifle_recoil_animation_resets_to_rest_rotation_between_fast_shots() -> void:
	var scene: PackedScene = load(RIFLE_SCENE_PATH)
	assert_not_null(scene, "rifle.tscn should load for recoil test")
	if scene == null:
		return

	var rifle := scene.instantiate() as RifleWeapon
	assert_not_null(rifle, "rifle scene should instantiate as RifleWeapon")
	if rifle == null:
		return

	var recoil_mount := Node2D.new()
	add_child_autofree(recoil_mount)
	add_child_autofree(rifle)
	await get_tree().process_frame

	rifle.set_owner_pivot(recoil_mount)
	rifle._play_recoil_animation()
	await wait_seconds(0.03)
	rifle._play_recoil_animation()
	await wait_seconds(0.12)

	assert_almost_eq(
		recoil_mount.rotation,
		0.0,
		0.001,
		"Repeated recoil shots should settle back to the stable rest rotation instead of accumulating upward drift"
	)


func test_shotgun_weapon_has_fire_method() -> void:
	var script = load("res://src/weapons/shotgun_weapon.gd")
	assert_true(script.source_code.contains("func _fire"), "ShotgunWeapon should have _fire method")


func test_shotgun_weapon_has_pellet_loop() -> void:
	var script = load("res://src/weapons/shotgun_weapon.gd")
	assert_true(script.source_code.contains("for i in range(pellet_count)"), "ShotgunWeapon should have pellet loop")


func test_shotgun_weapon_has_get_total_damage() -> void:
	var script = load("res://src/weapons/shotgun_weapon.gd")
	assert_true(script.source_code.contains("func get_total_damage_per_shot"), "ShotgunWeapon should have get_total_damage_per_shot")


# ============================================
# WeaponStats 脚本测试
# ============================================

func test_weapon_stats_has_pellet_count() -> void:
	var script = load("res://src/weapons/weapon_stats.gd")
	assert_true(script.source_code.contains("pellet_count"), "WeaponStats should have pellet_count")


func test_weapon_stats_has_pellet_spread() -> void:
	var script = load("res://src/weapons/weapon_stats.gd")
	assert_true(script.source_code.contains("pellet_spread"), "WeaponStats should have pellet_spread")


# ============================================
# Weapon 基类信号测试
# ============================================

func test_weapon_has_shot_fired_signal() -> void:
	var script = load("res://src/weapons/weapon.gd")
	assert_true(script.source_code.contains("signal shot_fired"), "Weapon should have shot_fired signal")


func test_weapon_has_ammo_changed_signal() -> void:
	var script = load("res://src/weapons/weapon.gd")
	assert_true(script.source_code.contains("signal ammo_changed"), "Weapon should have ammo_changed signal")


# ============================================
# 删除验证测试
# ============================================

func test_weapon_base_deleted() -> void:
	assert_false(ResourceLoader.exists("res://src/weapons/weapon_base.gd"), "WeaponBase should be deleted")


func test_old_rifle_deleted() -> void:
	assert_false(ResourceLoader.exists("res://src/weapons/rifle.gd"), "Old rifle.gd should be deleted")


func test_old_shotgun_deleted() -> void:
	assert_false(ResourceLoader.exists("res://src/weapons/shotgun.gd"), "Old shotgun.gd should be deleted")


# ============================================
# 阵营系统测试
# ============================================

func test_faction_script_exists() -> void:
	var script = load("res://src/utils/faction.gd")
	assert_not_null(script, "faction.gd should exist")


func test_faction_has_type_enum() -> void:
	var script = load("res://src/utils/faction.gd")
	assert_true(script.source_code.contains("enum Type"), "Faction should have Type enum")


func test_faction_has_player_enemy_values() -> void:
	var script = load("res://src/utils/faction.gd")
	assert_true(script.source_code.contains("PLAYER"), "Faction should have PLAYER")
	assert_true(script.source_code.contains("ENEMY"), "Faction should have ENEMY")
