class_name RifleWeapon
extends Weapon

# RifleWeapon - 突击步枪武器组件
# 基于 Weapon 类，使用 WeaponStats 资源配置
# 支持后坐力动画效果

# 持有者引用（用于后坐力动画）
var _owner_pivot: Node2D = null


func _ready() -> void:
	super._ready()


## 设置持有者的武器挂载点（用于后坐力动画）
func set_owner_pivot(pivot: Node2D) -> void:
	_owner_pivot = pivot


## 重写射击方法，添加后坐力动画
func _fire(muzzle_pos: Vector2, aim_dir: Vector2) -> void:
	# 调用父类射击逻辑（处理弹药、冷却、发射信号）
	super._fire(muzzle_pos, aim_dir)

	# 步枪特有的后坐力动画
	_play_recoil_animation()


## 播放后坐力动画
func _play_recoil_animation() -> void:
	if not _owner_pivot:
		return

	var original_rotation := _owner_pivot.rotation

	# 快速向上跳动
	_owner_pivot.rotation -= deg_to_rad(2.0)

	# 缓慢恢复
	var tween := create_tween()
	tween.tween_property(_owner_pivot, "rotation", original_rotation, 0.1)
## 获取武器描述
func get_weapon_description() -> String:
	return stats.get_display_description() if stats else ""


## 获取武器统计信息
func get_weapon_stats() -> Dictionary:
	if not stats:
		return {}

	return {
		"name": stats.weapon_name,
		"damage": stats.damage,
		"fire_rate": stats.fire_rate,
		"dps": stats.damage / stats.fire_rate,
		"magazine": stats.magazine_size,
		"reload": stats.reload_time
	}
