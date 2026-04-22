extends CanvasLayer

const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")
const VirtualJoystickScene = preload("res://scenes/ui/virtual_joystick.tscn")
const LockIndicatorScene = preload("res://scenes/ui/lock_indicator.tscn")

# HUD - 游戏内界面
# 显示生命值、弹药、分数等游戏信息

signal weapon_switched(index: int)
signal pause_requested

# 生命值显示
@onready var health_bar: ProgressBar = $MainContainer/TopBar/HealthSection/HealthBar
@onready var health_label: Label = $MainContainer/TopBar/HealthSection/HealthLabel
var health_warning_threshold: float = 0.3

# 弹药显示
@onready var ammo_label: Label = $MainContainer/BottomBar/WeaponSection/AmmoLabel
@onready var reload_progress: ProgressBar = $MainContainer/BottomBar/WeaponSection/ReloadProgress
@onready
var checkpoint_marker: ColorRect = $MainContainer/BottomBar/WeaponSection/ReloadProgress/CheckpointMarker
@onready var deploy_progress: ProgressBar = $MainContainer/BottomBar/WeaponSection/DeployProgress
@onready var slot_label: Label = $MainContainer/BottomBar/WeaponSection/SlotLabel

# 武器显示
@onready var weapon_name_label: Label = $MainContainer/BottomBar/WeaponSection/WeaponNameLabel
@onready var weapon_slots: HBoxContainer = $MainContainer/BottomBar/WeaponSection/WeaponSlots

# 分数显示
@onready var score_label: Label = $MainContainer/TopBar/ScoreSection/ScoreLabel
@onready var lives_label: Label = $MainContainer/TopBar/ScoreSection/LivesLabel

# 目标显示
@onready var objective_label: Label = $MainContainer/TopBar/ObjectiveSection/ObjectiveLabel
@onready var timer_label: Label = $MainContainer/TopBar/ObjectiveSection/TimerLabel

# Arena 模式显示
@onready var wave_counter: Label = $MainContainer/TopBar/ArenaSection/WaveCounter
@onready var enemy_count: Label = $MainContainer/TopBar/ArenaSection/EnemyCount
@onready var score_display: Label = $MainContainer/TopBar/ArenaSection/ScoreDisplay

# 伤害反馈
@onready var damage_overlay: ColorRect = $DamageOverlay
@onready var hit_marker: TextureRect = $MainContainer/BottomBar/CenterSection/HitMarker

# 准星 (使用动态类型避免 parser 解析 CrosshairUI 类名失败)
@onready var crosshair = $MainContainer/BottomBar/CenterSection/CrosshairUI

# 内部状态
var current_health: int = 100
var max_health: int = 100
var current_weapon_index: int = 0
var is_reload_animating: bool = false

# Arena 模式状态
var current_wave: int = 1
var max_waves: int = 5
var live_enemy_count: int = 0
var kill_count: int = 0
var kill_target: int = 25

# 换弹进度状态
var reload_duration: float = 0.0
var reload_elapsed: float = 0.0
var is_reloading: bool = false
var reload_checkpoint_ratio: float = 0.5
var _last_ammo_current: int = 0
var _last_ammo_max: int = 0
var _last_ammo_reserve: int = -1
var _current_objective_base_text: String = ""
var _localized_text_binder = null
var _missing_feedback_warned: Dictionary = {}

# 部署进度状态
var deploy_duration: float = 0.0
var deploy_elapsed: float = 0.0
var is_deploying: bool = false

# 武器槽位
var current_slot: int = 0  # 0 = primary, 1 = secondary

# 移动端 UI
var _virtual_joystick: CanvasLayer = null
var _lock_indicator: CanvasLayer = null

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_marker_timer: Timer = $HitMarkerTimer


func _get_enemy_manager() -> Node:
	return get_node_or_null("/root/EnemyManager")


func _ready() -> void:
	# 注册到 GameManager
	GameManager.register_hud(self)

	if (
		LocalizationManager
		and not LocalizationManager.locale_changed.is_connected(_on_locale_changed)
	):
		LocalizationManager.locale_changed.connect(_on_locale_changed)

	_setup_localized_bindings()

	# 连接游戏管理器信号
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_game_state_changed)

	# 连接敌人管理器信号（实时更新敌人计数）
	var enemy_manager := _get_enemy_manager()
	if (
		enemy_manager
		and not enemy_manager.enemy_count_changed.is_connected(_on_enemy_count_changed)
	):
		enemy_manager.enemy_count_changed.connect(_on_enemy_count_changed)

	# 初始化显示
	_update_health_display()
	_update_score_display()
	_update_wave_display()
	# 从 EnemyManager 获取初始敌人计数
	if enemy_manager:
		update_enemy_count(enemy_manager.get_active_enemy_count())
	else:
		update_enemy_count(0)
	update_arena_score(kill_count, kill_target)
	# 弹药显示会在武器切换时更新

	# 隐藏需要动态显示的元素
	if damage_overlay:
		damage_overlay.modulate.a = 0.0
	if hit_marker:
		hit_marker.visible = false
	if reload_progress:
		reload_progress.visible = false

	_apply_localized_texts()
	_sync_crosshair_runtime_from_player()

	_setup_mobile_ui()

	print("HUD initialized")


func _setup_mobile_ui() -> void:
	# 实例化虚拟摇杆
	_virtual_joystick = VirtualJoystickScene.instantiate()
	add_child(_virtual_joystick)
	_virtual_joystick.visible = InputModeManager.is_mobile_mode()

	# 实例化锁定指示器
	_lock_indicator = LockIndicatorScene.instantiate()
	add_child(_lock_indicator)
	_lock_indicator.visible = InputModeManager.is_mobile_mode()

	# 监听模式变化
	if not InputModeManager.input_mode_changed.is_connected(_on_input_mode_changed):
		InputModeManager.input_mode_changed.connect(_on_input_mode_changed)


func _on_input_mode_changed(mode: int) -> void:
	var is_mobile := (mode == 1)  # InputMode.MOBILE = 1
	if _virtual_joystick:
		_virtual_joystick.visible = is_mobile
	if _lock_indicator:
		_lock_indicator.visible = is_mobile


func _exit_tree() -> void:
	if InputModeManager and InputModeManager.input_mode_changed.is_connected(_on_input_mode_changed):
		InputModeManager.input_mode_changed.disconnect(_on_input_mode_changed)


func _setup_localized_bindings() -> void:
	_localized_text_binder = LocalizedTextBinderClass.new(self)

	_localized_text_binder.bind(
		"score",
		"MainContainer/TopBar/ScoreSection/ScoreLabel",
		"ui.hud.score",
		"text",
		Callable(self, "_get_score_params")
	)
	_localized_text_binder.bind(
		"lives",
		"MainContainer/TopBar/ScoreSection/LivesLabel",
		"ui.hud.lives",
		"text",
		Callable(self, "_get_lives_params")
	)
	_localized_text_binder.bind(
		"wave",
		"MainContainer/TopBar/ArenaSection/WaveCounter",
		"ui.hud.wave",
		"text",
		Callable(self, "_get_wave_params")
	)
	_localized_text_binder.bind(
		"enemies",
		"MainContainer/TopBar/ArenaSection/EnemyCount",
		"ui.hud.enemies",
		"text",
		Callable(self, "_get_enemies_params")
	)
	_localized_text_binder.bind(
		"kills",
		"MainContainer/TopBar/ArenaSection/ScoreDisplay",
		"ui.hud.kills",
		"text",
		Callable(self, "_get_kills_params")
	)

	_localized_text_binder.start()


func _process(delta: float) -> void:
	# 更新计时器
	if timer_label and LevelManager.current_state == LevelManager.LevelState.PLAYING:
		timer_label.text = LevelManager.get_formatted_time()

	# 更新目标进度
	_update_objective_display()

	# 更新换弹进度
	_update_reload_progress(delta)


# 生命值更新
func update_health(current: int, max: int) -> void:
	var old_health = current_health
	current_health = current
	max_health = max

	_update_health_display()

	# 受伤反馈
	if current < old_health:
		_show_damage_feedback(old_health - current)


func _update_health_display() -> void:
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

		# 低血量警告颜色
		var health_percent = float(current_health) / float(max_health)
		if health_percent <= health_warning_threshold:
			health_bar.modulate = Color(1, 0, 0, 1)
		else:
			health_bar.modulate = Color(1, 1, 1, 1)

	if health_label:
		health_label.text = "%d / %d" % [current_health, max_health]


func _show_damage_feedback(damage_amount: int) -> void:
	if animation_player and animation_player.has_animation("damage_flash"):
		animation_player.play("damage_flash")
	elif animation_player:
		_warn_missing_feedback_once("damage_flash")

	if damage_overlay:
		var tween = create_tween()
		tween.tween_property(damage_overlay, "modulate:a", 0.5, 0.1)
		tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.3)


# 弹药更新
func update_ammo(current: int, max: int, reserve: int = -1) -> void:
	_last_ammo_current = current
	_last_ammo_max = max
	_last_ammo_reserve = reserve

	if ammo_label:
		ammo_label.text = _format_ammo_text(current, max, reserve)

		# 低弹药警告
		if current <= max * 0.2:
			ammo_label.modulate = Color(1, 0.3, 0.3, 1)
		else:
			ammo_label.modulate = Color(1, 1, 1, 1)


func show_reload_progress(duration: float) -> void:
	if not reload_progress:
		return

	reload_progress.visible = true
	reload_progress.max_value = duration
	reload_progress.value = 0.0

	is_reload_animating = true
	var tween = create_tween()
	tween.tween_property(reload_progress, "value", duration, duration)
	tween.tween_callback(
		func():
			is_reload_animating = false
			reload_progress.visible = false
	)


func hide_reload_progress() -> void:
	if reload_progress:
		reload_progress.visible = false
	is_reload_animating = false


# 换弹进度控制（被 Player 信号调用）
func start_reload_progress(duration: float, checkpoint_percent: float = 0.5) -> void:
	reload_duration = duration
	reload_elapsed = 0.0
	is_reloading = true
	reload_checkpoint_ratio = checkpoint_percent

	if reload_progress:
		reload_progress.visible = true
		reload_progress.max_value = duration
		reload_progress.value = 0.0

	# 延迟一帧设置检查点标记位置，确保布局系统已计算正确的size
	_set_checkpoint_marker_position.call_deferred(checkpoint_percent)

	# 隐藏部署进度
	if deploy_progress:
		deploy_progress.visible = false
	is_deploying = false

	# 显示换弹中文本
	if ammo_label:
		ammo_label.modulate = Color(1, 0.8, 0.2, 1)  # 黄色表示换弹中


## 延迟设置检查点标记位置，确保ProgressBar布局已更新
func _set_checkpoint_marker_position(checkpoint_percent: float) -> void:
	if checkpoint_marker and reload_progress:
		var marker_x = reload_progress.size.x * checkpoint_percent
		checkpoint_marker.position.x = marker_x - 2  # 居中偏移
		checkpoint_marker.visible = true


func update_reload_progress(elapsed: float) -> void:
	"""更新换弹进度（由 Player 每帧调用）"""
	reload_elapsed = elapsed
	if reload_progress:
		reload_progress.value = reload_elapsed

	# 更新弹药标签显示进度
	if ammo_label and reload_duration > 0:
		var progress = reload_elapsed / reload_duration
		ammo_label.text = LocalizationManager.call(
			"tr", "ui.hud.reloading_progress", {"value": int(progress * 100)}
		)


func finish_reload_progress() -> void:
	is_reloading = false
	reload_duration = 0.0
	reload_elapsed = 0.0

	if reload_progress:
		reload_progress.visible = false

	if checkpoint_marker:
		checkpoint_marker.visible = false

	# 恢复弹药颜色
	if ammo_label:
		ammo_label.modulate = Color(1, 1, 1, 1)


func cancel_reload_progress() -> void:
	"""取消换弹进度显示"""
	is_reloading = false
	if reload_progress:
		reload_progress.visible = false
	if checkpoint_marker:
		checkpoint_marker.visible = false
	if ammo_label:
		ammo_label.modulate = Color(1, 1, 1, 1)


func _update_reload_progress(delta: float) -> void:
	# 已由 Player 调用 update_reload_progress，此处仅作备用
	pass


# 部署进度控制
func start_deploy_progress(duration: float) -> void:
	"""开始显示部署进度"""
	deploy_duration = duration
	deploy_elapsed = 0.0
	is_deploying = true

	if deploy_progress:
		deploy_progress.visible = true
		deploy_progress.max_value = duration
		deploy_progress.value = 0.0

	# 隐藏换弹进度
	if reload_progress:
		reload_progress.visible = false
	if checkpoint_marker:
		checkpoint_marker.visible = false
	is_reloading = false

	# 显示部署中文本
	if ammo_label:
		ammo_label.modulate = Color(0.2, 0.8, 1.0, 1)  # 青色表示部署中


func update_deploy_progress(elapsed: float) -> void:
	"""更新部署进度（由 Player 每帧调用）"""
	deploy_elapsed = elapsed
	if deploy_progress:
		deploy_progress.value = deploy_elapsed


func finish_deploy_progress() -> void:
	"""完成部署进度显示"""
	is_deploying = false
	deploy_duration = 0.0
	deploy_elapsed = 0.0

	if deploy_progress:
		deploy_progress.visible = false

	# 恢复弹药颜色
	if ammo_label and not is_reloading:
		ammo_label.modulate = Color(1, 1, 1, 1)


func cancel_deploy_progress() -> void:
	"""取消部署进度显示"""
	is_deploying = false
	if deploy_progress:
		deploy_progress.visible = false
	if ammo_label and not is_reloading:
		ammo_label.modulate = Color(1, 1, 1, 1)


# 武器更新
func update_weapon(weapon_name: String, slot_id: int, total_weapons: int) -> void:
	current_weapon_index = slot_id
	current_slot = slot_id

	if weapon_name_label:
		weapon_name_label.text = weapon_name

	# 更新武器槽位数字显示 (1 = primary, 2 = secondary)
	if slot_label:
		slot_label.text = str(slot_id + 1)

	# 更新武器槽位显示
	_update_weapon_slots(slot_id, total_weapons)


func _update_weapon_slots(active_index: int, total: int) -> void:
	if not weapon_slots:
		return

	# 清除现有槽位
	for child in weapon_slots.get_children():
		child.queue_free()

	# 创建新的槽位
	for i in range(total):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(40, 40)

		if i == active_index:
			slot.modulate = Color(1, 1, 0, 1)  # 高亮当前武器
		else:
			slot.modulate = Color(0.5, 0.5, 0.5, 1)

		weapon_slots.add_child(slot)


# 分数更新
func _on_score_changed(new_score: int) -> void:
	_update_score_display()


func _update_score_display() -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh("score")
		_localized_text_binder.refresh("lives")


func update_lives(lives: int) -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh("lives")
	elif lives_label:
		lives_label.text = LocalizationManager.call("tr", "ui.hud.lives", {"value": lives})


# 目标显示
func set_objective(text: String) -> void:
	_current_objective_base_text = text
	if objective_label:
		objective_label.text = _resolve_objective_text(text)


func update_objective_progress(progress: float) -> void:
	# 目标进度暂时显示在标签中
	if objective_label:
		var objective_text: String = _resolve_objective_text(_current_objective_base_text)
		objective_label.text = LocalizationManager.call(
			"tr",
			"ui.hud.objective_progress",
			{"objective": objective_text, "value": int(progress * 100)}
		)


func _update_objective_display() -> void:
	if not LevelManager.current_level_data:
		return

	if objective_label and objective_label.text.is_empty():
		set_objective(LevelManager.current_level_data.get_objective_description())


# 命中反馈
func show_hit_marker(is_kill: bool = false) -> void:
	if not hit_marker:
		return

	hit_marker.visible = true

	if is_kill:
		hit_marker.modulate = Color(1, 0, 0, 1)  # 击杀为红色
	else:
		hit_marker.modulate = Color(1, 1, 1, 1)  # 普通命中为白色

	hit_marker_timer.start(0.2)


func on_crosshair_confirmed_hit(is_kill: bool = false) -> void:
	show_hit_marker(is_kill)
	if crosshair and crosshair.has_method("show_hit_feedback"):
		crosshair.show_hit_feedback()


func _on_hit_marker_timer_timeout() -> void:
	if hit_marker:
		hit_marker.visible = false


# 伤害方向指示（暂时禁用 - 节点不存在）
func show_damage_direction(direction: Vector2) -> void:
	pass


# 游戏状态
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			visible = true
		GameManager.GameState.PAUSED:
			pass
		GameManager.GameState.MENU, GameManager.GameState.GAME_OVER:
			visible = false


# 输入处理 - pause已由GameManager统一处理，此处移除重复处理


# 显示/隐藏
func show_hud() -> void:
	visible = true
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func hide_hud() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)


# 消息提示
func show_message(text: String, duration: float = 2.0) -> void:
	var message_label = Label.new()
	message_label.text = text
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 24)

	add_child(message_label)
	message_label.position = Vector2(get_viewport().size.x / 2 - message_label.size.x / 2, 200)

	var tween = create_tween()
	tween.tween_property(message_label, "modulate:a", 0.0, duration).from(1.0)
	tween.tween_callback(message_label.queue_free)


# 连杀显示
func show_kill_streak(count: int) -> void:
	if count < 2:
		return

	var streak_key: String = ""
	match count:
		2:
			streak_key = "ui.hud.kill_streak.double"
		3:
			streak_key = "ui.hud.kill_streak.triple"
		4:
			streak_key = "ui.hud.kill_streak.quadra"
		5:
			streak_key = "ui.hud.kill_streak.penta"
		_:
			streak_key = "ui.hud.kill_streak.multi"

	var streak_text: String = LocalizationManager.call("tr", streak_key, {"value": count})

	show_message(streak_text, 1.5)

	if animation_player and animation_player.has_animation("kill_streak"):
		animation_player.play("kill_streak")
	elif animation_player:
		_warn_missing_feedback_once("kill_streak")


func _warn_missing_feedback_once(animation_name: String) -> void:
	var warn_key := "animation:%s" % animation_name
	if _missing_feedback_warned.has(warn_key):
		return

	_missing_feedback_warned[warn_key] = true
	push_warning("HUD animation not found (warn once): " + animation_name)


# ============================================
# Arena 模式显示
# ============================================


## 设置最大波数
func set_max_waves(total_waves: int) -> void:
	max_waves = total_waves
	_update_wave_display()


## 更新当前波数显示
func update_wave(wave_number: int) -> void:
	current_wave = wave_number
	_update_wave_display()


## 更新波数显示文本
func _update_wave_display() -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh("wave")


## 更新敌人数量显示
func update_enemy_count(count: int) -> void:
	live_enemy_count = count
	if _localized_text_binder:
		_localized_text_binder.refresh("enemies")


## 更新击杀数显示
func update_arena_score(current_kills: int, target: int) -> void:
	kill_count = current_kills
	kill_target = target
	if _localized_text_binder:
		_localized_text_binder.refresh("kills")


## 连接 WaveSpawner 信号
func connect_wave_spawner(spawner: Node) -> void:
	if spawner == null:
		return

	if spawner.has_signal("wave_started"):
		if not spawner.wave_started.is_connected(_on_wave_started):
			spawner.wave_started.connect(_on_wave_started)
	if spawner.has_signal("wave_complete"):
		if not spawner.wave_complete.is_connected(_on_wave_complete):
			spawner.wave_complete.connect(_on_wave_complete)
	if spawner.has_signal("enemy_spawned"):
		if not spawner.enemy_spawned.is_connected(_on_enemy_spawned):
			spawner.enemy_spawned.connect(_on_enemy_spawned)
	if spawner.has_signal("all_waves_complete"):
		if not spawner.all_waves_complete.is_connected(_on_all_waves_complete):
			spawner.all_waves_complete.connect(_on_all_waves_complete)


## 敌人计数变化回调（由 EnemyManager 调用）
func _on_enemy_count_changed(new_count: int) -> void:
	update_enemy_count(new_count)


## 连接 MissionObjective 信号
func connect_mission_objective(objective: Node) -> void:
	if objective == null:
		return

	if objective.has_signal("score_changed"):
		if not objective.score_changed.is_connected(_on_objective_score_changed):
			objective.score_changed.connect(_on_objective_score_changed)
	if objective.has_signal("objective_complete"):
		if not objective.objective_complete.is_connected(_on_objective_complete):
			objective.objective_complete.connect(_on_objective_complete)


## 显示/隐藏 Arena 模式 UI
func set_arena_mode(enabled: bool) -> void:
	if wave_counter:
		wave_counter.visible = enabled
	if enemy_count:
		enemy_count.visible = enabled
	if score_display:
		score_display.visible = enabled

	# 隐藏传统目标显示
	if objective_label:
		objective_label.visible = not enabled
	if timer_label:
		timer_label.visible = not enabled


# Arena 信号回调
func _on_wave_started(wave_number: int) -> void:
	update_wave(wave_number)


func _on_wave_complete(wave_number: int) -> void:
	# 波次完成，可以显示提示
	pass


func _on_enemy_spawned(_enemy: Node) -> void:
	# 敌人由 EnemyManager 追踪，无需手动更新
	# 计数更新通过 EnemyManager.enemy_count_changed 信号触发
	pass


func _on_all_waves_complete() -> void:
	# 所有波次完成 - 保持格式 "Wave X/5"
	current_wave = max_waves
	_update_wave_display()


func _on_objective_score_changed(current_kills: int, target: int) -> void:
	update_arena_score(current_kills, target)
	# 同时更新敌人计数
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	update_enemy_count(enemies.size())


func _on_objective_complete() -> void:
	# 目标完成 - 保持格式 "Kills: X/25"
	update_arena_score(kill_target, kill_target)


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	_apply_localized_texts()


func _apply_localized_texts() -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh_all()

	if is_reloading:
		var progress: int = 0
		if reload_duration > 0:
			progress = int((reload_elapsed / reload_duration) * 100)
		if ammo_label:
			ammo_label.text = LocalizationManager.call(
				"tr", "ui.hud.reloading_progress", {"value": progress}
			)
	else:
		update_ammo(_last_ammo_current, _last_ammo_max, _last_ammo_reserve)

	if not _current_objective_base_text.is_empty() and objective_label:
		objective_label.text = _resolve_objective_text(_current_objective_base_text)


func _format_ammo_text(current: int, max: int, reserve: int) -> String:
	if reserve >= 0:
		return LocalizationManager.call(
			"tr", "ui.hud.ammo.with_reserve", {"current": current, "max": max, "reserve": reserve}
		)
	return LocalizationManager.call("tr", "ui.hud.ammo", {"current": current, "max": max})


func _resolve_objective_text(text: String) -> String:
	if text.begins_with("ui."):
		return LocalizationManager.tr(text)
	return text


func _get_score_params() -> Dictionary:
	return {"value": GameManager.current_score}


func _get_lives_params() -> Dictionary:
	return {"value": GameManager.player_lives}


func _get_wave_params() -> Dictionary:
	return {"current": current_wave, "total": max_waves}


func _get_enemies_params() -> Dictionary:
	return {"value": live_enemy_count}


func _get_kills_params() -> Dictionary:
	return {"current": kill_count, "total": kill_target}


func _sync_crosshair_runtime_from_player() -> void:
	if not crosshair or not GameManager or not GameManager.has_method("get_player"):
		return

	var player = GameManager.get_player()
	if player == null:
		return

	var weapon = player.get("current_weapon")
	if weapon == null:
		return

	var ammo_current := (
		int(weapon.get("current_ammo_in_mag")) if "current_ammo_in_mag" in weapon else 0
	)
	var ammo_max := 0
	if "stats" in weapon and weapon.stats:
		ammo_max = int(weapon.stats.magazine_size)
	on_crosshair_ammo_changed(ammo_current, ammo_max)

	var base_spread := 0.0
	if "stats" in weapon and weapon.stats:
		base_spread = float(weapon.stats.spread)
	var current_spread := (
		float(weapon.get("current_visual_spread"))
		if "current_visual_spread" in weapon
		else base_spread
	)
	update_crosshair_spread(current_spread, base_spread)

	var deploying: bool = false
	if weapon.has_method("is_deploying"):
		deploying = bool(weapon.is_deploying())
	if deploying:
		on_crosshair_deploy_started()
		on_crosshair_reload_finished()
		return

	on_crosshair_deploy_finished()
	if bool(weapon.get("is_reloading")):
		var reload_duration := 0.0
		if "stats" in weapon and weapon.stats:
			reload_duration = float(weapon.stats.reload_time)
		on_crosshair_reload_started(reload_duration)
	else:
		on_crosshair_reload_finished()


# ============================================
# 准星转发方法
# ============================================


## 更新准星扩散
func update_crosshair_spread(current_spread: float, base_spread: float) -> void:
	if crosshair:
		crosshair.update_spread(current_spread, base_spread)


## 换弹开始转发
func on_crosshair_reload_started(duration: float) -> void:
	if crosshair:
		if crosshair.has_method("on_reload_start"):
			crosshair.on_reload_start(duration)
		else:
			crosshair._on_reload_started(duration)


## 换弹结束转发
func on_crosshair_reload_finished() -> void:
	if crosshair:
		if crosshair.has_method("on_reload_end"):
			crosshair.on_reload_end()
		else:
			crosshair._on_reload_finished()


## 部署开始转发
func on_crosshair_deploy_started() -> void:
	if crosshair:
		if crosshair.has_method("on_deploy_start"):
			crosshair.on_deploy_start()
		else:
			crosshair._on_deploy_started()


## 部署结束转发
func on_crosshair_deploy_finished() -> void:
	if crosshair:
		if crosshair.has_method("on_deploy_end"):
			crosshair.on_deploy_end()
		else:
			crosshair._on_deploy_finished()


## 弹药变化转发
func on_crosshair_ammo_changed(current: int, maximum: int) -> void:
	if crosshair:
		if crosshair.has_method("on_ammo_changed"):
			crosshair.on_ammo_changed(current, maximum)
		else:
			crosshair._on_ammo_changed(current, maximum)


func on_crosshair_ammo_empty() -> void:
	if crosshair:
		if crosshair.has_method("on_ammo_empty"):
			crosshair.on_ammo_empty()
		else:
			crosshair._on_ammo_changed(0, 1)
