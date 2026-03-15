class_name Player
extends CharacterBody2D

# Player - 玩家控制器
# 实现横板射击游戏的核心玩家逻辑

signal health_changed(current: int, max: int)
signal ammo_changed(current: int, max: int)
signal weapon_changed(weapon_name: String)
signal died

# 移动参数
@export_group("Movement")
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var deceleration: float = 1500.0
@export var air_acceleration: float = 1000.0
@export var air_deceleration: float = 500.0
@export var jump_velocity: float = -600.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1000.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1

# 战斗参数
@export_group("Combat")
@export var max_health: int = 100
@export var invulnerability_time: float = 0.5

# 组件引用
@onready var weapon_pivot: Marker2D = $WeaponPivot
@onready var muzzle: Marker2D = $WeaponPivot/Weapon/Muzzle
@onready var ground_check: Area2D = $GroundCheck
@onready var camera: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer

# 状态变量
var current_health: int = 100
var is_grounded: bool = false
var is_crouching: bool = false
var is_sprinting: bool = false
var is_invulnerable: bool = false
var facing_direction: int = 1

# 跳跃相关
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var has_double_jump: bool = false
var can_double_jump: bool = false

# 武器系统
var current_weapon = null
var weapons: Array = []
var current_weapon_index: int = 0

func _ready():
	add_to_group("player")
	current_health = max_health
	invulnerability_timer.wait_time = invulnerability_time
	
	# 连接信号
	ground_check.body_entered.connect(_on_ground_check_body_entered)
	ground_check.body_exited.connect(_on_ground_check_body_exited)
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	
	print("Player initialized")

func _physics_process(delta: float):
	_handle_input(delta)
	_apply_gravity(delta)
	_handle_jump(delta)
	_handle_movement(delta)
	_handle_aiming()
	_handle_shooting()
	_handle_weapon_switch()
	
	move_and_slide()
	_update_animation()

func _handle_input(delta: float) -> void:
	# 冲刺
	is_sprinting = Input.is_action_pressed("sprint") and is_grounded
	
	# 下蹲
	is_crouching = Input.is_action_pressed("crouch") and is_grounded
	
	# 跳跃缓冲
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta
	
	# 土狼时间
	if is_grounded:
		coyote_timer = coyote_time
		can_double_jump = has_double_jump
	else:
		coyote_timer -= delta

func _apply_gravity(delta: float) -> void:
	if not is_grounded:
		velocity.y += get_gravity().y * gravity_scale * delta
		velocity.y = min(velocity.y, max_fall_speed)

func _handle_jump(delta: float) -> void:
	# 普通跳跃
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		AudioManager.play_sfx("jump")
	# 二段跳
	elif jump_buffer_timer > 0 and can_double_jump:
		velocity.y = jump_velocity * 0.8
		jump_buffer_timer = 0
		can_double_jump = false
		AudioManager.play_sfx("jump")
	
	# 可变跳跃高度
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.5

func _handle_movement(delta: float) -> void:
	var input_direction = InputManager.get_movement_input().x
	
	var target_speed = max_speed
	if is_crouching:
		target_speed *= 0.5
	elif is_sprinting:
		target_speed *= 1.5
	
	var target_velocity = input_direction * target_speed
	
	if is_grounded:
		if abs(input_direction) > 0:
			velocity.x = move_toward(velocity.x, target_velocity, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
	else:
		if abs(input_direction) > 0:
			velocity.x = move_toward(velocity.x, target_velocity, air_acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, air_deceleration * delta)
	
	# 更新朝向
	if input_direction != 0:
		facing_direction = sign(input_direction)

func _handle_aiming() -> void:
	var aim_dir = InputManager.get_aim_direction()
	
	# 更新武器朝向
	if weapon_pivot:
		weapon_pivot.rotation = aim_dir.angle()
		
		# 根据瞄准方向翻转精灵
		if abs(aim_dir.x) > 0.1:
			$Body.flip_h = aim_dir.x < 0
			weapon_pivot.scale.y = -1 if aim_dir.x < 0 else 1

func _handle_shooting() -> void:
	if Input.is_action_pressed("shoot") and current_weapon:
		current_weapon.try_shoot()
	
	if Input.is_action_just_pressed("reload") and current_weapon:
		current_weapon.reload()

func _handle_weapon_switch() -> void:
	if Input.is_action_just_pressed("weapon_switch"):
		switch_weapon()

func switch_weapon() -> void:
	if weapons.size() <= 1:
		return
	
	current_weapon_index = (current_weapon_index + 1) % weapons.size()
	_equip_weapon(current_weapon_index)

func _equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	
	# 卸下当前武器
	if current_weapon:
		current_weapon.unequip()
	
	current_weapon = weapons[index]
	current_weapon.equip(self)
	weapon_changed.emit(current_weapon.weapon_name)

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or current_health <= 0:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	
	# 击退
	velocity += knockback
	
	# 无敌时间
	is_invulnerable = true
	invulnerability_timer.start()
	
	# 受伤特效
	_flash_sprite()
	AudioManager.play_sfx("player_hurt")
	
	if current_health <= 0:
		_die()

func heal(amount: int) -> void:
	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func _die() -> void:
	died.emit()
	GameManager.on_player_death()
	AudioManager.play_sfx("player_death")
	# 播放死亡动画
	animation_player.play("death")

func respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	current_health = max_health
	velocity = Vector2.ZERO
	is_invulnerable = false
	health_changed.emit(current_health, max_health)

func _flash_sprite() -> void:
	var tween = create_tween()
	$Body.modulate = Color(1, 0.3, 0.3, 0.7)
	tween.tween_property($Body, "modulate", Color.WHITE, invulnerability_time)

func _update_animation() -> void:
	if not animation_player:
		return
	
	if current_health <= 0:
		return
	
	if not is_grounded:
		if velocity.y < 0:
			animation_player.play("jump")
		else:
			animation_player.play("fall")
	elif abs(velocity.x) > 10:
		if is_sprinting:
			animation_player.play("sprint")
		else:
			animation_player.play("run")
	elif is_crouching:
		animation_player.play("crouch")
	else:
		animation_player.play("idle")

func _on_ground_check_body_entered(body: Node2D) -> void:
	if body.is_in_group("ground") or body.collision_layer & 8 != 0:
		is_grounded = true

func _on_ground_check_body_exited(body: Node2D) -> void:
	if body.is_in_group("ground") or body.collision_layer & 8 != 0:
		# 检查是否还有其他地面接触
		var bodies = ground_check.get_overlapping_bodies()
		is_grounded = false
		for b in bodies:
			if b.is_in_group("ground") or b.collision_layer & 8 != 0:
				is_grounded = true
				break

func _on_invulnerability_timeout() -> void:
	is_invulnerable = false

func get_muzzle_position() -> Vector2:
	if muzzle:
		return muzzle.global_position
	return global_position

func get_aim_direction() -> Vector2:
	return InputManager.get_aim_direction()
