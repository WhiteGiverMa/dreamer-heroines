extends Control

signal option_selected(blessing_id: String)

@export_group("Display Elements")
@export var background: ColorRect
@export var title_label: Label
@export var subtitle_label: Label

@export_group("Option Buttons")
@export var option_1_button: Button
@export var option_2_button: Button
@export var option_3_button: Button

var _option_buttons: Array[Button] = []
var _option_ids: Array[String] = []
var _current_options: Array[Dictionary] = []


func _ready() -> void:
	_resolve_node_references()
	_option_buttons = [option_1_button, option_2_button, option_3_button]
	_option_ids = ["", "", ""]
	if LocalizationManager and not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)

	for index in range(_option_buttons.size()):
		var button := _option_buttons[index]
		if button:
			button.pressed.connect(_on_option_pressed.bind(index))

	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	modulate.a = 0.0
	_apply_localized_texts()


func _resolve_node_references() -> void:
	if background == null:
		background = get_node_or_null("Background") as ColorRect
	if title_label == null:
		title_label = get_node_or_null("CenterContainer/VBoxContainer/TitleLabel") as Label
	if subtitle_label == null:
		subtitle_label = get_node_or_null("CenterContainer/VBoxContainer/SubtitleLabel") as Label
	if option_1_button == null:
		option_1_button = get_node_or_null("CenterContainer/VBoxContainer/Options/Option1Button") as Button
	if option_2_button == null:
		option_2_button = get_node_or_null("CenterContainer/VBoxContainer/Options/Option2Button") as Button
	if option_3_button == null:
		option_3_button = get_node_or_null("CenterContainer/VBoxContainer/Options/Option3Button") as Button


func _apply_localized_texts() -> void:
	if not LocalizationManager:
		return

	if title_label:
		title_label.text = LocalizationManager.tr("ui.roguelike_reward_selection.title")
	if subtitle_label:
		subtitle_label.text = LocalizationManager.tr("ui.roguelike_reward_selection.subtitle")


func show_rewards(options: Array[Dictionary]) -> void:
	if options.size() != _option_buttons.size():
		push_warning("RoguelikeRewardSelection.show_rewards expected 3 options, got %d" % options.size())

	_current_options = options.duplicate(true)
	_bind_options(options)
	visible = true
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	if option_1_button and not option_1_button.disabled:
		option_1_button.grab_focus()


func _bind_options(options: Array[Dictionary]) -> void:
	for index in range(_option_buttons.size()):
		var button := _option_buttons[index]
		var option := options[index] if index < options.size() else {}
		var blessing_id := String(option.get("id", option.get("blessing_id", option.get("key", ""))))
		var title := _resolve_option_title(option, blessing_id)
		var description := _resolve_option_description(option, blessing_id)

		_option_ids[index] = blessing_id

		if button:
			button.text = "%s\n%s" % [title, description]
			button.disabled = blessing_id.is_empty()


func _resolve_option_title(option: Dictionary, blessing_id: String) -> String:
	var translated := _translate_option_key(option, "title_key", blessing_id, "title")
	if not translated.is_empty():
		return translated

	return String(option.get("title", LocalizationManager.tr("ui.roguelike_reward_selection.unknown_blessing") if LocalizationManager else "Unknown Blessing"))


func _resolve_option_description(option: Dictionary, blessing_id: String) -> String:
	var translated := _translate_option_key(option, "description_key", blessing_id, "description")
	if not translated.is_empty():
		return translated

	if option.has("description"):
		return String(option.get("description", ""))

	return LocalizationManager.tr("ui.roguelike_reward_selection.unknown_description") if LocalizationManager else "Description unavailable"


func _translate_option_key(option: Dictionary, explicit_key_field: String, blessing_id: String, suffix: String) -> String:
	if not LocalizationManager:
		return ""

	var explicit_key := String(option.get(explicit_key_field, ""))
	if not explicit_key.is_empty():
		var explicit_translation := LocalizationManager.tr(explicit_key)
		if explicit_translation != explicit_key:
			return explicit_translation

	if blessing_id.is_empty():
		return ""

	var derived_key := "blessing.%s.%s" % [blessing_id, suffix]
	var derived_translation := LocalizationManager.tr(derived_key)
	if derived_translation != derived_key:
		return derived_translation

	return ""


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	_apply_localized_texts()
	if not _current_options.is_empty():
		_bind_options(_current_options)


func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= _option_ids.size():
		return

	var blessing_id := _option_ids[index]
	if blessing_id.is_empty():
		return

	_hide_and_emit(blessing_id)


func _hide_and_emit(blessing_id: String) -> void:
	for button in _option_buttons:
		if button:
			button.disabled = true

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func():
		visible = false
		option_selected.emit(blessing_id)
	)
