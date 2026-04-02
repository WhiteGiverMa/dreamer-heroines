class_name CrosshairSettingsPanel
extends PanelContainer

const LocalizedTextBinderClass = preload("res://src/ui/localized_text_binder.gd")

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_connect_locale_changed()
	_configure_slider_ranges()
	_populate_option_buttons()
	_connect_control_signals()
	_connect_service_signals()
	if CrosshairSettingsService:
		CrosshairSettingsService.reload_settings()
	_refresh_from_service()
	_setup_localized_bindings()


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
	if not CrosshairSettingsService:
		return

	var settings = CrosshairSettingsService.get_settings()
	_is_refreshing_controls = true

	_select_option_value(shape_option, SHAPE_VALUES, settings.crosshair_shape)
	size_slider.value = settings.crosshair_size
	alpha_slider.value = settings.crosshair_alpha
	t_shape_check.button_pressed = settings.use_t_shape
	_select_option_value(color_mode_option, COLOR_MODE_VALUES, settings.color_mode)
	_select_option_value(color_preset_option, COLOR_PRESET_VALUES, settings.color_preset)
	custom_color_r_slider.value = settings.custom_color_r
	custom_color_g_slider.value = settings.custom_color_g
	custom_color_b_slider.value = settings.custom_color_b
	line_length_slider.value = settings.line_length
	line_thickness_slider.value = settings.line_thickness
	line_gap_slider.value = settings.line_gap
	outline_enabled_check.button_pressed = settings.outline_enabled
	outline_thickness_slider.value = settings.outline_thickness
	outline_color_r_slider.value = settings.outline_color_r
	outline_color_g_slider.value = settings.outline_color_g
	outline_color_b_slider.value = settings.outline_color_b
	center_dot_enabled_check.button_pressed = settings.show_center_dot
	center_dot_size_slider.value = settings.center_dot_size
	center_dot_alpha_slider.value = settings.center_dot_alpha
	dynamic_spread_check.button_pressed = settings.enable_dynamic_spread
	spread_increase_slider.value = settings.spread_increase_per_shot
	recovery_rate_slider.value = settings.recovery_rate
	max_spread_multiplier_slider.value = settings.max_spread_multiplier
	hit_feedback_enabled_check.button_pressed = settings.hit_feedback_enabled
	hit_feedback_duration_slider.value = settings.hit_feedback_duration
	hit_feedback_scale_slider.value = settings.hit_feedback_scale
	hit_feedback_intensity_slider.value = settings.hit_feedback_intensity
	hit_feedback_expand_ratio_slider.value = settings.hit_feedback_expand_ratio
	hit_feedback_pulse_speed_slider.value = settings.hit_feedback_pulse_speed
	hit_feedback_max_stacks_slider.value = settings.hit_feedback_max_stacks
	_select_option_value(hit_feedback_stacking_mode_option, HIT_FEEDBACK_STACKING_MODE_VALUES, settings.hit_feedback_stacking_mode)
	_update_color_control_state(settings.color_mode)
	_update_outline_control_state(settings.outline_enabled)
	_is_refreshing_controls = false


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
	custom_color_r_slider.editable = not preset_enabled
	custom_color_g_slider.editable = not preset_enabled
	custom_color_b_slider.editable = not preset_enabled


func _set_color_control_row_state(label: Label, control: Control, row_visible: bool) -> void:
	label.visible = row_visible
	control.visible = row_visible


func _update_outline_control_state(outline_enabled: bool) -> void:
	_set_color_control_row_state(outline_thickness_label, outline_thickness_slider, outline_enabled)
	_set_color_control_row_state(outline_color_r_label, outline_color_r_slider, outline_enabled)
	_set_color_control_row_state(outline_color_g_label, outline_color_g_slider, outline_enabled)
	_set_color_control_row_state(outline_color_b_label, outline_color_b_slider, outline_enabled)
	outline_thickness_slider.editable = outline_enabled
	outline_color_r_slider.editable = outline_enabled
	outline_color_g_slider.editable = outline_enabled
	outline_color_b_slider.editable = outline_enabled


func _on_settings_changed(_settings) -> void:
	_refresh_from_service()


func _on_slider_value_changed(value: float, property_name: StringName) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	CrosshairSettingsService.update_setting(property_name, value)


func _on_int_slider_value_changed(value: float, property_name: StringName) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	CrosshairSettingsService.update_setting(property_name, int(round(value)))


func _on_toggle_changed(enabled: bool, property_name: StringName) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	if property_name == &"outline_enabled":
		_update_outline_control_state(enabled)

	CrosshairSettingsService.update_setting(property_name, enabled)


func _on_shape_selected(index: int) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	CrosshairSettingsService.update_setting(&"crosshair_shape", SHAPE_VALUES[index])


func _on_color_mode_selected(index: int) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	var color_mode := COLOR_MODE_VALUES[index]
	_update_color_control_state(color_mode)
	CrosshairSettingsService.update_setting(&"color_mode", color_mode)


func _on_color_preset_selected(index: int) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	CrosshairSettingsService.update_setting(&"color_preset", COLOR_PRESET_VALUES[index])


func _on_hit_feedback_stacking_mode_selected(index: int) -> void:
	if _is_refreshing_controls or not CrosshairSettingsService:
		return

	CrosshairSettingsService.update_setting(&"hit_feedback_stacking_mode", HIT_FEEDBACK_STACKING_MODE_VALUES[index])


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


func _apply_localized_texts() -> void:
	if _localized_text_binder:
		_localized_text_binder.refresh_all()
