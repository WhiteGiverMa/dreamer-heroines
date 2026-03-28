extends RefCounted

const RESOLUTIONS := [
	{"name": "720p", "width": 1280, "height": 720},
	{"name": "1080p", "width": 1920, "height": 1080},
	{"name": "1440p", "width": 2560, "height": 1440},
	{"name": "Native", "width": 0, "height": 0}
]

const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless"]


static func get_screen_size() -> Vector2i:
	return DisplayServer.screen_get_size()


static func get_window_size() -> Vector2i:
	return DisplayServer.window_get_size()


static func set_resolution(width: int, height: int) -> void:
	DisplayServer.window_set_size(Vector2i(width, height))


static func set_window_mode(mode_index: int) -> void:
	match mode_index:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)


static func set_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	)
