extends Control

const DisplaySettingsBoundary = preload("res://src/autoload/display_settings_boundary.gd")

# MainMenu - 主菜单
# 游戏启动时的主菜单界面

signal start_game_requested
signal continue_game_requested
signal load_game_requested
signal settings_requested
signal credits_requested
signal quit_requested

const SaveSlotScene = preload("res://scenes/ui/save_slot.tscn")

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
@export var level_select_panel: Control

@export_group("Level Select")
@export var arena_01_button: Button
@export var test_level_button: Button

@export_group("Save Slots")
@export var save_slot_container: VBoxContainer
@export var save_slot_scene: PackedScene

@export_group("Settings Controls")
@export var resolution_option: OptionButton
@export var window_mode_option: OptionButton
@export var volume_slider: HSlider
@export var sensitivity_slider: HSlider
@export var vsync_check: CheckBox

@export_group("Visual")
@export var background: TextureRect
@export var title_label: Label
@export var version_label: Label
@export var animation_player: AnimationPlayer

var current_panel: Control = null
var _pending_delete_slot: int = -1
var _pending_new_game_slot: int = -1

# 分辨率预设
const RESOLUTIONS = DisplaySettingsBoundary.RESOLUTIONS

# 窗口模式
const WINDOW_MODES = DisplaySettingsBoundary.WINDOW_MODES

func _ready() -> void:
	# 自动获取按钮引用（如果 export 变量未设置）
	_auto_get_node_references()
	
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
	if arena_01_button:
		arena_01_button.pressed.connect(_on_arena_01_selected)
	if test_level_button:
		test_level_button.pressed.connect(_on_test_level_selected)
	
	# 连接返回按钮
	_connect_back_buttons()
	
	# 连接内部信号
	start_game_requested.connect(_on_start_game)
	if LocalizationManager:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	
	# 初始化设置控件
	_init_settings_controls()
	
	# 初始化版本号
	if version_label:
		version_label.text = "v" + ProjectSettings.get_setting("application/config/version", "0.1.0")
	
	# 检查存档
	_check_save_files()
	
	# 播放开场动画
	if animation_player and animation_player.has_animation("intro"):
		animation_player.play("intro")

	# 明确初始化当前面板，避免首次切换时多个面板同时可见
	_show_panel(main_panel)

	_apply_localized_texts()

func _auto_get_node_references() -> void:
	"""自动获取节点引用，解决 export 变量未赋值的问题"""
	# 主面板按钮
	if not continue_button:
		continue_button = get_node_or_null("MainPanel/ContinueButton")
	if not new_game_button:
		new_game_button = get_node_or_null("MainPanel/NewGameButton")
	if not load_game_button:
		load_game_button = get_node_or_null("MainPanel/LoadGameButton")
	if not settings_button:
		settings_button = get_node_or_null("MainPanel/SettingsButton")
	if not credits_button:
		credits_button = get_node_or_null("MainPanel/CreditsButton")
	if not quit_button:
		quit_button = get_node_or_null("MainPanel/QuitButton")
	
	# 面板
	if not main_panel:
		main_panel = get_node_or_null("MainPanel")
	if not load_game_panel:
		load_game_panel = get_node_or_null("LoadGamePanel")
	if not settings_panel:
		settings_panel = get_node_or_null("SettingsPanel")
	if not credits_panel:
		credits_panel = get_node_or_null("CreditsPanel")
	if not level_select_panel:
		level_select_panel = get_node_or_null("LevelSelectPanel")

	if not arena_01_button:
		arena_01_button = get_node_or_null("LevelSelectPanel/VBoxContainer/Arena01Button")
	if not test_level_button:
		test_level_button = get_node_or_null("LevelSelectPanel/VBoxContainer/TestLevelButton")
	
	# 存档槽位容器
	if not save_slot_container:
		save_slot_container = get_node_or_null("LoadGamePanel/ScrollContainer/SaveSlotContainer")
	
	# 设置控件
	if not resolution_option:
		resolution_option = get_node_or_null("SettingsPanel/VBoxContainer/ResolutionOption")
	if not window_mode_option:
		window_mode_option = get_node_or_null("SettingsPanel/VBoxContainer/WindowModeOption")
	if not volume_slider:
		volume_slider = get_node_or_null("SettingsPanel/VBoxContainer/VolumeSlider")
	if not sensitivity_slider:
		sensitivity_slider = get_node_or_null("SettingsPanel/VBoxContainer/SensitivitySlider")
	if not vsync_check:
		vsync_check = get_node_or_null("SettingsPanel/VBoxContainer/VSyncCheck")
	
	# 其他
	if not title_label:
		title_label = get_node_or_null("TitleLabel")
	if not version_label:
		version_label = get_node_or_null("VersionLabel")
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")

func _connect_back_buttons() -> void:
	"""连接所有返回按钮"""
	var load_back = get_node_or_null("LoadGamePanel/BackButton")
	if load_back:
		load_back.pressed.connect(_on_back_to_main)
	
	# SettingsPanel 使用 close_requested 信号
	if settings_panel and settings_panel.has_signal("close_requested"):
		settings_panel.close_requested.connect(_on_back_to_main)
	
	var credits_back = get_node_or_null("CreditsPanel/BackButton")
	if credits_back:
		credits_back.pressed.connect(_on_back_to_main)

	var level_select_back = get_node_or_null("LevelSelectPanel/VBoxContainer/BackButton")
	if level_select_back:
		level_select_back.pressed.connect(_on_back_to_main)

func _on_back_to_main() -> void:
	"""返回主面板"""
	_show_panel(main_panel)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if current_panel and current_panel != main_panel:
			_show_panel(main_panel)
			get_viewport().set_input_as_handled()

# 存档检查
func _check_save_files() -> void:
	var has_save := false
	# Check all slots for any save
	for i in range(SaveManager.MAX_SLOTS if SaveManager.get("MAX_SLOTS") else 10):
		if SaveManager.has_save_in_slot(i):
			has_save = true
			break
	
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

func _on_start_game() -> void:
	"""处理开始游戏：先进入选关面板"""
	_show_panel(level_select_panel)

func _on_arena_01_selected() -> void:
	"""选择 Arena 01 并启动关卡"""
	_start_selected_level("arena_01")


func _on_test_level_selected() -> void:
	"""选择 Test Level 并启动关卡"""
	_start_selected_level("test_level")


func _start_selected_level(level_id: String) -> void:
	"""通用关卡启动流程"""
	if SaveManager.current_slot < 0:
		var first_empty_slot: int = SaveManager.get_first_empty_slot()
		SaveManager.current_slot = first_empty_slot if first_empty_slot >= 0 else 0

	if not SaveManager.has_save_in_slot(SaveManager.current_slot):
		SaveManager.save_to_slot(SaveManager.current_slot)

	GameManager.reset_game()
	GameManager.game_started.emit()

	var level_loaded: bool = LevelManager.load_level(level_id)
	if not level_loaded:
		push_error("Failed to load selected level: %s" % level_id)

func _on_load_game_pressed() -> void:
	_populate_save_slots()
	_show_panel(load_game_panel)

func _on_settings_pressed() -> void:
	_show_panel(settings_panel)

func _on_credits_pressed() -> void:
	_show_panel(credits_panel)
	if animation_player and animation_player.has_animation("credits_roll"):
		animation_player.play("credits_roll")

func _on_quit_pressed() -> void:
	get_tree().quit()

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

func _create_save_slot(slot_index: int, summary: Dictionary) -> Control:
	var slot = SaveSlotScene.instantiate()
	slot.setup(summary, slot_index)
	
	# Connect signals
	slot.load_requested.connect(_on_slot_load_requested)
	slot.delete_requested.connect(_on_slot_delete_requested)
	slot.slot_clicked.connect(_on_slot_clicked)
	
	return slot

func _on_slot_load_requested(slot_index: int) -> void:
	## Handle load button click on an occupied slot
	SaveManager.load_from_slot(slot_index)
	continue_game_requested.emit()

func _on_slot_delete_requested(slot_index: int) -> void:
	## Handle delete button click - show confirmation
	_pending_delete_slot = slot_index
	_show_delete_confirmation(slot_index)

func _on_slot_clicked(slot_index: int) -> void:
	## Handle click on slot main area (not buttons)
	var summary = SaveManager.get_save_summary(slot_index)
	if summary.get("has_save", false):
		# Occupied slot - load it
		_on_slot_load_requested(slot_index)
	else:
		# Empty slot - show new game confirmation
		_pending_new_game_slot = slot_index
		_show_new_game_slot_confirmation()

# 新游戏确认
func _show_new_game_confirmation() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = LocalizationManager.tr("ui.main_menu.dialog.new_game_overwrite.title")
	dialog.dialog_text = LocalizationManager.tr("ui.main_menu.dialog.new_game_overwrite.text")
	dialog.confirmed.connect(func():
		SaveManager.delete_save(SaveManager.current_slot)
		start_game_requested.emit()
	)
	add_child(dialog)
	dialog.popup_centered()

func _show_delete_confirmation(slot_index: int) -> void:
	## Show confirmation dialog before deleting a save
	var dialog = ConfirmationDialog.new()
	dialog.title = LocalizationManager.tr("ui.main_menu.dialog.delete_save.title")
	dialog.dialog_text = LocalizationManager.call(
		"tr",
		"ui.main_menu.dialog.delete_save.text",
		{"slot": slot_index + 1}
	)
	dialog.confirmed.connect(_on_delete_confirmed)
	dialog.canceled.connect(_on_delete_canceled)
	add_child(dialog)
	dialog.popup_centered()

func _on_delete_confirmed() -> void:
	## Handle delete confirmation
	if _pending_delete_slot >= 0:
		SaveManager.delete_save(_pending_delete_slot)
		_populate_save_slots()  # Refresh the slot list
		_pending_delete_slot = -1

func _on_delete_canceled() -> void:
	## Handle delete cancellation
	_pending_delete_slot = -1

func _show_new_game_slot_confirmation() -> void:
	## Show confirmation dialog for starting new game in an empty slot
	var dialog = ConfirmationDialog.new()
	dialog.title = LocalizationManager.tr("ui.main_menu.dialog.new_game_slot.title")
	dialog.dialog_text = LocalizationManager.call(
		"tr",
		"ui.main_menu.dialog.new_game_slot.text",
		{"slot": _pending_new_game_slot + 1}
	)
	dialog.confirmed.connect(_on_new_game_slot_confirmed)
	dialog.canceled.connect(_on_new_game_slot_canceled)
	add_child(dialog)
	dialog.popup_centered()

func _on_new_game_slot_confirmed() -> void:
	## Handle new game in empty slot confirmation
	if _pending_new_game_slot >= 0:
		# Set the current slot and start new game
		SaveManager.current_slot = _pending_new_game_slot
		_pending_new_game_slot = -1
		start_game_requested.emit()

func _on_new_game_slot_canceled() -> void:
	## Handle new game cancellation
	_pending_new_game_slot = -1

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

# 设置控件初始化
func _init_settings_controls() -> void:
	# 初始化分辨率下拉框
	if resolution_option:
		resolution_option.clear()
		for res in RESOLUTIONS:
			resolution_option.add_item(res.name)
		resolution_option.selected = 1  # 默认 1080p
		resolution_option.item_selected.connect(_on_resolution_selected)
	
	# 初始化窗口模式下拉框
	if window_mode_option:
		window_mode_option.clear()
		for mode in WINDOW_MODES:
			window_mode_option.add_item(mode)
		window_mode_option.selected = 0  # 默认窗口模式
		window_mode_option.item_selected.connect(_on_window_mode_selected)
	
	# 连接音量滑块
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	
	# 连接灵敏度滑块
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	# 连接 VSync 复选框
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	
	# 加载当前设置
	_load_settings_values()

func _load_settings_values() -> void:
	# 从 SaveManager 加载设置
	var settings = SaveManager.load_settings()
	if settings.is_empty():
		return
	
	if volume_slider:
		volume_slider.value = settings.get("master_volume", 0.8) * 100
	
	if sensitivity_slider:
		sensitivity_slider.value = settings.get("mouse_sensitivity", 1.0) * 100
	
	if window_mode_option:
		window_mode_option.selected = settings.get("window_mode", 0)
	
	if vsync_check:
		vsync_check.button_pressed = settings.get("vsync", true)

	_apply_localized_texts()

# 设置回调
func _on_resolution_selected(index: int) -> void:
	var res = RESOLUTIONS[index]
	var width: int = res.width
	var height: int = res.height
	
	# Native 分辨率使用当前屏幕大小
	if width == 0 or height == 0:
		var screen_size = DisplaySettingsBoundary.get_screen_size()
		width = screen_size.x
		height = screen_size.y
	
	DisplaySettingsBoundary.set_resolution(width, height)
	
	# 保存设置
	_save_current_settings()

func _on_window_mode_selected(index: int) -> void:
	DisplaySettingsBoundary.set_window_mode(index)
	
	# 保存设置
	_save_current_settings()

func _on_volume_changed(value: float) -> void:
	# 直接调用 AudioManager 应用音量
	# value 范围 0-100，转换为 0-1
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MASTER, value / 100.0)
	
	# 保存设置
	_save_current_settings()

func _on_sensitivity_changed(_value: float) -> void:
	# 保存设置
	_save_current_settings()

func _on_vsync_toggled(enabled: bool) -> void:
	DisplaySettingsBoundary.set_vsync(enabled)
	
	# 保存设置
	_save_current_settings()

## 保存当前设置到 user://settings.json
func _save_current_settings() -> void:
	var current_settings := SaveManager.load_settings()
	var window_size := DisplaySettingsBoundary.get_window_size()
	var settings := {
		"master_volume": volume_slider.value / 100.0 if volume_slider else 0.8,
		"music_volume": current_settings.get("music_volume", 0.7),
		"sfx_volume": current_settings.get("sfx_volume", 1.0),
		"mouse_sensitivity": sensitivity_slider.value / 100.0 if sensitivity_slider else 1.0,
		"fullscreen": window_mode_option.selected == 1 if window_mode_option else false,
		"vsync": vsync_check.button_pressed if vsync_check else true,
		"window_mode": window_mode_option.selected if window_mode_option else 0,
		"locale": current_settings.get("locale", "zh_CN"),
		"developer_mode_enabled": current_settings.get("developer_mode_enabled", false),
		"resolution_width": window_size.x,
		"resolution_height": window_size.y,
	}
	SaveManager.save_settings(settings)


@warning_ignore("unused_parameter")
func _on_locale_changed(__new_locale: String) -> void:
	_apply_localized_texts()


func _apply_localized_texts() -> void:
	if title_label:
		title_label.text = LocalizationManager.tr("ui.main_menu.title")

	if continue_button:
		continue_button.text = LocalizationManager.tr("ui.main_menu.button.continue")
	if new_game_button:
		new_game_button.text = LocalizationManager.tr("ui.main_menu.button.new_game")
	if load_game_button:
		load_game_button.text = LocalizationManager.tr("ui.main_menu.button.load_game")
	if settings_button:
		settings_button.text = LocalizationManager.tr("ui.main_menu.button.settings")
	if credits_button:
		credits_button.text = LocalizationManager.tr("ui.main_menu.button.credits")
	if quit_button:
		quit_button.text = LocalizationManager.tr("ui.main_menu.button.quit")

	if window_mode_option:
		var selected_index: int = window_mode_option.selected
		window_mode_option.clear()
		for i in range(WINDOW_MODES.size()):
			window_mode_option.add_item(LocalizationManager.tr("ui.main_menu.window_mode.%d" % i))
		window_mode_option.selected = selected_index if selected_index >= 0 else 0

	if vsync_check:
		vsync_check.text = LocalizationManager.tr("ui.main_menu.settings.vsync")

	var load_back = get_node_or_null("LoadGamePanel/BackButton")
	if load_back:
		load_back.text = LocalizationManager.tr("ui.main_menu.button.back")

	var load_title: Label = get_node_or_null("LoadGamePanel/Title")
	if load_title:
		load_title.text = LocalizationManager.tr("ui.main_menu.panel.load_game.title")

	var credits_title: Label = get_node_or_null("CreditsPanel/Title")
	if credits_title:
		credits_title.text = LocalizationManager.tr("ui.main_menu.panel.credits.title")

	var credits_back = get_node_or_null("CreditsPanel/BackButton")
	if credits_back:
		credits_back.text = LocalizationManager.tr("ui.main_menu.button.back")

	var level_select_title: Label = get_node_or_null("LevelSelectPanel/Title")
	if level_select_title:
		level_select_title.text = "Select Level"

	if arena_01_button:
		arena_01_button.text = "Arena 01"
	if test_level_button:
		test_level_button.text = "Test Level"

	var level_select_back = get_node_or_null("LevelSelectPanel/VBoxContainer/BackButton")
	if level_select_back:
		level_select_back.text = LocalizationManager.tr("ui.main_menu.button.back")

	var credits_text: Label = get_node_or_null("CreditsPanel/CreditsText")
	if credits_text:
		credits_text.text = LocalizationManager.tr("ui.main_menu.credits.text")

func _call_csharp_save_manager(method: String, args: Array = []) -> void:
	"""调用 C# SaveManager 的方法"""
	var csharp_manager = get_node_or_null("/root/CSharpSaveManager")
	if csharp_manager and csharp_manager.has_method(method):
		csharp_manager.callv(method, args)
	else:
		push_warning("CSharpSaveManager not found or method '%s' not available" % method)
