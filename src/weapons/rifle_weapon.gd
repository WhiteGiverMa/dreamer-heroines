class_name RifleWeapon
extends Weapon

# RifleWeapon - 突击步枪武器组件
# 基于 Weapon 类，使用 WeaponStats 资源配置
# 支持后坐力动画效果

# 后坐力视觉目标（只做局部视觉抖动，不参与主瞄准旋转）
var _recoil_target: Node2D = null
var _recoil_tween: Tween = null
var _recoil_rest_rotation: float = 0.0


func _ready() -> void:
	super._ready()


## 设置后坐力视觉目标（由持有者提供，不应与主瞄准旋转控制同节点）
func set_owner_pivot(pivot: Node2D) -> void:
	_recoil_target = pivot
	if _recoil_target:
		_recoil_rest_rotation = _recoil_target.rotation


## 重写射击方法，添加后坐力动画
func _fire(muzzle_pos: Vector2, aim_dir: Vector2, fired_at_usec: int = -1) -> void:
	# 调用父类射击逻辑（处理弹药、冷却、发射信号）
	super._fire(muzzle_pos, aim_dir, fired_at_usec)

	# 步枪特有的后坐力动画
	_play_recoil_animation()


## 播放后坐力动画
func _play_recoil_animation() -> void:
	if not _recoil_target:
		return

	if _recoil_tween != null:
		_recoil_tween.kill()
		_recoil_tween = null
		_recoil_target.rotation = _recoil_rest_rotation
	else:
		_recoil_rest_rotation = _recoil_target.rotation

	# 快速向上跳动
	_recoil_target.rotation = _recoil_rest_rotation - deg_to_rad(2.0)

	# 缓慢恢复
	_recoil_tween = create_tween()
	_recoil_tween.tween_property(_recoil_target, "rotation", _recoil_rest_rotation, 0.1)
	_recoil_tween.finished.connect(_clear_recoil_tween, CONNECT_ONE_SHOT)


func _clear_recoil_tween() -> void:
	_recoil_tween = null
	if _recoil_target:
		_recoil_target.rotation = _recoil_rest_rotation


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
