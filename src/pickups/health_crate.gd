class_name HealthCrate
extends SupplyCrate

## HealthCrate - 治疗补给箱
## 可被玩家和敌人拾取，恢复25点生命值

const HEAL_AMOUNT := 25

func _ready() -> void:
	super._ready()
	allowed_teams = []

func _on_pickup(body: Node2D) -> void:
	if not body.has_method("heal"):
		return

	if body.current_health >= body.max_health:
		return

	body.heal(HEAL_AMOUNT)
	EffectManager.play_pickup_effect(global_position, "health")
	queue_free()
