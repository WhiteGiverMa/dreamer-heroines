extends GutTest

## WeaponStats 资源文件单元测试
## 验证 .tres 资源文件正确加载和属性值

# 资源路径
const RIFLE_STATS_PATH := "res://resources/weapon_stats/rifle.tres"
const SHOTGUN_STATS_PATH := "res://resources/weapon_stats/shotgun.tres"
const SMG_STATS_PATH := "res://resources/weapon_stats/smg.tres"
const SNIPER_STATS_PATH := "res://resources/weapon_stats/sniper.tres"


# ============================================
# 文件存在性测试
# ============================================

func test_rifle_stats_file_exists() -> void:
	assert_true(ResourceLoader.exists(RIFLE_STATS_PATH), "rifle.tres should exist")


func test_shotgun_stats_file_exists() -> void:
	assert_true(ResourceLoader.exists(SHOTGUN_STATS_PATH), "shotgun.tres should exist")


func test_smg_stats_file_exists() -> void:
	assert_true(ResourceLoader.exists(SMG_STATS_PATH), "smg.tres should exist")


func test_sniper_stats_file_exists() -> void:
	assert_true(ResourceLoader.exists(SNIPER_STATS_PATH), "sniper.tres should exist")


# ============================================
# 资源加载测试
# ============================================

func test_rifle_stats_loads_as_weapon_stats() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_not_null(stats, "rifle.tres should load")
	# 验证是 WeaponStats 类型
	assert_true(stats is Resource, "Should be a Resource")


func test_shotgun_stats_loads_as_weapon_stats() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_not_null(stats, "shotgun.tres should load")
	assert_true(stats is Resource, "Should be a Resource")


# ============================================
# Rifle 属性值测试
# ============================================

func test_rifle_damage_value() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_eq(stats.damage, 15.0, "Rifle damage should be 15.0")


func test_rifle_fire_rate_value() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_eq(stats.fire_rate, 0.1, "Rifle fire_rate should be 0.1")


func test_rifle_magazine_size() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_eq(stats.magazine_size, 30, "Rifle magazine_size should be 30")


func test_rifle_pellet_count_is_one() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_eq(stats.pellet_count, 1, "Rifle should have pellet_count = 1 (single projectile)")


func test_rifle_is_automatic() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_true(stats.is_automatic, "Rifle should be automatic")


# ============================================
# Shotgun 属性值测试
# ============================================

func test_shotgun_damage_value() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_eq(stats.damage, 12.0, "Shotgun damage should be 12.0")


func test_shotgun_fire_rate_value() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_eq(stats.fire_rate, 0.8, "Shotgun fire_rate should be 0.8")


func test_shotgun_pellet_count() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_eq(stats.pellet_count, 8, "Shotgun should have pellet_count = 8")


func test_shotgun_pellet_spread() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_eq(stats.pellet_spread, 15.0, "Shotgun pellet_spread should be 15.0")


func test_shotgun_is_not_automatic() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_false(stats.is_automatic, "Shotgun should not be automatic")


func test_shotgun_total_damage_per_shot() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	var total_damage = stats.damage * stats.pellet_count
	assert_eq(total_damage, 96.0, "Shotgun total damage per shot should be 96.0 (12 * 8)")


# ============================================
# SMG 属性值测试（数据文件）
# ============================================

func test_smg_damage_value() -> void:
	var stats = load(SMG_STATS_PATH)
	assert_eq(stats.damage, 8.0, "SMG damage should be 8.0")


func test_smg_fire_rate_value() -> void:
	var stats = load(SMG_STATS_PATH)
	assert_eq(stats.fire_rate, 0.05, "SMG fire_rate should be 0.05")


func test_smg_magazine_size() -> void:
	var stats = load(SMG_STATS_PATH)
	assert_eq(stats.magazine_size, 45, "SMG magazine_size should be 45")


# ============================================
# Sniper 属性值测试（数据文件）
# ============================================

func test_sniper_damage_value() -> void:
	var stats = load(SNIPER_STATS_PATH)
	assert_eq(stats.damage, 50.0, "Sniper damage should be 50.0")


func test_sniper_fire_rate_value() -> void:
	var stats = load(SNIPER_STATS_PATH)
	assert_eq(stats.fire_rate, 1.5, "Sniper fire_rate should be 1.5")


func test_sniper_magazine_size() -> void:
	var stats = load(SNIPER_STATS_PATH)
	assert_eq(stats.magazine_size, 5, "Sniper magazine_size should be 5")


# ============================================
# 武器ID测试
# ============================================

func test_rifle_weapon_id() -> void:
	var stats = load(RIFLE_STATS_PATH)
	assert_eq(stats.weapon_id, "rifle_basic", "Rifle weapon_id should be 'rifle_basic'")


func test_shotgun_weapon_id() -> void:
	var stats = load(SHOTGUN_STATS_PATH)
	assert_eq(stats.weapon_id, "shotgun_basic", "Shotgun weapon_id should be 'shotgun_basic'")
