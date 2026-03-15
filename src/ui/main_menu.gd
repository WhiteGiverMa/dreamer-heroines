extends Control

# MainMenu - 主菜单
# 游戏启动时的主菜单界面

signal start_game_requested
signal continue_game_requested
signal load_game_requested
signal settings_requested
signal credits_requested
signal quit_requested

@export_group("Menu Buttons")
@export var continue_button: Button
@export var new_game_button: Button
@export var load_game_button: Button
@export var settings_button: Button
@export var credits_button: Button
@export var quit_button: Button

@export_group("Panels")
@export var main_panel: Control
@export var load_game_panel: Control
@export var settings_panel: Control
@export var credits_panel: Control

@export_group("Save Slots")
@export var save_slot_container: VBoxContainer
@export var save_slot_scene: PackedScene

@export_group("Visual")
@export var background: TextureRect
@export var title_label: Label
@export var version_label: Label
@export var animation_player: AnimationPlayer

var current_panel: Control = null

func _ready() -> void:
	# 连接按钮信号
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
	if load_game_button:
		load_game_button.pressed.connect(_on_load_game_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# 初始化版本号
	if version_label:
		version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "0.1.0")
	
	# 检查存档
	_check_save_files()
	
	# 播放开场动画
	if animation_player:
		animation_player.play("intro")
	
	print("MainMenu initialized")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if current_panel and current_panel != main_panel:
			_show_panel(main_panel)
			get_viewport().set_input_as_handled()

# 存档检查
func _check_save_files() -> void:
	var has_save = false
	
	# 检查是否有存档
	if continue_button:
		continue_button.disabled = not has_save

# 按钮回调
func _on_continue_pressed() -> void:
	# 加载最近的存档
	continue_game_requested.emit()

func _on_new_game_pressed() -> void:
	# 显示确认对话框（如果有存档）
	if SaveManager.has_current_save():
		_show_new_game_confirmation()
	else:
		start_game_requested.emit()

func _on_load_game_pressed() -> void:
	_populate_save_slots()
	_show_panel(load_game_panel)

func _on_settings_pressed() -> void:
	_show_panel(settings_panel)

func _on_credits_pressed() -> void:
	_show_panel(credits_panel)
	if animation_player:
		animation_player.play("credits_roll")

func _on_quit_pressed() -> void:
	quit_requested.emit()

# 面板管理
func _show_panel(panel: Control) -> void:
	if current_panel:
		current_panel.visible = false
	
	current_panel = panel
	if panel:
		panel.visible = true
		
		# 淡入动画
		panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.3)

# 存档槽位
func _populate_save_slots() -> void:
	if not save_slot_container:
		return
	
	# 清除现有槽位
	for child in save_slot_container.get_children():
		child.queue_free()
	
	# 获取存档摘要
	var summaries = SaveManager.get_all_save_summaries()
	
	for i in range(summaries.size()):
		var slot = _create_save_slot(i, summaries[i])
		save_slot_container.add_child(slot)

func _create_save_slot(slot_index: int, summary) -> Control:
	var slot_button = Button.new()
	
	if summary.has_save:
		var date_str = summary.save_time if summary.save_time else "Unknown"
		var level_str = summary.level_name if summary.level_name else "Unknown"
		slot_button.text = "Slot %d - %s\nLevel: %s" % [slot_index + 1, date_str, level_str]
		slot_button.pressed.connect(func(): _on_save_slot_selected(slot_index))
	else:
		slot_button.text = "Slot %d - Empty" % (slot_index + 1)
		slot_button.disabled = true
	
	slot_button.custom_minimum_size = Vector2(400, 80)
	slot_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	return slot_button

func _on_save_slot_selected(slot_index: int) -> void:
	SaveManager.load_from_slot(slot_index)
	continue_game_requested.emit()

# 新游戏确认
func _show_new_game_confirmation() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "新的开始"
	dialog.dialog_text = "开始新游戏将覆盖现有存档。\n是否继续？"
	dialog.confirmed.connect(func():
		SaveManager.delete_save(SaveManager.current_slot)
		start_game_requested.emit()
	)
	add_child(dialog)
	dialog.popup_centered()

# 公共方法
func show_menu() -> void:
	visible = true
	_show_panel(main_panel)
	
	if animation_player:
		animation_player.play("intro")

func hide_menu() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)

func set_background(texture: Texture2D) -> void:
	if background:
		background.texture = texture

func enable_continue_button(enabled: bool) -> void:
	if continue_button:
		continue_button.disabled = not enabled
