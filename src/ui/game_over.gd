extends Control

# GameOver - 游戏结束界面
# 显示游戏结束、胜利或失败信息

signal restart_requested
signal continue_requested
signal quit_to_menu_requested

enum GameOverType { VICTORY, DEFEAT, TIMEOUT }

@export_group("Display Elements")
@export var title_label: Label
@export var subtitle_label: Label
@export var stats_container: VBoxContainer
@export var score_label: Label
@export var kills_label: Label
@export var time_label: Label
@export var accuracy_label: Label

@export_group("Buttons")
@export var restart_button: Button
@export var continue_button: Button
@export var menu_button: Button

@export_group("Visual")
@export var background: ColorRect
@export var victory_color: Color = Color(0.2, 0.6, 0.2, 0.9)
@export var defeat_color: Color = Color(0.6, 0.2, 0.2, 0.9)
@export var animation_player: AnimationPlayer

var game_over_type: GameOverType = GameOverType.DEFEAT

func _ready() -> void:
	# 连接按钮信号
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if LocalizationManager:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	
	# 初始隐藏
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	_apply_static_texts()

# 显示游戏结束
func show_game_over(type: GameOverType, stats: Dictionary = {}) -> void:
	game_over_type = type
	visible = true
	GameManager.set_paused(true)
	
	# 设置标题和背景
	_setup_for_type(type)
	
	# 显示统计
	_show_stats(stats)
	
	# 播放动画
	if animation_player:
		match type:
			GameOverType.VICTORY:
				animation_player.play("victory")
			_:
				animation_player.play("defeat")
	
	# 淡入
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.5)

func _setup_for_type(type: GameOverType) -> void:
	match type:
		GameOverType.VICTORY:
			if title_label:
				title_label.text = LocalizationManager.tr("ui.game_over.title.victory")
				title_label.modulate = Color(0.2, 1.0, 0.2)
			if subtitle_label:
				subtitle_label.text = LocalizationManager.tr("ui.game_over.subtitle.victory")
			if background:
				background.color = victory_color
			if continue_button:
				continue_button.visible = true
			if restart_button:
				restart_button.visible = false
		
		GameOverType.DEFEAT:
			if title_label:
				title_label.text = LocalizationManager.tr("ui.game_over.title.defeat")
				title_label.modulate = Color(1.0, 0.2, 0.2)
			if subtitle_label:
				subtitle_label.text = LocalizationManager.tr("ui.game_over.subtitle.defeat")
			if background:
				background.color = defeat_color
			if continue_button:
				continue_button.visible = false
			if restart_button:
				restart_button.visible = true
		
		GameOverType.TIMEOUT:
			if title_label:
				title_label.text = LocalizationManager.tr("ui.game_over.title.timeout")
				title_label.modulate = Color(1.0, 0.5, 0.2)
			if subtitle_label:
				subtitle_label.text = LocalizationManager.tr("ui.game_over.subtitle.timeout")
			if background:
				background.color = defeat_color
			if continue_button:
				continue_button.visible = false
			if restart_button:
				restart_button.visible = true

func _show_stats(stats: Dictionary) -> void:
	if score_label:
		var score = stats.get("score", GameManager.current_score)
		score_label.text = LocalizationManager.call("tr", "ui.game_over.stats.score", {"value": score})
	
	if kills_label:
		var kills = stats.get("kills", 0)
		kills_label.text = LocalizationManager.call("tr", "ui.game_over.stats.kills", {"value": kills})
	
	if time_label:
		var time = stats.get("time", "00:00")
		time_label.text = LocalizationManager.call("tr", "ui.game_over.stats.time", {"value": time})
	
	if accuracy_label:
		var accuracy = stats.get("accuracy", 0.0)
		accuracy_label.text = LocalizationManager.call("tr", "ui.game_over.stats.accuracy", {"value": "%.1f" % (accuracy * 100)})

# 按钮回调
func _on_restart_pressed() -> void:
	_hide_and_emit(restart_requested)

func _on_continue_pressed() -> void:
	_hide_and_emit(continue_requested)

func _on_menu_pressed() -> void:
	_hide_and_emit(quit_to_menu_requested)

func _hide_and_emit(signal_to_emit: Signal) -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		GameManager.set_paused(false)
		signal_to_emit.emit()
	)

# 快速显示方法
func show_victory(stats: Dictionary = {}) -> void:
	show_game_over(GameOverType.VICTORY, stats)

func show_defeat(reason: String = "", stats: Dictionary = {}) -> void:
	if not reason.is_empty() and subtitle_label:
		subtitle_label.text = reason
	show_game_over(GameOverType.DEFEAT, stats)

func show_timeout(stats: Dictionary = {}) -> void:
	show_game_over(GameOverType.TIMEOUT, stats)

# 隐藏游戏结束界面
func hide_game_over() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		GameManager.set_paused(false)
	)


@warning_ignore("unused_parameter")
func _on_locale_changed(__new_locale: String) -> void:
	_apply_static_texts()
	if visible:
		_setup_for_type(game_over_type)


func _apply_static_texts() -> void:
	if restart_button:
		restart_button.text = LocalizationManager.tr("ui.game_over.button.restart")
	if continue_button:
		continue_button.text = LocalizationManager.tr("ui.game_over.button.continue")
	if menu_button:
		menu_button.text = LocalizationManager.tr("ui.game_over.button.menu")
