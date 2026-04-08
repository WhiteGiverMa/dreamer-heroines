class_name DamageSystem
extends RefCounted

const DamageDataClass = preload("res://src/utils/damage_data.gd")


func apply_damage(target: Object, damage_data) -> bool:
	if target == null or damage_data == null or damage_data.amount <= 0:
		return false

	var receiver := _resolve_receiver(target)
	if receiver == null:
		return false

	if receiver.has_method("apply_damage"):
		receiver.apply_damage(damage_data)
		return true

	if receiver.has_method("take_damage"):
		receiver.take_damage(damage_data.amount, damage_data.knockback)
		return true

	return false


func _resolve_receiver(target: Object) -> Object:
	if target is Hurtbox:
		return target

	if target is Node:
		var target_node := target as Node
		var nested_hurtbox := _find_hurtbox(target_node)
		if nested_hurtbox != null:
			return nested_hurtbox

		var health_component: Variant = target_node.get("health_component")
		if health_component != null and health_component.has_method("apply_damage"):
			return health_component

	if target.has_method("apply_damage") or target.has_method("take_damage"):
		return target

	return null


func _find_hurtbox(node: Node) -> Hurtbox:
	for child in node.get_children():
		if child is Hurtbox:
			return child as Hurtbox

	for child in node.get_children():
		var nested := _find_hurtbox(child)
		if nested != null:
			return nested

	return null
