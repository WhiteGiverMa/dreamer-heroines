extends GutTest

const SettingsPanelScene = preload("res://scenes/ui/settings_panel.tscn")

var _panel
var _original_viewport_size: Vector2i


func before_each():
	_original_viewport_size = DisplayServer.window_get_size()
	# Also store the original position to restore later
	var original_pos = DisplayServer.window_get_position()


func after_each():
	DisplayServer.window_set_size(_original_viewport_size)


func _set_viewport_size(width, height):
	DisplayServer.window_set_size(Vector2i(width, height))
	await get_tree().process_frame


func _is_button_visible(button):
	if button == null:
		return false
	var global_rect = button.get_global_rect()
	var viewport_size = DisplayServer.window_get_size()
	var viewport_pos = DisplayServer.window_get_position()
	var viewport_rect = Rect2(viewport_pos, viewport_size)
	return viewport_rect.encloses(global_rect)


func _get_buttons():
	if _panel == null:
		return []
	return [
		_panel.get_node_or_null("BackButton"),
		_panel.get_node_or_null("SaveButton"),
		_panel.get_node_or_null("CancelButton"),
		_panel.get_node_or_null("ResetPageButton"),
	]


func test_buttons_visible_at_1280x720():
	_set_viewport_size(1280, 720)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var all_visible = true
	for btn in _get_buttons():
		if btn == null:
			continue
		if not _is_button_visible(btn):
			all_visible = false
			break

	assert_true(all_visible,
		"All settings panel buttons must be visible at 1280x720 resolution")


func test_buttons_visible_at_1920x1080():
	_set_viewport_size(1920, 1080)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var all_visible = true
	for btn in _get_buttons():
		if btn == null:
			continue
		if not _is_button_visible(btn):
			all_visible = false
			break

	assert_true(all_visible,
		"All settings panel buttons must be visible at 1920x1080 resolution")


func test_buttons_visible_at_ultrawide_2560x1080():
	_set_viewport_size(2560, 1080)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var all_visible = true
	for btn in _get_buttons():
		if btn == null:
			continue
		if not _is_button_visible(btn):
			all_visible = false
			break

	assert_true(all_visible,
		"All settings panel buttons must be visible at 2560x1080 ultrawide resolution")


func test_no_horizontal_overflow_at_narrow_viewport():
	_set_viewport_size(800, 600)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var panel_global_rect = _panel.get_global_rect()
	var viewport_size = DisplayServer.window_get_size()
	var viewport_pos = DisplayServer.window_get_position()
	var viewport_rect = Rect2(viewport_pos, viewport_size)

	var overflows_horizontally = panel_global_rect.end.x > viewport_rect.end.x

	assert_false(overflows_horizontally,
		"Settings panel must not overflow viewport horizontally at 800x600")


func test_panel_stays_centered_at_ultrawide():
	_set_viewport_size(3440, 1440)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var panel_global_rect = _panel.get_global_rect()
	var viewport_size = DisplayServer.window_get_size()
	var viewport_pos = DisplayServer.window_get_position()
	var viewport_rect = Rect2(viewport_pos, viewport_size)
	var panel_center_x = panel_global_rect.position.x + panel_global_rect.size.x * 0.5
	var viewport_center_x = viewport_rect.position.x + viewport_rect.size.x * 0.5
	var center_offset = absf(panel_center_x - viewport_center_x)

	assert_lt(center_offset, 5.0,
		"Settings panel must stay horizontally centered at 3440x1440 ultrawide resolution")


func test_buttons_accessible_at_small_height_600():
	_set_viewport_size(1280, 600)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var all_visible = true
	for btn in _get_buttons():
		if btn == null:
			continue
		if not _is_button_visible(btn):
			all_visible = false
			break

	assert_true(all_visible,
		"All settings panel buttons must be visible at 1280x600 resolution")


func test_no_vertical_overflow_at_720p():
	_set_viewport_size(1280, 720)

	_panel = autofree(SettingsPanelScene.instantiate())
	add_child_autofree(_panel)
	await get_tree().process_frame

	var panel_global_rect = _panel.get_global_rect()
	var viewport_size = DisplayServer.window_get_size()
	var viewport_pos = DisplayServer.window_get_position()
	var viewport_rect = Rect2(viewport_pos, viewport_size)

	var overflows_vertically = panel_global_rect.end.y > viewport_rect.end.y

	assert_false(overflows_vertically,
		"Settings panel must not overflow viewport vertically at 1280x720")
