class_name CharacterConfig
extends Resource

# CharacterConfig - 角色配置数据
# 存储玩家角色的配置选择，与存档系统集成

@export_group("Character Selection")
@export var character_id: String = "heroine_default"
@export var character_name: String = "默认角色"
@export var skin_variant: String = "default"

@export_group("Weapon Loadout")
@export var primary_weapon_id: String = "rifle_basic"
@export var secondary_weapon_id: String = "shotgun_basic"

@export_group("Metadata")
@export var last_modified: int = 0  # Unix timestamp


func _init() -> void:
	resource_name = "CharacterConfig"


## 创建默认配置
static func create_default() -> CharacterConfig:
	var config := CharacterConfig.new()
	config.character_id = "heroine_default"
	config.character_name = "默认角色"
	config.skin_variant = "default"
	config.primary_weapon_id = "rifle_basic"
	config.secondary_weapon_id = "shotgun_basic"
	config.last_modified = int(Time.get_unix_time_from_system())
	return config


## 序列化为字典（用于存档）
func to_dictionary() -> Dictionary:
	return {
		"character_id": character_id,
		"character_name": character_name,
		"skin_variant": skin_variant,
		"primary_weapon_id": primary_weapon_id,
		"secondary_weapon_id": secondary_weapon_id,
		"last_modified": last_modified
	}


## 从字典加载（用于读档）
static func from_dictionary(data: Dictionary) -> CharacterConfig:
	var config := CharacterConfig.new()
	config.character_id = data.get("character_id", "heroine_default")
	config.character_name = data.get("character_name", "默认角色")
	config.skin_variant = data.get("skin_variant", "default")
	config.primary_weapon_id = data.get("primary_weapon_id", "rifle_basic")
	config.secondary_weapon_id = data.get("secondary_weapon_id", "shotgun_basic")
	config.last_modified = data.get("last_modified", 0)
	return config


## 更新修改时间
func mark_modified() -> void:
	last_modified = int(Time.get_unix_time_from_system())


## 获取主武器场景路径
func get_primary_weapon_scene_path() -> String:
	return _get_weapon_scene_path(primary_weapon_id)


## 获取副武器场景路径
func get_secondary_weapon_scene_path() -> String:
	return _get_weapon_scene_path(secondary_weapon_id)


## 获取武器场景路径（内部方法）
func _get_weapon_scene_path(weapon_id: String) -> String:
	# 武器ID到场景文件的映射
	var weapon_scene_map := {
		"rifle_basic": "res://scenes/weapons/rifle.tscn",
		"hk416": "res://scenes/weapons/hk416.tscn",
		"shotgun_basic": "res://scenes/weapons/shotgun.tscn",
		"sniper_basic": "res://scenes/weapons/sniper.tscn",
		"smg_basic": "res://scenes/weapons/smg.tscn",
	}

	return weapon_scene_map.get(weapon_id, "res://scenes/weapons/rifle.tscn")


## 检查配置是否有效
func is_valid() -> bool:
	return not character_id.is_empty() and not primary_weapon_id.is_empty()


## 复制配置
func duplicate_config() -> CharacterConfig:
	var copy := CharacterConfig.new()
	copy.character_id = character_id
	copy.character_name = character_name
	copy.skin_variant = skin_variant
	copy.primary_weapon_id = primary_weapon_id
	copy.secondary_weapon_id = secondary_weapon_id
	copy.last_modified = last_modified
	return copy
