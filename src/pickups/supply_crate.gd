class_name SupplyCrate
extends Area2D

## SupplyCrate - 可拾取补给箱基类
## 支持阵营过滤，子类实现具体拾取逻辑

@export var allowed_teams: Array[StringName] = []

var _is_empty: bool = false

func _ready() -> void:
	collision_layer = Layers.PICKUPS
	collision_mask = Layers.MASK_PICKUP
	body_entered.connect(_on_body_entered)

func can_be_picked_up_by(entity: Node2D) -> bool:
	if _is_empty:
		return false

	if allowed_teams.is_empty():
		return true

	var entity_group := _get_entity_group(entity)
	if entity_group.is_empty():
		return false

	return entity_group in allowed_teams

func _get_entity_group(entity: Node2D) -> StringName:
	if entity.is_in_group("player"):
		return &"player"
	elif entity.is_in_group("enemy"):
		return &"enemy"
	return &""

func _on_body_entered(body: Node2D) -> void:
	if not can_be_picked_up_by(body):
		return

	_on_pickup(body)

func _on_pickup(body: Node2D) -> void:
	## 子类覆盖此方法实现具体拾取逻辑
	pass

func set_empty() -> void:
	_is_empty = true
