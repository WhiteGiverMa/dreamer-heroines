extends Control

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
	
	# 初始隐藏
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# 设置加载 - 暂时注释
	# _load_settings()
	print("PauseMenu initialized")

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if event.is_action_pressed("pause"):
		if is_settings_open:
			_close_settings()
		else:
			_on_resume_pressed()
		get_viewport().set_input_as_handled()

# 显示/隐藏
func show_pause_menu() -> void:
	visible = true
	GameManager.set_paused(true)
	
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
		GameManager.set_paused(false)
	)

# 按钮回调
func _on_resume_pressed() -> void:
	hide_pause_menu()
	resume_requested.emit()

func _on_restart_pressed() -> void:
	_show_confirmation("restart", "确认重新开始？\n当前进度将丢失。")

func _on_settings_pressed() -> void:
	_open_settings()

func _on_menu_pressed() -> void:
	_show_confirmation("menu", "确认返回主菜单？\n未保存的进度将丢失。")

func _on_quit_pressed() -> void:
	_show_confirmation("quit", "确认退出游戏？")

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
			GameManager.set_paused(false)
			restart_requested.emit()
		"menu":
			GameManager.set_paused(false)
			quit_to_menu_requested.emit()
		"quit":
			quit_to_desktop_requested.emit()
	
	pending_action = ""

func _on_confirmation_canceled() -> void:
	pending_action = ""

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
