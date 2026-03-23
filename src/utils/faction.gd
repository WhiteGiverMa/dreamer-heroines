class_name Faction
extends RefCounted

## Faction - 阵营工具类
## 提供统一的阵营枚举与转换工具

enum Type {
	UNKNOWN = 0,
	PLAYER = 1,
	ENEMY = 2,
}

const PLAYER_NAME := "player"
const ENEMY_NAME := "enemy"


## 阵营类型转字符串
## @param faction_type: Faction.Type 枚举值
## @return: "player" 或 "enemy"；未知值安全回退为 "player"
static func type_to_string(faction_type: int) -> String:
	match faction_type:
		Type.ENEMY:
			return ENEMY_NAME
		Type.PLAYER:
			return PLAYER_NAME
		_:
			return PLAYER_NAME


## 字符串转阵营类型
## @param faction_name: 阵营字符串
## @return: Faction.Type 枚举值；未知值安全回退为 PLAYER
static func string_to_type(faction_name: String) -> int:
	var normalized := faction_name.strip_edges().to_lower()
	match normalized:
		ENEMY_NAME:
			return Type.ENEMY
		PLAYER_NAME:
			return Type.PLAYER
		_:
			return Type.PLAYER


## 获取对立阵营类型
## @param faction_type: 当前阵营类型
## @return: 对立阵营；未知值回退为 ENEMY
static func get_target_type(faction_type: int) -> int:
	match faction_type:
		Type.ENEMY:
			return Type.PLAYER
		Type.PLAYER:
			return Type.ENEMY
		_:
			return Type.ENEMY


## 获取投射物碰撞掩码
## Layer 1: Player, Layer 2: Enemies
## @param faction_type: 投射物所属阵营
## @return: 应命中的目标层掩码
static func get_projectile_collision_mask(faction_type: int) -> int:
	match faction_type:
		Type.ENEMY:
			return 1 << 0  # 命中 Player
		Type.PLAYER:
			return 1 << 1  # 命中 Enemies
		_:
			return (1 << 0) | (1 << 1)
