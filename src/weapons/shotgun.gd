class_name Shotgun
extends WeaponBase

# Shotgun - 霰弹枪
# 近距离高伤害武器，发射多发弹丸

@export_group("Shotgun Settings")
@export var pellet_count: int = 8  # 弹丸数量
@export var pellet_spread: float = 15.0  # 弹丸散布角度

func _ready() -> void:
	# 从配置加载武器属性
	_load_weapon_config()
	
	# 调用父类初始化
	super._ready()
	
	print("Shotgun initialized: %s" % weapon_name)

func _load_weapon_config() -> void:
	# 加载武器配置
	var config = _get_weapon_config()
	
	weapon_name = config.get("name", "Combat Shotgun")
	damage = config.get("damage", 15)  # 每发弹丸伤害
	fire_rate = config.get("fire_rate", 0.8)
	reload_time = config.get("reload_time", 2.5)
	magazine_size = config.get("magazine_size", 8)
	max_ammo = config.get("max_ammo", 64)
	projectile_speed = config.get("projectile_speed", 900.0)
	spread = config.get("spread", 0.0)  # 基础散布为0，使用弹丸散布
	is_automatic = config.get("is_automatic", false)
	recoil_amount = config.get("recoil_amount", 15.0)
	screen_shake_amount = config.get("screen_shake_amount", 0.5)
	
	pellet_count = config.get("pellet_count", 8)
	pellet_spread = config.get("pellet_spread", 15.0)

func _get_weapon_config() -> Dictionary:
	# 从JSON配置文件加载
	var file_path = "res://config/weapon_stats.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data and data.has("shotgun"):
			return data["shotgun"]
	
	# 默认配置
	return {
		"name": "Combat Shotgun",
		"damage": 15,
		"fire_rate": 0.8,
		"reload_time": 2.5,
		"magazine_size": 8,
		"max_ammo": 64,
		"projectile_speed": 900.0,
		"spread": 0.0,
		"is_automatic": false,
		"recoil_amount": 15.0,
		"screen_shake_amount": 0.5,
		"pellet_count": 8,
		"pellet_spread": 15.0
	}

func _fire() -> void:
	# 消耗弹药
	current_ammo_in_mag -= 1
	ammo_changed.emit(current_ammo_in_mag, magazine_size)
	
	# 设置冷却
	can_shoot = false
	fire_cooldown_timer = fire_rate
	
	# 发射多发弹丸
	_spawn_pellets()
	
	# 视觉特效
	_spawn_muzzle_flash()
	_spawn_shell_casing()
	_apply_recoil()
	
	# 音效
	AudioManager.play_sfx("shotgun_shoot")
	
	# 屏幕震动
	if owner_player and owner_player.camera:
		owner_player.camera.apply_shake(screen_shake_amount)
	
	shot_fired.emit()

func _spawn_pellets() -> void:
	if not owner_player:
		return
	
	var muzzle_pos = owner_player.get_muzzle_position()
	var base_aim_dir = owner_player.get_aim_direction()
	
	# 发射多个弹丸
	for i in range(pellet_count):
		var projectile_scene = load("res://src/weapons/projectile.tscn")
		if not projectile_scene:
			continue
		
		var projectile = projectile_scene.instantiate()
		
		# 计算弹丸方向（扇形散布）
		var angle_offset = randf_range(-pellet_spread, pellet_spread)
		var pellet_direction = base_aim_dir.rotated(deg_to_rad(angle_offset))
		
		projectile.global_position = muzzle_pos
		projectile.direction = pellet_direction
		projectile.speed = projectile_speed * randf_range(0.9, 1.1)  # 速度略有随机
		projectile.damage = damage
		projectile.owner_player = owner_player
		
		get_tree().current_scene.add_child(projectile)

func _apply_recoil() -> void:
	# 霰弹枪有更强的后坐力
	if owner_player:
		# 水平后坐力
		owner_player.velocity.x -= cos(rotation) * recoil_amount * 0.2
		# 垂直后坐力（略微向上）
		owner_player.velocity.y -= sin(rotation) * recoil_amount * 0.1

func get_weapon_description() -> String:
	return "近距离作战利器，发射多发弹丸造成范围伤害。"

func get_weapon_stats() -> Dictionary:
	return {
		"name": weapon_name,
		"damage_per_pellet": damage,
		"pellet_count": pellet_count,
		"total_damage": damage * pellet_count,
		"fire_rate": fire_rate,
		"magazine": magazine_size,
		"reload": reload_time
	}

func get_total_damage_per_shot() -> int:
	return damage * pellet_count
