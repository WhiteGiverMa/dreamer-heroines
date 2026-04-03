class_name SettingsPanel
extends Panel

const DisplaySettingsBoundary = preload("res://src/autoload/display_settings_boundary.gd")
const CrosshairSettingsPanelScene = preload("res://scenes/ui/crosshair_settings_panel.tscn")
const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")
const SliderValueInputClass = preload("res://src/ui/slider_value_input.gd")

# SettingsPanel - 设置面板
# 处理设置UI逻辑和持久化
# 可在主菜单和暂停菜单上下文中使用

signal close_requested

# 分辨率预设
const RESOLUTIONS = DisplaySettingsBoundary.RESOLUTIONS

# 窗口模式
const WINDOW_MODES = DisplaySettingsBoundary.WINDOW_MODES

# 节点引用 (使用 unique_name_in_owner)
@onready var tab_container: TabContainer = %TabContainer
@onready var resolution_option: OptionButton = %ResolutionOption
@onready var window_mode_option: OptionButton = %WindowModeOption
@onready var language_option: OptionButton = %LanguageOption
@onready var volume_slider: HSlider = %VolumeSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var ui_slider: HSlider = %UISlider
@onready var sensitivity_slider: HSlider = %SensitivitySlider
@onready var vsync_check: CheckBox = %VSyncCheck
@onready var developer_mode_check: CheckBox = %DeveloperModeCheck
@onready var lighting_effects_check: CheckBox = %LightingEffectsCheck
@onready var crosshair_panel_host: Control = %CrosshairPanelHost
@onready var back_button: Button = %BackButton

var _is_updating_controls: bool = false
var _is_loading_settings: bool = false
var _localized_text_binder = null
var _crosshair_settings_panel: Control = null
var _slider_value_inputs: Array = []


func _ready() -> void:
	if LocalizationManager:
		LocalizationManager.locale_changed.connect(_on_locale_changed)

	_init_controls()
	_setup_slider_value_inputs()
	_ensure_crosshair_settings_panel()
	_load_settings()
	_connect_signals()
	_setup_localized_bindings()
	_apply_localized_texts()


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

	# 初始化语言下拉框
	if language_option and LocalizationManager:
		language_option.clear()
		for locale in LocalizationManager.get_available_locales():
			language_option.add_item(_get_locale_display_name(locale))
		language_option.selected = _get_locale_index(LocalizationManager.get_locale())

	if volume_slider:
		volume_slider.step = 1.0
		volume_slider.rounded = true

	if music_slider:
		music_slider.step = 1.0
		music_slider.rounded = true

	if sfx_slider:
		sfx_slider.step = 1.0
		sfx_slider.rounded = true

	if ui_slider:
		ui_slider.step = 1.0
		ui_slider.rounded = true

	if sensitivity_slider:
		sensitivity_slider.step = 1.0
		sensitivity_slider.rounded = true


func _setup_slider_value_inputs() -> void:
	_slider_value_inputs.clear()
	_attach_slider_value_input(volume_slider, 0)
	_attach_slider_value_input(music_slider, 0)
	_attach_slider_value_input(sfx_slider, 0)
	_attach_slider_value_input(ui_slider, 0)
	_attach_slider_value_input(sensitivity_slider, 0)


func _attach_slider_value_input(slider: HSlider, decimals: int) -> void:
	if slider == null:
		return
	var options := {
		"decimals": decimals,
	}
	if slider == sensitivity_slider:
		options["decimals"] = 2
		options["display_scale"] = 0.01
		options["suffix"] = "x"
	else:
		options["suffix"] = "%"
	var binding = SliderValueInputClass.new().attach_to_slider(slider, options)
	if binding:
		_slider_value_inputs.append(binding)


func _load_settings() -> void:
	"""从 SaveManager 加载设置"""
	_is_loading_settings = true
	var settings = _get_saved_settings()
	if settings.is_empty():
		_is_loading_settings = false
		return
	
	if volume_slider:
		var master_vol = settings.get("master_volume", 0.8)
		volume_slider.value = master_vol * 100
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.MASTER, master_vol)

	if music_slider:
		var music_vol = settings.get("music_volume", 0.7)
		music_slider.value = music_vol * 100
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.MUSIC, music_vol)

	if sfx_slider:
		var sfx_vol = settings.get("sfx_volume", 1.0)
		sfx_slider.value = sfx_vol * 100
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.SFX, sfx_vol)

	if ui_slider:
		var ui_vol = settings.get("ui_volume", 0.7)
		ui_slider.value = ui_vol * 100
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.UI, ui_vol)
	
	if sensitivity_slider:
		sensitivity_slider.value = settings.get("mouse_sensitivity", 1.0) * 100

	if window_mode_option:
		window_mode_option.selected = settings.get("window_mode", 0)

	if language_option and LocalizationManager:
		var saved_locale: String = settings.get("locale", LocalizationManager.get_locale())
		language_option.selected = _get_locale_index(saved_locale)

	if vsync_check:
		vsync_check.button_pressed = settings.get("vsync", true)

	if developer_mode_check:
		developer_mode_check.button_pressed = settings.get("developer_mode_enabled", false)
		if DeveloperMode:
			DeveloperMode.set_user_enabled(developer_mode_check.button_pressed)

	if lighting_effects_check:
		lighting_effects_check.button_pressed = settings.get("lighting_enabled", true)
		if LightBudgetManager:
			LightBudgetManager.set_lighting_enabled(lighting_effects_check.button_pressed)
	
	# 分辨率没有保存，保持默认选择
	_is_loading_settings = false


func _get_saved_settings() -> Dictionary:
	return SaveManager.load_settings()


func _connect_signals() -> void:
	"""连接所有控件信号"""
	if resolution_option:
		resolution_option.item_selected.connect(_on_resolution_selected)
	
	if window_mode_option:
		window_mode_option.item_selected.connect(_on_window_mode_selected)

	if language_option:
		language_option.item_selected.connect(_on_language_selected)
	
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
	
	if music_slider:
		music_slider.value_changed.connect(_on_music_volume_changed)

	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	if ui_slider:
		ui_slider.value_changed.connect(_on_ui_volume_changed)

	if sensitivity_slider:
		sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	
	if vsync_check:
		vsync_check.toggled.connect(_on_vsync_toggled)

	if developer_mode_check:
		developer_mode_check.toggled.connect(_on_developer_mode_toggled)

	if lighting_effects_check:
		lighting_effects_check.toggled.connect(_on_lighting_effects_toggled)
	
	if back_button:
		back_button.pressed.connect(_on_back_pressed)


func _on_resolution_selected(index: int) -> void:
	"""处理分辨率选择"""
	var res = RESOLUTIONS[index]
	var width: int = res.width
	var height: int = res.height
	
	# Native 分辨率使用当前屏幕大小
	if width == 0 or height == 0:
		var screen_size = DisplaySettingsBoundary.get_screen_size()
		width = screen_size.x
		height = screen_size.y
	
	DisplaySettingsBoundary.set_resolution(width, height)
	print("[SettingsPanel] Resolution changed to: %dx%d" % [width, height])
	
	_save_settings()


func _on_window_mode_selected(index: int) -> void:
	"""处理窗口模式选择"""
	DisplaySettingsBoundary.set_window_mode(index)
	
	print("[SettingsPanel] Window mode changed to: %s" % WINDOW_MODES[index])
	
	_save_settings()


func _on_language_selected(index: int) -> void:
	"""处理语言选择"""
	if _is_updating_controls:
		return
	if not LocalizationManager:
		return

	var available_locales := LocalizationManager.get_available_locales()
	if index < 0 or index >= available_locales.size():
		return

	var selected_locale: String = available_locales[index]
	LocalizationManager.set_locale(selected_locale)
	_save_settings()


func _on_volume_changed(value: float) -> void:
	"""处理主音量变化"""
	# value 范围 0-100，转换为 0-1
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MASTER, value / 100.0)
	if not _is_loading_settings:
		_save_settings()


func _on_music_volume_changed(value: float) -> void:
	"""处理音乐音量变化"""
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MUSIC, value / 100.0)
	if not _is_loading_settings:
		_save_settings()


func _on_sfx_volume_changed(value: float) -> void:
	"""处理音效音量变化"""
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.SFX, value / 100.0)
	if not _is_loading_settings:
		_save_settings()


func _on_ui_volume_changed(value: float) -> void:
	"""处理UI音量变化"""
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.UI, value / 100.0)
	if not _is_loading_settings:
		_save_settings()


func _on_sensitivity_changed(_value: float) -> void:
	"""处理灵敏度变化"""
	_save_settings()


func _on_vsync_toggled(enabled: bool) -> void:
	"""处理 VSync 切换"""
	DisplaySettingsBoundary.set_vsync(enabled)
	
	print("[SettingsPanel] VSync changed to: %s" % ("enabled" if enabled else "disabled"))
	
	_save_settings()


func _on_developer_mode_toggled(enabled: bool) -> void:
	if DeveloperMode:
		DeveloperMode.set_user_enabled(enabled)
	print("[SettingsPanel] Developer mode changed to: %s" % ("enabled" if enabled else "disabled"))
	_save_settings()


func _on_lighting_effects_toggled(enabled: bool) -> void:
	if LightBudgetManager:
		LightBudgetManager.set_lighting_enabled(enabled)
	print("[SettingsPanel] Lighting effects changed to: %s" % ("enabled" if enabled else "disabled"))
	_save_settings()


func _save_settings() -> void:
	"""保存设置到 SaveManager"""
	var settings := SaveManager.load_settings()
	if settings.is_empty():
		settings = {}
	var window_size := DisplaySettingsBoundary.get_window_size()
	settings["master_volume"] = volume_slider.value / 100.0 if volume_slider else 0.8
	settings["music_volume"] = music_slider.value / 100.0 if music_slider else 0.7
	settings["sfx_volume"] = sfx_slider.value / 100.0 if sfx_slider else 1.0
	settings["ui_volume"] = ui_slider.value / 100.0 if ui_slider else 0.7
	settings["mouse_sensitivity"] = sensitivity_slider.value / 100.0 if sensitivity_slider else 1.0
	settings["fullscreen"] = window_mode_option.selected == 1 if window_mode_option else false
	settings["vsync"] = vsync_check.button_pressed if vsync_check else true
	settings["window_mode"] = window_mode_option.selected if window_mode_option else 0
	settings["locale"] = LocalizationManager.get_locale() if LocalizationManager else "zh_CN"
	settings["developer_mode_enabled"] = developer_mode_check.button_pressed if developer_mode_check else false
	settings["lighting_enabled"] = lighting_effects_check.button_pressed if lighting_effects_check else true
	settings["resolution_width"] = window_size.x
	settings["resolution_height"] = window_size.y
	SaveManager.save_settings(settings)


func _on_back_pressed() -> void:
	"""处理返回按钮点击"""
	_save_settings()
	close_requested.emit()


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	_apply_localized_texts()


func _apply_localized_texts() -> void:
	if not LocalizationManager:
		return

	if _localized_text_binder:
		_localized_text_binder.refresh_all()

	# 更新 Tab 标题
	if tab_container:
		tab_container.set_tab_title(0, LocalizationManager.tr("ui.settings.tab.basic"))
		tab_container.set_tab_title(1, LocalizationManager.tr("ui.settings.tab.crosshair"))

	if window_mode_option:
		var selected_window_mode := window_mode_option.selected
		window_mode_option.clear()
		for i in range(WINDOW_MODES.size()):
			window_mode_option.add_item(LocalizationManager.tr("ui.main_menu.window_mode.%d" % i))
		window_mode_option.selected = selected_window_mode if selected_window_mode >= 0 else 0

	if language_option:
		_is_updating_controls = true
		var selected_locale := LocalizationManager.get_locale()
		language_option.clear()
		for locale in LocalizationManager.get_available_locales():
			language_option.add_item(_get_locale_display_name(locale))
		language_option.selected = _get_locale_index(selected_locale)
		_is_updating_controls = false


func _get_locale_display_name(locale: String) -> String:
	match locale:
		"zh_CN":
			return LocalizationManager.tr("ui.settings.language.option.zh_cn")
		"en":
			return LocalizationManager.tr("ui.settings.language.option.en")
		_:
			return locale


func _get_locale_index(locale: String) -> int:
	var available_locales := LocalizationManager.get_available_locales()
	var locale_index := available_locales.find(locale)
	return locale_index if locale_index >= 0 else 0


func show_panel() -> void:
	"""显示面板（带淡入动画）"""
	_ensure_crosshair_settings_panel()
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


func _setup_localized_bindings() -> void:
	_localized_text_binder = LocalizedTextBinderClass.new(self)

	_localized_text_binder.bind("title", "Title", "ui.settings.title")
	_localized_text_binder.bind("resolution_label", "TabContainer/BasicTab/BasicScrollContainer/BasicContent/ResolutionLabel", "ui.settings.resolution")
	_localized_text_binder.bind("window_mode_label", "TabContainer/BasicTab/BasicScrollContainer/BasicContent/WindowModeLabel", "ui.settings.window_mode")
	_localized_text_binder.bind("language_label", "TabContainer/BasicTab/BasicScrollContainer/BasicContent/LanguageLabel", "ui.settings.language")
	_localized_text_binder.bind("volume_label", "TabContainer/BasicTab/BasicScrollContainer/BasicContent/VolumeLabel", "ui.settings.master_volume")
	_localized_text_binder.bind("sensitivity_label", "TabContainer/BasicTab/BasicScrollContainer/BasicContent/SensitivityLabel", "ui.settings.mouse_sensitivity")
	_localized_text_binder.bind_node("vsync_text", vsync_check, "ui.settings.vsync")
	_localized_text_binder.bind_node("developer_mode_text", developer_mode_check, "ui.settings.developer_mode")
	_localized_text_binder.bind_node("lighting_effects_text", lighting_effects_check, "ui.settings.lighting_effects")
	_localized_text_binder.bind_node("back_text", back_button, "ui.main_menu.button.back")

	_localized_text_binder.start()


func _ensure_crosshair_settings_panel() -> void:
	if not crosshair_panel_host:
		return

	if is_instance_valid(_crosshair_settings_panel):
		if _crosshair_settings_panel.get_parent() != crosshair_panel_host:
			_crosshair_settings_panel.reparent(crosshair_panel_host)
		return

	for child in crosshair_panel_host.get_children():
		child.queue_free()

	_crosshair_settings_panel = CrosshairSettingsPanelScene.instantiate()
	_crosshair_settings_panel.name = "CrosshairSettingsPanel"
	if _crosshair_settings_panel is Control:
		_crosshair_settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_crosshair_settings_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	crosshair_panel_host.add_child(_crosshair_settings_panel)
