extends CanvasLayer

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

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_marker_timer: Timer = $HitMarkerTimer


func _ready() -> void:
	# 注册到 GameManager
	GameManager.register_hud(self)

	# 连接游戏管理器信号
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.state_changed.connect(_on_game_state_changed)

	# 初始化显示
	_update_health_display()
	_update_score_display()
	# 弹药显示会在武器切换时更新

	# 隐藏需要动态显示的元素
	if damage_overlay:
		damage_overlay.modulate.a = 0.0
	if hit_marker:
		hit_marker.visible = false
	if reload_progress:
		reload_progress.visible = false

	print("HUD initialized")


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
	if animation_player:
		animation_player.play("damage_flash")

	if damage_overlay:
		var tween = create_tween()
		tween.tween_property(damage_overlay, "modulate:a", 0.5, 0.1)
		tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.3)


# 弹药更新
func update_ammo(current: int, max: int, reserve: int = -1) -> void:
	if ammo_label:
		if reserve >= 0:
			ammo_label.text = "%d / %d (%d)" % [current, max, reserve]
		else:
			ammo_label.text = "%d / %d" % [current, max]

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
func start_reload_progress(duration: float) -> void:
	reload_duration = duration
	reload_elapsed = 0.0
	is_reloading = true

	if reload_progress:
		reload_progress.visible = true
		reload_progress.max_value = duration
		reload_progress.value = 0.0

	# 显示换弹中文本
	if ammo_label:
		ammo_label.modulate = Color(1, 0.8, 0.2, 1)  # 黄色表示换弹中


func finish_reload_progress() -> void:
	is_reloading = false
	reload_duration = 0.0
	reload_elapsed = 0.0

	if reload_progress:
		reload_progress.visible = false

	# 恢复弹药颜色
	if ammo_label:
		ammo_label.modulate = Color(1, 1, 1, 1)


func _update_reload_progress(delta: float) -> void:
	if not is_reloading:
		return

	reload_elapsed += delta

	if reload_progress:
		reload_progress.value = reload_elapsed

	# 更新弹药标签显示进度
	if ammo_label and reload_duration > 0:
		var progress = reload_elapsed / reload_duration
		ammo_label.text = "Reloading... %d%%" % int(progress * 100)


# 武器更新
func update_weapon(weapon_name: String, weapon_index: int, total_weapons: int) -> void:
	current_weapon_index = weapon_index

	if weapon_name_label:
		weapon_name_label.text = weapon_name

	# 更新武器槽位显示
	_update_weapon_slots(weapon_index, total_weapons)


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
	if score_label:
		score_label.text = "Score: %d" % GameManager.current_score

	if lives_label:
		lives_label.text = "x%d" % GameManager.player_lives


# 目标显示
func set_objective(text: String) -> void:
	if objective_label:
		objective_label.text = text


func update_objective_progress(progress: float) -> void:
	# 目标进度暂时显示在标签中
	if objective_label:
		objective_label.text = objective_label.text + " (%d%%)" % int(progress * 100)


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

	var streak_text = ""
	match count:
		2:
			streak_text = "Double Kill!"
		3:
			streak_text = "Triple Kill!"
		4:
			streak_text = "Quadra Kill!"
		5:
			streak_text = "Penta Kill!"
		_:
			streak_text = "%d Kills!" % count

	show_message(streak_text, 1.5)

	if animation_player:
		animation_player.play("kill_streak")


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
	if wave_counter:
		wave_counter.text = "Wave %d/%d" % [current_wave, max_waves]


## 更新敌人数量显示
func update_enemy_count(count: int) -> void:
	live_enemy_count = count
	if enemy_count:
		enemy_count.text = "Enemies: %d" % count


## 更新击杀数显示
func update_arena_score(current_kills: int, target: int) -> void:
	kill_count = current_kills
	kill_target = target
	if score_display:
		score_display.text = "Kills: %d/%d" % [current_kills, target]


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
	# 敌人生成时更新计数
	var enemies := get_tree().get_nodes_in_group("enemy")
	update_enemy_count(enemies.size())


func _on_all_waves_complete() -> void:
	# 所有波次完成 - 保持格式 "Wave X/5"
	current_wave = max_waves
	_update_wave_display()


func _on_objective_score_changed(current_kills: int, target: int) -> void:
	update_arena_score(current_kills, target)
	# 同时更新敌人计数
	var enemies := get_tree().get_nodes_in_group("enemy")
	update_enemy_count(enemies.size())


func _on_objective_complete() -> void:
	# 目标完成 - 保持格式 "Kills: X/25"
	update_arena_score(kill_target, kill_target)


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
		crosshair._on_reload_started(duration)


## 换弹结束转发
func on_crosshair_reload_finished() -> void:
	if crosshair:
		crosshair._on_reload_finished()


## 弹药变化转发
func on_crosshair_ammo_changed(current: int, maximum: int) -> void:
	if crosshair:
		crosshair._on_ammo_changed(current, maximum)
