class_name SettingsPanel
extends Panel

const DisplaySettingsBoundary = preload("res://src/autoload/display_settings_boundary.gd")
const CrosshairSettingsPanelScene = preload("res://scenes/ui/crosshair_settings_panel.tscn")
const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")
const SliderValueInputClass = preload("res://src/ui/slider_value_input.gd")

const DEFAULT_BASIC_SETTINGS := {
	"master_volume": 0.8,
	"music_volume": 0.7,
	"sfx_volume": 1.0,
	"ui_volume": 0.7,
	"mouse_sensitivity": 1.0,
	"fullscreen": false,
	"vsync": true,
	"window_mode": 0,
	"locale": "zh_CN",
	"developer_mode_enabled": false,
	"lighting_enabled": true,
	"slider_wheel_on_slider": true,
	"mobile_deadzone": 0.4,
	"mobile_target_search_angle": 60.0,
	"mobile_show_deadzone_ring": true,
	"mobile_show_aim_line": true,
	"mobile_lock_on_sound_enabled": true,
}

const DEFAULT_RESOLUTION_INDEX := 1

# SettingsPanel - 设置面板
# 处理设置UI逻辑和持久化
# 可在主菜单和暂停菜单上下文中使用

signal close_requested
signal settings_saved
signal settings_cancelled

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
@onready var slider_wheel_on_slider_check: CheckBox = %SliderWheelOnSliderCheck
@onready var crosshair_panel_host: Control = %CrosshairPanelHost
@onready var mobile_settings_section: VBoxContainer = %MobileSettingsSection
@onready var deadzone_slider: HSlider = %DeadzoneSlider
@onready var deadzone_value_label: Label = %DeadzoneValueLabel
@onready var search_angle_slider: HSlider = %SearchAngleSlider
@onready var search_angle_value_label: Label = %SearchAngleValueLabel
@onready var show_deadzone_ring_check: CheckBox = %ShowDeadzoneRingCheck
@onready var show_aim_line_check: CheckBox = %ShowAimLineCheck
@onready var lock_on_sound_check: CheckBox = %LockOnSoundCheck
@onready var save_button: Button = %SaveButton
@onready var cancel_button: Button = %CancelButton
@onready var back_button: Button = %BackButton
@onready var reset_page_button: Button = %ResetPageButton

# 确认对话框
@onready var unsaved_dialog: ConfirmationDialog = %UnsavedDialog

var _is_updating_controls: bool = false
var _is_loading_settings: bool = false
var _localized_text_binder = null
var _crosshair_settings_panel: Control = null
var _slider_value_inputs: Array = []

# 暂存系统 - 用于保存/取消功能
var _pending_settings: Dictionary = {}
var _original_settings: Dictionary = {}
var _has_unsaved_changes: bool = false


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

	if deadzone_slider:
		deadzone_slider.min_value = 0.1
		deadzone_slider.max_value = 0.7
		deadzone_slider.step = 0.05
		deadzone_slider.value = 0.4

	if search_angle_slider:
		search_angle_slider.min_value = 30.0
		search_angle_slider.max_value = 120.0
		search_angle_slider.step = 5.0
		search_angle_slider.value = 60.0

	if mobile_settings_section:
		var os_name := OS.get_name()
		mobile_settings_section.visible = os_name in ["Android", "iOS", "Web"]


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
	"""从 SaveManager 加载设置并初始化暂存系统"""
	var settings = _get_saved_settings()
	if settings.is_empty():
		_original_settings = DEFAULT_BASIC_SETTINGS.duplicate()
		_apply_basic_settings(DEFAULT_BASIC_SETTINGS, false)
	else:
		_original_settings = settings.duplicate()
		_apply_basic_settings(settings, false)

	# 重置暂存系统
	_pending_settings.clear()
	_has_unsaved_changes = false
	_update_button_states()


func _get_saved_settings() -> Dictionary:
	return SaveManager.load_settings()


func _connect_signals() -> void:
	"""连接所有控件信号"""
	if tab_container and not tab_container.tab_changed.is_connected(_on_tab_changed):
		tab_container.tab_changed.connect(_on_tab_changed)

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

	if slider_wheel_on_slider_check:
		slider_wheel_on_slider_check.toggled.connect(_on_slider_wheel_on_slider_toggled)

	if deadzone_slider:
		deadzone_slider.value_changed.connect(_on_deadzone_changed)

	if search_angle_slider:
		search_angle_slider.value_changed.connect(_on_search_angle_changed)

	if show_deadzone_ring_check:
		show_deadzone_ring_check.toggled.connect(_on_show_deadzone_ring_toggled)

	if show_aim_line_check:
		show_aim_line_check.toggled.connect(_on_show_aim_line_toggled)

	if lock_on_sound_check:
		lock_on_sound_check.toggled.connect(_on_lock_on_sound_toggled)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	if save_button:
		save_button.pressed.connect(_on_save_pressed)

	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_pressed)

	if reset_page_button:
		reset_page_button.pressed.connect(_on_reset_page_pressed)

	# 连接确认对话框信号
	if unsaved_dialog:
		unsaved_dialog.confirmed.connect(_on_unsaved_dialog_confirmed)
		unsaved_dialog.canceled.connect(_on_unsaved_dialog_canceled)


func _apply_basic_settings(settings: Dictionary, _persist_after_apply: bool = false) -> void:
	_is_loading_settings = true

	if volume_slider:
		var master_vol = float(settings.get("master_volume", DEFAULT_BASIC_SETTINGS["master_volume"]))
		volume_slider.value = master_vol * 100.0
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.MASTER, master_vol)

	if music_slider:
		var music_vol = float(settings.get("music_volume", DEFAULT_BASIC_SETTINGS["music_volume"]))
		music_slider.value = music_vol * 100.0
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.MUSIC, music_vol)

	if sfx_slider:
		var sfx_vol = float(settings.get("sfx_volume", DEFAULT_BASIC_SETTINGS["sfx_volume"]))
		sfx_slider.value = sfx_vol * 100.0
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.SFX, sfx_vol)

	if ui_slider:
		var ui_vol = float(settings.get("ui_volume", DEFAULT_BASIC_SETTINGS["ui_volume"]))
		ui_slider.value = ui_vol * 100.0
		if AudioManager:
			AudioManager.set_bus_volume(AudioManager.BusType.UI, ui_vol)

	if sensitivity_slider:
		sensitivity_slider.value = float(settings.get("mouse_sensitivity", DEFAULT_BASIC_SETTINGS["mouse_sensitivity"])) * 100.0

	if window_mode_option:
		window_mode_option.selected = int(settings.get("window_mode", DEFAULT_BASIC_SETTINGS["window_mode"]))
		DisplaySettingsBoundary.set_window_mode(window_mode_option.selected)

	if resolution_option:
		resolution_option.selected = int(settings.get("resolution_index", DEFAULT_RESOLUTION_INDEX))
		var res = RESOLUTIONS[clampi(resolution_option.selected, 0, RESOLUTIONS.size() - 1)]
		var width: int = res.width
		var height: int = res.height
		if width == 0 or height == 0:
			var screen_size := DisplaySettingsBoundary.get_screen_size()
			width = screen_size.x
			height = screen_size.y
		DisplaySettingsBoundary.set_resolution(width, height)

	if language_option and LocalizationManager:
		var saved_locale: String = str(settings.get("locale", DEFAULT_BASIC_SETTINGS["locale"]))
		if LocalizationManager.get_locale() != saved_locale:
			LocalizationManager.set_locale(saved_locale)
		language_option.selected = _get_locale_index(saved_locale)

	if vsync_check:
		vsync_check.button_pressed = bool(settings.get("vsync", DEFAULT_BASIC_SETTINGS["vsync"]))
		DisplaySettingsBoundary.set_vsync(vsync_check.button_pressed)

	if developer_mode_check:
		developer_mode_check.button_pressed = bool(settings.get("developer_mode_enabled", DEFAULT_BASIC_SETTINGS["developer_mode_enabled"]))
		if DeveloperMode:
			DeveloperMode.set_user_enabled(developer_mode_check.button_pressed)

	if lighting_effects_check:
		lighting_effects_check.button_pressed = bool(settings.get("lighting_enabled", DEFAULT_BASIC_SETTINGS["lighting_enabled"]))
		if LightBudgetManager:
			LightBudgetManager.set_lighting_enabled(lighting_effects_check.button_pressed)


	if slider_wheel_on_slider_check:
		slider_wheel_on_slider_check.button_pressed = bool(settings.get("slider_wheel_on_slider", DEFAULT_BASIC_SETTINGS["slider_wheel_on_slider"]))
		if UISettingsService:
			UISettingsService.set_setting("slider_wheel_on_slider", slider_wheel_on_slider_check.button_pressed, false)

	if deadzone_slider:
		deadzone_slider.value = float(settings.get("mobile_deadzone", DEFAULT_BASIC_SETTINGS["mobile_deadzone"]))
		if deadzone_value_label:
			deadzone_value_label.text = "%.2f" % deadzone_slider.value

	if search_angle_slider:
		search_angle_slider.value = float(settings.get("mobile_target_search_angle", DEFAULT_BASIC_SETTINGS["mobile_target_search_angle"]))
		if search_angle_value_label:
			search_angle_value_label.text = "%d°" % int(search_angle_slider.value)

	if show_deadzone_ring_check:
		show_deadzone_ring_check.button_pressed = bool(settings.get("mobile_show_deadzone_ring", DEFAULT_BASIC_SETTINGS["mobile_show_deadzone_ring"]))

	if show_aim_line_check:
		show_aim_line_check.button_pressed = bool(settings.get("mobile_show_aim_line", DEFAULT_BASIC_SETTINGS["mobile_show_aim_line"]))

	if lock_on_sound_check:
		lock_on_sound_check.button_pressed = bool(settings.get("mobile_lock_on_sound_enabled", DEFAULT_BASIC_SETTINGS["mobile_lock_on_sound_enabled"]))

	_is_loading_settings = false


func _restore_current_page_defaults() -> void:
	"""恢复当前页面默认设置（暂存到_pending_settings）"""
	if tab_container == null:
		return

	match tab_container.current_tab:
		0:
			# 基本设置页 - 将默认值暂存到_pending_settings
			for key in DEFAULT_BASIC_SETTINGS.keys():
				_pending_settings[key] = DEFAULT_BASIC_SETTINGS[key]
			_mark_as_changed()
			# 更新UI显示
			_apply_basic_settings(DEFAULT_BASIC_SETTINGS, false)
		1:
			# 准星设置页 - 通知准星面板恢复默认
			if is_instance_valid(_crosshair_settings_panel) and _crosshair_settings_panel.has_method("restore_to_defaults_pending"):
				_crosshair_settings_panel.call("restore_to_defaults_pending")
		2:
			# UI设置页
			if slider_wheel_on_slider_check:
				_pending_settings["slider_wheel_on_slider"] = DEFAULT_BASIC_SETTINGS["slider_wheel_on_slider"]
				_mark_as_changed()
				slider_wheel_on_slider_check.button_pressed = DEFAULT_BASIC_SETTINGS["slider_wheel_on_slider"]


func _on_reset_page_pressed() -> void:
	_restore_current_page_defaults()


func _on_resolution_selected(index: int) -> void:
	"""处理分辨率选择 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["resolution_index"] = index
	_mark_as_changed()


func _on_window_mode_selected(index: int) -> void:
	"""处理窗口模式选择 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["window_mode"] = index
	_pending_settings["fullscreen"] = (index == 1)
	_mark_as_changed()


func _on_language_selected(index: int) -> void:
	"""处理语言选择 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return
	if not LocalizationManager:
		return

	var available_locales := LocalizationManager.get_available_locales()
	if index < 0 or index >= available_locales.size():
		return

	var selected_locale: String = available_locales[index]
	_pending_settings["locale"] = selected_locale
	_mark_as_changed()


func _on_volume_changed(value: float) -> void:
	"""处理主音量变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["master_volume"] = value / 100.0
	_mark_as_changed()


func _on_music_volume_changed(value: float) -> void:
	"""处理音乐音量变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["music_volume"] = value / 100.0
	_mark_as_changed()


func _on_sfx_volume_changed(value: float) -> void:
	"""处理音效音量变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["sfx_volume"] = value / 100.0
	_mark_as_changed()


func _on_ui_volume_changed(value: float) -> void:
	"""处理UI音量变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["ui_volume"] = value / 100.0
	_mark_as_changed()


func _on_sensitivity_changed(value: float) -> void:
	"""处理灵敏度变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["mouse_sensitivity"] = value / 100.0
	_mark_as_changed()


func _on_vsync_toggled(enabled: bool) -> void:
	"""处理 VSync 切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["vsync"] = enabled
	_mark_as_changed()


func _on_developer_mode_toggled(enabled: bool) -> void:
	"""处理开发者模式切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["developer_mode_enabled"] = enabled
	_mark_as_changed()


func _on_lighting_effects_toggled(enabled: bool) -> void:
	"""处理光效切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["lighting_enabled"] = enabled
	_mark_as_changed()


func _on_slider_wheel_on_slider_toggled(enabled: bool) -> void:
	"""处理滑轮在滑块上切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["slider_wheel_on_slider"] = enabled
	_mark_as_changed()


func _on_deadzone_changed(value: float) -> void:
	"""处理摇杆死区变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	if deadzone_value_label:
		deadzone_value_label.text = "%.2f" % value
	_pending_settings["mobile_deadzone"] = value
	_mark_as_changed()


func _on_search_angle_changed(value: float) -> void:
	"""处理目标搜索角度变化 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	if search_angle_value_label:
		search_angle_value_label.text = "%d°" % int(value)
	_pending_settings["mobile_target_search_angle"] = value
	_mark_as_changed()


func _on_show_deadzone_ring_toggled(enabled: bool) -> void:
	"""处理显示死区环切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["mobile_show_deadzone_ring"] = enabled
	_mark_as_changed()


func _on_show_aim_line_toggled(enabled: bool) -> void:
	"""处理显示瞄准线切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["mobile_show_aim_line"] = enabled
	_mark_as_changed()


func _on_lock_on_sound_toggled(enabled: bool) -> void:
	"""处理锁定音效切换 - 暂存到_pending_settings"""
	if _is_updating_controls or _is_loading_settings:
		return

	_pending_settings["mobile_lock_on_sound_enabled"] = enabled
	_mark_as_changed()


func _mark_as_changed() -> void:
	"""标记有未保存的更改"""
	if not _has_unsaved_changes:
		_has_unsaved_changes = true
		_update_button_states()


func _update_button_states() -> void:
	"""更新保存/取消按钮的可用状态"""
	if save_button:
		save_button.disabled = not _has_unsaved_changes
	if cancel_button:
		cancel_button.disabled = not _has_unsaved_changes


func _on_back_pressed() -> void:
	"""处理返回按钮点击 - 检查是否有未保存的更改"""
	if _has_unsaved_changes:
		_show_unsaved_dialog()
	else:
		close_requested.emit()


func _show_unsaved_dialog() -> void:
	"""显示未保存更改的确认对话框"""
	if unsaved_dialog:
		if LocalizationManager:
			unsaved_dialog.dialog_text = LocalizationManager.tr("ui.settings.unsaved_changes_prompt")
			unsaved_dialog.ok_button_text = LocalizationManager.tr("ui.settings.save_and_exit")
			unsaved_dialog.cancel_button_text = LocalizationManager.tr("ui.settings.discard_and_exit")
		else:
			unsaved_dialog.dialog_text = "有未保存的更改，是否保存？"
			unsaved_dialog.ok_button_text = "保存并退出"
			unsaved_dialog.cancel_button_text = "放弃并退出"
		unsaved_dialog.popup_centered()
	else:
		# 如果没有对话框，默认保存
		_save_pending_settings()
		close_requested.emit()


func _on_unsaved_dialog_confirmed() -> void:
	"""用户选择保存并退出"""
	_save_pending_settings()
	close_requested.emit()


func _on_unsaved_dialog_canceled() -> void:
	"""用户选择放弃并退出"""
	_cancel_pending_changes()
	close_requested.emit()


func _on_save_pressed() -> void:
	"""处理保存按钮点击 - 应用暂存设置并保存"""
	_save_pending_settings()


func _on_cancel_pressed() -> void:
	"""处理取消按钮点击 - 恢复原始设置"""
	_cancel_pending_changes()


func _save_pending_settings() -> void:
	"""应用暂存设置并保存到文件"""
	if _pending_settings.is_empty():
		_has_unsaved_changes = false
		_update_button_states()
		return

	# 1. 应用到系统
	_apply_pending_to_system()

	# 2. 合并到原始设置
	for key in _pending_settings.keys():
		_original_settings[key] = _pending_settings[key]

	# 3. 保存到文件
	_save_settings_to_file()

	# 4. 清空暂存
	_pending_settings.clear()
	_has_unsaved_changes = false
	_update_button_states()

	# 5. 通知准星面板保存
	if is_instance_valid(_crosshair_settings_panel) and _crosshair_settings_panel.has_method("save_pending_changes"):
		_crosshair_settings_panel.call("save_pending_changes")

	settings_saved.emit()
	print("[SettingsPanel] Settings saved successfully")


func _cancel_pending_changes() -> void:
	"""取消暂存的更改，恢复原始设置"""
	if _pending_settings.is_empty():
		_has_unsaved_changes = false
		_update_button_states()
		return

	# 1. 通知准星面板取消
	if is_instance_valid(_crosshair_settings_panel) and _crosshair_settings_panel.has_method("cancel_pending_changes"):
		_crosshair_settings_panel.call("cancel_pending_changes")

	# 2. 清空暂存
	_pending_settings.clear()
	_has_unsaved_changes = false

	# 3. 恢复控件到原始设置值
	_apply_basic_settings(_original_settings, false)

	# 4. 应用原始设置到系统（恢复之前的实际状态）
	_apply_basic_settings(_original_settings, false)

	_update_button_states()
	settings_cancelled.emit()
	print("[SettingsPanel] Changes cancelled, restored to original settings")


func _apply_pending_to_system() -> void:
	"""将暂存设置应用到实际系统"""
	# 应用音量
	if _pending_settings.has("master_volume") and AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MASTER, _pending_settings["master_volume"])

	if _pending_settings.has("music_volume") and AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MUSIC, _pending_settings["music_volume"])

	if _pending_settings.has("sfx_volume") and AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.SFX, _pending_settings["sfx_volume"])

	if _pending_settings.has("ui_volume") and AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.UI, _pending_settings["ui_volume"])

	# 应用窗口模式
	if _pending_settings.has("window_mode"):
		DisplaySettingsBoundary.set_window_mode(_pending_settings["window_mode"])
		print("[SettingsPanel] Window mode applied: %s" % WINDOW_MODES[_pending_settings["window_mode"]])

	# 应用分辨率
	if _pending_settings.has("resolution_index"):
		var res = RESOLUTIONS[_pending_settings["resolution_index"]]
		var width: int = res.width
		var height: int = res.height
		if width == 0 or height == 0:
			var screen_size = DisplaySettingsBoundary.get_screen_size()
			width = screen_size.x
			height = screen_size.y
		DisplaySettingsBoundary.set_resolution(width, height)
		print("[SettingsPanel] Resolution applied: %dx%d" % [width, height])

	# 应用语言
	if _pending_settings.has("locale") and LocalizationManager:
		LocalizationManager.set_locale(_pending_settings["locale"])

	# 应用VSync
	if _pending_settings.has("vsync"):
		DisplaySettingsBoundary.set_vsync(_pending_settings["vsync"])
		print("[SettingsPanel] VSync applied: %s" % ("enabled" if _pending_settings["vsync"] else "disabled"))

	# 应用开发者模式
	if _pending_settings.has("developer_mode_enabled") and DeveloperMode:
		DeveloperMode.set_user_enabled(_pending_settings["developer_mode_enabled"])
		print("[SettingsPanel] Developer mode applied: %s" % ("enabled" if _pending_settings["developer_mode_enabled"] else "disabled"))

	# 应用光效
	if _pending_settings.has("lighting_enabled") and LightBudgetManager:
		LightBudgetManager.set_lighting_enabled(_pending_settings["lighting_enabled"])
		print("[SettingsPanel] Lighting effects applied: %s" % ("enabled" if _pending_settings["lighting_enabled"] else "disabled"))

	# 应用滑轮设置
	if _pending_settings.has("slider_wheel_on_slider") and UISettingsService:
		UISettingsService.set_setting("slider_wheel_on_slider", _pending_settings["slider_wheel_on_slider"], false)
		print("[SettingsPanel] Slider wheel setting applied: %s" % ("enabled" if _pending_settings["slider_wheel_on_slider"] else "disabled"))


func _save_settings_to_file() -> void:
	"""保存设置到 SaveManager"""
	var settings := SaveManager.load_settings()
	if settings.is_empty():
		settings = {}

	# 使用原始设置（包含已应用的所有更改）
	var window_size := DisplaySettingsBoundary.get_window_size()
	settings["master_volume"] = _original_settings.get("master_volume", DEFAULT_BASIC_SETTINGS["master_volume"])
	settings["music_volume"] = _original_settings.get("music_volume", DEFAULT_BASIC_SETTINGS["music_volume"])
	settings["sfx_volume"] = _original_settings.get("sfx_volume", DEFAULT_BASIC_SETTINGS["sfx_volume"])
	settings["ui_volume"] = _original_settings.get("ui_volume", DEFAULT_BASIC_SETTINGS["ui_volume"])
	settings["mouse_sensitivity"] = _original_settings.get("mouse_sensitivity", DEFAULT_BASIC_SETTINGS["mouse_sensitivity"])
	settings["fullscreen"] = _original_settings.get("fullscreen", DEFAULT_BASIC_SETTINGS["fullscreen"])
	settings["vsync"] = _original_settings.get("vsync", DEFAULT_BASIC_SETTINGS["vsync"])
	settings["window_mode"] = _original_settings.get("window_mode", DEFAULT_BASIC_SETTINGS["window_mode"])
	settings["resolution_index"] = _original_settings.get("resolution_index", DEFAULT_RESOLUTION_INDEX)
	settings["locale"] = _original_settings.get("locale", DEFAULT_BASIC_SETTINGS["locale"])
	settings["developer_mode_enabled"] = _original_settings.get("developer_mode_enabled", DEFAULT_BASIC_SETTINGS["developer_mode_enabled"])
	settings["lighting_enabled"] = _original_settings.get("lighting_enabled", DEFAULT_BASIC_SETTINGS["lighting_enabled"])
	settings["slider_wheel_on_slider"] = _original_settings.get("slider_wheel_on_slider", DEFAULT_BASIC_SETTINGS["slider_wheel_on_slider"])
	settings["mobile_deadzone"] = _original_settings.get("mobile_deadzone", DEFAULT_BASIC_SETTINGS["mobile_deadzone"])
	settings["mobile_target_search_angle"] = _original_settings.get("mobile_target_search_angle", DEFAULT_BASIC_SETTINGS["mobile_target_search_angle"])
	settings["mobile_show_deadzone_ring"] = _original_settings.get("mobile_show_deadzone_ring", DEFAULT_BASIC_SETTINGS["mobile_show_deadzone_ring"])
	settings["mobile_show_aim_line"] = _original_settings.get("mobile_show_aim_line", DEFAULT_BASIC_SETTINGS["mobile_show_aim_line"])
	settings["mobile_lock_on_sound_enabled"] = _original_settings.get("mobile_lock_on_sound_enabled", DEFAULT_BASIC_SETTINGS["mobile_lock_on_sound_enabled"])
	settings["resolution_width"] = window_size.x
	settings["resolution_height"] = window_size.y

	SaveManager.save_settings(settings)


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
		tab_container.set_tab_title(2, LocalizationManager.tr("ui.settings.tab.ui"))

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

	_update_reset_button_text()


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


func _on_tab_changed(_tab: int) -> void:
	_update_reset_button_text()


func show_panel() -> void:
	"""显示面板（带淡入动画）"""
	_ensure_crosshair_settings_panel()
	_load_settings()
	_apply_localized_texts()
	if is_instance_valid(_crosshair_settings_panel) and _crosshair_settings_panel.has_method("refresh_panel_state"):
		_crosshair_settings_panel.call("refresh_panel_state")
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
	_localized_text_binder.bind_node("slider_wheel_on_slider_text", slider_wheel_on_slider_check, "ui.settings.slider_wheel_on_slider")
	_localized_text_binder.bind_node("back_text", back_button, "ui.main_menu.button.back")
	_localized_text_binder.bind_node("save_text", save_button, "ui.settings.button.save")
	_localized_text_binder.bind_node("cancel_text", cancel_button, "ui.settings.button.cancel")

	_localized_text_binder.start()
	_update_reset_button_text()


func _on_crosshair_unsaved_changes_changed(has_unsaved: bool) -> void:
	"""处理准星面板的未保存更改信号"""
	if has_unsaved and not _has_unsaved_changes:
		# 准星有更改，标记整体有未保存更改
		_mark_as_changed()


func _update_reset_button_text() -> void:
	if reset_page_button == null or tab_container == null or LocalizationManager == null:
		return

	var page_name := LocalizationManager.tr("ui.settings.tab.basic")
	if tab_container.current_tab == 1:
		page_name = LocalizationManager.tr("ui.settings.tab.crosshair")
	elif tab_container.current_tab == 2:
		page_name = LocalizationManager.tr("ui.settings.tab.ui")

	var template := LocalizationManager.tr("ui.settings.restore_page_defaults")
	reset_page_button.text = template.replace("{page}", page_name)


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

	# 连接准星面板的未保存更改信号
	if _crosshair_settings_panel.has_signal("unsaved_changes_changed"):
		_crosshair_settings_panel.unsaved_changes_changed.connect(_on_crosshair_unsaved_changes_changed)

	crosshair_panel_host.add_child(_crosshair_settings_panel)
