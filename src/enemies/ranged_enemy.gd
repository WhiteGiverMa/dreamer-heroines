class_name RangedEnemy
extends EnemyBase

# RangedEnemy - 远程敌人
# 保持距离并向玩家射击

@export_group("Ranged Settings")
@export var preferred_distance: float = 300.0  # 理想攻击距离
@export var retreat_distance: float = 150.0    # 过近时撤退距离
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 600.0
@export var aim_time: float = 0.5

@export_group("Weapon Loadout")
@export var initial_weapons: Array[PackedScene] = []  # 武器配置（Inspector）

var is_aiming: bool = false
var aim_timer: float = 0.0

@onready var muzzle: Marker2D = $Muzzle
@onready var aim_line: Line2D = $AimLine

func _ready() -> void:
	# 从配置加载属性
	_load_enemy_config()
	
	# 调用父类初始化
	super._ready()
	
	# 设置远程敌人特性
	can_shoot = true
	
	# 初始化武器配置
	_initialize_weapon_loadout()
	
	# 隐藏瞄准线
	if aim_line:
		aim_line.visible = false
	
	print("RangedEnemy initialized")


func _initialize_weapon_loadout() -> void:
	"""Initialize weapons from inspector or scene hierarchy."""
	# First, try to load from inspector config
	for weapon_scene in initial_weapons:
		if weapon_scene:
			add_weapon(weapon_scene)

	# Fallback: instantiate default rifle for node-based weapon setup
	if weapons.is_empty():
		var default_weapon_scene: PackedScene = load("res://scenes/weapons/rifle.tscn")
		if default_weapon_scene:
			add_weapon(default_weapon_scene)
		else:
			push_warning("RangedEnemy: Failed to load default weapon scene res://scenes/weapons/rifle.tscn")

	# If no weapons from inspector, check for WeaponPivot/Weapon in scene
	if weapons.is_empty():
		var scene_weapon = get_node_or_null("WeaponPivot/Weapon")
		if scene_weapon:
			# Find weapon child
			for child in scene_weapon.get_children():
				if child.has_signal("shot_fired"):
					equip_weapon(child)
					break

	if not equipped_weapon:
		push_warning("RangedEnemy: No weapon equipped after loadout initialization")

func _load_enemy_config() -> void:
	var config = _get_enemy_config()

	# JSON values are nested in { "value": x } structure
	max_health = _get_config_value(config, "max_health", 40)
	move_speed = _get_config_value(config, "move_speed", 120.0)
	jump_velocity = _get_config_value(config, "jump_velocity", -350.0)
	detection_range = _get_config_value(config, "detection_range", 600.0)
	attack_range = _get_config_value(config, "attack_range", 500.0)
	attack_damage = _get_config_value(config, "attack_damage", 15)
	attack_cooldown = _get_config_value(config, "attack_cooldown", 1.5)
	patrol_distance = _get_config_value(config, "patrol_distance", 200.0)
	patrol_wait_time = config.get("patrol_wait_time", 2.0)  # Not in JSON, use default

	preferred_distance = _get_config_value(config, "preferred_range", 300.0)  # JSON uses "preferred_range"
	retreat_distance = config.get("retreat_distance", 150.0)  # Not in JSON, use default
	projectile_speed = _get_config_value(config, "projectile_speed", 600.0)
	aim_time = config.get("aim_time", 0.5)  # Not in JSON, use default


func _get_config_value(config: Dictionary, key: String, default) -> Variant:
	"""Extract value from nested JSON structure: { "value": x }"""
	if config.has(key):
		var entry = config[key]
		if entry is Dictionary and entry.has("value"):
			return entry["value"]
		return entry
	return default

func _get_enemy_config() -> Dictionary:
	var file_path = "res://config/enemy_stats.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data and data.has("ranged_basic"):
			return data["ranged_basic"]
	
	# 默认配置
	return {
		"max_health": 40,
		"move_speed": 120.0,
		"jump_velocity": -350.0,
		"detection_range": 600.0,
		"attack_range": 500.0,
		"attack_damage": 15,
		"attack_cooldown": 1.5,
		"patrol_distance": 200.0,
		"patrol_wait_time": 2.0,
		"preferred_distance": 300.0,
		"retreat_distance": 150.0,
		"projectile_speed": 600.0,
		"aim_time": 0.5
	}

func _state_chase(delta: float) -> void:
	if not player or player.current_health <= 0:
		player = null
		change_state(State.PATROL)
		player_lost.emit()
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = sign(player.global_position.x - global_position.x)

	# AI weapon switching based on distance
	_select_weapon_for_range(distance_to_player)

	# 检查是否在攻击范围内
	if distance_to_player <= attack_range and can_attack and not is_aiming:
		change_state(State.ATTACK)
		return

	# 距离控制
	if distance_to_player < retreat_distance:
		# 太近了，撤退
		velocity.x = -direction_to_player * move_speed
		sprite.flip_h = direction_to_player > 0
	elif distance_to_player > preferred_distance + 50:
		# 太远了，接近
		velocity.x = direction_to_player * move_speed
		sprite.flip_h = direction_to_player < 0
	else:
		# 理想距离，停止移动
		velocity.x = 0
		sprite.flip_h = direction_to_player < 0
		
		# 尝试攻击
		if can_attack and distance_to_player <= attack_range:
			change_state(State.ATTACK)


func _select_weapon_for_range(distance: float) -> void:
	"""Switch weapon based on distance to player."""
	if weapons.size() <= 1:
		return

	# Find best weapon for current distance
	for i in range(weapons.size()):
		var w = weapons[i]
		# Check if weapon has stats with pellet_count
		if w and w.stats:
			# Shotgun for close range, rifle for far
			if distance < 150.0 and w.stats.pellet_count > 1:
				switch_weapon_to(i)
				return
			elif distance >= 150.0 and w.stats.pellet_count == 1:
				switch_weapon_to(i)
				return

func _state_attack(delta: float) -> void:
	if not player:
		change_state(State.CHASE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# 如果玩家移动太远，取消攻击
	if distance_to_player > attack_range * 1.2:
		change_state(State.CHASE)
		is_aiming = false
		if aim_line:
			aim_line.visible = false
		return
	
	if can_attack and not is_aiming:
		_start_aiming()

func _start_aiming() -> void:
	is_aiming = true
	aim_timer = 0.0
	
	# 显示瞄准线
	if aim_line:
		aim_line.visible = true
		_update_aim_line()
	
	# 瞄准动画
	if animation_player:
		animation_player.play("aim")
	
	# 延迟射击
	await get_tree().create_timer(aim_time).timeout
	
	if is_aiming and current_state == State.ATTACK:
		_fire_projectile()
	
	is_aiming = false
	if aim_line:
		aim_line.visible = false
	
	can_attack = false
	attack_timer.start()

func _update_aim_line() -> void:
	if not aim_line or not player:
		return
	
	# 更新瞄准线
	aim_line.clear_points()
	aim_line.add_point(Vector2.ZERO)
	
	var target_point := _get_player_aim_point()
	var aim_direction = (target_point - global_position).normalized()
	aim_line.add_point(aim_direction * attack_range)

func _fire_projectile() -> void:
	if not player:
		return
	
	# 射击动画
	if animation_player:
		animation_player.play("shoot")
	
	AudioManager.play_sfx("enemy_shoot")
	
	# Use weapon component only
	if equipped_weapon:
		var muzzle_pos = muzzle.global_position if muzzle else global_position
		var target_point := _get_player_aim_point()
		var aim_dir = (target_point - muzzle_pos).normalized()
		try_shoot_weapon(muzzle_pos, aim_dir)
	else:
		push_warning("RangedEnemy: No weapon equipped, cannot fire")


func _get_player_aim_point() -> Vector2:
	if not player:
		return global_position

	if player.has_method("get_aim_point"):
		var aim_point = player.call("get_aim_point")
		if aim_point is Vector2:
			return aim_point

	return player.global_position

func _perform_attack() -> void:
	# 远程敌人使用射击而非近战
	pass

func _update_animation() -> void:
	if not animation_player:
		return
	
	match current_state:
		State.IDLE:
			if animation_player.has_animation("idle"):
				animation_player.play("idle")
		State.PATROL:
			if animation_player.has_animation("run"):
				animation_player.play("run")
		State.CHASE:
			if animation_player.has_animation("run"):
				animation_player.play("run")
		State.ATTACK:
			if is_aiming:
				if animation_player.has_animation("aim"):
					animation_player.play("aim")
			else:
				if animation_player.has_animation("idle"):
					animation_player.play("idle")
		State.HURT:
			if animation_player.has_animation("hurt"):
				animation_player.play("hurt")
		State.DEAD:
			if not animation_player.is_playing() or animation_player.current_animation != "death":
				if animation_player.has_animation("death"):
					animation_player.play("death")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# 更新瞄准线
	if is_aiming and aim_line:
		_update_aim_line()

func get_enemy_type() -> String:
	return "ranged"


# === Weapon Integration ===

# Use parent's _on_weapon_shot_fired from EnemyBase which uses ProjectileSpawner
# No override needed - weapons handle spread internally
