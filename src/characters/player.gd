class_name Player
extends CharacterBody2D

# Player - 玩家控制器
# 实现横板射击游戏的核心玩家逻辑

# Dash 状态枚举
enum DashState { IDLE, DASHING, COOLDOWN }
enum DashInterruptMode { NONE, ON_DAMAGE, ON_CONDITION }

signal health_changed(current: int, max: int)
signal ammo_changed(current: int, max: int)
signal weapon_changed(weapon_name: String)
signal died
signal dash_started()
signal dash_ended()

# 输入动作 (GUIDE)
@export_group("Input Actions")
@export var move_action: GUIDEAction
@export var jump_action: GUIDEAction
@export var shoot_action: GUIDEAction
@export var reload_action: GUIDEAction
@export var dash_action: GUIDEAction
@export var crouch_action: GUIDEAction
@export var weapon_switch_action: GUIDEAction

# 移动参数
@export_group("Movement")
@export var max_speed: float = 300.0
@export var acceleration: float = 2000.0
@export var deceleration: float = 1500.0
@export var air_acceleration: float = 1000.0
@export var air_deceleration: float = 500.0
@export var crouch_multiplier: float = 0.5

# 跳跃参数
@export_group("Jump")
@export var jump_velocity: float = -600.0
@export var gravity_scale: float = 1.0
@export var max_fall_speed: float = 1000.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var variable_jump_cut: float = 0.5
@export var enable_double_jump: bool = false
@export var double_jump_velocity: float = -480.0

# 战斗参数
@export_group("Combat")
@export var max_health: int = 100
@export var invulnerability_time: float = 0.5
@export var knockback_resistance: float = 0.8

# Dash 参数
@export_group("Dash")
@export var dash_duration: float = 0.25
@export var dash_distance: float = 150.0
@export var dash_cooldown: float = 1.5
@export var dash_invincibility_time: float = 0.2
@export var max_air_dashes: int = 1
@export var dash_interrupt_mode: DashInterruptMode = DashInterruptMode.NONE

# 组件引用
@onready var weapon_pivot: Marker2D = $WeaponPivot
@onready var muzzle: Marker2D = $WeaponPivot/Weapon/Muzzle
@onready var camera: Camera2D = $Camera2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var invulnerability_timer: Timer = $InvulnerabilityTimer
@onready var dash_iframe_timer: Timer = $DashIframeTimer

# 状态变量
var current_health: int = 100
var is_grounded: bool = false
var is_crouching: bool = false
var is_invulnerable: bool = false
var facing_direction: int = 1

# 跳跃相关运行时变量
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_double_jump: bool = false
var _jump_release_requested: bool = false

# 可变跳高 (Celeste 风格)
var _var_jump_timer: float = 0.0
var _var_jump_speed: float = 0.0
var _jump_held: bool = false
const VAR_JUMP_TIME: float = 0.25  # 250ms 可变跳高窗口

# Dash 状态变量
var dash_state: DashState = DashState.IDLE
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _air_dashes_used: int = 0

# 武器系统
var current_weapon = null
var weapons: Array = []
var current_weapon_index: int = 0

func _ready():
	add_to_group("player")
	
	# 注册到 GameManager
	GameManager.register_player(self)
	
	current_health = max_health
	invulnerability_timer.wait_time = invulnerability_time
	if jump_action and not jump_action.just_triggered.is_connected(_on_jump_action_just_triggered):
		jump_action.just_triggered.connect(_on_jump_action_just_triggered)
	if jump_action and not jump_action.completed.is_connected(_on_jump_action_completed):
		jump_action.completed.connect(_on_jump_action_completed)
	
	# 连接信号
	invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
	dash_iframe_timer.timeout.connect(_on_dash_iframe_timeout)
	is_grounded = is_on_floor()
	
	# 初始化武器系统
	_initialize_weapons()
	
	print("Player initialized")


func _initialize_weapons() -> void:
	# 加载步枪场景
	var rifle_scene = load("res://scenes/weapons/rifle.tscn")
	if rifle_scene:
		var rifle = rifle_scene.instantiate()
		# 添加到 WeaponPivot/Weapon 节点下
		var weapon_container = weapon_pivot.get_node_or_null("Weapon")
		if weapon_container:
			weapon_container.add_child(rifle)
			weapons.append(rifle)
			_equip_weapon(0)
			# 检测武器类型并打印信息
			if rifle is Weapon:
				print("Player equipped Rifle (Weapon component) with stats: %s" % rifle.stats.weapon_name if rifle.stats else "unknown")
		else:
			push_error("Weapon container not found!")
	else:
		push_error("Failed to load rifle scene!")

func _physics_process(delta: float):
	# 先更新输入状态（包括跳跃按键状态）
	_update_jump_held_state()
	_handle_input(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_movement(delta)
	_update_dash(delta)
	_handle_aiming()
	_handle_shooting()
	_handle_weapon_switch()
	
	move_and_slide()
	is_grounded = is_on_floor()
	_update_animation()

func _update_jump_held_state() -> void:
	# 单独更新跳跃按键状态，确保在重力应用前获取最新状态
	# 使用 value_bool 而非 is_triggered()，因为 is_triggered() 只在 TRIGGERED 状态时返回 true
	# 而 value_bool 在按键被按住期间始终为 true
	if jump_action != null:
		_jump_held = jump_action.value_bool

func _handle_input(delta: float) -> void:
	# Dash 冷却计时器更新
	if dash_state == DashState.COOLDOWN:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer <= 0:
			dash_state = DashState.IDLE
	
	# Dash 输入检测（使用 is_action_just_pressed）
	if dash_state == DashState.IDLE:
		if EnhancedInput.instance.is_action_just_pressed(dash_action):
			if _air_dashes_used < max_air_dashes:
				_start_dash()
	
	# 下蹲
	is_crouching = EnhancedInput.instance.is_action_pressed(crouch_action) and is_grounded
	
	# 跳跃缓冲
	jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)
	
	# 土狼时间
	if is_grounded:
		coyote_timer = coyote_time
		can_double_jump = enable_double_jump
		_air_dashes_used = 0  # 落地重置空中Dash次数
		# 落地时重置可变跳高状态
		_var_jump_timer = 0.0
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

func _apply_gravity(delta: float) -> void:
	if is_grounded:
		return
	
	# 可变跳高 (Celeste 风格)：按住跳跃期间维持初始上升速度
	if _var_jump_timer > 0 and velocity.y < 0:
		# 计时器始终递减，无论是否按住
		_var_jump_timer = max(_var_jump_timer - delta, 0.0)
		
		# 如果还在窗口内且按住跳跃，维持初始速度
		if _jump_held:
			velocity.y = _var_jump_speed  # 用固定速度覆盖，而非缩放
			return  # 跳过正常重力
	
	# 正常重力（窗口结束或未按住）
	velocity.y += get_gravity().y * gravity_scale * delta
	velocity.y = min(velocity.y, max_fall_speed)

func _handle_jump() -> void:
	# 普通跳跃
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0
		coyote_timer = 0
		# 初始化可变跳高状态
		_var_jump_timer = VAR_JUMP_TIME
		_var_jump_speed = jump_velocity
		AudioManager.play_sfx("jump")
	# 二段跳
	elif jump_buffer_timer > 0 and can_double_jump:
		velocity.y = double_jump_velocity
		jump_buffer_timer = 0
		can_double_jump = false
		# 二段跳也支持可变跳高（稍短的窗口）
		_var_jump_timer = VAR_JUMP_TIME * 0.8
		_var_jump_speed = double_jump_velocity
		AudioManager.play_sfx("jump")
	
	# 可变跳高释放：停止可变窗口，让重力正常生效
	if _jump_release_requested and velocity.y < 0:
		_var_jump_timer = 0.0
	_jump_release_requested = false

func _handle_movement(delta: float) -> void:
	# move_action 是 AXIS_2D 类型，直接读取 2D 向量
	var input_direction = EnhancedInput.instance.get_axis_2d(move_action).x
	
	var target_speed = max_speed
	if is_crouching:
		target_speed *= crouch_multiplier
	
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
	var aim_dir = EnhancedInput.instance.get_aim_direction()
	
	# 更新武器朝向
	if weapon_pivot:
		weapon_pivot.rotation = aim_dir.angle()
		
		# 根据瞄准方向翻转精灵
		if abs(aim_dir.x) > 0.1:
			$Body.flip_h = aim_dir.x < 0
			weapon_pivot.scale.y = -1 if aim_dir.x < 0 else 1

func _handle_shooting() -> void:
	# Debug: Check input state
	if shoot_action == null:
		push_warning("shoot_action is NULL!")
		return
	if current_weapon == null:
		push_warning("current_weapon is NULL!")
		return
	
	var is_pressed = EnhancedInput.instance.is_action_pressed(shoot_action)
	if is_pressed:
		# 使用 Weapon 组件：传递枪口位置和瞄准方向
		if current_weapon:
			var muzzle_pos := get_muzzle_position()
			var aim_dir := get_aim_direction()
			current_weapon.try_shoot(muzzle_pos, aim_dir)

	
	if EnhancedInput.instance.is_action_just_pressed(reload_action) and current_weapon:
		current_weapon.reload()

func _handle_weapon_switch() -> void:
	if EnhancedInput.instance.is_action_just_pressed(weapon_switch_action):
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
		# 断开旧武器的信号
		if current_weapon.has_signal("ammo_changed") and current_weapon.ammo_changed.is_connected(_on_weapon_ammo_changed):
			current_weapon.ammo_changed.disconnect(_on_weapon_ammo_changed)
		if current_weapon.has_signal("reload_started") and current_weapon.reload_started.is_connected(_on_weapon_reload_started):
			current_weapon.reload_started.disconnect(_on_weapon_reload_started)
		if current_weapon.has_signal("reload_finished") and current_weapon.reload_finished.is_connected(_on_weapon_reload_finished):
			current_weapon.reload_finished.disconnect(_on_weapon_reload_finished)
		if current_weapon.has_signal("spread_changed") and current_weapon.spread_changed.is_connected(_on_weapon_spread_changed):
			current_weapon.spread_changed.disconnect(_on_weapon_spread_changed)
		if current_weapon.has_signal("shot_fired") and current_weapon.shot_fired.is_connected(_on_weapon_shot_fired):
			current_weapon.shot_fired.disconnect(_on_weapon_shot_fired)
	
	current_weapon = weapons[index]
	
	# 连接武器信号
	if current_weapon.has_signal("ammo_changed") and not current_weapon.ammo_changed.is_connected(_on_weapon_ammo_changed):
		current_weapon.ammo_changed.connect(_on_weapon_ammo_changed)
	if current_weapon.has_signal("reload_started") and not current_weapon.reload_started.is_connected(_on_weapon_reload_started):
		current_weapon.reload_started.connect(_on_weapon_reload_started)
	if current_weapon.has_signal("reload_finished") and not current_weapon.reload_finished.is_connected(_on_weapon_reload_finished):
		current_weapon.reload_finished.connect(_on_weapon_reload_finished)
	if current_weapon.has_signal("spread_changed") and not current_weapon.spread_changed.is_connected(_on_weapon_spread_changed):
		current_weapon.spread_changed.connect(_on_weapon_spread_changed)
	
	# 设置阵营并连接 shot_fired 信号
	current_weapon.faction = "player"
	if current_weapon.has_method("set_use_ammo_system"):
		current_weapon.set_use_ammo_system(true)
	_setup_weapon_signals(current_weapon)
	
	var weapon_name := "Unknown"
	if current_weapon.stats:
		weapon_name = current_weapon.stats.weapon_name
	weapon_changed.emit(weapon_name)
	
	# 立即更新弹药显示
	var mag_size := 0
	if current_weapon.stats:
		mag_size = current_weapon.stats.magazine_size
	_on_weapon_ammo_changed(current_weapon.current_ammo_in_mag, mag_size)
	
	# 立即同步准星扩散状态
	var base_spread := 0.0
	if current_weapon.stats:
		base_spread = current_weapon.stats.spread
	_on_weapon_spread_changed(current_weapon.current_visual_spread, base_spread)


func _setup_weapon_signals(weapon: Weapon) -> void:
	"""设置新 Weapon 组件的信号连接"""
	if weapon.has_signal("shot_fired") and not weapon.shot_fired.is_connected(_on_weapon_shot_fired):
		weapon.shot_fired.connect(_on_weapon_shot_fired)


func _on_weapon_shot_fired(pos: Vector2, dir: Vector2, faction: String) -> void:
	"""处理 Weapon 组件的射击信号"""
	# 生成玩家投射物
	if ProjectileSpawner and current_weapon and current_weapon.stats:
		var faction_type: int = Faction.Type.ENEMY if faction == "enemy" else Faction.Type.PLAYER
		ProjectileSpawner.spawn_projectile(pos, dir, current_weapon.stats, faction_type, self)
	
	# 应用相机震动（玩家特有）
	if camera and current_weapon and current_weapon.stats:
		camera.apply_shake(current_weapon.stats.screen_shake_amount)


func _on_weapon_ammo_changed(current: int, max: int) -> void:
	# 转发武器弹药信号到玩家信号
	ammo_changed.emit(current, max)
	if GameManager.hud:
		GameManager.hud.on_crosshair_ammo_changed(current, max)


func _on_weapon_reload_started() -> void:
	# 通知 HUD 显示换弹进度
	if GameManager.hud and current_weapon and current_weapon.stats:
		GameManager.hud.start_reload_progress(current_weapon.stats.reload_time)
		GameManager.hud.on_crosshair_reload_started(current_weapon.stats.reload_time)


func _on_weapon_reload_finished() -> void:
	# 通知 HUD 隐藏换弹进度
	if GameManager.hud:
		GameManager.hud.finish_reload_progress()
		GameManager.hud.on_crosshair_reload_finished()


func _on_weapon_spread_changed(current_spread: float, base_spread: float) -> void:
	if GameManager.hud:
		GameManager.hud.update_crosshair_spread(current_spread, base_spread)

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if is_invulnerable or current_health <= 0:
		return
	
	# 根据打断模式处理Dash打断
	if dash_interrupt_mode == DashInterruptMode.ON_DAMAGE and dash_state == DashState.DASHING:
		_interrupt_dash()
	
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
			if animation_player.has_animation("jump"):
				animation_player.play("jump")
		else:
			if animation_player.has_animation("fall"):
				animation_player.play("fall")
	elif abs(velocity.x) > 10:
		if animation_player.has_animation("run"):
			animation_player.play("run")
	elif is_crouching:
		if animation_player.has_animation("crouch"):
			animation_player.play("crouch")
	else:
		if animation_player.has_animation("idle"):
			animation_player.play("idle")

func _on_invulnerability_timeout() -> void:
	is_invulnerable = false


func _start_dash() -> void:
	dash_state = DashState.DASHING
	_dash_timer = dash_duration
	if not is_grounded:
		_air_dashes_used += 1
	# 启动无敌帧
	is_invulnerable = true
	dash_iframe_timer.wait_time = dash_invincibility_time
	dash_iframe_timer.start()
	dash_started.emit()


func _on_dash_iframe_timeout() -> void:
	if dash_state != DashState.DASHING:
		is_invulnerable = false


func _update_dash(delta: float) -> void:
	if dash_state != DashState.DASHING:
		return

	var dash_speed = dash_distance / dash_duration
	velocity.x = facing_direction * dash_speed
	velocity.y = 0

	_dash_timer -= delta
	if _dash_timer <= 0:
		_end_dash()


func _end_dash() -> void:
	dash_state = DashState.COOLDOWN
	_dash_cooldown_timer = dash_cooldown
	# 如果无敌帧计时器已停止，取消无敌
	if dash_iframe_timer.is_stopped():
		is_invulnerable = false
	dash_ended.emit()


func _interrupt_dash() -> void:
	if dash_state == DashState.DASHING:
		_end_dash()


func _on_jump_action_just_triggered() -> void:
	jump_buffer_timer = jump_buffer_time


func _on_jump_action_completed() -> void:
	_jump_release_requested = true

func get_muzzle_position() -> Vector2:
	# 优先使用当前武器的 get_muzzle_position() 方法（新 Weapon 组件）
	if current_weapon and current_weapon is Weapon:
		return current_weapon.get_muzzle_position()
	# 回退到旧的 muzzle 节点引用
	if muzzle:
		return muzzle.global_position
	return global_position

func get_aim_direction() -> Vector2:
	return EnhancedInput.instance.get_aim_direction()


func get_aim_point() -> Vector2:
	var collision_shape_node := get_node_or_null("CollisionShape2D")
	if collision_shape_node is CollisionShape2D:
		var collision_shape := collision_shape_node as CollisionShape2D
		return collision_shape.global_position

	return global_position


func get_weapon_aim_origin() -> Vector2:
	if current_weapon and current_weapon is Weapon:
		return current_weapon.get_muzzle_position()
	if weapon_pivot:
		return weapon_pivot.global_position
	return global_position
