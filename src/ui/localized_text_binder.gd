class_name LocalizedTextBinder
extends RefCounted


var _owner: Node
var _bindings: Dictionary = {}
var _is_connected_to_locale_changed: bool = false


func _init(owner: Node) -> void:
	_owner = owner


func bind(
	binding_id: String,
	node_path: String,
	translation_key: String,
	property_name: String = "text",
	params_provider: Callable = Callable()
) -> void:
	if binding_id.is_empty():
		push_warning("[LocalizedTextBinder] binding_id 不能为空")
		return

	_bindings[binding_id] = {
		"node": null,
		"node_path": node_path,
		"translation_key": translation_key,
		"property_name": property_name,
		"params_provider": params_provider,
	}


func bind_node(
	binding_id: String,
	node: Node,
	translation_key: String,
	property_name: String = "text",
	params_provider: Callable = Callable()
) -> void:
	if binding_id.is_empty():
		push_warning("[LocalizedTextBinder] binding_id 不能为空")
		return

	if not node:
		return

	_bindings[binding_id] = {
		"node": node,
		"node_path": "",
		"translation_key": translation_key,
		"property_name": property_name,
		"params_provider": params_provider,
	}


func start() -> void:
	_connect_locale_changed()
	refresh_all()


func refresh(binding_id: String) -> void:
	if not _bindings.has(binding_id):
		return

	var binding: Dictionary = _bindings[binding_id]
	_apply_binding(binding)


func refresh_all() -> void:
	for binding_id in _bindings.keys():
		refresh(binding_id)


func _connect_locale_changed() -> void:
	if _is_connected_to_locale_changed:
		return

	if not LocalizationManager:
		return

	if not LocalizationManager.locale_changed.is_connected(_on_locale_changed):
		LocalizationManager.locale_changed.connect(_on_locale_changed)

	_is_connected_to_locale_changed = true


@warning_ignore("unused_parameter")
func _on_locale_changed(_new_locale: String) -> void:
	refresh_all()


func _apply_binding(binding: Dictionary) -> void:
	if not _owner:
		return

	var node_path: String = binding.get("node_path", "")
	var node: Node = binding.get("node", null)
	if not node and not node_path.is_empty():
		node = _owner.get_node_or_null(node_path)

	if not node:
		return

	var translation_key: String = binding.get("translation_key", "")
	var translated_text := _translate(translation_key, binding.get("params_provider", Callable()))
	var property_name: String = binding.get("property_name", "text")

	node.set(property_name, translated_text)


func _translate(translation_key: String, params_provider: Callable) -> String:
	if not LocalizationManager:
		return translation_key

	if params_provider.is_valid():
		var params = params_provider.call()
		if params is Dictionary:
			return LocalizationManager.call("tr", translation_key, params)

	return LocalizationManager.tr(translation_key)
