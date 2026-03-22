class_name MeleeEnemy
extends EnemyBase

# MeleeEnemy - 近战敌人
# 快速接近玩家进行近战攻击

@export_group("Melee Settings")
@export var charge_speed_multiplier: float = 2.0
@export var charge_cooldown: float = 3.0
@export var attack_knockback: float = 400.0

var is_charging: bool = false
var charge_timer: float = 0.0
var can_charge: bool = true

@onready var charge_timer_node: Timer = $ChargeTimer

func _ready() -> void:
	# 从配置加载属性
	_load_enemy_config()
	
	# 调用父类初始化
	super._ready()
	
	# 设置近战敌人特性
	can_shoot = false
	
	# 连接信号
	if charge_timer_node:
		charge_timer_node.wait_time = charge_cooldown
		charge_timer_node.timeout.connect(_on_charge_cooldown_timeout)
	
	print("MeleeEnemy initialized")

func _load_enemy_config() -> void:
	var config = _get_enemy_config()
	
	max_health = config.get("max_health", 60)
	move_speed = config.get("move_speed", 200.0)
	jump_velocity = config.get("jump_velocity", -450.0)
	detection_range = config.get("detection_range", 400.0)
	attack_range = config.get("attack_range", 60.0)
	attack_damage = config.get("attack_damage", 20)
	attack_cooldown = config.get("attack_cooldown", 1.2)
	patrol_distance = config.get("patrol_distance", 150.0)
	patrol_wait_time = config.get("patrol_wait_time", 1.5)

func _get_enemy_config() -> Dictionary:
	var file_path = "res://config/enemy_stats.json"
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data and data.has("melee"):
			return data["melee"]
	
	# 默认配置
	return {
		"max_health": 60,
		"move_speed": 200.0,
		"jump_velocity": -450.0,
		"detection_range": 400.0,
		"attack_range": 60.0,
		"attack_damage": 20,
		"attack_cooldown": 1.2,
		"patrol_distance": 150.0,
		"patrol_wait_time": 1.5
	}

func _state_chase(delta: float) -> void:
	if not player or player.current_health <= 0:
		player = null
		change_state(State.PATROL)
		player_lost.emit()
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	var direction = sign(player.global_position.x - global_position.x)
	
	# 检查是否在攻击范围内
	if distance_to_player <= attack_range and can_attack:
		change_state(State.ATTACK)
		return
	
	# 冲锋逻辑
	if can_charge and distance_to_player > attack_range and distance_to_player < detection_range * 0.5:
		_start_charge(direction)
		return
	
	# 正常追击
	if is_charging:
		velocity.x = direction * move_speed * charge_speed_multiplier
	else:
		velocity.x = direction * move_speed
	
	sprite.flip_h = direction < 0
	
	# 尝试跳跃越过障碍
	if can_jump and wall_check and wall_check.is_colliding() and is_on_floor():
		velocity.y = jump_velocity

func _start_charge(direction: int) -> void:
	is_charging = true
	can_charge = false
	
	# 冲锋特效
	_play_charge_effect()
	AudioManager.play_sfx("enemy_charge")
	
	# 冲锋动画
	if animation_player:
		animation_player.play("charge")
	
	# 冲锋持续一段时间
	await get_tree().create_timer(0.5).timeout
	is_charging = false
	
	# 开始冷却
	if charge_timer_node:
		charge_timer_node.start()

func _state_attack(delta: float) -> void:
	if not player:
		change_state(State.CHASE)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if distance_to_player > attack_range * 1.5:
		change_state(State.CHASE)
		return
	
	if can_attack:
		_perform_melee_attack()
		can_attack = false
		attack_timer.start()

func _perform_melee_attack() -> void:
	# 近战攻击动画
	if animation_player:
		animation_player.play("melee_attack")
	
	AudioManager.play_sfx("enemy_melee")
	
	# 延迟造成伤害（配合动画）
	await get_tree().create_timer(0.2).timeout
	
	if player and global_position.distance_to(player.global_position) <= attack_range:
		# 计算击退方向
		var knockback_dir = (player.global_position - global_position).normalized()
		var knockback = knockback_dir * attack_knockback
		
		player.take_damage(attack_damage, knockback)
		
		# 播放命中特效
		_play_hit_effect()

func _play_charge_effect() -> void:
	# 冲锋视觉特效
	var tween = create_tween()
	sprite.modulate = Color(1, 0.5, 0.5, 1)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _play_hit_effect() -> void:
	# 近战命中特效
	pass

func _on_charge_cooldown_timeout() -> void:
	can_charge = true

func _update_animation() -> void:
	if not animation_player:
		return
	
	match current_state:
		State.IDLE:
			if animation_player.has_animation("idle"):
				animation_player.play("idle")
		State.PATROL, State.CHASE:
			if is_charging:
				if animation_player.has_animation("charge_run"):
					animation_player.play("charge_run")
			else:
				if animation_player.has_animation("run"):
					animation_player.play("run")
		State.ATTACK:
			if not animation_player.is_playing():
				if animation_player.has_animation("idle"):
					animation_player.play("idle")
		State.HURT:
			if animation_player.has_animation("hurt"):
				animation_player.play("hurt")
		State.DEAD:
			if not animation_player.is_playing() or animation_player.current_animation != "death":
				if animation_player.has_animation("death"):
					animation_player.play("death")

func get_enemy_type() -> String:
	return "melee"
