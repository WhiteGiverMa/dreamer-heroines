class_name ShotgunWeapon
extends Weapon

# ShotgunWeapon - 霰弹枪武器组件
# 基于 Weapon 类，使用 WeaponStats 资源配置
# 支持多弹丸发射（pellet_count 和 pellet_spread）

# 持有者引用（用于后坐力）
var _owner_node: Node2D = null


func _ready() -> void:
	super._ready()


## 设置持有者（用于后坐力效果）
func _set_weapon_owner(node: Node2D) -> void:
	_owner_node = node


## 重写射击方法，实现多弹丸发射
func _fire(muzzle_pos: Vector2, aim_dir: Vector2) -> void:
	if not stats:
		return

	# 消耗弹药（一次扣弹，不是每颗弹丸都扣）
	if stats.use_ammo_system:
		current_ammo_in_mag -= 1
		ammo_changed.emit(current_ammo_in_mag, stats.magazine_size)

	# 设置冷却
	can_shoot = false
	_fire_cooldown_timer = stats.fire_rate

	# 获取弹丸数量（从 WeaponStats 读取）
	var pellet_count := stats.pellet_count if stats.pellet_count > 0 else 1

	# 发射多发弹丸，每颗发射独立信号
	for i in range(pellet_count):
		# 计算弹丸方向（扇形散布）
		var spread_angle := randf_range(-stats.pellet_spread, stats.pellet_spread)
		var pellet_dir := aim_dir.rotated(deg_to_rad(spread_angle))

		# 发射信号 - 让外部决定如何处理投射物
		shot_fired.emit(muzzle_pos, pellet_dir, faction_type)

	# 视觉特效（只播放一次，不是每颗弹丸都播放）
	_spawn_muzzle_flash(muzzle_pos, aim_dir)
	_spawn_shell_casing()

	# 音效
	AudioManager.play_sfx(stats.weapon_name + "_shoot")

	# 应用后坐力
	_apply_recoil()


## 应用后坐力效果
func _apply_recoil() -> void:
	if not _owner_node:
		return

	# 检查是否有 velocity 属性（玩家角色）
	if "velocity" in _owner_node:
		# 水平后坐力
		_owner_node.velocity.x -= cos(rotation) * stats.recoil_amount * 0.2
		# 垂直后坐力（略微向上）
		_owner_node.velocity.y -= sin(rotation) * stats.recoil_amount * 0.1


## 获取武器描述
func get_weapon_description() -> String:
	return stats.get_display_description() if stats else ""


## 获取武器统计信息
func get_weapon_stats() -> Dictionary:
	if not stats:
		return {}

	return {
		"name": stats.weapon_name,
		"damage_per_pellet": stats.damage,
		"pellet_count": stats.pellet_count,
		"total_damage": stats.damage * stats.pellet_count,
		"fire_rate": stats.fire_rate,
		"magazine": stats.magazine_size,
		"reload": stats.reload_time
	}


## 获取单次射击总伤害
func get_total_damage_per_shot() -> float:
	if not stats:
		return 0.0
	return stats.damage * stats.pellet_count
