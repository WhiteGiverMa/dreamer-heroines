class_name Rifle
extends WeaponBase

# Rifle - 突击步枪
# 标准自动步枪，中等伤害，中等射速，适合中距离作战
# 属性在 Inspector 中编辑，默认值参考 docs/weapon_defaults.md

func _ready() -> void:
	super._ready()
	print("Rifle initialized: %s" % weapon_name)

func _fire() -> void:
	# 调用父类射击逻辑
	super._fire()
	
	# 步枪特有的后坐力动画
	_play_recoil_animation()

func _play_recoil_animation() -> void:
	# 武器后坐力动画
	if owner_player and owner_player.weapon_pivot:
		var pivot = owner_player.weapon_pivot
		var original_rotation = pivot.rotation
		
		# 快速向上跳动
		pivot.rotation -= deg_to_rad(2.0)
		
		# 缓慢恢复
		var tween = create_tween()
		tween.tween_property(pivot, "rotation", original_rotation, 0.1)

func get_weapon_description() -> String:
	return "标准突击步枪，平衡的伤害和射速，适合各种距离作战。"

func get_weapon_stats() -> Dictionary:
	return {
		"name": weapon_name,
		"damage": damage,
		"fire_rate": fire_rate,
		"dps": damage / fire_rate,
		"magazine": magazine_size,
		"reload": reload_time
	}
