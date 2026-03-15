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
	
	# 隐藏瞄准线
	if aim_line:
		aim_line.visible = false
	
	print("RangedEnemy initialized")

func _load_enemy_config() -> void:
	var config = _get_enemy_config()
	
	max_health = config.get("max_health", 40)
	move_speed = config.get("move_speed", 120.0)
	jump_velocity = config.get("jump_velocity", -350.0)
	detection_range = config.get("detection_range", 600.0)
	attack_range = config.get("attack_range", 500.0)
	attack_damage = config.get("attack_damage", 15)
	attack_cooldown = config.get("attack_cooldown", 1.5)
	patrol_distance = config.get("patrol_distance", 200.0)
	patrol_wait_time = config.get("patrol_wait_time", 2.0)
	
	preferred_distance = config.get("preferred_distance", 300.0)
	retreat_distance = config.get("retreat_distance", 150.0)
	projectile_speed = config.get("projectile_speed", 600.0)
	aim_time = config.get("aim_time", 0.5)

func _get_enemy_config() -> Dictionary:
	var file_path = "res://config/enemy_stats.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data and data.has("ranged"):
			return data["ranged"]
	
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
	
	var aim_direction = (player.global_position - global_position).normalized()
	aim_line.add_point(aim_direction * attack_range)

func _fire_projectile() -> void:
	if not player:
		return
	
	# 射击动画
	if animation_player:
		animation_player.play("shoot")
	
	AudioManager.play_sfx("enemy_shoot")
	
	# 创建投射物
	var projectile = _create_projectile()
	if projectile:
		get_tree().current_scene.add_child(projectile)

func _create_projectile() -> Node:
	var scene = projectile_scene
	if not scene:
		scene = load("res://src/weapons/projectile.tscn")
	
	if not scene:
		return null
	
	var projectile = scene.instantiate()
	
	var muzzle_pos = muzzle.global_position if muzzle else global_position
	var aim_direction = (player.global_position - muzzle_pos).normalized()
	
	# 添加一点随机散布
	var spread_angle = randf_range(-5.0, 5.0)
	aim_direction = aim_direction.rotated(deg_to_rad(spread_angle))
	
	projectile.global_position = muzzle_pos
	projectile.direction = aim_direction
	projectile.speed = projectile_speed
	projectile.damage = attack_damage
	
	return projectile

func _perform_attack() -> void:
	# 远程敌人使用射击而非近战
	pass

func _update_animation() -> void:
	if not animation_player:
		return
	
	match current_state:
		State.IDLE:
			animation_player.play("idle")
		State.PATROL:
			animation_player.play("run")
		State.CHASE:
			animation_player.play("run")
		State.ATTACK:
			if is_aiming:
				animation_player.play("aim")
			else:
				animation_player.play("idle")
		State.HURT:
			animation_player.play("hurt")
		State.DEAD:
			if not animation_player.is_playing() or animation_player.current_animation != "death":
				animation_player.play("death")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# 更新瞄准线
	if is_aiming and aim_line:
		_update_aim_line()

func get_enemy_type() -> String:
	return "ranged"
