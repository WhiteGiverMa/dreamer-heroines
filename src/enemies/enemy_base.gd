class_name EnemyBase
extends CharacterBody2D

const DamageDataClass = preload("res://src/utils/damage_data.gd")
const DamageSystemClass = preload("res://src/utils/damage_system.gd")

var _damage_system: Variant = DamageSystemClass.new()

# EnemyBase - 敌人基类
# 所有敌人的父类，实现基础AI和战斗逻辑

signal health_changed(current: int, max: int)
signal died
signal player_detected
signal player_lost

@export_group("Stats")
@export var max_health: int = 50
@export var move_speed: float = 150.0
@export var jump_velocity: float = -400.0
@export var detection_range: float = 500.0
@export var attack_range: float = 300.0
@export var attack_damage: int = 10
@export var attack_cooldown: float = 1.0
@export var gravity_scale: float = 1.0

@export_group("AI")
@export var patrol_distance: float = 200.0
@export var patrol_wait_time: float = 2.0
@export var attack_move_speed_multiplier: float = 0.85
@export var can_jump: bool = true
@export var can_shoot: bool = false

@export_group("Weapon")
@export var weapon_uses_ammo_system: bool = false

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

var current_health: int = 0
var current_state: State = State.IDLE
var player: Node2D = null
var patrol_start_position: Vector2 = Vector2.ZERO
var patrol_direction: int = 1
var can_attack: bool = true

# Weapon support (use untyped to avoid circular dependency)
var equipped_weapon = null
var weapons: Array = []
var current_weapon_index: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var ground_check: RayCast2D = get_node_or_null("GroundCheck") as RayCast2D
@onready var wall_check: RayCast2D = get_node_or_null("WallCheck") as RayCast2D
@onready var health_component = get_node_or_null("HealthComponent")
@onready var hurtbox = get_node_or_null("Hurtbox")
@onready var hitbox = get_node_or_null("Hitbox")


func _get_enemy_manager() -> Node:
	return get_node_or_null("/root/EnemyManager")

func _ready():
	add_to_group("enemy")
	_setup_damage_pipeline()
	patrol_start_position = global_position

	# 注册到全局敌人管理器
	var enemy_manager := _get_enemy_manager()
	if enemy_manager:
		enemy_manager.register_enemy(self)

	# 连接信号
	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)

	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.timeout.connect(_on_attack_cooldown_timeout)

	_sync_detection_range_shape()

	change_state(State.PATROL)


func _setup_damage_pipeline() -> void:
	if health_component:
		health_component.max_health = max_health
		health_component.invulnerability_duration = 0.0
		health_component.set_health(max_health)
		if not health_component.health_changed.is_connected(_on_health_component_changed):
			health_component.health_changed.connect(_on_health_component_changed)
		if not health_component.health_depleted.is_connected(_on_health_component_depleted):
			health_component.health_depleted.connect(_on_health_component_depleted)
		current_health = health_component.current_health
	else:
		current_health = max_health

	if hurtbox:
		hurtbox.health_component = health_component
		hurtbox.invulnerability_duration = 0.1
		if not hurtbox.damage_taken.is_connected(_on_hurtbox_damage_taken):
			hurtbox.damage_taken.connect(_on_hurtbox_damage_taken)

	if hitbox:
		hitbox.damage = attack_damage


func _on_health_component_changed(current: int, max_value: int, _change_amount: int) -> void:
	current_health = current
	max_health = max_value
	health_changed.emit(current_health, max_health)


func _on_health_component_depleted() -> void:
	if current_state != State.DEAD:
		change_state(State.DEAD)


func _on_hurtbox_damage_taken(_amount: int, knockback: Vector2, _source: Node) -> void:
	if current_state == State.DEAD:
		return

	velocity += knockback
	_flash_sprite()
	AudioManager.play_sfx("enemy_hurt")

	if health_component and health_component.current_health > 0:
		change_state(State.HURT)
		await get_tree().create_timer(0.2).timeout
		if current_state == State.HURT:
			change_state(State.CHASE)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	_apply_gravity(delta)

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

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += get_gravity().y * gravity_scale * delta

func change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	_exit_state(current_state)
	current_state = new_state
	_enter_state(new_state)

func _enter_state(state: State) -> void:
	match state:
		State.IDLE:
			velocity.x = 0
		State.PATROL:
			pass
		State.CHASE:
			player_detected.emit()
		State.ATTACK:
			pass
		State.HURT:
			velocity.x = 0
		State.DEAD:
			velocity = Vector2.ZERO
			died.emit()
			_die()

func _exit_state(_state: State) -> void:
	pass

func _state_idle(_delta: float) -> void:
	# 检查是否可以开始巡逻
	await get_tree().create_timer(patrol_wait_time).timeout
	if current_state == State.IDLE:
		change_state(State.PATROL)

func _state_patrol(_delta: float) -> void:
	# 检查是否发现玩家
	if player:
		change_state(State.CHASE)
		return

	# 巡逻移动
	velocity.x = patrol_direction * move_speed * 0.5

	# 检查是否需要转向
	var patrol_distance_traveled = abs(global_position.x - patrol_start_position.x)
	if patrol_distance_traveled >= patrol_distance or _should_turn():
		patrol_direction *= -1
		sprite.flip_h = patrol_direction < 0
		change_state(State.IDLE)

func _state_chase(_delta: float) -> void:
	if not _has_valid_player_target():
		_clear_player_target()
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	# 检查是否在攻击范围内
	if distance_to_player <= attack_range and can_attack:
		change_state(State.ATTACK)
		return

	_move_towards_player()

func _state_attack(_delta: float) -> void:
	if not player:
		change_state(State.CHASE)
		return

	var distance_to_player = global_position.distance_to(player.global_position)

	if distance_to_player > attack_range:
		change_state(State.CHASE)
		return

	if not can_shoot:
		_move_towards_player(attack_move_speed_multiplier)
	else:
		_face_player()

	if can_attack:
		_perform_attack()
		can_attack = false
		attack_timer.start()

func _state_hurt(_delta: float) -> void:
	# 受伤硬直
	pass

func _perform_attack() -> void:
	if can_shoot:
		_shoot()
	else:
		_melee_attack()

func _shoot() -> void:
	# 射击逻辑 - 子类实现
	animation_player.play("shoot")
	AudioManager.play_sfx("enemy_shoot")

func _melee_attack() -> void:
	animation_player.play("attack")
	AudioManager.play_sfx("enemy_melee")

	# 延迟造成伤害（配合动画）
	await get_tree().create_timer(0.3).timeout

	if player and global_position.distance_to(player.global_position) <= attack_range:
		var knockback = (player.global_position - global_position).normalized() * 200
		var damage_data := DamageDataClass.new(attack_damage, knockback, self, self)
		_damage_system.call("apply_damage", player, damage_data)


func apply_damage(damage_data: DamageDataClass) -> void:
	if damage_data == null:
		return

	if hurtbox and hurtbox.has_method("apply_damage"):
		hurtbox.apply_damage(damage_data)
		return

	var amount := damage_data.amount
	var knockback := damage_data.knockback
	if current_state == State.DEAD:
		return

	current_health -= amount
	health_changed.emit(current_health, max_health)

	# 击退
	velocity += knockback

	# 受伤特效
	_flash_sprite()
	AudioManager.play_sfx("enemy_hurt")

	if current_health <= 0:
		change_state(State.DEAD)
	else:
		change_state(State.HURT)
		await get_tree().create_timer(0.2).timeout
		if current_state == State.HURT:
			change_state(State.CHASE)


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	apply_damage(DamageDataClass.new(amount, knockback, null, null))

func heal(amount: int) -> void:
	if health_component and health_component.has_method("heal"):
		health_component.heal(amount)
		return

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)

func _die() -> void:
	AudioManager.play_sfx("enemy_death")
	animation_player.play("death")

	# 掉落物品
	_drop_loot()

	# 给予分数
	GameManager.add_score(100)

	# 注销敌人管理（击杀统计由 died 信号驱动，这里只做即时移除）
	var enemy_manager := _get_enemy_manager()
	if enemy_manager:
		enemy_manager.unregister_enemy(self)

	await animation_player.animation_finished
	queue_free()


## Public method for external calls (e.g., developer commands)
func die() -> void:
	"""Public method for external calls (e.g., developer commands)."""
	if current_state == State.DEAD:
		return
	change_state(State.DEAD)

func _drop_loot() -> void:
	# 掉落逻辑 - 子类实现
	pass

func _should_turn() -> bool:
	if ground_check and not ground_check.is_colliding():
		return true
	if wall_check and wall_check.is_colliding():
		return true
	return false


func _has_valid_player_target() -> bool:
	return player != null and is_instance_valid(player) and player.current_health > 0


func _clear_player_target() -> void:
	player = null
	change_state(State.PATROL)
	player_lost.emit()


func _get_horizontal_direction_to_player() -> float:
	if not player:
		return 0.0
	var delta_x := player.global_position.x - global_position.x
	if is_zero_approx(delta_x):
		return 0.0
	return sign(delta_x)


func _face_player() -> void:
	var direction := _get_horizontal_direction_to_player()
	if direction != 0.0:
		sprite.flip_h = direction < 0


func _move_towards_player(speed_multiplier: float = 1.0) -> void:
	var direction := _get_horizontal_direction_to_player()
	velocity.x = direction * move_speed * speed_multiplier
	_face_player()
	_try_jump_over_obstacle()


func _move_away_from_player(speed_multiplier: float = 1.0) -> void:
	var direction := _get_horizontal_direction_to_player()
	velocity.x = -direction * move_speed * speed_multiplier
	if direction != 0.0:
		sprite.flip_h = direction > 0
	_try_jump_over_obstacle()


func _try_jump_over_obstacle() -> void:
	if can_jump and wall_check and wall_check.is_colliding() and is_on_floor():
		velocity.y = jump_velocity


func _sync_detection_range_shape() -> void:
	if not detection_area:
		return
	var detection_shape := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not detection_shape:
		return
	var circle_shape := detection_shape.shape as CircleShape2D
	if circle_shape:
		circle_shape.radius = detection_range

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body

func _on_detection_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = null

func _on_attack_cooldown_timeout() -> void:
	can_attack = true

func _flash_sprite() -> void:
	var tween = create_tween()
	sprite.modulate = Color(1, 0.3, 0.3, 0.7)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _update_animation() -> void:
	if not animation_player:
		return

	match current_state:
		State.IDLE:
			animation_player.play("idle")
		State.PATROL, State.CHASE:
			animation_player.play("run")
		State.ATTACK:
			if not animation_player.is_playing():
				animation_player.play("idle")
		State.HURT:
			animation_player.play("hurt")
		State.DEAD:
			if not animation_player.is_playing() or animation_player.current_animation != "death":
				animation_player.play("death")


# === Weapon Support Methods ===

func add_weapon(weapon_scene: PackedScene) -> void:
	"""Add a weapon to the enemy's weapon array and equip it if first."""
	var weapon = weapon_scene.instantiate()
	weapons.append(weapon)

	# Add to WeaponPivot if exists
	var pivot = get_node_or_null("WeaponPivot")
	if pivot:
		var weapon_container = pivot.get_node_or_null("Weapon")
		if weapon_container:
			weapon_container.add_child(weapon)
		else:
			pivot.add_child(weapon)
	else:
		add_child(weapon)

	# Equip if first weapon
	if weapons.size() == 1:
		_equip_weapon_at_index(0)


func switch_weapon_to(index: int) -> void:
	"""Switch to weapon at specified index."""
	if index < 0 or index >= weapons.size():
		return
	_equip_weapon_at_index(index)


func _equip_weapon_at_index(index: int) -> void:
	"""Internal method to equip weapon at index."""
	if index < 0 or index >= weapons.size():
		return

	# Disconnect previous weapon
	if equipped_weapon and equipped_weapon.has_signal("shot_fired"):
		if equipped_weapon.shot_fired.is_connected(_on_weapon_shot_fired):
			equipped_weapon.shot_fired.disconnect(_on_weapon_shot_fired)
		equipped_weapon.visible = false

	current_weapon_index = index
	equipped_weapon = weapons[index]

	# Setup new weapon
	equipped_weapon.visible = true
	equipped_weapon.faction = Faction.ENEMY_NAME
	if equipped_weapon.has_method("set_use_ammo_system"):
		equipped_weapon.set_use_ammo_system(weapon_uses_ammo_system)
	if equipped_weapon.has_signal("shot_fired") and not equipped_weapon.shot_fired.is_connected(_on_weapon_shot_fired):
		equipped_weapon.shot_fired.connect(_on_weapon_shot_fired)


func equip_weapon(weapon) -> void:
	"""Legacy method - add weapon to array and equip it."""
	# If weapon not in array, add it
	if weapon not in weapons:
		weapons.append(weapon)
	_equip_weapon_at_index(weapons.find(weapon))


func _on_weapon_shot_fired(pos: Vector2, dir: Vector2, faction: String) -> void:
	if equipped_weapon and equipped_weapon.stats:
		var faction_type: int = Faction.string_to_type(faction)
		ProjectileSpawner.spawn_projectile(pos, dir, equipped_weapon.stats, faction_type, self)


func try_shoot_weapon(muzzle_pos: Vector2, aim_dir: Vector2) -> bool:
	if equipped_weapon:
		return equipped_weapon.try_shoot(muzzle_pos, aim_dir)
	return false


func get_weapon_muzzle_position() -> Vector2:
	if equipped_weapon:
		return equipped_weapon.get_muzzle_position()
	return global_position
