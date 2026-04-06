extends GutTest

const SettingsPanelClass = preload("res://src/ui/settings_panel.gd")


class SettingsPanelSpy:
	extends SettingsPanelClass

	var stubbed_settings: Dictionary = {}

	func _get_saved_settings() -> Dictionary:
		return stubbed_settings.duplicate(true)


var _panel: SettingsPanelSpy


func before_each() -> void:
	_panel = autofree(SettingsPanelSpy.new())

	_panel.volume_slider = autofree(HSlider.new())
	_panel.ui_slider = autofree(HSlider.new())
	_panel.window_mode_option = autofree(OptionButton.new())
	_panel.vsync_check = autofree(CheckBox.new())

	for mode_name in ["Windowed", "Fullscreen", "Borderless"]:
		_panel.window_mode_option.add_item(mode_name)


func test_empty_settings_clear_loading_guard_and_allow_guarded_save_handlers() -> void:
	_panel.stubbed_settings = {}

	_panel._load_settings()

	assert_false(_panel._is_loading_settings, "Empty settings path should release the loading guard")

	_panel._on_volume_changed(55.0)

	assert_true(_panel._has_unsaved_changes, "Volume edits after empty settings load should be tracked as unsaved changes")
	assert_eq(_panel._pending_settings.get("master_volume"), 0.55, "Volume edits should be staged into pending settings")


func test_non_empty_settings_load_still_updates_controls_and_clears_guard() -> void:
	_panel.stubbed_settings = {
		"master_volume": 0.42,
		"ui_volume": 0.65,
		"window_mode": 2,
		"vsync": false,
	}

	_panel._load_settings()

	assert_eq(_panel.volume_slider.value, 42.0, "Master volume should still load into the slider")
	assert_eq(_panel.ui_slider.value, 65.0, "UI volume should still load into the slider")
	assert_eq(_panel.window_mode_option.selected, 2, "Window mode should still load normally")
	assert_false(_panel.vsync_check.button_pressed, "VSync state should still load normally")
	assert_false(_panel._is_loading_settings, "Non-empty settings path should also release the loading guard")
	assert_true(_panel._pending_settings.is_empty(), "Loading settings should not stage pending changes")
