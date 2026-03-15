class_name WeaponBase
extends Node2D

# WeaponBase - 武器基类
# 所有武器的父类，定义通用接口和逻辑

signal shot_fired
signal reload_started
signal reload_finished
signal ammo_changed(current: int, max: int)
signal out_of_ammo

@export_group("Weapon Stats")
@export var weapon_name: String = "Base Weapon"
@export var damage: int = 10
@export var fire_rate: float = 0.1  # 射击间隔（秒）
@export var reload_time: float = 1.5
@export var magazine_size: int = 30
@export var max_ammo: int = 300
@export var projectile_speed: float = 1000.0
@export var spread: float = 0.0  # 散布角度
@export var is_automatic: bool = true
@export var can_aim_down_sights: bool = false

@export_group("Visual")
@export var muzzle_flash_scene: PackedScene
@export var shell_casing_scene: PackedScene
@export var recoil_amount: float = 5.0
@export var screen_shake_amount: float = 0.3

# 运行时状态
var current_ammo_in_mag: int = 0
var current_reserve_ammo: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var owner_player: Node2D = null

# 计时器
var fire_cooldown_timer: float = 0.0
var reload_timer: float = 0.0

func _ready():
	current_ammo_in_mag = magazine_size
	current_reserve_ammo = max_ammo

func _process(delta: float) -> void:
	if fire_cooldown_timer > 0:
		fire_cooldown_timer -= delta
		if fire_cooldown_timer <= 0:
			can_shoot = true

func equip(player: Node2D) -> void:
	owner_player = player
	visible = true
	ammo_changed.emit(current_ammo_in_mag, magazine_size)

func unequip() -> void:
	owner_player = null
	visible = false
	if is_reloading:
		_cancel_reload()

func try_shoot() -> bool:
	if not can_shoot or is_reloading:
		return false
	
	if current_ammo_in_mag <= 0:
		out_of_ammo.emit()
		AudioManager.play_sfx("empty_click")
		return false
	
	_fire()
	return true

func _fire() -> void:
	# 消耗弹药
	current_ammo_in_mag -= 1
	ammo_changed.emit(current_ammo_in_mag, magazine_size)
	
	# 设置冷却
	can_shoot = false
	fire_cooldown_timer = fire_rate
	
	# 生成投射物
	_spawn_projectile()
	
	# 视觉特效
	_spawn_muzzle_flash()
	_spawn_shell_casing()
	_apply_recoil()
	
	# 音效
	AudioManager.play_sfx(weapon_name + "_shoot")
	
	# 屏幕震动
	if owner_player and owner_player.camera:
		owner_player.camera.apply_shake(screen_shake_amount)
	
	shot_fired.emit()

func _spawn_projectile() -> void:
	if not owner_player:
		return
	
	var projectile_scene = load("res://src/weapons/projectile.tscn")
	if not projectile_scene:
		return
	
	var projectile = projectile_scene.instantiate()
	var muzzle_pos = owner_player.get_muzzle_position()
	var aim_dir = owner_player.get_aim_direction()
	
	# 应用散布
	if spread > 0:
		var random_angle = randf_range(-spread, spread)
		aim_dir = aim_dir.rotated(deg_to_rad(random_angle))
	
	projectile.global_position = muzzle_pos
	projectile.direction = aim_dir
	projectile.speed = projectile_speed
	projectile.damage = damage
	projectile.owner_player = owner_player
	
	get_tree().current_scene.add_child(projectile)

func _spawn_muzzle_flash() -> void:
	if muzzle_flash_scene:
		var flash = muzzle_flash_scene.instantiate()
		add_child(flash)
		flash.global_position = owner_player.get_muzzle_position()

func _spawn_shell_casing() -> void:
	if shell_casing_scene:
		var casing = shell_casing_scene.instantiate()
		get_tree().current_scene.add_child(casing)
		casing.global_position = global_position
		# 添加随机弹射方向
		var eject_dir = Vector2.RIGHT.rotated(randf_range(-PI/3, PI/3))
		if owner_player and owner_player.facing_direction < 0:
			eject_dir.x *= -1
		casing.apply_impulse(eject_dir * randf_range(100, 200))

func _apply_recoil() -> void:
	if owner_player:
		owner_player.velocity.x -= cos(rotation) * recoil_amount * 0.1

func reload() -> void:
	if is_reloading or current_ammo_in_mag >= magazine_size or current_reserve_ammo <= 0:
		return
	
	is_reloading = true
	reload_started.emit()
	AudioManager.play_sfx(weapon_name + "_reload")
	
	# 使用Timer进行重载
	var timer = get_tree().create_timer(reload_time)
	await timer.timeout
	
	if is_reloading:  # 检查是否被取消
		_finish_reload()

func _finish_reload() -> void:
	var ammo_needed = magazine_size - current_ammo_in_mag
	var ammo_to_reload = min(ammo_needed, current_reserve_ammo)
	
	current_ammo_in_mag += ammo_to_reload
	current_reserve_ammo -= ammo_to_reload
	
	is_reloading = false
	ammo_changed.emit(current_ammo_in_mag, magazine_size)
	reload_finished.emit()

func _cancel_reload() -> void:
	is_reloading = false

func add_ammo(amount: int) -> void:
	current_reserve_ammo = min(current_reserve_ammo + amount, max_ammo)

func get_total_ammo() -> int:
	return current_ammo_in_mag + current_reserve_ammo

func is_full() -> bool:
	return current_ammo_in_mag >= magazine_size and current_reserve_ammo >= max_ammo
