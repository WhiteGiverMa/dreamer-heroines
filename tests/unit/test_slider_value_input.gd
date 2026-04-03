extends GutTest

const SliderValueInputClass = preload("res://src/ui/slider_value_input.gd")


func test_slider_change_updates_line_edit_text() -> void:
	var host: VBoxContainer = autofree(VBoxContainer.new())
	add_child_autofree(host)

	var slider: HSlider = autofree(HSlider.new())
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	host.add_child(slider)

	var binding = SliderValueInputClass.new().attach_to_slider(slider, {"decimals": 0})

	slider.value = 42.0

	assert_not_null(binding.line_edit, "Binding should create a LineEdit next to the slider")
	assert_eq(binding.line_edit.text, "42", "Slider drag preview should sync numeric text immediately")


func test_text_commit_updates_slider_value_with_step_rounding() -> void:
	var host: VBoxContainer = autofree(VBoxContainer.new())
	add_child_autofree(host)

	var slider: HSlider = autofree(HSlider.new())
	slider.min_value = 0.0
	slider.max_value = 10.0
	slider.step = 0.5
	host.add_child(slider)

	var binding = SliderValueInputClass.new().attach_to_slider(slider)
	binding.line_edit.text = "2.26"

	binding.commit_text()

	assert_eq(slider.value, 2.5, "Committed text should snap to the slider step")
	assert_eq(binding.line_edit.text, "2.5", "Committed text should normalize to the snapped value")


func test_invalid_or_out_of_range_text_reverts_or_clamps() -> void:
	var host: VBoxContainer = autofree(VBoxContainer.new())
	add_child_autofree(host)

	var slider: HSlider = autofree(HSlider.new())
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.35
	host.add_child(slider)

	var binding = SliderValueInputClass.new().attach_to_slider(slider)

	binding.line_edit.text = "abc"
	binding.commit_text()
	assert_eq(slider.value, 0.35, "Invalid text should keep the current slider value")
	assert_eq(binding.line_edit.text, "0.35", "Invalid text should revert to the current normalized display")

	binding.line_edit.text = "4.2"
	binding.commit_text()
	assert_eq(slider.value, 1.0, "Out of range text should clamp to the slider max")
	assert_eq(binding.line_edit.text, "1", "Clamped text should display the normalized max value")


func test_display_scale_and_suffix_support_percent_and_multiplier_formats() -> void:
	var host: VBoxContainer = autofree(VBoxContainer.new())
	add_child_autofree(host)

	var percent_slider: HSlider = autofree(HSlider.new())
	percent_slider.min_value = 0.0
	percent_slider.max_value = 1.0
	percent_slider.step = 0.01
	host.add_child(percent_slider)

	var percent_binding = SliderValueInputClass.new().attach_to_slider(percent_slider, {
		"display_scale": 100.0,
		"suffix": "%",
		"decimals": 0,
	})
	percent_slider.value = 0.65
	assert_eq(percent_binding.line_edit.text, "65%", "Display scale should format fractional values as percentages")
	percent_binding.line_edit.text = "25%"
	percent_binding.commit_text()
	assert_eq(percent_slider.value, 0.25, "Percent text should convert back to normalized slider value")

	var multiplier_slider: HSlider = autofree(HSlider.new())
	multiplier_slider.min_value = 0.0
	multiplier_slider.max_value = 2.0
	multiplier_slider.step = 0.01
	host.add_child(multiplier_slider)

	var multiplier_binding = SliderValueInputClass.new().attach_to_slider(multiplier_slider, {
		"display_scale": 1.0,
		"suffix": "x",
		"decimals": 2,
	})
	multiplier_slider.value = 1.25
	assert_eq(multiplier_binding.line_edit.text, "1.25x", "Multiplier format should keep decimal precision and suffix")
	multiplier_binding.line_edit.text = "0.5x"
	multiplier_binding.commit_text()
	assert_eq(multiplier_slider.value, 0.5, "Multiplier text should parse back into slider value")
