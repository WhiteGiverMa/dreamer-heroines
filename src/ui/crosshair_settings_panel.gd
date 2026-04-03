class_name CrosshairSettingsPanel
extends Panel

signal unsaved_changes_changed(has_unsaved_changes: bool)

const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")
const TooltipTriggerClass = preload("res://src/ui/tooltip_trigger.gd")
const SliderValueInputClass = preload("res://src/ui/slider_value_input.gd")

const SHAPE_VALUES: Array[String] = ["cross", "dot", "circle", "combined"]
const COLOR_MODE_VALUES: Array[String] = ["preset", "custom"]
const COLOR_PRESET_VALUES: Array[String] = ["white", "green", "yellow", "cyan", "red", "magenta", "blue", "orange"]
const HIT_FEEDBACK_STACKING_MODE_VALUES: Array[String] = ["replace", "stack", "ignore_new"]

# Localization keys for option values
const SHAPE_KEYS: Array[String] = [
	"ui.settings.crosshair.shape.cross",
	"ui.settings.crosshair.shape.dot",
	"ui.settings.crosshair.shape.circle",
	"ui.settings.crosshair.shape.combined",
]
const COLOR_MODE_KEYS: Array[String] = [
	"ui.settings.crosshair.color_mode.preset",
	"ui.settings.crosshair.color_mode.custom",
]
const COLOR_PRESET_KEYS: Array[String] = [
	"ui.settings.crosshair.color_preset.white",
	"ui.settings.crosshair.color_preset.green",
	"ui.settings.crosshair.color_preset.yellow",
	"ui.settings.crosshair.color_preset.cyan",
	"ui.settings.crosshair.color_preset.red",
	"ui.settings.crosshair.color_preset.magenta",
	"ui.settings.crosshair.color_preset.blue",
	"ui.settings.crosshair.color_preset.orange",
]
const STACKING_MODE_KEYS: Array[String] = [
	"ui.settings.crosshair.stacking_mode.replace",
	"ui.settings.crosshair.stacking_mode.stack",
	"ui.settings.crosshair.stacking_mode.ignore_new",
]

@onready var shape_option: OptionButton = %ShapeOption
@onready var size_slider: HSlider = %SizeSlider
@onready var alpha_slider: HSlider = %AlphaSlider
@onready var t_shape_check: CheckBox = %TShapeCheck
@onready var color_mode_option: OptionButton = %ColorModeOption
@onready var color_preset_option: OptionButton = %ColorPresetOption
@onready var custom_color_r_slider: HSlider = %CustomColorRSlider
@onready var custom_color_g_slider: HSlider = %CustomColorGSlider
@onready var custom_color_b_slider: HSlider = %CustomColorBSlider
@onready var line_length_slider: HSlider = %LineLengthSlider
@onready var line_thickness_slider: HSlider = %LineThicknessSlider
@onready var line_gap_slider: HSlider = %LineGapSlider
@onready var outline_enabled_check: CheckBox = %OutlineEnabledCheck
@onready var outline_thickness_slider: HSlider = %OutlineThicknessSlider
@onready var outline_color_r_slider: HSlider = %OutlineColorRSlider
@onready var outline_color_g_slider: HSlider = %OutlineColorGSlider
@onready var outline_color_b_slider: HSlider = %OutlineColorBSlider
@onready var center_dot_enabled_check: CheckBox = %CenterDotEnabledCheck
@onready var center_dot_size_slider: HSlider = %CenterDotSizeSlider
@onready var center_dot_alpha_slider: HSlider = %CenterDotAlphaSlider
@onready var dynamic_spread_check: CheckBox = %DynamicSpreadCheck
@onready var spread_increase_slider: HSlider = %SpreadIncreaseSlider
@onready var recovery_rate_slider: HSlider = %RecoveryRateSlider
@onready var max_spread_multiplier_slider: HSlider = %MaxSpreadMultiplierSlider
@onready var hit_feedback_enabled_check: CheckBox = %HitFeedbackEnabledCheck
@onready var hit_feedback_duration_slider: HSlider = %HitFeedbackDurationSlider
@onready var hit_feedback_scale_slider: HSlider = %HitFeedbackScaleSlider
@onready var hit_feedback_intensity_slider: HSlider = %HitFeedbackIntensitySlider
@onready var hit_feedback_expand_ratio_slider: HSlider = %HitFeedbackExpandRatioSlider
@onready var hit_feedback_pulse_speed_slider: HSlider = %HitFeedbackPulseSpeedSlider
@onready var hit_feedback_max_stacks_slider: HSlider = %HitFeedbackMaxStacksSlider
@onready var hit_feedback_stacking_mode_option: OptionButton = %HitFeedbackStackingModeOption
@onready var scroll_container: ScrollContainer = $MarginContainer/ScrollContainer

# Section title labels
@onready var shape_section_title: Label = $MarginContainer/ScrollContainer/Content/ShapeSection/SectionTitle
@onready var color_section_title: Label = $MarginContainer/ScrollContainer/Content/ColorSection/SectionTitle
@onready var line_section_title: Label = $MarginContainer/ScrollContainer/Content/LineSection/SectionTitle
@onready var outline_section_title: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/SectionTitle
@onready var center_dot_section_title: Label = $MarginContainer/ScrollContainer/Content/CenterDotSection/SectionTitle
@onready var spread_section_title: Label = $MarginContainer/ScrollContainer/Content/SpreadSection/SectionTitle
@onready var hit_feedback_section_title: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/SectionTitle

# Field labels
@onready var shape_label: Label = $MarginContainer/ScrollContainer/Content/ShapeSection/Grid/ShapeLabel
@onready var size_label: Label = $MarginContainer/ScrollContainer/Content/ShapeSection/Grid/SizeLabel
@onready var alpha_label: Label = $MarginContainer/ScrollContainer/Content/ShapeSection/Grid/AlphaLabel
@onready var t_shape_label: Label = $MarginContainer/ScrollContainer/Content/ShapeSection/Grid/TShapeLabel
@onready var color_mode_label: Label = $MarginContainer/ScrollContainer/Content/ColorSection/Grid/ColorModeLabel
@onready var color_preset_label: Label = $MarginContainer/ScrollContainer/Content/ColorSection/Grid/ColorPresetLabel
@onready var custom_color_r_label: Label = $MarginContainer/ScrollContainer/Content/ColorSection/Grid/CustomColorRLabel
@onready var custom_color_g_label: Label = $MarginContainer/ScrollContainer/Content/ColorSection/Grid/CustomColorGLabel
@onready var custom_color_b_label: Label = $MarginContainer/ScrollContainer/Content/ColorSection/Grid/CustomColorBLabel
@onready var line_length_label: Label = $MarginContainer/ScrollContainer/Content/LineSection/Grid/LineLengthLabel
@onready var line_thickness_label: Label = $MarginContainer/ScrollContainer/Content/LineSection/Grid/LineThicknessLabel
@onready var line_gap_label: Label = $MarginContainer/ScrollContainer/Content/LineSection/Grid/LineGapLabel
@onready var outline_enabled_label: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/Grid/OutlineEnabledLabel
@onready var outline_thickness_label: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/Grid/OutlineThicknessLabel
@onready var outline_color_r_label: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/Grid/OutlineColorRLabel
@onready var outline_color_g_label: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/Grid/OutlineColorGLabel
@onready var outline_color_b_label: Label = $MarginContainer/ScrollContainer/Content/OutlineSection/Grid/OutlineColorBLabel
@onready var center_dot_enabled_label: Label = $MarginContainer/ScrollContainer/Content/CenterDotSection/Grid/CenterDotEnabledLabel
@onready var center_dot_size_label: Label = $MarginContainer/ScrollContainer/Content/CenterDotSection/Grid/CenterDotSizeLabel
@onready var center_dot_alpha_label: Label = $MarginContainer/ScrollContainer/Content/CenterDotSection/Grid/CenterDotAlphaLabel
@onready var dynamic_spread_label: Label = $MarginContainer/ScrollContainer/Content/SpreadSection/Grid/DynamicSpreadLabel
@onready var spread_increase_label: Label = $MarginContainer/ScrollContainer/Content/SpreadSection/Grid/SpreadIncreaseLabel
@onready var recovery_rate_label: Label = $MarginContainer/ScrollContainer/Content/SpreadSection/Grid/RecoveryRateLabel
@onready var max_spread_multiplier_label: Label = $MarginContainer/ScrollContainer/Content/SpreadSection/Grid/MaxSpreadMultiplierLabel
@onready var hit_feedback_enabled_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackEnabledLabel
@onready var hit_feedback_duration_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackDurationLabel
@onready var hit_feedback_scale_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackScaleLabel
@onready var hit_feedback_intensity_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackIntensityLabel
@onready var hit_feedback_expand_ratio_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackExpandRatioLabel
@onready var hit_feedback_pulse_speed_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackPulseSpeedLabel
@onready var hit_feedback_max_stacks_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackMaxStacksLabel
@onready var hit_feedback_stacking_mode_label: Label = $MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackStackingModeLabel

var _is_refreshing_controls: bool = false
var _localized_text_binder = null
var _slider_value_inputs: Dictionary = {}

# 暂存系统 - 用于保存/取消功能
var _pending_settings: Dictionary = {}
var _original_settings: CrosshairSettings = null
var _has_unsaved_changes: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_locale_changed()
	_configure_slider_ranges()
	_setup_slider_value_inputs()
	_populate_option_buttons()
	_connect_control_signals()
	_connect_service_signals()
	_configure_scroll_behavior()
	if CrosshairSettingsService:
		CrosshairSettingsService.reload_settings()
		var settings = CrosshairSettingsService.get_settings()
		# 防御性检查：确保获取到正确的类型
		if settings is CrosshairSettings:
			_original_settings = settings
		else:
			push_error("[CrosshairSettingsPanel] get_settings() returned wrong type in _ready: %s" % typeof(settings))
	_refresh_from_service()
	_setup_localized_bindings()
	_setup_tooltips()
	_apply_localized_texts()


func refresh_panel_state() -> void:
	"""刷新面板状态并重置暂存系统"""
	if CrosshairSettingsService:
		CrosshairSettingsService.reload_settings()
	_reset_pending_system()
	_refresh_from_service()
	_apply_localized_texts()


func _connect_locale_changed() -> void:
	if not LocalizationManager:
		return
	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	_apply_localized_texts()
	_refresh_option_button_texts()


func _connect_service_signals() -> void:
	if not CrosshairSettingsService:
		push_warning("[CrosshairSettingsPanel] CrosshairSettingsService is unavailable")
		return

	if not CrosshairSettingsService.settings_changed.is_connected(_on_settings_changed):
		CrosshairSettingsService.settings_changed.connect(_on_settings_changed)

	if not CrosshairSettingsService.settings_loaded.is_connected(_on_settings_changed):
		CrosshairSettingsService.settings_loaded.connect(_on_settings_changed)


func _populate_option_buttons() -> void:
	_populate_option_button_with_keys(shape_option, SHAPE_VALUES, SHAPE_KEYS)
	_populate_option_button_with_keys(color_mode_option, COLOR_MODE_VALUES, COLOR_MODE_KEYS)
	_populate_option_button_with_keys(color_preset_option, COLOR_PRESET_VALUES, COLOR_PRESET_KEYS)
	_populate_option_button_with_keys(hit_feedback_stacking_mode_option, HIT_FEEDBACK_STACKING_MODE_VALUES, STACKING_MODE_KEYS)


func _populate_option_button_with_keys(option_button: OptionButton, values: Array[String], keys: Array[String]) -> void:
	option_button.clear()
	for i in range(values.size()):
		var localized_text := _tr(keys[i]) if i < keys.size() else _prettify_label(values[i])
		option_button.add_item(localized_text)


func _refresh_option_button_texts() -> void:
	_refresh_option_button_with_keys(shape_option, SHAPE_VALUES, SHAPE_KEYS)
	_refresh_option_button_with_keys(color_mode_option, COLOR_MODE_VALUES, COLOR_MODE_KEYS)
	_refresh_option_button_with_keys(color_preset_option, COLOR_PRESET_VALUES, COLOR_PRESET_KEYS)
	_refresh_option_button_with_keys(hit_feedback_stacking_mode_option, HIT_FEEDBACK_STACKING_MODE_VALUES, STACKING_MODE_KEYS)


func _refresh_option_button_with_keys(option_button: OptionButton, values: Array[String], keys: Array[String]) -> void:
	var selected := option_button.selected
	for i in range(values.size()):
		if i < keys.size():
			option_button.set_item_text(i, _tr(keys[i]))
	selected = mini(selected, option_button.item_count - 1)
	if selected >= 0:
		option_button.selected = selected


func _tr(key: String) -> String:
	if LocalizationManager:
		return LocalizationManager.tr(key)
	return key


func _configure_slider_ranges() -> void:
	_configure_slider(size_slider, CrosshairSettingsService.SIZE_MIN, CrosshairSettingsService.SIZE_MAX, 0.5)
	_configure_slider(alpha_slider, CrosshairSettingsService.ALPHA_MIN, CrosshairSettingsService.ALPHA_MAX, 0.01)
	_configure_slider(custom_color_r_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(custom_color_g_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(custom_color_b_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(line_length_slider, CrosshairSettingsService.LINE_LENGTH_MIN, CrosshairSettingsService.LINE_LENGTH_MAX, 0.5)
	_configure_slider(line_thickness_slider, CrosshairSettingsService.LINE_THICKNESS_MIN, CrosshairSettingsService.LINE_THICKNESS_MAX, 0.5)
	_configure_slider(line_gap_slider, CrosshairSettingsService.LINE_GAP_MIN, CrosshairSettingsService.LINE_GAP_MAX, 0.5)
	_configure_slider(outline_thickness_slider, CrosshairSettingsService.OUTLINE_THICKNESS_MIN, CrosshairSettingsService.OUTLINE_THICKNESS_MAX, 0.5)
	_configure_slider(outline_color_r_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(outline_color_g_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(outline_color_b_slider, CrosshairSettingsService.COLOR_CHANNEL_MIN, CrosshairSettingsService.COLOR_CHANNEL_MAX, 0.01)
	_configure_slider(center_dot_size_slider, CrosshairSettingsService.DOT_SIZE_MIN, CrosshairSettingsService.DOT_SIZE_MAX, 0.5)
	_configure_slider(center_dot_alpha_slider, CrosshairSettingsService.DOT_ALPHA_MIN, CrosshairSettingsService.DOT_ALPHA_MAX, 0.01)
	_configure_slider(spread_increase_slider, CrosshairSettingsService.SPREAD_INCREASE_MIN, CrosshairSettingsService.SPREAD_INCREASE_MAX, 0.5)
	_configure_slider(recovery_rate_slider, CrosshairSettingsService.RECOVERY_RATE_MIN, CrosshairSettingsService.RECOVERY_RATE_MAX, 1.0)
	_configure_slider(max_spread_multiplier_slider, CrosshairSettingsService.MAX_SPREAD_MULTIPLIER_MIN, CrosshairSettingsService.MAX_SPREAD_MULTIPLIER_MAX, 0.1)
	_configure_slider(hit_feedback_duration_slider, CrosshairSettingsService.HIT_FEEDBACK_DURATION_MIN, CrosshairSettingsService.HIT_FEEDBACK_DURATION_MAX, 0.01)
	_configure_slider(hit_feedback_scale_slider, CrosshairSettingsService.HIT_FEEDBACK_SCALE_MIN, CrosshairSettingsService.HIT_FEEDBACK_SCALE_MAX, 0.1)
	_configure_slider(hit_feedback_intensity_slider, CrosshairSettingsService.HIT_FEEDBACK_INTENSITY_MIN, CrosshairSettingsService.HIT_FEEDBACK_INTENSITY_MAX, 0.1)
	_configure_slider(hit_feedback_expand_ratio_slider, CrosshairSettingsService.HIT_FEEDBACK_EXPAND_RATIO_MIN, CrosshairSettingsService.HIT_FEEDBACK_EXPAND_RATIO_MAX, 0.01)
	_configure_slider(hit_feedback_pulse_speed_slider, CrosshairSettingsService.HIT_FEEDBACK_PULSE_SPEED_MIN, CrosshairSettingsService.HIT_FEEDBACK_PULSE_SPEED_MAX, 0.5)
	_configure_slider(hit_feedback_max_stacks_slider, CrosshairSettingsService.HIT_FEEDBACK_MAX_STACKS_MIN, CrosshairSettingsService.HIT_FEEDBACK_MAX_STACKS_MAX, 1.0, true)


func _configure_slider(slider: HSlider, min_value: float, max_value: float, step: float, rounded: bool = false) -> void:
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.rounded = rounded


func _setup_slider_value_inputs() -> void:
	_slider_value_inputs.clear()
	_attach_slider_value_input(size_slider)
	_attach_slider_value_input(alpha_slider)
	_attach_slider_value_input(custom_color_r_slider)
	_attach_slider_value_input(custom_color_g_slider)
	_attach_slider_value_input(custom_color_b_slider)
	_attach_slider_value_input(line_length_slider)
	_attach_slider_value_input(line_thickness_slider)
	_attach_slider_value_input(line_gap_slider)
	_attach_slider_value_input(outline_thickness_slider)
	_attach_slider_value_input(outline_color_r_slider)
	_attach_slider_value_input(outline_color_g_slider)
	_attach_slider_value_input(outline_color_b_slider)
	_attach_slider_value_input(center_dot_size_slider)
	_attach_slider_value_input(center_dot_alpha_slider)
	_attach_slider_value_input(spread_increase_slider)
	_attach_slider_value_input(recovery_rate_slider)
	_attach_slider_value_input(max_spread_multiplier_slider)
	_attach_slider_value_input(hit_feedback_duration_slider)
	_attach_slider_value_input(hit_feedback_scale_slider)
	_attach_slider_value_input(hit_feedback_intensity_slider)
	_attach_slider_value_input(hit_feedback_expand_ratio_slider)
	_attach_slider_value_input(hit_feedback_pulse_speed_slider)
	_attach_slider_value_input(hit_feedback_max_stacks_slider)


func _attach_slider_value_input(slider: HSlider) -> void:
	if slider == null:
		return
	var options := _get_slider_value_input_options(slider)
	var binding = SliderValueInputClass.new().attach_to_slider(slider, options)
	if binding:
		_slider_value_inputs[slider] = binding


func _get_slider_value_input_options(slider: HSlider) -> Dictionary:
	var options := {}
	if slider == hit_feedback_max_stacks_slider:
		options["decimals"] = 0
	elif slider.step >= 1.0:
		options["decimals"] = 0
	else:
		options["decimals"] = 2

	if slider == alpha_slider or slider == center_dot_alpha_slider or \
		slider == custom_color_r_slider or slider == custom_color_g_slider or slider == custom_color_b_slider or \
		slider == outline_color_r_slider or slider == outline_color_g_slider or slider == outline_color_b_slider or \
		slider == hit_feedback_expand_ratio_slider:
		options["display_scale"] = 100.0
		options["suffix"] = "%"
	elif slider == hit_feedback_duration_slider:
		options["suffix"] = "s"

	return options


func _set_slider_row_enabled(slider: HSlider, enabled: bool) -> void:
	if slider == null:
		return
	slider.editable = enabled
	var binding = _slider_value_inputs.get(slider)
	if binding != null:
		binding.set_editable(enabled)


func _set_slider_row_visible(slider: HSlider, visible: bool) -> void:
	if slider == null:
		return
	var binding = _slider_value_inputs.get(slider)
	if binding != null:
		binding.set_visible(visible)
	else:
		slider.visible = visible


func _configure_scroll_behavior() -> void:
	if scroll_container == null:
		return

	scroll_container.follow_focus = true
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	for control: Control in _get_focus_scroll_targets():
		if control != null and not control.focus_entered.is_connected(_on_focus_target_entered.bind(control)):
			control.focus_entered.connect(_on_focus_target_entered.bind(control))
			if control is Range:
				(control as Range).scrollable = false

	for binding in _slider_value_inputs.values():
		var slider_binding = binding
		if slider_binding != null and slider_binding.line_edit != null:
			var line_edit: LineEdit = slider_binding.line_edit
			if not line_edit.focus_entered.is_connected(_on_focus_target_entered.bind(line_edit)):
				line_edit.focus_entered.connect(_on_focus_target_entered.bind(line_edit))


func _get_focus_scroll_targets() -> Array[Control]:
	return [
		shape_option,
		size_slider,
		alpha_slider,
		t_shape_check,
		color_mode_option,
		color_preset_option,
		custom_color_r_slider,
		custom_color_g_slider,
		custom_color_b_slider,
		line_length_slider,
		line_thickness_slider,
		line_gap_slider,
		outline_enabled_check,
		outline_thickness_slider,
		outline_color_r_slider,
		outline_color_g_slider,
		outline_color_b_slider,
		center_dot_enabled_check,
		center_dot_size_slider,
		center_dot_alpha_slider,
		dynamic_spread_check,
		spread_increase_slider,
		recovery_rate_slider,
		max_spread_multiplier_slider,
		hit_feedback_enabled_check,
		hit_feedback_duration_slider,
		hit_feedback_scale_slider,
		hit_feedback_intensity_slider,
		hit_feedback_expand_ratio_slider,
		hit_feedback_pulse_speed_slider,
		hit_feedback_max_stacks_slider,
		hit_feedback_stacking_mode_option,
	]


func _on_focus_target_entered(control: Control) -> void:
	if scroll_container != null and control != null:
		scroll_container.ensure_control_visible(control)


func _connect_control_signals() -> void:
	shape_option.item_selected.connect(_on_shape_selected)
	size_slider.value_changed.connect(_on_slider_value_changed.bind(&"crosshair_size"))
	alpha_slider.value_changed.connect(_on_slider_value_changed.bind(&"crosshair_alpha"))
	t_shape_check.toggled.connect(_on_toggle_changed.bind(&"use_t_shape"))
	color_mode_option.item_selected.connect(_on_color_mode_selected)
	color_preset_option.item_selected.connect(_on_color_preset_selected)
	custom_color_r_slider.value_changed.connect(_on_slider_value_changed.bind(&"custom_color_r"))
	custom_color_g_slider.value_changed.connect(_on_slider_value_changed.bind(&"custom_color_g"))
	custom_color_b_slider.value_changed.connect(_on_slider_value_changed.bind(&"custom_color_b"))
	line_length_slider.value_changed.connect(_on_slider_value_changed.bind(&"line_length"))
	line_thickness_slider.value_changed.connect(_on_slider_value_changed.bind(&"line_thickness"))
	line_gap_slider.value_changed.connect(_on_slider_value_changed.bind(&"line_gap"))
	outline_enabled_check.toggled.connect(_on_toggle_changed.bind(&"outline_enabled"))
	outline_thickness_slider.value_changed.connect(_on_slider_value_changed.bind(&"outline_thickness"))
	outline_color_r_slider.value_changed.connect(_on_slider_value_changed.bind(&"outline_color_r"))
	outline_color_g_slider.value_changed.connect(_on_slider_value_changed.bind(&"outline_color_g"))
	outline_color_b_slider.value_changed.connect(_on_slider_value_changed.bind(&"outline_color_b"))
	center_dot_enabled_check.toggled.connect(_on_toggle_changed.bind(&"show_center_dot"))
	center_dot_size_slider.value_changed.connect(_on_slider_value_changed.bind(&"center_dot_size"))
	center_dot_alpha_slider.value_changed.connect(_on_slider_value_changed.bind(&"center_dot_alpha"))
	dynamic_spread_check.toggled.connect(_on_toggle_changed.bind(&"enable_dynamic_spread"))
	spread_increase_slider.value_changed.connect(_on_slider_value_changed.bind(&"spread_increase_per_shot"))
	recovery_rate_slider.value_changed.connect(_on_slider_value_changed.bind(&"recovery_rate"))
	max_spread_multiplier_slider.value_changed.connect(_on_slider_value_changed.bind(&"max_spread_multiplier"))
	hit_feedback_enabled_check.toggled.connect(_on_toggle_changed.bind(&"hit_feedback_enabled"))
	hit_feedback_duration_slider.value_changed.connect(_on_slider_value_changed.bind(&"hit_feedback_duration"))
	hit_feedback_scale_slider.value_changed.connect(_on_slider_value_changed.bind(&"hit_feedback_scale"))
	hit_feedback_intensity_slider.value_changed.connect(_on_slider_value_changed.bind(&"hit_feedback_intensity"))
	hit_feedback_expand_ratio_slider.value_changed.connect(_on_slider_value_changed.bind(&"hit_feedback_expand_ratio"))
	hit_feedback_pulse_speed_slider.value_changed.connect(_on_slider_value_changed.bind(&"hit_feedback_pulse_speed"))
	hit_feedback_max_stacks_slider.value_changed.connect(_on_int_slider_value_changed.bind(&"hit_feedback_max_stacks"))
	hit_feedback_stacking_mode_option.item_selected.connect(_on_hit_feedback_stacking_mode_selected)


func _refresh_from_service() -> void:
	"""从服务刷新UI，同时应用暂存设置"""
	if not CrosshairSettingsService:
		return

	# 获取基础设置（服务中的当前设置或原始设置）
	var base_settings: CrosshairSettings = CrosshairSettingsService.get_settings()

	# 防御性检查：确保获取到正确的类型
	if not base_settings is CrosshairSettings:
		push_error("[CrosshairSettingsPanel] get_settings() returned wrong type: %s" % typeof(base_settings))
		return

	# 如果有暂存的更改，覆盖显示值（但这里我们不应用它们到服务）
	# UI显示：优先使用暂存值 > 服务当前值
	_is_refreshing_controls = true

	# 获取实际要显示的值（暂存值优先）
	var crosshair_shape = _pending_settings.get("crosshair_shape", base_settings.crosshair_shape)
	var crosshair_size = _pending_settings.get("crosshair_size", base_settings.crosshair_size)
	var crosshair_alpha = _pending_settings.get("crosshair_alpha", base_settings.crosshair_alpha)
	var use_t_shape = _pending_settings.get("use_t_shape", base_settings.use_t_shape)
	var color_mode = _pending_settings.get("color_mode", base_settings.color_mode)
	var color_preset = _pending_settings.get("color_preset", base_settings.color_preset)
	var custom_color_r = _pending_settings.get("custom_color_r", base_settings.custom_color_r)
	var custom_color_g = _pending_settings.get("custom_color_g", base_settings.custom_color_g)
	var custom_color_b = _pending_settings.get("custom_color_b", base_settings.custom_color_b)
	var line_length = _pending_settings.get("line_length", base_settings.line_length)
	var line_thickness = _pending_settings.get("line_thickness", base_settings.line_thickness)
	var line_gap = _pending_settings.get("line_gap", base_settings.line_gap)
	var outline_enabled = _pending_settings.get("outline_enabled", base_settings.outline_enabled)
	var outline_thickness = _pending_settings.get("outline_thickness", base_settings.outline_thickness)
	var outline_color_r = _pending_settings.get("outline_color_r", base_settings.outline_color_r)
	var outline_color_g = _pending_settings.get("outline_color_g", base_settings.outline_color_g)
	var outline_color_b = _pending_settings.get("outline_color_b", base_settings.outline_color_b)
	var show_center_dot = _pending_settings.get("show_center_dot", base_settings.show_center_dot)
	var center_dot_size = _pending_settings.get("center_dot_size", base_settings.center_dot_size)
	var center_dot_alpha = _pending_settings.get("center_dot_alpha", base_settings.center_dot_alpha)
	var enable_dynamic_spread = _pending_settings.get("enable_dynamic_spread", base_settings.enable_dynamic_spread)
	var spread_increase_per_shot = _pending_settings.get("spread_increase_per_shot", base_settings.spread_increase_per_shot)
	var recovery_rate = _pending_settings.get("recovery_rate", base_settings.recovery_rate)
	var max_spread_multiplier = _pending_settings.get("max_spread_multiplier", base_settings.max_spread_multiplier)
	var hit_feedback_enabled = _pending_settings.get("hit_feedback_enabled", base_settings.hit_feedback_enabled)
	var hit_feedback_duration = _pending_settings.get("hit_feedback_duration", base_settings.hit_feedback_duration)
	var hit_feedback_scale = _pending_settings.get("hit_feedback_scale", base_settings.hit_feedback_scale)
	var hit_feedback_intensity = _pending_settings.get("hit_feedback_intensity", base_settings.hit_feedback_intensity)
	var hit_feedback_expand_ratio = _pending_settings.get("hit_feedback_expand_ratio", base_settings.hit_feedback_expand_ratio)
	var hit_feedback_pulse_speed = _pending_settings.get("hit_feedback_pulse_speed", base_settings.hit_feedback_pulse_speed)
	var hit_feedback_max_stacks = _pending_settings.get("hit_feedback_max_stacks", base_settings.hit_feedback_max_stacks)
	var hit_feedback_stacking_mode = _pending_settings.get("hit_feedback_stacking_mode", base_settings.hit_feedback_stacking_mode)

	_select_option_value(shape_option, SHAPE_VALUES, crosshair_shape)
	size_slider.value = crosshair_size
	alpha_slider.value = crosshair_alpha
	t_shape_check.button_pressed = use_t_shape
	_select_option_value(color_mode_option, COLOR_MODE_VALUES, color_mode)
	_select_option_value(color_preset_option, COLOR_PRESET_VALUES, color_preset)
	custom_color_r_slider.value = custom_color_r
	custom_color_g_slider.value = custom_color_g
	custom_color_b_slider.value = custom_color_b
	line_length_slider.value = line_length
	line_thickness_slider.value = line_thickness
	line_gap_slider.value = line_gap
	outline_enabled_check.button_pressed = outline_enabled
	outline_thickness_slider.value = outline_thickness
	outline_color_r_slider.value = outline_color_r
	outline_color_g_slider.value = outline_color_g
	outline_color_b_slider.value = outline_color_b
	center_dot_enabled_check.button_pressed = show_center_dot
	center_dot_size_slider.value = center_dot_size
	center_dot_alpha_slider.value = center_dot_alpha
	dynamic_spread_check.button_pressed = enable_dynamic_spread
	spread_increase_slider.value = spread_increase_per_shot
	recovery_rate_slider.value = recovery_rate
	max_spread_multiplier_slider.value = max_spread_multiplier
	hit_feedback_enabled_check.button_pressed = hit_feedback_enabled
	hit_feedback_duration_slider.value = hit_feedback_duration
	hit_feedback_scale_slider.value = hit_feedback_scale
	hit_feedback_intensity_slider.value = hit_feedback_intensity
	hit_feedback_expand_ratio_slider.value = hit_feedback_expand_ratio
	hit_feedback_pulse_speed_slider.value = hit_feedback_pulse_speed
	hit_feedback_max_stacks_slider.value = hit_feedback_max_stacks
	_select_option_value(hit_feedback_stacking_mode_option, HIT_FEEDBACK_STACKING_MODE_VALUES, hit_feedback_stacking_mode)
	_refresh_slider_value_inputs()
	_update_color_control_state(color_mode)
	_update_outline_control_state(outline_enabled)
	_is_refreshing_controls = false


func _refresh_slider_value_inputs() -> void:
	for binding in _slider_value_inputs.values():
		var slider_binding = binding
		if slider_binding != null:
			slider_binding.refresh_from_slider()


func _select_option_value(option_button: OptionButton, values: Array[String], current_value: String) -> void:
	var selected_index := values.find(current_value)
	option_button.select(selected_index if selected_index >= 0 else 0)


func _update_color_control_state(color_mode: String) -> void:
	var preset_enabled := color_mode == "preset"
	_set_color_control_row_state(color_preset_label, color_preset_option, preset_enabled)
	color_preset_option.disabled = not preset_enabled

	_set_color_control_row_state(custom_color_r_label, custom_color_r_slider, not preset_enabled)
	_set_color_control_row_state(custom_color_g_label, custom_color_g_slider, not preset_enabled)
	_set_color_control_row_state(custom_color_b_label, custom_color_b_slider, not preset_enabled)
	_set_slider_row_visible(custom_color_r_slider, not preset_enabled)
	_set_slider_row_visible(custom_color_g_slider, not preset_enabled)
	_set_slider_row_visible(custom_color_b_slider, not preset_enabled)
	_set_slider_row_enabled(custom_color_r_slider, not preset_enabled)
	_set_slider_row_enabled(custom_color_g_slider, not preset_enabled)
	_set_slider_row_enabled(custom_color_b_slider, not preset_enabled)


func _set_color_control_row_state(label: Label, control: Control, row_visible: bool) -> void:
	label.visible = row_visible
	if control is HSlider:
		_set_slider_row_visible(control as HSlider, row_visible)
	else:
		control.visible = row_visible


func _update_outline_control_state(outline_enabled: bool) -> void:
	_set_color_control_row_state(outline_thickness_label, outline_thickness_slider, outline_enabled)
	_set_color_control_row_state(outline_color_r_label, outline_color_r_slider, outline_enabled)
	_set_color_control_row_state(outline_color_g_label, outline_color_g_slider, outline_enabled)
	_set_color_control_row_state(outline_color_b_label, outline_color_b_slider, outline_enabled)
	_set_slider_row_enabled(outline_thickness_slider, outline_enabled)
	_set_slider_row_enabled(outline_color_r_slider, outline_enabled)
	_set_slider_row_enabled(outline_color_g_slider, outline_enabled)
	_set_slider_row_enabled(outline_color_b_slider, outline_enabled)


func _on_settings_changed(_settings) -> void:
	"""当服务设置变化时刷新（通常是外部保存后）"""
	# 重新加载时，重置暂存系统
	_reset_pending_system()
	_refresh_from_service()


func _reset_pending_system() -> void:
	"""重置暂存系统"""
	_pending_settings.clear()
	var had_unsaved_changes := _has_unsaved_changes
	_has_unsaved_changes = false
	if had_unsaved_changes:
		unsaved_changes_changed.emit(false)

	if CrosshairSettingsService:
		var settings = CrosshairSettingsService.get_settings()
		# 防御性检查：确保获取到正确的类型
		if settings is CrosshairSettings:
			_original_settings = settings
		else:
			push_error("[CrosshairSettingsPanel] get_settings() returned wrong type in _reset_pending_system: %s" % typeof(settings))


func _mark_as_changed() -> void:
	"""标记有未保存的更改"""
	if not _has_unsaved_changes:
		_has_unsaved_changes = true
		unsaved_changes_changed.emit(true)


func save_pending_changes() -> void:
	"""保存暂存的更改到服务"""
	if _pending_settings.is_empty() or not CrosshairSettingsService:
		if _has_unsaved_changes:
			_has_unsaved_changes = false
			unsaved_changes_changed.emit(false)
		return

	# 应用到服务
	for key in _pending_settings.keys():
		CrosshairSettingsService.update_setting(key, _pending_settings[key])
		# 更新原始设置
		if _original_settings:
			_original_settings.set(key, _pending_settings[key])

	_pending_settings.clear()
	if _has_unsaved_changes:
		_has_unsaved_changes = false
		unsaved_changes_changed.emit(false)
	print("[CrosshairSettingsPanel] Crosshair settings saved")


func cancel_pending_changes() -> void:
	"""取消暂存的更改，恢复原始设置"""
	if _pending_settings.is_empty():
		if _has_unsaved_changes:
			_has_unsaved_changes = false
			unsaved_changes_changed.emit(false)
		return

	_pending_settings.clear()
	if _has_unsaved_changes:
		_has_unsaved_changes = false
		unsaved_changes_changed.emit(false)

	# 恢复UI到原始设置
	_refresh_from_service()
	print("[CrosshairSettingsPanel] Crosshair changes cancelled")


func restore_to_defaults_pending() -> void:
	"""恢复默认设置（暂存模式）"""
	if not CrosshairSettingsService:
		return

	# 使用 CrosshairSettingsResource 获取默认值
	var CrosshairSettingsResource = load("res://src/data/crosshair_settings.gd")
	var defaults = CrosshairSettingsResource.DEFAULT_VALUES

	# 将所有可设置属性设为默认值
	for key in defaults.keys():
		_pending_settings[key] = defaults[key]

	_mark_as_changed()
	_refresh_from_service()  # 更新UI显示
	print("[CrosshairSettingsPanel] Restore to defaults pending")


func _on_slider_value_changed(value: float, property_name: StringName) -> void:
	"""处理滑块值变化 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	_pending_settings[property_name] = value
	_mark_as_changed()


func _on_int_slider_value_changed(value: float, property_name: StringName) -> void:
	"""处理整数滑块值变化 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	_pending_settings[property_name] = int(round(value))
	_mark_as_changed()


func _on_toggle_changed(enabled: bool, property_name: StringName) -> void:
	"""处理复选框切换 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	if property_name == &"outline_enabled":
		_update_outline_control_state(enabled)

	_pending_settings[property_name] = enabled
	_mark_as_changed()


func _on_shape_selected(index: int) -> void:
	"""处理准星形状选择 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	_pending_settings[&"crosshair_shape"] = SHAPE_VALUES[index]
	_mark_as_changed()


func _on_color_mode_selected(index: int) -> void:
	"""处理颜色模式选择 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	var color_mode := COLOR_MODE_VALUES[index]
	_update_color_control_state(color_mode)
	_pending_settings[&"color_mode"] = color_mode
	_mark_as_changed()


func _on_color_preset_selected(index: int) -> void:
	"""处理颜色预设选择 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	_pending_settings[&"color_preset"] = COLOR_PRESET_VALUES[index]
	_mark_as_changed()


func _on_hit_feedback_stacking_mode_selected(index: int) -> void:
	"""处理击中反馈堆叠模式选择 - 暂存到_pending_settings"""
	if _is_refreshing_controls:
		return

	_pending_settings[&"hit_feedback_stacking_mode"] = HIT_FEEDBACK_STACKING_MODE_VALUES[index]
	_mark_as_changed()


func _prettify_label(value: String) -> String:
	return value.replace("_", " ").capitalize()


func _setup_localized_bindings() -> void:
	_localized_text_binder = LocalizedTextBinderClass.new(self)

	# Section titles
	_localized_text_binder.bind_node("shape_section_title", shape_section_title, "ui.settings.crosshair.section.shape")
	_localized_text_binder.bind_node("color_section_title", color_section_title, "ui.settings.crosshair.section.color")
	_localized_text_binder.bind_node("line_section_title", line_section_title, "ui.settings.crosshair.section.line")
	_localized_text_binder.bind_node("outline_section_title", outline_section_title, "ui.settings.crosshair.section.outline")
	_localized_text_binder.bind_node("center_dot_section_title", center_dot_section_title, "ui.settings.crosshair.section.center_dot")
	_localized_text_binder.bind_node("spread_section_title", spread_section_title, "ui.settings.crosshair.section.spread")
	_localized_text_binder.bind_node("hit_feedback_section_title", hit_feedback_section_title, "ui.settings.crosshair.section.hit_feedback")

	# Shape section labels
	_localized_text_binder.bind_node("shape_label", shape_label, "ui.settings.crosshair.shape.label")
	_localized_text_binder.bind_node("size_label", size_label, "ui.settings.crosshair.size.label")
	_localized_text_binder.bind_node("alpha_label", alpha_label, "ui.settings.crosshair.alpha.label")
	_localized_text_binder.bind_node("t_shape_label", t_shape_label, "ui.settings.crosshair.t_shape.label")

	# Color section labels
	_localized_text_binder.bind_node("color_mode_label", color_mode_label, "ui.settings.crosshair.color_mode.label")
	_localized_text_binder.bind_node("color_preset_label", color_preset_label, "ui.settings.crosshair.color_preset.label")
	_localized_text_binder.bind_node("custom_color_r_label", custom_color_r_label, "ui.settings.crosshair.custom_red.label")
	_localized_text_binder.bind_node("custom_color_g_label", custom_color_g_label, "ui.settings.crosshair.custom_green.label")
	_localized_text_binder.bind_node("custom_color_b_label", custom_color_b_label, "ui.settings.crosshair.custom_blue.label")

	# Line section labels
	_localized_text_binder.bind_node("line_length_label", line_length_label, "ui.settings.crosshair.line_length.label")
	_localized_text_binder.bind_node("line_thickness_label", line_thickness_label, "ui.settings.crosshair.line_thickness.label")
	_localized_text_binder.bind_node("line_gap_label", line_gap_label, "ui.settings.crosshair.line_gap.label")

	# Outline section labels
	_localized_text_binder.bind_node("outline_enabled_label", outline_enabled_label, "ui.settings.crosshair.outline_enabled.label")
	_localized_text_binder.bind_node("outline_thickness_label", outline_thickness_label, "ui.settings.crosshair.outline_thickness.label")
	_localized_text_binder.bind_node("outline_color_r_label", outline_color_r_label, "ui.settings.crosshair.outline_red.label")
	_localized_text_binder.bind_node("outline_color_g_label", outline_color_g_label, "ui.settings.crosshair.outline_green.label")
	_localized_text_binder.bind_node("outline_color_b_label", outline_color_b_label, "ui.settings.crosshair.outline_blue.label")

	# Center dot section labels
	_localized_text_binder.bind_node("center_dot_enabled_label", center_dot_enabled_label, "ui.settings.crosshair.center_dot_enabled.label")
	_localized_text_binder.bind_node("center_dot_size_label", center_dot_size_label, "ui.settings.crosshair.center_dot_size.label")
	_localized_text_binder.bind_node("center_dot_alpha_label", center_dot_alpha_label, "ui.settings.crosshair.center_dot_alpha.label")

	# Spread section labels
	_localized_text_binder.bind_node("dynamic_spread_label", dynamic_spread_label, "ui.settings.crosshair.dynamic_spread.label")
	_localized_text_binder.bind_node("spread_increase_label", spread_increase_label, "ui.settings.crosshair.spread_increase.label")
	_localized_text_binder.bind_node("recovery_rate_label", recovery_rate_label, "ui.settings.crosshair.recovery_rate.label")
	_localized_text_binder.bind_node("max_spread_multiplier_label", max_spread_multiplier_label, "ui.settings.crosshair.max_spread_multiplier.label")

	# Hit feedback section labels
	_localized_text_binder.bind_node("hit_feedback_enabled_label", hit_feedback_enabled_label, "ui.settings.crosshair.hit_feedback_enabled.label")
	_localized_text_binder.bind_node("hit_feedback_duration_label", hit_feedback_duration_label, "ui.settings.crosshair.hit_feedback_duration.label")
	_localized_text_binder.bind_node("hit_feedback_scale_label", hit_feedback_scale_label, "ui.settings.crosshair.hit_feedback_scale.label")
	_localized_text_binder.bind_node("hit_feedback_intensity_label", hit_feedback_intensity_label, "ui.settings.crosshair.hit_feedback_intensity.label")
	_localized_text_binder.bind_node("hit_feedback_expand_ratio_label", hit_feedback_expand_ratio_label, "ui.settings.crosshair.hit_feedback_expand_ratio.label")
	_localized_text_binder.bind_node("hit_feedback_pulse_speed_label", hit_feedback_pulse_speed_label, "ui.settings.crosshair.hit_feedback_pulse_speed.label")
	_localized_text_binder.bind_node("hit_feedback_max_stacks_label", hit_feedback_max_stacks_label, "ui.settings.crosshair.hit_feedback_max_stacks.label")
	_localized_text_binder.bind_node("hit_feedback_stacking_mode_label", hit_feedback_stacking_mode_label, "ui.settings.crosshair.hit_feedback_stacking_mode.label")

	_localized_text_binder.start()


func _setup_tooltips() -> void:
	_attach_tooltip_pair(t_shape_label, t_shape_check, "ui.settings.crosshair.tooltip.t_shape")
	_attach_tooltip_pair(color_mode_label, color_mode_option, "ui.settings.crosshair.tooltip.color_mode")
	_attach_tooltip_pair(line_gap_label, line_gap_slider, "ui.settings.crosshair.tooltip.line_gap")
	_attach_tooltip_pair(outline_enabled_label, outline_enabled_check, "ui.settings.crosshair.tooltip.outline")
	_attach_tooltip_pair(dynamic_spread_label, dynamic_spread_check, "ui.settings.crosshair.tooltip.dynamic_spread")
	_attach_tooltip_pair(hit_feedback_enabled_label, hit_feedback_enabled_check, "ui.settings.crosshair.tooltip.hit_feedback")
	_attach_tooltip_pair(hit_feedback_duration_label, hit_feedback_duration_slider, "ui.settings.crosshair.tooltip.hit_feedback_duration")
	_attach_tooltip_pair(hit_feedback_scale_label, hit_feedback_scale_slider, "ui.settings.crosshair.tooltip.hit_feedback_scale")
	_attach_tooltip_pair(hit_feedback_expand_ratio_label, hit_feedback_expand_ratio_slider, "ui.settings.crosshair.tooltip.hit_feedback_expand_ratio")
	_attach_tooltip_pair(hit_feedback_pulse_speed_label, hit_feedback_pulse_speed_slider, "ui.settings.crosshair.tooltip.hit_feedback_pulse_speed")
	_attach_tooltip_pair(hit_feedback_max_stacks_label, hit_feedback_max_stacks_slider, "ui.settings.crosshair.tooltip.hit_feedback_max_stacks")
	_attach_tooltip_pair(hit_feedback_stacking_mode_label, hit_feedback_stacking_mode_option, "ui.settings.crosshair.tooltip.hit_feedback_stacking_mode")


func _attach_tooltip_pair(label: Control, control: Control, translation_key: String) -> void:
	_attach_tooltip(label, translation_key)
	_attach_tooltip(control, translation_key)


func _attach_tooltip(target: Control, translation_key: String) -> void:
	if target == null or translation_key.is_empty():
		return

	for child in target.get_children():
		if child is TooltipTrigger:
			var existing_trigger := child as TooltipTrigger
			existing_trigger.tooltip_translation_key = translation_key
			return

	var trigger := TooltipTriggerClass.new()
	trigger.tooltip_translation_key = translation_key
	target.add_child(trigger)


func _apply_localized_texts() -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh_all()
