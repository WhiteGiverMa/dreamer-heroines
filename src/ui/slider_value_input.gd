class_name SliderValueInput
extends RefCounted

const DEFAULT_INPUT_WIDTH := 84.0
const EPSILON := 0.0001

var slider: HSlider
var line_edit: LineEdit
var container: HBoxContainer
var suffix_label: Label

var _decimals: int = 0
var _display_scale: float = 1.0
var _suffix: String = ""
var _is_editing_text: bool = false


func attach_to_slider(target_slider: HSlider, options: Dictionary = {}) -> SliderValueInput:
	_setup(target_slider, options)
	return self


func set_editable(enabled: bool) -> void:
	if slider:
		slider.editable = enabled
	if line_edit:
		line_edit.editable = enabled
		line_edit.selecting_enabled = enabled


func set_visible(visible: bool) -> void:
	if container:
		container.visible = visible


func refresh_from_slider() -> void:
	if slider == null:
		return
	_sync_text_from_slider(slider.value)


func commit_text() -> void:
	_apply_line_edit_value()


func _setup(target_slider: HSlider, options: Dictionary) -> void:
	if target_slider == null:
		push_warning("[SliderValueInput] Cannot attach to a null slider")
		return

	slider = target_slider
	_decimals = int(options.get("decimals", _infer_decimals(slider.step)))
	_display_scale = float(options.get("display_scale", 1.0))
	if is_zero_approx(_display_scale):
		_display_scale = 1.0
	_suffix = String(options.get("suffix", ""))
	_reparent_slider_into_container(float(options.get("input_width", DEFAULT_INPUT_WIDTH)))
	_configure_line_edit(options)
	_connect_signals()
	_sync_text_from_slider(slider.value)


func _reparent_slider_into_container(input_width: float) -> void:
	var parent := slider.get_parent()
	if parent == null:
		push_warning("[SliderValueInput] Slider %s has no parent" % slider.name)
		return

	var original_index := slider.get_index()
	container = HBoxContainer.new()
	container.name = "%sContainer" % slider.name
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 8)

	parent.remove_child(slider)
	parent.add_child(container)
	parent.move_child(container, original_index)
	container.add_child(slider)

	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit = LineEdit.new()
	line_edit.name = "%sInput" % slider.name
	line_edit.custom_minimum_size = Vector2(input_width, 0.0)
	container.add_child(line_edit)

	if not _suffix.is_empty():
		suffix_label = Label.new()
		suffix_label.name = "%sSuffix" % slider.name
		suffix_label.text = _suffix
		suffix_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		container.add_child(suffix_label)


func _configure_line_edit(options: Dictionary) -> void:
	if line_edit == null:
		return

	line_edit.placeholder_text = String(options.get("placeholder", ""))
	line_edit.select_all_on_focus = true
	line_edit.clear_button_enabled = true


func _connect_signals() -> void:
	if slider and not slider.value_changed.is_connected(_on_slider_value_changed):
		slider.value_changed.connect(_on_slider_value_changed)

	if line_edit and not line_edit.focus_entered.is_connected(_on_line_edit_focus_entered):
		line_edit.focus_entered.connect(_on_line_edit_focus_entered)

	if line_edit and not line_edit.focus_exited.is_connected(_on_line_edit_focus_exited):
		line_edit.focus_exited.connect(_on_line_edit_focus_exited)

	if line_edit and not line_edit.text_submitted.is_connected(_on_line_edit_text_submitted):
		line_edit.text_submitted.connect(_on_line_edit_text_submitted)


func _on_slider_value_changed(value: float) -> void:
	_sync_text_from_slider(value)


func _on_line_edit_focus_entered() -> void:
	_is_editing_text = true


func _on_line_edit_focus_exited() -> void:
	_apply_line_edit_value()


@warning_ignore("unused_parameter")
func _on_line_edit_text_submitted(_new_text: String) -> void:
	_apply_line_edit_value()
	if line_edit:
		line_edit.release_focus()


func _apply_line_edit_value() -> void:
	if slider == null or line_edit == null:
		return

	_is_editing_text = false
	var trimmed_text := _sanitize_input_text(line_edit.text)
	if trimmed_text.is_empty():
		_sync_text_from_slider(slider.value)
		return

	if not _is_valid_number(trimmed_text):
		_sync_text_from_slider(slider.value)
		return

	var normalized_value := _normalize_value(trimmed_text.to_float() / _display_scale)
	if absf(normalized_value - slider.value) <= EPSILON:
		_sync_text_from_slider(slider.value)
		return

	slider.value = normalized_value


func _sync_text_from_slider(value: float) -> void:
	if line_edit == null or _is_editing_text:
		return
	line_edit.text = _format_value(value)


func _normalize_value(value: float) -> float:
	var normalized_value := clampf(value, slider.min_value, slider.max_value)
	if slider.step > 0.0:
		normalized_value = slider.min_value + snappedf(normalized_value - slider.min_value, slider.step)
		normalized_value = clampf(normalized_value, slider.min_value, slider.max_value)
	if slider.rounded:
		normalized_value = round(normalized_value)
	return normalized_value


func _format_value(value: float) -> String:
	var display_value := value * _display_scale
	if _decimals <= 0:
		return str(int(round(display_value)))
	return ("%.*f" % [_decimals, display_value]).rstrip("0").rstrip(".")


func _is_valid_number(text: String) -> bool:
	return text.is_valid_float() or text.is_valid_int()


func _sanitize_input_text(text: String) -> String:
	return text.strip_edges()


func _infer_decimals(step: float) -> int:
	if step <= 0.0:
		return 2

	var decimals := 0
	var scaled_step := step
	while decimals < 4 and absf(scaled_step - round(scaled_step)) > EPSILON:
		scaled_step *= 10.0
		decimals += 1
	return decimals
