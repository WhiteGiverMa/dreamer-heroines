extends Control

## Runtime tooltip verification harness.
##
## Purpose:
## - Standalone scene for MCP/runtime verification of TooltipTrigger + TooltipHost.
## - Provides machine-checkable methods for hover, focus, replacement, hide, and disable suppression.
## - Saves structured verification output to `user://tooltip_test_results.json`.
##
## Suggested MCP verification flow:
## 1. Launch project: run_project(projectPath="G:/dev/DreamerHeroines")
## 2. Switch scene: game_change_scene(scenePath="res://tests/scenes/tooltip_test.tscn")
## 3. Run all checks:
##    game_call_method(nodePath="/root/TooltipTest", method="run_programmatic_verification")
## 4. Query live state/evidence:
##    - game_get_property(nodePath="/root/TooltipTest/TooltipLayer/TooltipView", property="visible")
##    - game_call_method(nodePath="/root/TooltipTest", method="get_current_tooltip_snapshot")
##    - game_screenshot()
## 5. Drive individual scenarios if needed:
##    - game_call_method(nodePath="/root/TooltipTest", method="show_hover_case", args=["ControlA"])
##    - game_call_method(nodePath="/root/TooltipTest", method="show_focus_case", args=["ControlB"])
##    - game_call_method(nodePath="/root/TooltipTest", method="show_disabled_case")
##    - game_call_method(nodePath="/root/TooltipTest", method="hide_current_tooltip")

const RESULT_PATH := "user://tooltip_test_results.json"
const TRANSLATION_FILES := [
	"res://localization/zh_CN.po",
	"res://localization/en.po",
]

@onready var _tooltip_layer: CanvasLayer = %TooltipLayer
@onready var _control_a: Button = %ControlA
@onready var _control_b: Button = %ControlB
@onready var _control_c: Button = %ControlC
@onready var _status_label: RichTextLabel = %StatusLabel

var _last_results: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_translations_manually()
	_set_locale("zh_CN")
	_bind_runtime_host()
	_status_label.text = _build_status_text({"status": "ready", "scene": get_path()})


func run_programmatic_verification() -> Dictionary:
	_load_translations_manually()
	_set_locale("zh_CN")
	hide_current_tooltip()
	await _await_tooltip_settle()

	var hover_result := await _verify_hover_case("ControlA", "新游戏")
	var focus_result := await _verify_focus_case("ControlB", "设置")
	var replacement_result := await _verify_replacement_case()
	var disabled_result := await _verify_disabled_case()
	var hide_result := await _verify_hide_case()

	_last_results = {
		"scene": get_path(),
		"tooltip_path": _get_tooltip_view_path(),
		"hover": hover_result,
		"focus": focus_result,
		"replacement": replacement_result,
		"disabled": disabled_result,
		"hide": hide_result,
	}
	_last_results["passed"] = _all_passed(_last_results)

	_save_results(_last_results)
	_status_label.text = _build_status_text(_last_results)
	return _last_results


func show_hover_case(control_name: String) -> Dictionary:
	var target := _get_control(control_name)
	if target == null:
		return {"passed": false, "error": "Unknown control: %s" % control_name}

	var trigger := _get_trigger(target)
	if trigger == null:
		return {"passed": false, "error": "Missing TooltipTrigger for %s" % control_name}

	trigger.call("_on_mouse_entered")
	await _await_tooltip_settle()
	return get_current_tooltip_snapshot()


func show_focus_case(control_name: String) -> Dictionary:
	var target := _get_control(control_name)
	if target == null:
		return {"passed": false, "error": "Unknown control: %s" % control_name}

	target.grab_focus()
	await _await_tooltip_settle()
	return get_current_tooltip_snapshot()


func show_disabled_case() -> Dictionary:
	var trigger := _get_trigger(_control_c)
	if trigger == null:
		return {"passed": false, "error": "Missing TooltipTrigger for ControlC"}

	trigger.call("_on_mouse_entered")
	await _await_tooltip_settle()
	return get_current_tooltip_snapshot()


func hide_current_tooltip() -> Dictionary:
	var host := _get_tooltip_host()
	if host != null:
		host.call("hide_tooltip")

	for control in [_control_a, _control_b, _control_c]:
		var trigger = _get_trigger(control)
		if trigger != null:
			trigger.set("_tooltip_visible", false)

	if get_viewport() != null:
		get_viewport().gui_release_focus()

	return get_current_tooltip_snapshot()


func get_current_tooltip_snapshot() -> Dictionary:
	var host = _get_tooltip_host()
	var view = _get_tooltip_view()
	var host_path: String = ""
	var tooltip_path: String = ""
	if host != null:
		host_path = String(host.get_path())
	if view != null:
		tooltip_path = String(view.get_path())

	return {
		"host_path": host_path,
		"tooltip_path": tooltip_path,
		"visible": view.visible if view != null else false,
		"text": view.call("get_body_text") if view != null and view.has_method("get_body_text") else "",
		"position": view.global_position if view != null else Vector2.ZERO,
		"size": view.size if view != null else Vector2.ZERO,
		"current_target": String(host.current_target.name) if host != null and host.current_target != null else "",
	}


func _verify_hover_case(control_name: String, expected_text: String) -> Dictionary:
	var snapshot := await show_hover_case(control_name)
	var passed: bool = snapshot.visible and snapshot.text == expected_text and snapshot.current_target == control_name
	return {
		"passed": passed,
		"expected_text": expected_text,
		"snapshot": snapshot,
		"error": "" if passed else "Hover case failed for %s" % control_name,
	}


func _verify_focus_case(control_name: String, expected_text: String) -> Dictionary:
	var snapshot := await show_focus_case(control_name)
	var passed: bool = snapshot.visible and snapshot.text == expected_text and snapshot.current_target == control_name
	return {
		"passed": passed,
		"expected_text": expected_text,
		"snapshot": snapshot,
		"error": "" if passed else "Focus case failed for %s" % control_name,
	}


func _verify_replacement_case() -> Dictionary:
	var first_snapshot := await show_hover_case("ControlA")
	var first_view_path := String(first_snapshot.tooltip_path)
	var second_snapshot := await show_hover_case("ControlB")
	var host = _get_tooltip_host()
	var child_count := host.get_child_count() if host != null else -1
	var passed: bool = (
		first_snapshot.visible
		and second_snapshot.visible
		and first_view_path == String(second_snapshot.tooltip_path)
		and second_snapshot.current_target == "ControlB"
		and second_snapshot.text == "设置"
		and child_count == 1
	)
	return {
		"passed": passed,
		"first": first_snapshot,
		"second": second_snapshot,
		"host_child_count": child_count,
		"error": "" if passed else "Replacement case failed",
	}


func _verify_disabled_case() -> Dictionary:
	hide_current_tooltip()
	await _await_tooltip_settle()
	var snapshot := await show_disabled_case()
	var passed: bool = not snapshot.visible and snapshot.text == "" and snapshot.current_target == ""
	return {
		"passed": passed,
		"snapshot": snapshot,
		"error": "" if passed else "Disabled tooltip should remain hidden",
	}


func _verify_hide_case() -> Dictionary:
	await show_hover_case("ControlA")
	var trigger = _get_trigger(_control_a)
	if trigger == null:
		return {"passed": false, "error": "Missing TooltipTrigger for ControlA"}

	trigger.call("_on_mouse_exited")
	await _await_tooltip_settle()
	var snapshot := get_current_tooltip_snapshot()
	var passed: bool = not snapshot.visible and snapshot.current_target == ""
	return {
		"passed": passed,
		"snapshot": snapshot,
		"error": "" if passed else "Tooltip should hide immediately on exit",
	}


func _get_control(control_name: String) -> Button:
	match control_name:
		"ControlA":
			return _control_a
		"ControlB":
			return _control_b
		"ControlC":
			return _control_c
		_:
			return null


func _get_trigger(control: Control) -> Node:
	if control == null:
		return null
	return control.get_node_or_null("TooltipTrigger")


func _get_tooltip_host() -> CanvasLayer:
	return _tooltip_layer


func _get_tooltip_view() -> Control:
	var host := _get_tooltip_host()
	if host == null:
		return null
	return host.get_node_or_null("TooltipView") as Control


func _get_tooltip_view_path() -> String:
	var view := _get_tooltip_view()
	return String(view.get_path()) if view != null else ""


func _load_translations_manually() -> void:
	for file_path in TRANSLATION_FILES:
		if not ResourceLoader.exists(file_path):
			continue

		var translation = load(file_path)
		if translation is Translation:
			TranslationServer.add_translation(translation)


func _set_locale(locale_code: String) -> void:
	var manager = get_node_or_null("/root/LocalizationManager")
	if manager != null and manager.has_method("set_locale"):
		manager.call("set_locale", locale_code)
	else:
		TranslationServer.set_locale(locale_code)


func _bind_runtime_host() -> void:
	for control in [_control_a, _control_b, _control_c]:
		var trigger = _get_trigger(control)
		if trigger != null:
			trigger.tooltip_host = _tooltip_layer


func _await_tooltip_settle(frames: int = 3) -> void:
	for _index in frames:
		await get_tree().process_frame


func _all_passed(results: Dictionary) -> bool:
	for key in ["hover", "focus", "replacement", "disabled", "hide"]:
		if not bool(results.get(key, {}).get("passed", false)):
			return false
	return true


func _save_results(results: Dictionary) -> void:
	var file := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(results, "\t"))
	file.close()


func _build_status_text(results: Dictionary) -> String:
	var lines := [
		"Tooltip Runtime Verification Harness",
		"Scene: %s" % String(results.get("scene", get_path())),
		"Tooltip Path: %s" % String(results.get("tooltip_path", _get_tooltip_view_path())),
	]

	if results.has("passed"):
		lines.append("Overall: %s" % ("PASS" if results.passed else "FAIL"))
		for key in ["hover", "focus", "replacement", "disabled", "hide"]:
			var case_result: Dictionary = results.get(key, {})
			lines.append("- %s: %s" % [key, "PASS" if case_result.get("passed", false) else "FAIL"])
	else:
		lines.append("Overall: READY")

	lines.append("Result File: %s" % RESULT_PATH)
	return "\n".join(lines)
