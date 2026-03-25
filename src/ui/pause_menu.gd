extends Control

const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")

# PauseMenu - 暂停菜单
# 游戏暂停时的菜单界面

signal resume_requested
signal restart_requested
signal settings_requested
signal quit_to_menu_requested
signal quit_to_desktop_requested

# 使用 % 唯一名称引用按钮
@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var settings_button: Button = %SettingsButton
@onready var menu_button: Button = %MenuButton
@onready var quit_button: Button = %QuitButton

# 设置面板
@onready var settings_panel: Control = %SettingsPanel
# @onready var volume_slider: HSlider = %VolumeSlider
# @onready var sensitivity_slider: HSlider = %SensitivitySlider
# @onready var fullscreen_checkbox: CheckBox = %FullscreenCheckbox
# @onready var vsync_checkbox: CheckBox = %VsyncCheckbox

# 确认对话框
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

var pending_action: String = ""
var is_settings_open: bool = false
var _localized_text_binder = null

func _ready() -> void:
	# 自注册到 GameManager
	if GameManager:
		GameManager.register_pause_menu(self)
	
	# 连接按钮信号
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# 连接设置面板关闭信号
	if settings_panel:
		settings_panel.close_requested.connect(_close_settings)
	
	# 设置控件连接 - 暂时注释
	# if volume_slider:
	# 	volume_slider.value_changed.connect(_on_volume_changed)
	# if sensitivity_slider:
	# 	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	# if fullscreen_checkbox:
	# 	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	# if vsync_checkbox:
	# 	vsync_checkbox.toggled.connect(_on_vsync_toggled)
	
	# 连接确认对话框
	if confirmation_dialog:
		confirmation_dialog.confirmed.connect(_on_confirmation_confirmed)
		confirmation_dialog.canceled.connect(_on_confirmation_canceled)

	if LocalizationManager:
		LocalizationManager.locale_changed.connect(_on_locale_changed)
	
	# 初始隐藏
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# 设置加载 - 暂时注释
	# _load_settings()
	_setup_localized_bindings()
	_apply_localized_texts()
	print("PauseMenu initialized")


func _setup_localized_bindings() -> void:
	_localized_text_binder = LocalizedTextBinderClass.new(self)

	_localized_text_binder.bind("pause_label", "CenterContainer/VBoxContainer/PauseLabel", "ui.pause_menu.title")
	_localized_text_binder.bind_node("resume_button", resume_button, "ui.pause_menu.button.resume")
	_localized_text_binder.bind_node("restart_button", restart_button, "ui.pause_menu.button.restart")
	_localized_text_binder.bind_node("settings_button", settings_button, "ui.main_menu.button.settings")
	_localized_text_binder.bind_node("menu_button", menu_button, "ui.pause_menu.button.main_menu")
	_localized_text_binder.bind_node("quit_button", quit_button, "ui.pause_menu.button.quit")

	_localized_text_binder.start()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if not is_settings_open and event.is_action_pressed("pause"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
		return

	if is_settings_open and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		_close_settings()
		get_viewport().set_input_as_handled()

# 显示/隐藏
func show_pause_menu() -> void:
	visible = true
	
	# 动画
	modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# 聚焦到继续按钮
	if resume_button:
		resume_button.grab_focus()

func hide_pause_menu() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
	)

# 按钮回调
func _on_resume_pressed() -> void:
	resume_requested.emit()

func _on_restart_pressed() -> void:
	_show_confirmation("restart", LocalizationManager.tr("ui.pause_menu.confirm.restart"))

func _on_settings_pressed() -> void:
	_open_settings()

func _on_menu_pressed() -> void:
	_show_confirmation("menu", LocalizationManager.tr("ui.pause_menu.confirm.menu"))

func _on_quit_pressed() -> void:
	_show_confirmation("quit", LocalizationManager.tr("ui.pause_menu.confirm.quit"))

# 设置面板
func _open_settings() -> void:
	if not settings_panel:
		return
	
	is_settings_open = true
	settings_panel.visible = true
	
	# Animation with pause-safe tween
	settings_panel.modulate.a = 0.0
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(settings_panel, "modulate:a", 1.0, 0.2)

func _close_settings() -> void:
	if not settings_panel:
		return
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(settings_panel, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		settings_panel.visible = false
		is_settings_open = false
	)

# 设置控件回调 - 暂时注释
# func _on_volume_changed(value: float) -> void:
# 	AudioManager.set_master_volume(value / 100.0)
# 
# func _on_sensitivity_changed(value: float) -> void:
# 	# 保存到设置
# 	if SaveManager.has_current_save():
# 		SaveManager.current_save_data.settings.mouse_sensitivity = value / 100.0
# 
# func _on_fullscreen_toggled(enabled: bool) -> void:
# 	if enabled:
# 		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
# 	else:
# 		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
# 
# func _on_vsync_toggled(enabled: bool) -> void:
# 	DisplayServer.window_set_vsync_mode(
# 		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
# 	)

# 确认对话框
func _show_confirmation(action: String, message: String) -> void:
	pending_action = action
	
	if confirmation_dialog:
		confirmation_dialog.dialog_text = message
		confirmation_dialog.popup_centered()
	else:
		# 如果没有对话框，直接执行
		_on_confirmation_confirmed()

func _on_confirmation_confirmed() -> void:
	match pending_action:
		"restart":
			restart_requested.emit()
		"menu":
			quit_to_menu_requested.emit()
		"quit":
			quit_to_desktop_requested.emit()
	
	pending_action = ""

func _on_confirmation_canceled() -> void:
	pending_action = ""


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	_apply_localized_texts()


func _apply_localized_texts() -> void:
	if not LocalizationManager:
		return

	if _localized_text_binder:
		_localized_text_binder.refresh_all()

	if confirmation_dialog and confirmation_dialog.visible and not pending_action.is_empty():
		match pending_action:
			"restart":
				confirmation_dialog.dialog_text = LocalizationManager.tr("ui.pause_menu.confirm.restart")
			"menu":
				confirmation_dialog.dialog_text = LocalizationManager.tr("ui.pause_menu.confirm.menu")
			"quit":
				confirmation_dialog.dialog_text = LocalizationManager.tr("ui.pause_menu.confirm.quit")

# 设置加载/保存 - 暂时注释
# func _load_settings() -> void:
# 	var settings = null
# 	if SaveManager.has_current_save():
# 		settings = SaveManager.current_save_data.settings
# 	
# 	if settings:
# 		if volume_slider:
# 			volume_slider.value = settings.master_volume * 100
# 		if sensitivity_slider:
# 			sensitivity_slider.value = settings.mouse_sensitivity * 100
# 		if fullscreen_checkbox:
# 			fullscreen_checkbox.button_pressed = settings.fullscreen
# 		if vsync_checkbox:
# 			vsync_checkbox.button_pressed = settings.vsync
# 
# func save_settings() -> void:
# 	if SaveManager.has_current_save():
# 		SaveManager.save_current_game()
