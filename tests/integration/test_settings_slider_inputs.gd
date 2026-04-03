extends GutTest

const SettingsPanelScene := preload("res://scenes/ui/settings_panel.tscn")

var _panel: SettingsPanel
var _save_manager
var _original_settings: Dictionary = {}


func before_each() -> void:
	_save_manager = get_node_or_null("/root/SaveManager")
	assert_not_null(_save_manager, "SaveManager autoload should exist for settings integration tests")
	if _save_manager == null:
		return

	_original_settings = _save_manager.load_settings()
	_panel = SettingsPanelScene.instantiate() as SettingsPanel
	add_child_autofree(_panel)
	_panel.show_panel()
	await wait_process_frames(2)


func after_each() -> void:
	if _save_manager != null:
		_save_manager.save_settings(_original_settings)


func test_basic_settings_inputs_show_expected_formats_and_submit_back_to_settings() -> void:
	var volume_input := _panel.get_node_or_null("TabContainer/BasicTab/BasicScrollContainer/BasicContent/VolumeSliderContainer/VolumeSliderInput") as LineEdit
	var sensitivity_input := _panel.get_node_or_null("TabContainer/BasicTab/BasicScrollContainer/BasicContent/SensitivitySliderContainer/SensitivitySliderInput") as LineEdit

	assert_not_null(volume_input, "Volume slider should have a paired LineEdit")
	assert_not_null(sensitivity_input, "Sensitivity slider should have a paired LineEdit")
	if volume_input == null or sensitivity_input == null:
		return

	_panel.volume_slider.value = 64.0
	_panel.sensitivity_slider.value = 125.0

	assert_eq(volume_input.text, "64%", "Volume input should format slider values as percentages")
	assert_eq(sensitivity_input.text, "1.25x", "Sensitivity input should format slider values as multipliers")

	volume_input.text = "37%"
	volume_input.text_submitted.emit(volume_input.text)
	await wait_process_frames(1)

	assert_eq(_panel.volume_slider.value, 37.0, "Submitting percent text should update the backing slider")
	var saved_settings: Dictionary = _save_manager.load_settings()
	assert_almost_eq(float(saved_settings.get("master_volume", -1.0)), 0.37, 0.01,
		"Submitting percent text should persist normalized master volume")


func test_crosshair_settings_inputs_use_runtime_formatting_on_real_scene() -> void:
	_panel.tab_container.current_tab = 1
	await wait_process_frames(1)

	var crosshair_panel := _panel.get_node_or_null("TabContainer/CrosshairTab/CrosshairPanelHost/CrosshairSettingsPanel") as CrosshairSettingsPanel
	assert_not_null(crosshair_panel, "Crosshair settings panel should be instantiated inside SettingsPanel")
	if crosshair_panel == null:
		return

	var alpha_input := crosshair_panel.get_node_or_null("MarginContainer/ScrollContainer/Content/ShapeSection/Grid/AlphaSliderContainer/AlphaSliderInput") as LineEdit
	var duration_input := crosshair_panel.get_node_or_null("MarginContainer/ScrollContainer/Content/HitFeedbackSection/Grid/HitFeedbackDurationSliderContainer/HitFeedbackDurationSliderInput") as LineEdit

	assert_not_null(alpha_input, "Alpha slider should expose a percentage input field")
	assert_not_null(duration_input, "Hit feedback duration slider should expose a seconds input field")
	if alpha_input == null or duration_input == null:
		return

	crosshair_panel.alpha_slider.value = 0.42
	crosshair_panel.hit_feedback_duration_slider.value = 0.25

	assert_eq(alpha_input.text, "42%", "Alpha input should render normalized values as percentages")
	assert_eq(duration_input.text, "0.25s", "Duration input should render seconds suffix")

	alpha_input.text = "55%"
	alpha_input.text_submitted.emit(alpha_input.text)
	await wait_process_frames(1)

	assert_almost_eq(crosshair_panel.alpha_slider.value, 0.55, 0.001,
		"Submitting percentage text should convert back to fractional alpha slider value")
