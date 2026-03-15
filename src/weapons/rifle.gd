class_name Rifle
extends WeaponBase

# Rifle - 突击步枪
# 标准自动步枪，中等伤害，中等射速，适合中距离作战

func _ready() -> void:
	# 从配置加载武器属性
	_load_weapon_config()
	
	# 调用父类初始化
	super._ready()
	
	print("Rifle initialized: %s" % weapon_name)

func _load_weapon_config() -> void:
	# 加载武器配置
	var config = _get_weapon_config()
	
	weapon_name = config.get("name", "Assault Rifle")
	damage = config.get("damage", 25)
	fire_rate = config.get("fire_rate", 0.12)
	reload_time = config.get("reload_time", 2.0)
	magazine_size = config.get("magazine_size", 30)
	max_ammo = config.get("max_ammo", 300)
	projectile_speed = config.get("projectile_speed", 1200.0)
	spread = config.get("spread", 2.0)
	is_automatic = config.get("is_automatic", true)
	recoil_amount = config.get("recoil_amount", 3.0)
	screen_shake_amount = config.get("screen_shake_amount", 0.2)

func _get_weapon_config() -> Dictionary:
	# 从JSON配置文件加载
	var file_path = "res://config/weapon_stats.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data and data.has("rifle"):
			return data["rifle"]
	
	# 默认配置
	return {
		"name": "Assault Rifle",
		"damage": 25,
		"fire_rate": 0.12,
		"reload_time": 2.0,
		"magazine_size": 30,
		"max_ammo": 300,
		"projectile_speed": 1200.0,
		"spread": 2.0,
		"is_automatic": true,
		"recoil_amount": 3.0,
		"screen_shake_amount": 0.2
	}

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

func _spawn_projectile() -> void:
	# 步枪使用标准单发射击
	super._spawn_projectile()

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
