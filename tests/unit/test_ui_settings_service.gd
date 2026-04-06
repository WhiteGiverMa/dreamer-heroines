extends GutTest

var ui_settings_service: Node


func before_each() -> void:
	ui_settings_service = preload("res://src/autoload/ui_settings_service.gd").new()
	add_child(ui_settings_service)
	await get_tree().process_frame


func after_each() -> void:
	if ui_settings_service:
		ui_settings_service.queue_free()


func test_default_settings() -> void:
	assert_eq(ui_settings_service.get_setting("slider_wheel_on_slider"), true, "Default slider_wheel_on_slider should be true")


func test_set_setting() -> void:
	var signal_emitted := false
	var received_value: Variant = null

	ui_settings_service.setting_changed.connect(func(key: StringName, value: Variant):
		if key == "slider_wheel_on_slider":
			signal_emitted = true
			received_value = value
	)

	ui_settings_service.set_setting("slider_wheel_on_slider", false, false)

	assert_true(signal_emitted, "setting_changed signal should emit")
	assert_eq(received_value, false, "Should receive new value")
	assert_eq(ui_settings_service.get_setting("slider_wheel_on_slider"), false, "Setting should be updated")


func test_set_setting_same_value() -> void:
	var signal_count := 0

	ui_settings_service.setting_changed.connect(func(_key: StringName, _value: Variant):
		signal_count += 1
	)

	# Set to same value (default is true)
	ui_settings_service.set_setting("slider_wheel_on_slider", true, false)

	assert_eq(signal_count, 0, "Should not emit signal when setting to same value")


func test_reset_to_defaults() -> void:
	ui_settings_service.set_setting("slider_wheel_on_slider", false, false)
	assert_eq(ui_settings_service.get_setting("slider_wheel_on_slider"), false)

	ui_settings_service.reset_to_defaults()
	assert_eq(ui_settings_service.get_setting("slider_wheel_on_slider"), true, "Should reset to default")


func test_get_settings_returns_copy() -> void:
	var settings1 := ui_settings_service.get_settings()
	var settings2 := ui_settings_service.get_settings()

	settings1["slider_wheel_on_slider"] = false

	assert_eq(settings2["slider_wheel_on_slider"], true, "Modifying returned dictionary should not affect internal state")


func test_set_unknown_setting() -> void:
	var warning_count_before := 0
	# Note: We can't easily test push_warning output in GUT, but we can verify it doesn't crash

	ui_settings_service.set_setting("unknown_setting", "value", false)

	# Should not crash and should not add the setting
	assert_eq(ui_settings_service.get_setting("unknown_setting"), null, "Unknown setting should return null")


func test_convenience_methods() -> void:
	ui_settings_service.set_slider_wheel_on_slider(false)
	assert_eq(ui_settings_service.get_slider_wheel_on_slider(), false)

	ui_settings_service.set_slider_wheel_on_slider(true)
	assert_eq(ui_settings_service.get_slider_wheel_on_slider(), true)
