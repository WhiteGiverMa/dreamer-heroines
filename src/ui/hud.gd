extends CanvasLayer

# HUD - 游戏内界面
# 显示生命值、弹药、分数等游戏信息

signal weapon_switched(index: int)
signal pause_requested

@export_group("Health Display")
@export var health_bar: ProgressBar
@export var health_label: Label
@export var health_warning_threshold: float = 0.3

@export_group("Ammo Display")
@export var ammo_label: Label
@export var reserve_ammo_label: Label
@export var reload_progress: ProgressBar

@export_group("Weapon Display")
@export var weapon_name_label: Label
@export var weapon_icon: TextureRect
@export var weapon_slots: HBoxContainer

@export_group("Score Display")
@export var score_label: Label
@export var lives_label: Label

@export_group("Objective Display")
@export var objective_label: Label
@export var objective_progress: ProgressBar
@export var timer_label: Label

@export_group("Damage Feedback")
@export var damage_overlay: ColorRect
@export var damage_direction_indicator: Control
@export var hit_marker: TextureRect

# 内部状态
var current_health: int = 100
var max_health: int = 100
var current_weapon_index: int = 0
var is_reload_animating: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var hit_marker_timer: Timer = $HitMarkerTimer

func _ready() -> void:
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

func _process(_delta: float) -> void:
	# 更新计时器
	if timer_label and LevelManager.current_state == LevelManager.LevelState.PLAYING:
		timer_label.text = LevelManager.get_formatted_time()
	
	# 更新目标进度
	_update_objective_display()

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
		ammo_label.text = "%d / %d" % [current, max]
		
		# 低弹药警告
		if current <= max * 0.2:
			ammo_label.modulate = Color(1, 0.3, 0.3, 1)
		else:
			ammo_label.modulate = Color(1, 1, 1, 1)
	
	if reserve_ammo_label and reserve >= 0:
		reserve_ammo_label.text = " Reserve: %d" % reserve

func show_reload_progress(duration: float) -> void:
	if not reload_progress:
		return
	
	reload_progress.visible = true
	reload_progress.max_value = duration
	reload_progress.value = 0.0
	
	is_reload_animating = true
	var tween = create_tween()
	tween.tween_property(reload_progress, "value", duration, duration)
	tween.tween_callback(func():
		is_reload_animating = false
		reload_progress.visible = false
	)

func hide_reload_progress() -> void:
	if reload_progress:
		reload_progress.visible = false
	is_reload_animating = false

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
	if objective_progress:
		objective_progress.value = progress * 100

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

# 伤害方向指示
func show_damage_direction(direction: Vector2) -> void:
	if not damage_direction_indicator:
		return
	
	# 计算角度
	var angle = direction.angle()
	damage_direction_indicator.rotation = angle
	
	# 显示动画
	var tween = create_tween()
	damage_direction_indicator.modulate.a = 1.0
	tween.tween_property(damage_direction_indicator, "modulate:a", 0.0, 1.0)

# 游戏状态
func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.PLAYING:
			visible = true
		GameManager.GameState.PAUSED:
			pass
		GameManager.GameState.MENU, GameManager.GameState.GAME_OVER:
			visible = false

# 输入处理
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		pause_requested.emit()

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
		2: streak_text = "Double Kill!"
		3: streak_text = "Triple Kill!"
		4: streak_text = "Quadra Kill!"
		5: streak_text = "Penta Kill!"
		_: streak_text = "%d Kills!" % count
	
	show_message(streak_text, 1.5)
	
	if animation_player:
		animation_player.play("kill_streak")
