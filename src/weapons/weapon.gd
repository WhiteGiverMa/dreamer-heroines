class_name Weapon
extends Node2D

# Weapon - 组合式武器组件
# 零依赖设计：不引用持有者，通过信号通信
# 可被玩家、敌人或其他实体复用

# === 信号定义 ===
# 射击信号：通知外部投射物生成参数
signal shot_fired(position: Vector2, direction: Vector2, faction: String)
signal reload_started
signal reload_finished
signal ammo_changed(current: int, max: int)
signal out_of_ammo
# 视觉扩散信号：通知UI当前扩散状态（不影响弹道精度）
signal spread_changed(current_spread: float, base_spread: float)

enum WeaponState {
	IDLE,
	RELOADING_PRE_CHECKPOINT,
	RELOADING_POST_CHECKPOINT,
	DEPLOYING
}

# === 配置 ===
@export var stats: WeaponStats

# 阵营标识（由持有者设置）
# "player" = 玩家阵营，子弹命中敌人
# "enemy" = 敌人阵营，子弹命中玩家
var faction: String = "player"

# === 运行时状态 ===
var current_ammo_in_mag: int = 0
var current_reserve_ammo: int = 0
var can_shoot: bool = true
var is_reloading: bool = false
var _use_ammo_system_runtime: bool = true
var _weapon_state: WeaponState = WeaponState.IDLE
var _reload_elapsed: float = 0.0
var _checkpoint_reached: bool = false
var _deploy_elapsed: float = 0.0

# 视觉扩散状态（仅用于UI反馈，不影响实际弹道）
var current_visual_spread: float = 0.0

# 计时器
var _fire_cooldown_timer: float = 0.0

# 子节点引用
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	if stats:
		_use_ammo_system_runtime = stats.use_ammo_system
	else:
		_use_ammo_system_runtime = false
	_initialize_stats()


func _process(delta: float) -> void:
	_update_reload_state(delta)
	_update_deploy_state(delta)

	if _fire_cooldown_timer > 0:
		_fire_cooldown_timer -= delta
		if _fire_cooldown_timer <= 0:
			can_shoot = true
	
	# 恢复视觉扩散（仅视觉，不影响弹道精度）
	if stats and current_visual_spread > stats.spread:
		var recovery_rate := 50.0  # 视觉恢复速率（度/秒）
		var recovery_amount := recovery_rate * delta
		var previous_spread := current_visual_spread
		current_visual_spread -= recovery_amount
		current_visual_spread = maxf(current_visual_spread, stats.spread)
		# 发射恢复阶段扩散变化信号
		if not is_equal_approx(current_visual_spread, previous_spread):
			spread_changed.emit(current_visual_spread, stats.spread)


func _initialize_stats() -> void:
	if not stats:
		return
	
	# 初始化弹药
	if _use_ammo_system_runtime:
		current_ammo_in_mag = stats.magazine_size
		current_reserve_ammo = stats.max_ammo
	else:
		# 无限弹药模式（敌人）
		current_ammo_in_mag = 999
		current_reserve_ammo = 999
	
	# 初始化视觉扩散
	current_visual_spread = stats.spread if stats.spread > 0 else 0.0


# === 主要接口 ===

## 尝试射击
## @param muzzle_pos: 枪口世界坐标
## @param aim_dir: 瞄准方向（归一化向量）
## @return: 是否成功射击
func try_shoot(muzzle_pos: Vector2, aim_dir: Vector2) -> bool:
	if not can_shoot or is_reloading or is_deploying():
		return false
	
	# 检查弹药（无限弹药模式跳过）
	if stats and _use_ammo_system_runtime:
		if current_ammo_in_mag <= 0:
			out_of_ammo.emit()
			AudioManager.play_sfx("empty_click")
			return false
	
	_fire(muzzle_pos, aim_dir)
	return true


## 执行射击
func _fire(muzzle_pos: Vector2, aim_dir: Vector2) -> void:
	# 消耗弹药
	if stats and _use_ammo_system_runtime:
		current_ammo_in_mag -= 1
		_emit_ammo_changed()
	
	# 设置冷却
	can_shoot = false
	_fire_cooldown_timer = stats.fire_rate if stats else 0.1
	
	# 应用散布
	var final_dir := aim_dir
	if stats and stats.spread > 0:
		var random_angle = randf_range(-stats.spread, stats.spread)
		final_dir = aim_dir.rotated(deg_to_rad(random_angle))
	
	# 视觉扩散增加（不影响实际弹道）
	if stats:
		current_visual_spread = stats.spread + 10.0  # 射击时视觉扩散峰值
		spread_changed.emit(current_visual_spread, stats.spread)
	
	# 发射信号 - 让外部决定如何处理投射物
	shot_fired.emit(muzzle_pos, final_dir, faction)
	
	# 视觉特效
	_spawn_muzzle_flash(muzzle_pos, final_dir)
	_spawn_shell_casing()
	
	# 音效
	if stats:
		AudioManager.play_sfx(stats.weapon_name + "_shoot")
	else:
		AudioManager.play_sfx("shoot")


## 换弹
func reload() -> void:
	if is_reloading or is_deploying():
		return
	if not stats or not _use_ammo_system_runtime:
		return
	if current_ammo_in_mag >= stats.magazine_size:
		return
	if current_reserve_ammo <= 0:
		return

	_reload_elapsed = _get_reload_start_elapsed()
	if _reload_elapsed >= _get_reload_duration():
		_finish_reload()
		return

	_set_weapon_state(_get_reload_state_for_elapsed(_reload_elapsed))
	reload_started.emit()

	if stats:
		AudioManager.play_sfx(stats.weapon_name + "_reload")


## 完成换弹
func _finish_reload() -> void:
	if not stats:
		return

	var ammo_needed := stats.magazine_size - current_ammo_in_mag
	var ammo_to_reload := mini(ammo_needed, current_reserve_ammo)

	current_ammo_in_mag += ammo_to_reload
	current_reserve_ammo -= ammo_to_reload

	_checkpoint_reached = false
	_reload_elapsed = 0.0
	_set_weapon_state(WeaponState.IDLE)
	_emit_ammo_changed()
	reload_finished.emit()


## 取消换弹
func cancel_reload(reason: String = "") -> void:
	if not is_reloading:
		return

	var checkpoint_elapsed := _get_checkpoint_elapsed()
	if _reload_elapsed >= checkpoint_elapsed:
		_checkpoint_reached = true
		_reload_elapsed = checkpoint_elapsed
	else:
		_checkpoint_reached = false
		_reload_elapsed = 0.0

	_set_weapon_state(WeaponState.IDLE)

	if not reason.is_empty():
		# 占位分支：reason 由外部调用方用于日志/调试语义
		pass


func start_deploy() -> bool:
	if _weapon_state == WeaponState.DEPLOYING:
		return false

	if is_reloading:
		cancel_reload("deploy_started")

	_set_weapon_state(WeaponState.DEPLOYING)
	_deploy_elapsed = 0.0
	return true


func cancel_deploy(reason: String = "") -> void:
	if _weapon_state != WeaponState.DEPLOYING:
		return

	_deploy_elapsed = 0.0
	_set_weapon_state(WeaponState.IDLE)

	if not reason.is_empty():
		# 占位分支：reason 由外部调用方用于日志/调试语义
		pass


func is_deploying() -> bool:
	return _weapon_state == WeaponState.DEPLOYING


func get_reload_progress_ratio() -> float:
	if not stats:
		return 0.0

	var reload_duration := _get_reload_duration()
	if reload_duration <= 0.0:
		return 1.0

	return clampf(_reload_elapsed / reload_duration, 0.0, 1.0)


func get_reload_checkpoint_ratio() -> float:
	if not stats:
		return 0.0
	return clampf(stats.reload_checkpoint_percent, 0.0, 1.0)


func has_reload_checkpoint() -> bool:
	return _checkpoint_reached


func get_weapon_state() -> WeaponState:
	return _weapon_state


## 添加弹药
func add_ammo(amount: int) -> void:
	if not stats:
		return
	var previous_reserve_ammo: int = current_reserve_ammo
	current_reserve_ammo = mini(current_reserve_ammo + amount, stats.max_ammo)
	if current_reserve_ammo != previous_reserve_ammo:
		_emit_ammo_changed()


## 获取枪口位置
func get_muzzle_position() -> Vector2:
	if muzzle:
		return muzzle.global_position
	return global_position


## 获取当前弹药状态
func get_ammo_info() -> Dictionary:
	return {
		"current": current_ammo_in_mag,
		"reserve": current_reserve_ammo,
		"max": stats.magazine_size if stats else 0
	}


## 检查是否需要换弹
func needs_reload() -> bool:
	if not stats or not _use_ammo_system_runtime:
		return false
	return current_ammo_in_mag < stats.magazine_size and current_reserve_ammo > 0


func set_use_ammo_system(enabled: bool) -> void:
	"""Configure whether this weapon instance consumes ammo at runtime."""
	_use_ammo_system_runtime = enabled

	if not stats:
		return

	if enabled:
		if current_ammo_in_mag <= 0 or current_ammo_in_mag > stats.magazine_size:
			current_ammo_in_mag = stats.magazine_size
		current_reserve_ammo = clampi(current_reserve_ammo, 0, stats.max_ammo)
	else:
		current_ammo_in_mag = 999
		current_reserve_ammo = 999

	_emit_ammo_changed()


func is_using_ammo_system() -> bool:
	return _use_ammo_system_runtime


# === 内部方法 ===

func _spawn_muzzle_flash(pos: Vector2, dir: Vector2) -> void:
	if not stats or stats.muzzle_flash_effect.is_empty():
		return
	
	if EffectManager:
		EffectManager.play_muzzle_flash(pos, dir.angle(), stats.muzzle_flash_effect)


func _spawn_shell_casing() -> void:
	if not stats or not stats.shell_casing_scene:
		return
	
	var casing := stats.shell_casing_scene.instantiate()
	get_tree().current_scene.add_child(casing)
	casing.global_position = global_position


func _emit_ammo_changed() -> void:
	if not stats:
		return
	ammo_changed.emit(current_ammo_in_mag, stats.magazine_size)


func _update_reload_state(delta: float) -> void:
	if not is_reloading or not stats:
		return

	_reload_elapsed += delta

	if _weapon_state == WeaponState.RELOADING_PRE_CHECKPOINT and _reload_elapsed >= _get_checkpoint_elapsed():
		_checkpoint_reached = true
		_set_weapon_state(WeaponState.RELOADING_POST_CHECKPOINT)

	if _reload_elapsed >= _get_reload_duration():
		_finish_reload()


func _update_deploy_state(delta: float) -> void:
	if _weapon_state != WeaponState.DEPLOYING:
		return

	var deploy_duration := _get_deploy_duration()
	if deploy_duration <= 0.0:
		_finish_deploy()
		return

	_deploy_elapsed += delta
	if _deploy_elapsed >= deploy_duration:
		_finish_deploy()


func _finish_deploy() -> void:
	_deploy_elapsed = 0.0
	_set_weapon_state(WeaponState.IDLE)


func _set_weapon_state(new_state: WeaponState) -> void:
	_weapon_state = new_state
	is_reloading = (
		new_state == WeaponState.RELOADING_PRE_CHECKPOINT
		or new_state == WeaponState.RELOADING_POST_CHECKPOINT
	)


func _get_reload_duration() -> float:
	if not stats:
		return 0.0
	return maxf(stats.reload_time, 0.0)


func _get_checkpoint_elapsed() -> float:
	return _get_reload_duration() * get_reload_checkpoint_ratio()


func _get_reload_start_elapsed() -> float:
	if _checkpoint_reached:
		return _get_checkpoint_elapsed()
	return 0.0


func _get_reload_state_for_elapsed(elapsed: float) -> WeaponState:
	if elapsed >= _get_checkpoint_elapsed():
		_checkpoint_reached = true
		return WeaponState.RELOADING_POST_CHECKPOINT

	_checkpoint_reached = false
	return WeaponState.RELOADING_PRE_CHECKPOINT


func _get_deploy_duration() -> float:
	if not stats:
		return 0.0
	return maxf(stats.deploy_time, 0.0)
