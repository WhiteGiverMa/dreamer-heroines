class_name AmmoCrate
extends SupplyCrate

## AmmoCrate - 玩家专用弹药补给箱
## 只允许玩家拾取，填充当前武器弹药


func _ready() -> void:
	super._ready()
	allowed_teams = [&"player"]


func _on_pickup(body: Node2D) -> void:
	# Check if body is a player (has current_weapon property)
	if not body.is_in_group("player"):
		return

	var weapon = body.current_weapon
	if weapon == null:
		return

	if not weapon.has_method("add_ammo"):
		return

	# Don't pickup if ammo is already full
	if weapon.current_reserve_ammo >= weapon.stats.max_ammo:
		return

	# Fill the ammo to max
	weapon.add_ammo(weapon.stats.max_ammo)

	# Play pickup effect
	EffectManager.play_pickup_effect(global_position, "ammo")

	# Destroy the crate
	queue_free()
