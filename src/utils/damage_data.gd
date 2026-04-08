class_name DamageData
extends RefCounted


var amount: int = 0
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
var causer: Node = null


func _init(
	new_amount: int = 0,
	new_knockback: Vector2 = Vector2.ZERO,
	new_source: Node = null,
	new_causer: Node = null
) -> void:
	amount = maxi(new_amount, 0)
	knockback = new_knockback
	source = new_source
	causer = new_causer


func duplicate_data():
	return get_script().new(amount, knockback, source, causer)
