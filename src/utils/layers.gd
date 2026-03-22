@tool
class_name Layers
extends Object

## 碰撞层常量定义
## 详细规范请参考 docs/COLLISION_LAYERS.md

# 物理层位掩码 (1 << (layer_number - 1))
const PLAYER := 1 << 0           ## 第1层: 玩家角色
const ENEMIES := 1 << 1          ## 第2层: 敌人
const WORLD := 1 << 2            ## 第3层: 世界/地形
const PROJECTILES := 1 << 3      ## 第4层: 玩家投射物
const ENEMY_PROJECTILES := 1 << 4 ## 第5层: 敌人投射物
const PICKUPS := 1 << 5          ## 第6层: 可拾取物品
const TRIGGERS := 1 << 6         ## 第7层: 触发区域
const PLATFORMS := 1 << 7        ## 第8层: 平台

# 常用碰撞掩码组合
const MASK_PLAYER := WORLD | ENEMIES | ENEMY_PROJECTILES | PICKUPS | PLATFORMS
const MASK_ENEMY := WORLD | PLAYER | PROJECTILES | PLATFORMS
const MASK_PROJECTILE := WORLD | ENEMIES
const MASK_ENEMY_PROJECTILE := WORLD | PLAYER
const MASK_PICKUP := PLAYER
const MASK_TRIGGER := PLAYER

## 获取指定层的位掩码
## [param layer_number] 层编号 (1-8)
## [return] 对应的位掩码
static func get_layer_bit(layer_number: int) -> int:
	return 1 << (layer_number - 1)

## 从位掩码获取层编号
## [param bit_mask] 位掩码
## [return] 层编号 (1-8)，如果无效返回 -1
static func get_layer_number(bit_mask: int) -> int:
	if bit_mask <= 0:
		return -1
	var layer := 1
	while bit_mask > 1:
		bit_mask >>= 1
		layer += 1
	return layer if layer <= 8 else -1

## 检查掩码是否包含指定层
## [param mask] 要检查的掩码
## [param layer_bit] 层的位掩码
## [return] 是否包含
static func has_layer(mask: int, layer_bit: int) -> bool:
	return (mask & layer_bit) != 0

## 添加层到掩码
## [param mask] 原掩码
## [param layer_bit] 要添加的层位掩码
## [return] 新掩码
static func add_layer(mask: int, layer_bit: int) -> int:
	return mask | layer_bit

## 从掩码移除层
## [param mask] 原掩码
## [param layer_bit] 要移除的层位掩码
## [return] 新掩码
static func remove_layer(mask: int, layer_bit: int) -> int:
	return mask & ~layer_bit
