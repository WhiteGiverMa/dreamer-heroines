extends GutTest

## 武器配置加载单元测试
## 测试武器从 JSON 配置正确加载属性

const WEAPON_STATS_PATH := "res://config/weapon_stats.json"


func test_json_file_exists() -> void:
	assert_true(FileAccess.file_exists(WEAPON_STATS_PATH), "weapon_stats.json should exist")


func test_json_contains_rifle_basic_key() -> void:
	var data: Dictionary = _load_json()
	assert_not_null(data, "JSON should parse successfully")
	assert_true(data.has("rifle_basic"), "JSON should contain 'rifle_basic' key")


func test_json_contains_shotgun_basic_key() -> void:
	var data: Dictionary = _load_json()
	assert_true(data.has("shotgun_basic"), "JSON should contain 'shotgun_basic' key")


func test_rifle_basic_has_correct_structure() -> void:
	var data: Dictionary = _load_json()
	var rifle: Dictionary = data.get("rifle_basic", {})

	assert_true(rifle.has("damage"), "rifle_basic should have damage")
	assert_true(rifle.has("fire_rate"), "rifle_basic should have fire_rate")
	assert_true(rifle.has("magazine_size"), "rifle_basic should have magazine_size")


func test_extract_value_from_nested_object() -> void:
	var nested: Dictionary = {"damage": {"value": 15, "description": "test"}}
	var extracted: Variant = _extract_config_value(nested, "damage", 0)
	assert_eq(extracted, 15, "Should extract value from nested object")


func test_extract_value_from_flat_value() -> void:
	var flat: Dictionary = {"weapon_name": "Test Weapon"}
	var extracted: Variant = _extract_config_value(flat, "weapon_name", "")
	assert_eq(extracted, "Test Weapon", "Should return flat value directly")


func test_extract_value_missing_key_returns_default() -> void:
	var data: Dictionary = {"other_key": 123}
	var extracted: Variant = _extract_config_value(data, "missing_key", 999)
	assert_eq(extracted, 999, "Should return default for missing key")


func test_rifle_basic_damage_value() -> void:
	var data: Dictionary = _load_json()
	var rifle: Dictionary = data.get("rifle_basic", {})
	var damage: Variant = _extract_config_value(rifle, "damage", 0)
	assert_eq(damage, 15, "rifle_basic damage should be 15")


func test_rifle_basic_fire_rate_value() -> void:
	var data: Dictionary = _load_json()
	var rifle: Dictionary = data.get("rifle_basic", {})
	var fire_rate: Variant = _extract_config_value(rifle, "fire_rate", 0.0)
	assert_eq(fire_rate, 0.1, "rifle_basic fire_rate should be 0.1")


func test_shotgun_basic_pellet_count() -> void:
	var data: Dictionary = _load_json()
	var shotgun: Dictionary = data.get("shotgun_basic", {})
	var pellet_count: Variant = _extract_config_value(shotgun, "pellet_count", 0)
	assert_eq(pellet_count, 8, "shotgun_basic pellet_count should be 8")


# ============================================
# Helper Functions
# ============================================

func _load_json() -> Dictionary:
	if not FileAccess.file_exists(WEAPON_STATS_PATH):
		return {}

	var file: FileAccess = FileAccess.open(WEAPON_STATS_PATH, FileAccess.READ)
	var json_text: String = file.get_as_text()
	file.close()

	var data: Variant = JSON.parse_string(json_text)
	if data is Dictionary:
		return data
	return {}


func _extract_config_value(data: Dictionary, key: String, default: Variant) -> Variant:
	if not data.has(key):
		return default

	var val: Variant = data[key]
	if val is Dictionary and val.has("value"):
		return val["value"]
	return val
