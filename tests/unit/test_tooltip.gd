extends GutTest

const TOOLTIP_VIEW_SCRIPT_PATH := "res://src/ui/tooltip_view.gd"
const TOOLTIP_VIEW_SCENE_PATH := "res://scenes/ui/tooltip_view.tscn"
const TOOLTIP_HOST_SCRIPT_PATH := "res://src/ui/tooltip_host.gd"
const TOOLTIP_TRIGGER_SCRIPT_PATH := "res://src/ui/tooltip_trigger.gd"


class TooltipHostSpy:
	extends RefCounted

	var show_calls: Array[Dictionary] = []
	var hide_call_count: int = 0

	func show_tooltip(trigger: Node, target: Control, body_text: String) -> void:
		show_calls.append({
			"trigger": trigger,
			"target": target,
			"body_text": body_text,
		})

	func hide_tooltip() -> void:
		hide_call_count += 1


class LocalizationManagerStub:
	extends Node

	signal locale_changed(new_locale: String)

	var current_locale: String = "en"
	var translations: Dictionary = {
		"en": {},
		"zh_CN": {},
	}

	@warning_ignore("native_method_override")
	func tr(message: StringName, context: Variant = &"") -> String:
		var key := String(message)
		var locale_translations: Dictionary = translations.get(current_locale, {}) as Dictionary
		var translated: String = String(locale_translations.get(key, key))

		if context is Dictionary:
			for param_key in context:
				translated = translated.replace("{%s}" % param_key, str(context[param_key]))

		return translated

	func set_locale(locale: String) -> void:
		current_locale = locale
		locale_changed.emit(locale)


class TooltipViewStub:
	extends PanelContainer

	var body_text: String = ""

	func get_body_text() -> String:
		return body_text


func test_hover_shows_tooltip() -> void:
	var host_spy := TooltipHostSpy.new()
	var localization: LocalizationManagerStub = autofree(LocalizationManagerStub.new())
	localization.translations["en"] = {"ui.tooltip.hover": "Hover tooltip"}

	var target := _create_target_control()
	var trigger = _create_trigger(target, host_spy, localization, true, "ui.tooltip.hover")
	if trigger == null:
		return

	assert_true(trigger.has_method("_on_mouse_entered"), "TooltipTrigger should implement _on_mouse_entered for hover-driven display")

	trigger.call("_on_mouse_entered")

	assert_eq(host_spy.show_calls.size(), 1, "Mouse hover should synchronously request one tooltip display")
	assert_same(host_spy.show_calls[0]["trigger"], trigger, "Hover display should identify the active trigger")
	assert_same(host_spy.show_calls[0]["target"], target, "Hover display should anchor the tooltip to the hovered control")
	assert_eq(host_spy.show_calls[0]["body_text"], "Hover tooltip", "Hover display should resolve the localized body text before showing")


func test_focus_shows_tooltip() -> void:
	var host_spy := TooltipHostSpy.new()
	var localization: LocalizationManagerStub = autofree(LocalizationManagerStub.new())
	localization.translations["en"] = {"ui.tooltip.focus": "Focus tooltip"}

	var target := _create_target_control()
	var trigger = _create_trigger(target, host_spy, localization, true, "ui.tooltip.focus")
	if trigger == null:
		return

	assert_true(trigger.has_method("_on_focus_entered"), "TooltipTrigger should implement _on_focus_entered for keyboard and gamepad focus")

	trigger.call("_on_focus_entered")

	assert_eq(host_spy.show_calls.size(), 1, "Focus should immediately request one tooltip display")
	assert_same(host_spy.show_calls[0]["target"], target, "Focus display should anchor the tooltip to the focused control")
	assert_eq(host_spy.show_calls[0]["body_text"], "Focus tooltip", "Focus display should use the localized tooltip body text")


func test_immediate_hide_on_exit() -> void:
	var host_spy := TooltipHostSpy.new()
	var localization: LocalizationManagerStub = autofree(LocalizationManagerStub.new())
	localization.translations["en"] = {"ui.tooltip.hide": "Hide tooltip"}

	var target := _create_target_control()
	var trigger = _create_trigger(target, host_spy, localization, true, "ui.tooltip.hide")
	if trigger == null:
		return

	assert_true(trigger.has_method("_on_mouse_exited"), "TooltipTrigger should implement _on_mouse_exited for hover dismissal")
	assert_true(trigger.has_method("_on_focus_exited"), "TooltipTrigger should implement _on_focus_exited for focus-loss dismissal")

	trigger.call("_on_mouse_entered")
	trigger.call("_on_mouse_exited")

	assert_eq(host_spy.hide_call_count, 1, "Mouse exit should hide the tooltip immediately without delay")

	trigger.call("_on_focus_entered")
	trigger.call("_on_focus_exited")

	assert_eq(host_spy.hide_call_count, 2, "Focus loss should also hide the tooltip immediately")


func test_disabled_config_suppresses_display() -> void:
	var host_spy := TooltipHostSpy.new()
	var localization: LocalizationManagerStub = autofree(LocalizationManagerStub.new())
	localization.translations["en"] = {"ui.tooltip.disabled": "Disabled tooltip"}

	var disabled_target := _create_target_control()
	var disabled_trigger = _create_trigger(disabled_target, host_spy, localization, false, "ui.tooltip.disabled")
	if disabled_trigger == null:
		return

	disabled_trigger.call("_on_mouse_entered")
	disabled_trigger.call("_on_focus_entered")

	assert_eq(host_spy.show_calls.size(), 0, "tooltip_enabled = false should suppress hover and focus display requests")

	var missing_config_target := _create_target_control()
	var missing_config_trigger = _create_trigger(missing_config_target, host_spy, localization, true, "")
	if missing_config_trigger == null:
		return

	missing_config_trigger.call("_on_mouse_entered")
	missing_config_trigger.call("_on_focus_entered")

	assert_eq(host_spy.show_calls.size(), 0, "Missing translation key should no-op safely without crashing or showing a tooltip")


func test_single_instance_replacement() -> void:
	var tooltip_view_scene = _require_view_scene()
	var host = _create_host_instance(tooltip_view_scene)
	if host == null:
		return

	assert_true(host.has_method("show_tooltip"), "TooltipHost should expose show_tooltip(trigger, target, body_text)")

	var first_target := _create_target_control(Vector2(40, 40), Vector2(100, 30))
	var second_target := _create_target_control(Vector2(220, 120), Vector2(100, 30))
	var first_trigger: Node = autofree(Node.new())
	var second_trigger: Node = autofree(Node.new())

	host.call("show_tooltip", first_trigger, first_target, "First tooltip")
	host.call("show_tooltip", second_trigger, second_target, "Second tooltip")

	var tooltip_views := _find_nodes_by_script_path(host, TOOLTIP_VIEW_SCRIPT_PATH)
	assert_eq(tooltip_views.size(), 1, "Only one tooltip view instance should remain after a second control replaces the first")
	assert_true(tooltip_views[0] is Control, "TooltipHost should manage a Control-based tooltip view")
	assert_eq(_extract_body_text(tooltip_views[0]), "Second tooltip", "The visible tooltip should be replaced with the second control's body text")

	assert_true(_has_property(host, "current_target"), "TooltipHost should track the currently anchored control")
	assert_same(host.get("current_target"), second_target, "Second tooltip request should replace the host's active target")


func test_viewport_anchored_placement() -> void:
	var tooltip_view_scene = _require_view_scene()
	var host = _create_host_instance(tooltip_view_scene)
	if host == null:
		return

	var tooltip_view_script = _require_script(TOOLTIP_VIEW_SCRIPT_PATH, "TooltipView script")
	if tooltip_view_script == null:
		return

	var tooltip_view: Control = autofree(tooltip_view_script.new())
	assert_true(tooltip_view.has_method("_compute_position"), "TooltipView should compute viewport-safe anchored placement")

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(320, 180))
	var tooltip_size := Vector2(120, 40)

	var top_center_position: Vector2 = tooltip_view.call(
		"_compute_position",
		Rect2(Vector2(100, 50), Vector2(80, 20)),
		tooltip_size,
		viewport_rect
	)
	assert_eq(top_center_position, Vector2(80, 10), "Tooltip should prefer top-center placement when there is sufficient room above the target")

	var bottom_fallback_position: Vector2 = tooltip_view.call(
		"_compute_position",
		Rect2(Vector2(100, 5), Vector2(80, 20)),
		tooltip_size,
		viewport_rect
	)
	assert_eq(bottom_fallback_position, Vector2(80, 25), "Tooltip should flip to bottom-center when top placement would leave the viewport")

	var clamped_position: Vector2 = tooltip_view.call(
		"_compute_position",
		Rect2(Vector2(300, 60), Vector2(40, 20)),
		tooltip_size,
		viewport_rect
	)
	assert_eq(clamped_position, Vector2(200, 20), "Tooltip placement should clamp into the viewport while preserving top/bottom anchoring")


func test_localization_refresh() -> void:
	var host_spy := TooltipHostSpy.new()
	var localization: LocalizationManagerStub = autofree(LocalizationManagerStub.new())
	localization.translations["en"] = {"ui.tooltip.localized": "Localized tooltip"}
	localization.translations["zh_CN"] = {"ui.tooltip.localized": "本地化提示"}

	var target := _create_target_control()
	var trigger = _create_trigger(target, host_spy, localization, true, "ui.tooltip.localized")
	if trigger == null:
		return

	trigger.call("_on_mouse_entered")
	assert_eq(host_spy.show_calls.size(), 1, "Initial hover should show the localized tooltip")
	assert_eq(host_spy.show_calls[0]["body_text"], "Localized tooltip", "Initial tooltip text should use the current locale")

	localization.set_locale("zh_CN")

	assert_eq(host_spy.show_calls.size(), 2, "Visible tooltip should refresh immediately when the locale changes")
	assert_eq(host_spy.show_calls[1]["body_text"], "本地化提示", "Locale refresh should update the visible tooltip body text in-place")
	assert_same(host_spy.show_calls[1]["target"], target, "Locale refresh should keep the tooltip anchored to the same control")


func _create_target_control(position: Vector2 = Vector2(32, 32), size: Vector2 = Vector2(120, 32)) -> Control:
	var target: Button = autofree(Button.new())
	target.position = position
	target.size = size
	target.focus_mode = Control.FOCUS_ALL
	return target


func _create_trigger(target: Control, host: TooltipHostSpy, localization: LocalizationManagerStub, tooltip_enabled: bool, translation_key: String) -> Node:
	var trigger_script = _require_script(TOOLTIP_TRIGGER_SCRIPT_PATH, "TooltipTrigger script")
	if trigger_script == null:
		return null

	var trigger: Node = autofree(trigger_script.new())
	target.add_child(trigger)

	assert_true(_has_property(trigger, "tooltip_enabled"), "TooltipTrigger should expose tooltip_enabled for per-control opt-in")
	assert_true(_has_property(trigger, "tooltip_translation_key"), "TooltipTrigger should expose tooltip_translation_key for localized body text")
	assert_true(_has_property(trigger, "tooltip_host"), "TooltipTrigger should allow injecting a tooltip host instance for deterministic tests")
	assert_true(_has_property(trigger, "localization_manager"), "TooltipTrigger should allow injecting a localization manager for deterministic tests")

	trigger.set("tooltip_enabled", tooltip_enabled)
	trigger.set("tooltip_translation_key", translation_key)
	trigger.set("tooltip_host", host)
	trigger.set("localization_manager", localization)

	if trigger.has_method("_ready"):
		trigger.call("_ready")

	return trigger


func _create_host_instance(tooltip_view_scene: PackedScene) -> CanvasLayer:
	var host_script = _require_script(TOOLTIP_HOST_SCRIPT_PATH, "TooltipHost script")
	if host_script == null:
		return null

	var host: CanvasLayer = autofree(host_script.new())
	assert_true(_has_property(host, "tooltip_view_scene"), "TooltipHost should expose tooltip_view_scene so tests can inject the tooltip view scene")
	host.set("tooltip_view_scene", tooltip_view_scene)
	host.name = "TooltipLayer"
	return host


func _require_view_scene() -> PackedScene:
	assert_true(ResourceLoader.exists(TOOLTIP_VIEW_SCRIPT_PATH), "TooltipView script should exist for tooltip host contract coverage")
	assert_true(ResourceLoader.exists(TOOLTIP_VIEW_SCENE_PATH), "TooltipView scene should exist for tooltip host contract coverage")

	if not ResourceLoader.exists(TOOLTIP_VIEW_SCENE_PATH):
		return null

	var scene = load(TOOLTIP_VIEW_SCENE_PATH)
	assert_not_null(scene, "TooltipView scene should be loadable")
	return scene


func _require_script(path: String, label: String) -> Script:
	assert_true(ResourceLoader.exists(path), "%s should exist" % label)
	if not ResourceLoader.exists(path):
		return null

	var script = load(path)
	assert_not_null(script, "%s should load" % label)
	return script


func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if String(property.get("name", "")) == property_name:
			return true
	return false


func _find_nodes_by_script_path(root: Node, script_path: String) -> Array[Node]:
	var matches: Array[Node] = []

	for child in root.get_children():
		if child is Node:
			var child_node: Node = child
			var child_script: Variant = child_node.get_script()
			if child_script != null and child_script.resource_path == script_path:
				matches.append(child_node)

			matches.append_array(_find_nodes_by_script_path(child_node, script_path))

	return matches


func _extract_body_text(view: Node) -> String:
	assert_true(view.has_method("get_body_text") or _has_property(view, "body_text"), "TooltipView should expose its resolved body text for deterministic contract tests")

	if view.has_method("get_body_text"):
		return view.call("get_body_text")

	return String(view.get("body_text"))
