extends GutTest

const CrosshairSettingsScript = preload("res://src/data/crosshair_settings.gd")
const CrosshairSettingsServiceScript = preload("res://src/autoload/crosshair_settings_service.gd")
const CrosshairUIScript = preload("res://src/ui/crosshair_ui.gd")


class CrosshairSettingsServiceSpy:
	extends CrosshairSettingsServiceScript

	var save_deferred_call_count: int = 0

	func _load_settings_from_disk() -> CrosshairSettings:
		return null

	func _save_settings_deferred() -> void:
		save_deferred_call_count += 1


func _make_settings(overrides: Dictionary = {}) -> CrosshairSettings:
	var settings := CrosshairSettingsScript.new() as CrosshairSettings
	var merged_values: Dictionary = CrosshairSettingsScript.get_default_values()

	for key: String in overrides:
		merged_values[key] = overrides[key]

	settings.from_dictionary(merged_values)
	return settings


func _hit_stack_count(ui: CrosshairUI) -> int:
	var stacks: Array = ui.get("_active_hit_feedback_stacks")
	return stacks.size()


func test_crosshair_settings_serialization_round_trip_preserves_sanitized_values() -> void:
	var source := CrosshairSettingsScript.new() as CrosshairSettings
	source.from_dictionary({
		"crosshair_size": 999.0,
		"crosshair_alpha": -0.5,
		"shape": "combined",
		"crosshair_color_mode": "custom",
		"crosshair_custom_color_r": 1.2,
		"crosshair_custom_color_g": -0.1,
		"crosshair_custom_color_b": 0.33,
		"crosshair_line_gap": 35.0,
		"dynamic_spread_enabled": false,
		"hit_feedback_stack_mode": "stack",
		"hit_feedback_max_stacking": 12,
	})

	var serialized: Dictionary = source.to_dictionary()

	assert_eq(serialized["crosshair_size"], 60.0,
		"to_dictionary should serialize clamped crosshair_size to max limit")
	assert_eq(serialized["crosshair_alpha"], 0.0,
		"to_dictionary should serialize clamped crosshair_alpha to min limit")
	assert_eq(serialized["crosshair_shape"], "combined",
		"from_dictionary should map alias 'shape' and preserve valid shape enum")
	assert_eq(serialized["color_mode"], "custom",
		"from_dictionary should map alias 'crosshair_color_mode' to canonical color_mode")
	assert_eq(serialized["custom_color_r"], 1.0,
		"Custom color red channel should be clamped to 1.0")
	assert_eq(serialized["custom_color_g"], 0.0,
		"Custom color green channel should be clamped to 0.0")
	assert_eq(serialized["custom_color_b"], 0.33,
		"Custom color blue channel should preserve in-range values")
	assert_eq(serialized["line_gap"], 30.0,
		"line_gap should clamp to service/schema upper bound")
	assert_false(serialized["enable_dynamic_spread"],
		"Alias 'dynamic_spread_enabled' should map to enable_dynamic_spread")
	assert_eq(serialized["hit_feedback_stacking_mode"], "stack",
		"Alias 'hit_feedback_stack_mode' should map to hit_feedback_stacking_mode")
	assert_eq(serialized["hit_feedback_max_stacks"], 10,
		"Alias 'hit_feedback_max_stacking' should clamp to max stack limit")

	var restored := CrosshairSettingsScript.new() as CrosshairSettings
	restored.from_dictionary(serialized)

	assert_true(source.equals(restored),
		"Settings restored from to_dictionary output should equal the sanitized source settings")


func test_crosshair_settings_to_persisted_dictionary_uses_flat_persistence_keys() -> void:
	var settings: CrosshairSettings = _make_settings({
		"crosshair_shape": "dot",
		"color_mode": "preset",
		"color_preset": "cyan",
		"hit_feedback_expand_ratio": 0.42,
	})

	var persisted: Dictionary = settings.to_persisted_dictionary()

	assert_true(persisted.has("crosshair_color_mode"),
		"Persisted dictionary should contain compatibility key 'crosshair_color_mode'")
	assert_true(persisted.has("crosshair_line_gap"),
		"Persisted dictionary should contain compatibility key 'crosshair_line_gap'")
	assert_true(persisted.has("dynamic_spread_enabled"),
		"Persisted dictionary should contain compatibility key 'dynamic_spread_enabled'")
	assert_true(persisted.has("hit_feedback_expand_ratio"),
		"Persisted dictionary should contain hit feedback expanded parameter key")
	assert_eq(persisted["crosshair_shape"], "dot",
		"Persisted shape key should use canonical value")
	assert_eq(persisted["crosshair_color_mode"], "preset",
		"Persisted color mode should match configured mode")
	assert_eq(persisted["crosshair_color_preset"], "cyan",
		"Persisted color preset should match configured preset")


func test_service_update_setting_clamps_and_validates_values() -> void:
	var service: CrosshairSettingsServiceSpy = autofree(CrosshairSettingsServiceSpy.new())
	add_child_autofree(service)
	await get_tree().process_frame

	service.update_setting(&"crosshair_size", 500.0)
	service.update_setting(&"crosshair_alpha", -2.0)
	service.update_setting(&"crosshair_shape", "invalid-shape")
	service.update_setting(&"show_center_dot", "not-bool")

	assert_eq(service.get_crosshair_size(), 60.0,
		"crosshair_size should clamp to SIZE_MAX when update_setting receives oversized values")
	assert_eq(service.get_crosshair_alpha(), 0.0,
		"crosshair_alpha should clamp to ALPHA_MIN when update_setting receives negative values")
	assert_eq(service.get_crosshair_shape(), "cross",
		"Invalid crosshair_shape enum should fall back to current valid value")
	assert_true(service.get_show_center_dot(),
		"Non-bool show_center_dot input should be rejected and keep previous bool value")
	assert_eq(service.save_deferred_call_count, 2,
		"Only actual setting changes should schedule deferred persistence")


func test_service_emits_setting_changed_and_settings_changed_only_when_value_changes() -> void:
	var service: CrosshairSettingsServiceSpy = autofree(CrosshairSettingsServiceSpy.new())
	add_child_autofree(service)
	await get_tree().process_frame

	var setting_events: Array[Dictionary] = []
	var settings_events: Array = []

	service.setting_changed.connect(
		func(property_name: StringName, value: Variant) -> void:
			setting_events.append({
				"property_name": String(property_name),
				"value": value,
			})
	)

	service.settings_changed.connect(
		func(settings: Resource) -> void:
			settings_events.append(settings)
	)

	service.update_setting(&"line_gap", 9.0)
	service.update_setting(&"line_gap", 9.0)

	assert_eq(setting_events.size(), 1,
		"setting_changed should emit once when value changes and should not emit for no-op updates")
	assert_eq(settings_events.size(), 1,
		"settings_changed should emit once for an effective mutation and skip duplicate no-op updates")
	assert_eq(setting_events[0]["property_name"], "line_gap",
		"setting_changed should report the actual property name that changed")
	assert_eq(setting_events[0]["value"], 9.0,
		"setting_changed should emit normalized/clamped value")

	var emitted_settings := settings_events[0] as CrosshairSettings
	assert_not_null(emitted_settings,
		"settings_changed should emit a CrosshairSettings resource snapshot")
	assert_eq(emitted_settings.line_gap, 9.0,
		"settings_changed snapshot should contain updated line_gap value")


func test_service_update_settings_clamps_bulk_values_and_emits_per_property_changes() -> void:
	var service: CrosshairSettingsServiceSpy = autofree(CrosshairSettingsServiceSpy.new())
	add_child_autofree(service)
	await get_tree().process_frame

	var changed_props: Array[String] = []
	var settings_events: Array = []

	service.setting_changed.connect(
		func(property_name: StringName, _value: Variant) -> void:
			changed_props.append(String(property_name))
	)
	service.settings_changed.connect(
		func(settings: Resource) -> void:
			settings_events.append(settings)
	)

	var incoming: CrosshairSettings = _make_settings({
		"spread_increase_per_shot": 99.0,
		"recovery_rate": -1.0,
		"max_spread_multiplier": 99.0,
		"hit_feedback_max_stacks": 0,
		"hit_feedback_stacking_mode": "invalid-mode",
	})

	service.update_settings(incoming)

	assert_eq(service.get_spread_increase_per_shot(), 20.0,
		"Bulk update should clamp spread_increase_per_shot to defined max")
	assert_eq(service.get_recovery_rate(), 1.0,
		"Bulk update should clamp recovery_rate to defined min")
	assert_eq(service.get_max_spread_multiplier(), 6.0,
		"Bulk update should clamp max_spread_multiplier to defined max")
	assert_eq(service.get_hit_feedback_max_stacks(), 1,
		"Bulk update should clamp hit_feedback_max_stacks to minimum of 1")
	assert_eq(service.get_hit_feedback_stacking_mode(), "replace",
		"Invalid bulk hit feedback stacking mode should fallback to default valid enum")

	assert_true(changed_props.has("spread_increase_per_shot"),
		"setting_changed should include spread_increase_per_shot for bulk updates")
	assert_true(changed_props.has("recovery_rate"),
		"setting_changed should include recovery_rate for bulk updates")
	assert_true(changed_props.has("max_spread_multiplier"),
		"setting_changed should include max_spread_multiplier for bulk updates")
	assert_true(changed_props.has("hit_feedback_max_stacks"),
		"setting_changed should include hit_feedback_max_stacks for bulk updates")
	assert_eq(settings_events.size(), 1,
		"settings_changed should emit once per effective bulk update transaction")


func test_crosshair_ui_apply_settings_updates_runtime_parameters() -> void:
	var ui: CrosshairUI = autofree(CrosshairUIScript.new() as CrosshairUI)
	var settings: CrosshairSettings = _make_settings({
		"crosshair_size": 32.0,
		"crosshair_alpha": 0.45,
		"crosshair_shape": "circle",
		"color_mode": "custom",
		"custom_color_r": 0.2,
		"custom_color_g": 0.4,
		"custom_color_b": 0.6,
		"line_length": 18.0,
		"line_thickness": 3.0,
		"line_gap": 7.0,
		"use_t_shape": true,
		"outline_enabled": true,
		"outline_thickness": 2.0,
		"center_dot_size": 4.0,
		"center_dot_alpha": 0.75,
		"enable_dynamic_spread": false,
		"spread_increase_per_shot": 8.0,
		"recovery_rate": 40.0,
		"max_spread_multiplier": 2.5,
		"hit_feedback_duration": 0.2,
		"hit_feedback_scale": 1.8,
		"hit_feedback_intensity": 1.6,
		"hit_feedback_expand_ratio": 0.5,
		"hit_feedback_pulse_speed": 12.0,
		"hit_feedback_max_stacks": 5,
		"hit_feedback_stacking_mode": "stack",
		"hit_feedback_color_r": 1.0,
		"hit_feedback_color_g": 0.1,
		"hit_feedback_color_b": 0.2,
	})

	ui._apply_settings(settings)

	assert_eq(ui.crosshair_size, 32.0, "_apply_settings should apply crosshair_size")
	assert_eq(ui.crosshair_alpha, 0.45, "_apply_settings should apply crosshair_alpha")
	assert_eq(ui.crosshair_shape, "circle", "_apply_settings should apply crosshair_shape")
	assert_eq(ui.line_length, 18.0, "_apply_settings should apply line_length")
	assert_eq(ui.line_thickness, 3.0, "_apply_settings should apply line_thickness")
	assert_eq(ui.line_gap, 7.0, "_apply_settings should apply line_gap")
	assert_true(ui.use_t_shape, "_apply_settings should apply T-shape toggle")
	assert_true(ui.outline_enabled, "_apply_settings should apply outline toggle")
	assert_eq(ui.outline_thickness, 2.0, "_apply_settings should apply outline thickness")
	assert_eq(ui.center_dot_size, 4.0, "_apply_settings should apply center dot size")
	assert_eq(ui.center_dot_alpha, 0.75, "_apply_settings should apply center dot alpha")
	assert_false(ui.enable_dynamic_spread, "_apply_settings should apply dynamic spread toggle")
	assert_eq(ui.spread_increase_per_shot, 8.0, "_apply_settings should apply spread increase value")
	assert_eq(ui.recovery_rate, 40.0, "_apply_settings should apply recovery rate")
	assert_eq(ui.max_spread_multiplier, 2.5, "_apply_settings should apply max spread multiplier")
	assert_eq(ui.hit_feedback_duration, 0.2, "_apply_settings should apply hit feedback duration")
	assert_eq(ui.hit_feedback_scale, 1.8, "_apply_settings should apply hit feedback scale")
	assert_eq(ui.hit_feedback_intensity, 1.6, "_apply_settings should apply hit feedback intensity")
	assert_eq(ui.hit_feedback_expand_ratio, 0.5, "_apply_settings should apply hit feedback expand ratio")
	assert_eq(ui.hit_feedback_pulse_speed, 12.0, "_apply_settings should apply hit feedback pulse speed")
	assert_eq(ui.hit_feedback_max_stacks, 5, "_apply_settings should apply max hit feedback stacks")
	assert_eq(ui.hit_feedback_stacking_mode, "stack", "_apply_settings should apply hit feedback stacking mode")
	assert_eq(ui.hit_color, Color(1.0, 0.1, 0.2, 1.0),
		"_apply_settings should rebuild hit_color from RGB channels")
	assert_eq(ui.normal_color, Color(0.2, 0.4, 0.6, 1.0),
		"_apply_settings should resolve custom normal color when color_mode=custom")


func test_crosshair_ui_dynamic_spread_expands_recovers_and_respects_disable_toggle() -> void:
	var ui: CrosshairUI = autofree(CrosshairUIScript.new() as CrosshairUI)
	ui.enable_dynamic_spread = true
	ui.spread_increase_per_shot = 5.0
	ui.recovery_rate = 20.0
	ui.max_spread_multiplier = 3.0

	ui.update_spread(10.0, 5.0)
	assert_almost_eq(ui.current_spread, 10.0, 0.001,
		"update_spread should set current_spread inside [base_spread, max_spread]")
	assert_almost_eq(ui.max_spread, 15.0, 0.001,
		"max_spread should equal base_spread * max_spread_multiplier")

	ui.expand_on_shot()
	assert_almost_eq(ui.current_spread, 15.0, 0.001,
		"expand_on_shot should increase spread until max_spread cap")

	ui.expand_on_shot()
	assert_almost_eq(ui.current_spread, 15.0, 0.001,
		"expand_on_shot should not exceed max_spread cap")

	ui.recover(0.1)
	assert_almost_eq(ui.current_spread, 13.0, 0.001,
		"recover(delta) should reduce current_spread by recovery_rate * delta")

	ui.enable_dynamic_spread = false
	assert_almost_eq(ui.current_spread, ui.base_spread, 0.001,
		"Disabling dynamic spread should snap current_spread back to base_spread")

	var spread_before_disabled_shot: float = ui.current_spread
	ui.expand_on_shot()
	assert_almost_eq(ui.current_spread, spread_before_disabled_shot, 0.001,
		"expand_on_shot should become a no-op when dynamic spread is disabled")


func test_crosshair_ui_update_spread_signal_only_on_base_spread_change() -> void:
	var ui: CrosshairUI = autofree(CrosshairUIScript.new() as CrosshairUI)
	ui.max_spread_multiplier = 3.0

	var spread_signal_values: Array[float] = []
	ui.spread_changed.connect(func(new_spread: float) -> void: spread_signal_values.append(new_spread))

	ui.update_spread(8.0, 4.0)
	ui.update_spread(6.0, 4.0)

	assert_eq(spread_signal_values.size(), 1,
		"spread_changed should emit only when base_spread changes")
	assert_almost_eq(spread_signal_values[0], 8.0, 0.001,
		"spread_changed payload should be the current_spread computed for the new base_spread")


func test_crosshair_ui_hit_feedback_stacking_modes_manage_stack_state_transitions() -> void:
	var ui: CrosshairUI = autofree(CrosshairUIScript.new() as CrosshairUI)
	ui.hit_feedback_enabled = true
	ui.hit_feedback_max_stacks = 2

	ui.hit_feedback_stacking_mode = "replace"
	ui.show_hit_feedback()
	ui._update_hit_feedback(0.02)
	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 1,
		"replace mode should reset existing hit feedback and keep a single active stack")

	var stacks: Array = ui.get("_active_hit_feedback_stacks")
	assert_almost_eq(stacks[0], 0.0, 0.001,
		"replace mode should restart elapsed time for the new hit feedback stack")

	stacks.clear()
	ui.hit_feedback_stacking_mode = "stack"
	ui.show_hit_feedback()
	ui.show_hit_feedback()
	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 2,
		"stack mode should keep up to hit_feedback_max_stacks and discard oldest overflow stack")

	stacks.clear()
	ui.hit_feedback_stacking_mode = "ignore_new"
	ui.show_hit_feedback()
	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 1,
		"ignore_new mode should ignore subsequent hits while one feedback stack is active")


func test_crosshair_ui_hit_feedback_expires_and_clears_when_disabled() -> void:
	var ui: CrosshairUI = autofree(CrosshairUIScript.new() as CrosshairUI)
	ui.hit_feedback_enabled = true
	ui.hit_feedback_duration = 0.05
	ui.hit_feedback_stacking_mode = "stack"
	ui.hit_feedback_max_stacks = 3

	ui.show_hit_feedback()
	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 2,
		"Precondition: two hit feedback stacks should be active before expiration update")

	ui._update_hit_feedback(0.06)
	assert_eq(_hit_stack_count(ui), 0,
		"_update_hit_feedback should expire stacks whose elapsed time exceeds hit_feedback_duration")

	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 1,
		"show_hit_feedback should create a stack when feedback is enabled")

	ui.hit_feedback_enabled = false
	assert_eq(_hit_stack_count(ui), 0,
		"Disabling hit feedback should clear all active feedback stacks immediately")

	ui.show_hit_feedback()
	assert_eq(_hit_stack_count(ui), 0,
		"show_hit_feedback should be a no-op while hit_feedback_enabled=false")
