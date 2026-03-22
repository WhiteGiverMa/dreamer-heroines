class_name SettingsPanel
extends Panel

# SettingsPanel - 设置面板
# 处理设置UI逻辑和持久化
# 可在主菜单和暂停菜单上下文中使用

signal close_requested

# 分辨率预设
const RESOLUTIONS := [
	{"name": "720p", "width": 1280, "height": 720},
	{"name": "1080p", "width": 1920, "height": 1080},
	{"name": "1440p", "width": 2560, "height": 1440},
	{"name": "Native", "width": 0, "height": 0}  # 0 = 使用屏幕分辨率
]

# 窗口模式
const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless"]

# 节点引用 (使用 unique_name_in_owner)
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var volume_slider: HSlider = %VolumeSlider
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_init_controls()
	_load_settings()
	_connect_signals()


func _init_controls() -> void:
	"""初始化设置控件"""
	# 初始化分辨率下拉框
	if resolution_option:
		resolution_option.clear()
		for res in RESOLUTIONS:
			resolution_option.add_item(res.name)
		resolution_option.selected = 1  # 默认 1080p
	
	# 初始化窗口模式下拉框
	if window_mode_option:
		window_mode_option.clear()
		for mode in WINDOW_MODES:
			window_mode_option.add_item(mode)
		window_mode_option.selected = 0  # 默认窗口模式


func _load_settings() -> void:
	"""从 SaveManager 加载设置"""
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
	
	# 分辨率没有保存，保持默认选择


func _connect_signals() -> void:
	"""连接所有控件信号"""
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_selected)
	
	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_selected)
	
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	
	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_resolution_selected(index: int) -> void:
	"""处理分辨率选择"""
	var res = RESOLUTIONS[index]
	var width: int = res.width
	var height: int = res.height
	
	# Native 分辨率使用当前屏幕大小
	if width == 0 or height == 0:
		var screen_size = DisplayServer.screen_get_size()
		width = screen_size.x
		height = screen_size.y
	
	# 直接调用 DisplayServer 应用分辨率
	DisplayServer.window_set_size(Vector2i(width, height))
	print("[SettingsPanel] Resolution changed to: %dx%d" % [width, height])
	
	_save_settings()


func _on_window_mode_selected(index: int) -> void:
	"""处理窗口模式选择"""
	# 直接调用 DisplayServer API 应用窗口模式
	# 0=Windowed, 1=Fullscreen, 2=Borderless(ExclusiveFullscreen)
	match index:
		0:  # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:  # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:  # Borderless (ExclusiveFullscreen)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	print("[SettingsPanel] Window mode changed to: %s" % WINDOW_MODES[index])
	
	_save_settings()


func _on_volume_changed(value: float) -> void:
	"""处理音量变化"""
	# value 范围 0-100，转换为 0-1
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MASTER, value / 100.0)
	
	_save_settings()


func _on_sensitivity_changed(_value: float) -> void:
	"""处理灵敏度变化"""
	_save_settings()


func _on_vsync_toggled(enabled: bool) -> void:
	"""处理 VSync 切换"""
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
	
	print("[SettingsPanel] VSync changed to: %s" % ("enabled" if enabled else "disabled"))
	
	_save_settings()


func _save_settings() -> void:
	"""保存设置到 SaveManager"""
	var settings := {
		"master_volume": volume_slider.value / 100.0 if volume_slider else 0.8,
		"music_volume": 0.7,
		"sfx_volume": 1.0,
		"mouse_sensitivity": sensitivity_slider.value / 100.0 if sensitivity_slider else 1.0,
		"fullscreen": window_mode_option.selected == 1 if window_mode_option else false,
		"vsync": vsync_check.button_pressed if vsync_check else true,
		"window_mode": window_mode_option.selected if window_mode_option else 0,
	}
	SaveManager.save_settings(settings)


func _on_back_pressed() -> void:
	"""处理返回按钮点击"""
	close_requested.emit()


func show_panel() -> void:
	"""显示面板（带淡入动画）"""
	visible = true
	modulate.a = 0.0
	
	var tween = create_tween()
	# 使用 TWEEN_PAUSE_PROCESS 使动画在暂停时也能运行
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)


func hide_panel() -> void:
	"""隐藏面板（带淡出动画）"""
	var tween = create_tween()
	# 使用 TWEEN_PAUSE_PROCESS 使动画在暂停时也能运行
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)
