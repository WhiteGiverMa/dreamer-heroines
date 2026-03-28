class_name CrosshairSettings
extends Resource

@export var crosshair_size: float = 20.0
@export var crosshair_alpha: float = 1.0
@export var show_center_dot: bool = true
@export var center_dot_size: float = 2.0
@export var spread_increase_per_shot: float = 5.0
@export var recovery_rate: float = 30.0
@export var max_spread_multiplier: float = 3.0

func copy():
	var obj := get_script().new() as CrosshairSettings
	obj.crosshair_size = crosshair_size
	obj.crosshair_alpha = crosshair_alpha
	obj.show_center_dot = show_center_dot
	obj.center_dot_size = center_dot_size
	obj.spread_increase_per_shot = spread_increase_per_shot
	obj.recovery_rate = recovery_rate
	obj.max_spread_multiplier = max_spread_multiplier
	return obj

func to_dictionary() -> Dictionary:
	return {
		"crosshair_size": crosshair_size,
		"crosshair_alpha": crosshair_alpha,
		"show_center_dot": show_center_dot,
		"center_dot_size": center_dot_size,
		"spread_increase_per_shot": spread_increase_per_shot,
		"recovery_rate": recovery_rate,
		"max_spread_multiplier": max_spread_multiplier
	}

func from_dictionary(dict: Dictionary) -> void:
	crosshair_size = dict.get("crosshair_size", 20.0)
	crosshair_alpha = dict.get("crosshair_alpha", 1.0)
	show_center_dot = dict.get("show_center_dot", true)
	center_dot_size = dict.get("center_dot_size", 2.0)
	spread_increase_per_shot = dict.get("spread_increase_per_shot", 5.0)
	recovery_rate = dict.get("recovery_rate", 30.0)
	max_spread_multiplier = dict.get("max_spread_multiplier", 3.0)

func equals(other: CrosshairSettings) -> bool:
	if other == null:
		return false
	if not other is CrosshairSettings:
		return false
	var same_size := is_equal_approx(crosshair_size, other.crosshair_size)
	var same_alpha := is_equal_approx(crosshair_alpha, other.crosshair_alpha)
	var same_dot := show_center_dot == other.show_center_dot
	var same_dot_size := is_equal_approx(center_dot_size, other.center_dot_size)
	var same_spread := is_equal_approx(spread_increase_per_shot,
			other.spread_increase_per_shot)
	var same_recovery := is_equal_approx(recovery_rate, other.recovery_rate)
	var same_max := is_equal_approx(max_spread_multiplier,
			other.max_spread_multiplier)
	return same_size and same_alpha and same_dot and same_dot_size and \
			same_spread and same_recovery and same_max

static func get_defaults() -> Resource:
	var settings := new()
	settings.crosshair_size = 20.0
	settings.crosshair_alpha = 1.0
	settings.show_center_dot = true
	settings.center_dot_size = 2.0
	settings.spread_increase_per_shot = 5.0
	settings.recovery_rate = 30.0
	settings.max_spread_multiplier = 3.0
	return settings
