class_name TooltipTrigger
extends Node

const TOOLTIP_HOST_SCRIPT := preload("res://src/ui/tooltip_host.gd")

@export var tooltip_enabled: bool = true
@export var tooltip_translation_key: String = ""

var tooltip_host = null
var localization_manager: Node = null

var _target_control: Control = null
var _tooltip_visible: bool = false


func _ready() -> void:
	var parent_node := get_parent()
	if not parent_node is Control:
		push_warning("[TooltipTrigger] Parent must be a Control node")
		return

	_target_control = parent_node as Control
	_connect_parent_signals()
	_connect_localization_signal()


func _connect_parent_signals() -> void:
	if _target_control == null:
		return

	if not _target_control.mouse_entered.is_connected(_on_mouse_entered):
		_target_control.mouse_entered.connect(_on_mouse_entered)

	if not _target_control.mouse_exited.is_connected(_on_mouse_exited):
		_target_control.mouse_exited.connect(_on_mouse_exited)

	if not _target_control.focus_entered.is_connected(_on_focus_entered):
		_target_control.focus_entered.connect(_on_focus_entered)

	if not _target_control.focus_exited.is_connected(_on_focus_exited):
		_target_control.focus_exited.connect(_on_focus_exited)


func _on_mouse_entered() -> void:
	_show_tooltip()


func _on_mouse_exited() -> void:
	_hide_tooltip()


func _on_focus_entered() -> void:
	_show_tooltip()


func _on_focus_exited() -> void:
	_hide_tooltip()


func _show_tooltip() -> void:
	if not _can_show_tooltip():
		return

	var host = _resolve_tooltip_host()
	var body_text := _resolve_tooltip_body_text()
	if host == null or body_text.is_empty():
		return

	_tooltip_visible = true
	host.call("show_tooltip", self, _target_control, body_text)


func _hide_tooltip() -> void:
	_tooltip_visible = false

	if _target_control == null:
		return

	if not tooltip_enabled or tooltip_translation_key.is_empty():
		return

	var host = _resolve_tooltip_host(false)
	if host == null or not host.has_method("hide_tooltip"):
		return

	if _is_runtime_tooltip_host(host):
		host.hide_tooltip()
		return

	host.hide_tooltip(self, _target_control)


func _can_show_tooltip() -> bool:
	return _target_control != null and tooltip_enabled and not tooltip_translation_key.is_empty()


func _connect_localization_signal() -> void:
	var manager = _resolve_localization_manager()
	if manager == null or not manager.has_signal("locale_changed"):
		return

	if not manager.locale_changed.is_connected(_on_locale_changed):
		manager.locale_changed.connect(_on_locale_changed)


func _on_locale_changed(_new_locale: String) -> void:
	if not _tooltip_visible:
		return

	_show_tooltip()


func _resolve_tooltip_body_text() -> String:
	var manager = _resolve_localization_manager()
	if manager == null or not manager.has_method("tr"):
		return ""

	return String(manager.call("tr", StringName(tooltip_translation_key)))


func _resolve_tooltip_host(create_if_missing: bool = true):
	if tooltip_host != null:
		return tooltip_host

	# First, check if scene already has a TooltipLayer
	var tree := get_tree()
	if tree != null and tree.current_scene != null:
		var existing_host = tree.current_scene.get_node_or_null(TOOLTIP_HOST_SCRIPT.TOOLTIP_LAYER_NAME)
		if existing_host != null:
			tooltip_host = existing_host
			return tooltip_host

	if not create_if_missing:
		return null

	tooltip_host = TOOLTIP_HOST_SCRIPT.new()

	# Add host to scene tree as TooltipLayer
	if tree != null and tree.current_scene != null:
		tooltip_host.name = TOOLTIP_HOST_SCRIPT.TOOLTIP_LAYER_NAME
		tree.current_scene.add_child(tooltip_host)

	return tooltip_host


func _resolve_localization_manager() -> Node:
	if localization_manager != null:
		return localization_manager

	if Engine.has_singleton("LocalizationManager"):
		localization_manager = Engine.get_singleton("LocalizationManager")
		return localization_manager

	localization_manager = get_node_or_null("/root/LocalizationManager")

	return localization_manager


func _is_runtime_tooltip_host(host: Object) -> bool:
	return host.get_script() == TOOLTIP_HOST_SCRIPT and _get_method_argument_count(host, "hide_tooltip") == 0


func _get_method_argument_count(object: Object, method_name: String) -> int:
	for method_data in object.get_method_list():
		if String(method_data.get("name", "")) != method_name:
			continue

		var args: Array = method_data.get("args", [])
		return args.size()

	return -1
