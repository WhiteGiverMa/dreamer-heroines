class_name FlyingEnemy
extends EnemyBase

# FlyingEnemy - 飞行敌人
# 在空中飞行，可以越过障碍

@export_group("Flying Settings")
@export var enemy_config_key: String = "flying_basic"
@export var fly_speed: float = 180.0
@export var hover_amplitude: float = 20.0
@export var hover_frequency: float = 2.0
@export var dive_speed: float = 400.0
@export var dive_range: float = 200.0

var base_y_position: float = 0.0
var hover_time: float = 0.0
var is_diving: bool = false
var dive_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	# 从配置加载属性
	_load_enemy_config()

	# 调用父类初始化
	super._ready()

	# 设置飞行敌人特性
	can_jump = false
	gravity_scale = 0.0  # 飞行敌人不受重力影响

	# 记录基础高度
	base_y_position = global_position.y

	print("FlyingEnemy initialized")


func _load_enemy_config() -> void:
	var config = _get_enemy_config()

	max_health = _get_config_value(config, "max_health", 35)
	move_speed = _get_config_value(config, "move_speed", 180.0)
	detection_range = _get_config_value(config, "detection_range", 500.0)
	attack_range = _get_config_value(config, "attack_range", 80.0)
	attack_damage = _get_config_value(config, "attack_damage", 15)
	attack_cooldown = _get_config_value(config, "attack_cooldown", 1.0)

	fly_speed = _get_config_value(config, "fly_speed", 180.0)
	hover_amplitude = _get_config_value(config, "hover_amplitude", 20.0)
	hover_frequency = _get_config_value(config, "hover_frequency", 2.0)
	dive_speed = _get_config_value(config, "dive_speed", 400.0)
	dive_range = _get_config_value(config, "dive_range", 200.0)


func _get_config_value(config: Dictionary, key: String, default) -> Variant:
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
		if data and data.has(enemy_config_key):
			return data[enemy_config_key]

	# 默认配置
	return {
		"max_health": {"value": 35},
		"move_speed": {"value": 180.0},
		"detection_range": {"value": 500.0},
		"attack_range": {"value": 80.0},
		"attack_damage": {"value": 15},
		"attack_cooldown": {"value": 1.0},
		"fly_speed": {"value": 180.0},
		"hover_amplitude": {"value": 20.0},
		"hover_frequency": {"value": 2.0},
		"dive_speed": {"value": 400.0},
		"dive_range": {"value": 200.0}
	}


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	hover_time += delta

	if is_diving:
		_handle_dive(delta)
	else:
		_handle_hover(delta)

	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.PATROL:
			_state_patrol(delta)
		State.CHASE:
			_state_chase(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)

	move_and_slide()
	_update_animation()


func _handle_hover(_delta: float) -> void:
	# 悬停效果
	var hover_offset = sin(hover_time * hover_frequency) * hover_amplitude
	velocity.y = (base_y_position + hover_offset - global_position.y) * 5.0


func _handle_dive(_delta: float) -> void:
	# 俯冲攻击
	var dive_direction = (dive_target - global_position).normalized()
	velocity = dive_direction * dive_speed

	# 检查是否到达目标附近
	if global_position.distance_to(dive_target) < 30.0:
		_end_dive()


func _end_dive() -> void:
	is_diving = false

	# 对玩家造成伤害
	if player and global_position.distance_to(player.global_position) < attack_range:
		var knockback = Vector2(0, -300)  # 向上击退
		var damage_data := DamageDataClass.new(attack_damage, knockback, self, self)
		_damage_system.call("apply_damage", player, damage_data)

	# 返回空中
	base_y_position = global_position.y - 100.0
	can_attack = false
	attack_timer.start()


func _state_patrol(_delta: float) -> void:
	# 检查是否发现玩家
	if player:
		change_state(State.CHASE)
		return

	# 巡逻移动
	velocity.x = patrol_direction * fly_speed * 0.5

	# 检查是否需要转向
	var patrol_distance_traveled = abs(global_position.x - patrol_start_position.x)
	if patrol_distance_traveled >= patrol_distance:
		patrol_direction *= -1
		sprite.flip_h = patrol_direction < 0


func _state_chase(delta: float) -> void:
	if not player or player.current_health <= 0:
		player = null
		change_state(State.PATROL)
		player_lost.emit()
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = sign(player.global_position.x - global_position.x)

	# 更新基础高度以跟随玩家
	base_y_position = lerp(base_y_position, player.global_position.y - 100.0, delta * 2.0)

	# 检查是否在俯冲范围内
	if distance_to_player <= dive_range and can_attack and not is_diving:
		_start_dive()
		return

	# 朝玩家水平移动
	velocity.x = direction_to_player * fly_speed
	sprite.flip_h = direction_to_player < 0


func _start_dive() -> void:
	is_diving = true
	dive_target = player.global_position

	# 俯冲特效
	AudioManager.play_sfx("enemy_dive")

	# 俯冲动画
	if animation_player:
		animation_player.play("dive")


func _state_attack(_delta: float) -> void:
	# 飞行敌人使用俯冲攻击，在_chase中处理
	change_state(State.CHASE)


func _apply_gravity(_delta: float) -> void:
	# 飞行敌人不受重力影响
	pass


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	# 飞行敌人受到击退时暂时失去控制
	super.take_damage(amount, knockback)

	if current_state != State.DEAD:
		# 被击中时停止俯冲
		if is_diving:
			is_diving = false
			base_y_position = global_position.y

		# 应用击退
		velocity += knockback * 0.5


func _die() -> void:
	# 飞行敌人死亡时开始下落
	gravity_scale = 1.0
	super._die()


func _update_animation() -> void:
	if not animation_player:
		return

	match current_state:
		State.IDLE, State.PATROL:
			if is_diving:
				animation_player.play("dive")
			else:
				animation_player.play("fly")
		State.CHASE:
			if is_diving:
				animation_player.play("dive")
			else:
				animation_player.play("fly_fast")
		State.HURT:
			animation_player.play("hurt")
		State.DEAD:
			if not animation_player.is_playing() or animation_player.current_animation != "death":
				animation_player.play("death")


func get_enemy_type() -> String:
	return "flying"
