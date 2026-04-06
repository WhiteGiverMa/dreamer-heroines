class_name CrosshairSettings
extends Resource

const VALID_SHAPES := ["cross", "dot", "circle", "combined"]
const VALID_COLOR_MODES := ["preset", "custom"]
const VALID_COLOR_PRESETS := [
	"white", "green", "yellow", "cyan", "red", "magenta", "blue", "orange"
]
const VALID_HIT_FEEDBACK_STACKING_MODES := ["replace", "stack", "ignore_new"]

const SIZE_MIN := 2.0
const SIZE_MAX := 60.0
const ALPHA_MIN := 0.0
const ALPHA_MAX := 1.0
const DOT_SIZE_MIN := 1.0
const DOT_SIZE_MAX := 10.0
const CENTER_DOT_ALPHA_MIN := 0.0
const CENTER_DOT_ALPHA_MAX := 1.0
const COLOR_CHANNEL_MIN := 0.0
const COLOR_CHANNEL_MAX := 1.0
const LINE_LENGTH_MIN := 1.0
const LINE_LENGTH_MAX := 40.0
const LINE_THICKNESS_MIN := 1.0
const LINE_THICKNESS_MAX := 10.0
const LINE_GAP_MIN := 0.0
const LINE_GAP_MAX := 30.0
const OUTLINE_THICKNESS_MIN := 0.0
const OUTLINE_THICKNESS_MAX := 6.0
const SPREAD_INCREASE_MIN := 0.0
const SPREAD_INCREASE_MAX := 20.0
const RECOVERY_RATE_MIN := 1.0
const RECOVERY_RATE_MAX := 120.0
const MAX_SPREAD_MULTIPLIER_MIN := 1.0
const MAX_SPREAD_MULTIPLIER_MAX := 6.0
const HIT_FEEDBACK_DURATION_MIN := 0.01
const HIT_FEEDBACK_DURATION_MAX := 1.0
const HIT_FEEDBACK_SCALE_MIN := 0.1
const HIT_FEEDBACK_SCALE_MAX := 3.0
const HIT_FEEDBACK_INTENSITY_MIN := 0.0
const HIT_FEEDBACK_INTENSITY_MAX := 2.0
const HIT_FEEDBACK_EXPAND_RATIO_MIN := 0.0
const HIT_FEEDBACK_EXPAND_RATIO_MAX := 1.0
const HIT_FEEDBACK_PULSE_SPEED_MIN := 1.0
const HIT_FEEDBACK_PULSE_SPEED_MAX := 30.0
const HIT_FEEDBACK_MAX_STACKS_MIN := 1
const HIT_FEEDBACK_MAX_STACKS_MAX := 10

const DEFAULT_VALUES := {
	"crosshair_size": 20.0,
	"crosshair_alpha": 1.0,
	"crosshair_shape": "cross",
	"color_mode": "preset",
	"color_preset": "green",
	"custom_color_r": 0.0,
	"custom_color_g": 1.0,
	"custom_color_b": 0.0,
	"line_length": 10.0,
	"line_thickness": 2.0,
	"line_gap": 4.0,
	"use_t_shape": false,
	"outline_enabled": false,
	"outline_color_r": 0.0,
	"outline_color_g": 0.0,
	"outline_color_b": 0.0,
	"outline_thickness": 1.0,
	"show_center_dot": true,
	"center_dot_size": 2.0,
	"center_dot_alpha": 1.0,
	"enable_dynamic_spread": true,
	"spread_increase_per_shot": 5.0,
	"recovery_rate": 30.0,
	"max_spread_multiplier": 3.0,
	"hit_feedback_enabled": true,
	"hit_feedback_duration": 0.08,
	"hit_feedback_scale": 1.0,
	"hit_feedback_intensity": 1.0,
	"hit_feedback_expand_ratio": 0.15,
	"hit_feedback_pulse_speed": 8.0,
	"hit_feedback_max_stacks": 3,
	"hit_feedback_stacking_mode": "replace",
	"hit_feedback_color_r": 0.0,
	"hit_feedback_color_g": 1.0,
	"hit_feedback_color_b": 0.0,
}

const PROPERTY_KEY_ALIASES := {
	"crosshair_size": ["crosshair_size"],
	"crosshair_alpha": ["crosshair_alpha"],
	"crosshair_shape": ["crosshair_shape", "shape"],
	"color_mode": ["color_mode", "crosshair_color_mode"],
	"color_preset": ["color_preset", "crosshair_color_preset"],
	"custom_color_r": ["custom_color_r", "crosshair_custom_color_r"],
	"custom_color_g": ["custom_color_g", "crosshair_custom_color_g"],
	"custom_color_b": ["custom_color_b", "crosshair_custom_color_b"],
	"line_length": ["line_length", "crosshair_line_length"],
	"line_thickness": ["line_thickness", "crosshair_line_thickness"],
	"line_gap": ["line_gap", "crosshair_gap", "crosshair_line_gap"],
	"use_t_shape": ["use_t_shape", "crosshair_t_shape"],
	"outline_enabled": ["outline_enabled", "crosshair_outline_enabled"],
	"outline_color_r": ["outline_color_r", "crosshair_outline_color_r"],
	"outline_color_g": ["outline_color_g", "crosshair_outline_color_g"],
	"outline_color_b": ["outline_color_b", "crosshair_outline_color_b"],
	"outline_thickness": ["outline_thickness", "crosshair_outline_thickness"],
	"show_center_dot": ["show_center_dot"],
	"center_dot_size": ["center_dot_size"],
	"center_dot_alpha": ["center_dot_alpha"],
	"enable_dynamic_spread": ["enable_dynamic_spread", "dynamic_spread_enabled"],
	"spread_increase_per_shot": ["spread_increase_per_shot"],
	"recovery_rate": ["recovery_rate", "crosshair_recovery_rate"],
	"max_spread_multiplier": ["max_spread_multiplier"],
	"hit_feedback_enabled": ["hit_feedback_enabled"],
	"hit_feedback_duration": ["hit_feedback_duration"],
	"hit_feedback_scale": ["hit_feedback_scale", "hit_feedback_size"],
	"hit_feedback_intensity": ["hit_feedback_intensity"],
	"hit_feedback_expand_ratio": ["hit_feedback_expand_ratio", "hit_feedback_size_ratio"],
	"hit_feedback_pulse_speed": ["hit_feedback_pulse_speed"],
	"hit_feedback_max_stacks":
	["hit_feedback_max_stacks", "hit_feedback_max_stacking", "hit_feedback_concurrency_limit"],
	"hit_feedback_stacking_mode": ["hit_feedback_stacking_mode", "hit_feedback_stack_mode"],
	"hit_feedback_color_r": ["hit_feedback_color_r"],
	"hit_feedback_color_g": ["hit_feedback_color_g"],
	"hit_feedback_color_b": ["hit_feedback_color_b"],
}

const PERSISTED_KEY_MAP := {
	"crosshair_size": "crosshair_size",
	"crosshair_alpha": "crosshair_alpha",
	"crosshair_shape": "crosshair_shape",
	"color_mode": "crosshair_color_mode",
	"color_preset": "crosshair_color_preset",
	"custom_color_r": "crosshair_custom_color_r",
	"custom_color_g": "crosshair_custom_color_g",
	"custom_color_b": "crosshair_custom_color_b",
	"line_length": "crosshair_line_length",
	"line_thickness": "crosshair_line_thickness",
	"line_gap": "crosshair_line_gap",
	"use_t_shape": "crosshair_t_shape",
	"outline_enabled": "crosshair_outline_enabled",
	"outline_color_r": "crosshair_outline_color_r",
	"outline_color_g": "crosshair_outline_color_g",
	"outline_color_b": "crosshair_outline_color_b",
	"outline_thickness": "crosshair_outline_thickness",
	"show_center_dot": "show_center_dot",
	"center_dot_size": "center_dot_size",
	"center_dot_alpha": "center_dot_alpha",
	"enable_dynamic_spread": "dynamic_spread_enabled",
	"spread_increase_per_shot": "spread_increase_per_shot",
	"recovery_rate": "crosshair_recovery_rate",
	"max_spread_multiplier": "max_spread_multiplier",
	"hit_feedback_enabled": "hit_feedback_enabled",
	"hit_feedback_duration": "hit_feedback_duration",
	"hit_feedback_scale": "hit_feedback_scale",
	"hit_feedback_intensity": "hit_feedback_intensity",
	"hit_feedback_expand_ratio": "hit_feedback_expand_ratio",
	"hit_feedback_pulse_speed": "hit_feedback_pulse_speed",
	"hit_feedback_max_stacks": "hit_feedback_max_stacks",
	"hit_feedback_stacking_mode": "hit_feedback_stacking_mode",
	"hit_feedback_color_r": "hit_feedback_color_r",
	"hit_feedback_color_g": "hit_feedback_color_g",
	"hit_feedback_color_b": "hit_feedback_color_b",
}

@export var crosshair_size: float = 20.0
@export var crosshair_alpha: float = 1.0
@export var crosshair_shape: String = "cross"
@export var color_mode: String = "preset"
@export var color_preset: String = "green"
@export var custom_color_r: float = 0.0
@export var custom_color_g: float = 1.0
@export var custom_color_b: float = 0.0
@export var line_length: float = 10.0
@export var line_thickness: float = 2.0
@export var line_gap: float = 4.0
@export var use_t_shape: bool = false
@export var outline_enabled: bool = false
@export var outline_color_r: float = 0.0
@export var outline_color_g: float = 0.0
@export var outline_color_b: float = 0.0
@export var outline_thickness: float = 1.0
@export var show_center_dot: bool = true
@export var center_dot_size: float = 2.0
@export var center_dot_alpha: float = 1.0
@export var enable_dynamic_spread: bool = true
@export var spread_increase_per_shot: float = 5.0
@export var recovery_rate: float = 30.0
@export var max_spread_multiplier: float = 3.0
@export var hit_feedback_enabled: bool = true
@export var hit_feedback_duration: float = 0.08
@export var hit_feedback_scale: float = 1.0
@export var hit_feedback_intensity: float = 1.0
@export var hit_feedback_expand_ratio: float = 0.15
@export var hit_feedback_pulse_speed: float = 8.0
@export var hit_feedback_max_stacks: int = 3
@export var hit_feedback_stacking_mode: String = "replace"
@export var hit_feedback_color_r: float = 0.0
@export var hit_feedback_color_g: float = 1.0
@export var hit_feedback_color_b: float = 0.0


func copy():
	var obj := get_script().new() as CrosshairSettings
	obj.from_dictionary(to_dictionary())
	return obj


func to_dictionary() -> Dictionary:
	return _sanitize_dictionary(
		{
			"crosshair_size": crosshair_size,
			"crosshair_alpha": crosshair_alpha,
			"crosshair_shape": crosshair_shape,
			"color_mode": color_mode,
			"color_preset": color_preset,
			"custom_color_r": custom_color_r,
			"custom_color_g": custom_color_g,
			"custom_color_b": custom_color_b,
			"line_length": line_length,
			"line_thickness": line_thickness,
			"line_gap": line_gap,
			"use_t_shape": use_t_shape,
			"outline_enabled": outline_enabled,
			"outline_color_r": outline_color_r,
			"outline_color_g": outline_color_g,
			"outline_color_b": outline_color_b,
			"outline_thickness": outline_thickness,
			"show_center_dot": show_center_dot,
			"center_dot_size": center_dot_size,
			"center_dot_alpha": center_dot_alpha,
			"enable_dynamic_spread": enable_dynamic_spread,
			"spread_increase_per_shot": spread_increase_per_shot,
			"recovery_rate": recovery_rate,
			"max_spread_multiplier": max_spread_multiplier,
			"hit_feedback_enabled": hit_feedback_enabled,
			"hit_feedback_duration": hit_feedback_duration,
			"hit_feedback_scale": hit_feedback_scale,
			"hit_feedback_intensity": hit_feedback_intensity,
			"hit_feedback_expand_ratio": hit_feedback_expand_ratio,
			"hit_feedback_pulse_speed": hit_feedback_pulse_speed,
			"hit_feedback_max_stacks": hit_feedback_max_stacks,
			"hit_feedback_stacking_mode": hit_feedback_stacking_mode,
			"hit_feedback_color_r": hit_feedback_color_r,
			"hit_feedback_color_g": hit_feedback_color_g,
			"hit_feedback_color_b": hit_feedback_color_b,
		}
	)


func to_persisted_dictionary() -> Dictionary:
	var canonical := to_dictionary()
	var persisted: Dictionary = {}

	for property_name: String in PERSISTED_KEY_MAP:
		var persisted_key: String = PERSISTED_KEY_MAP[property_name]
		persisted[persisted_key] = canonical.get(property_name, DEFAULT_VALUES[property_name])

	return persisted


func from_dictionary(dict: Dictionary) -> void:
	var normalized := normalize_dictionary(dict)
	crosshair_size = float(normalized["crosshair_size"])
	crosshair_alpha = float(normalized["crosshair_alpha"])
	crosshair_shape = String(normalized["crosshair_shape"])
	color_mode = String(normalized["color_mode"])
	color_preset = String(normalized["color_preset"])
	custom_color_r = float(normalized["custom_color_r"])
	custom_color_g = float(normalized["custom_color_g"])
	custom_color_b = float(normalized["custom_color_b"])
	line_length = float(normalized["line_length"])
	line_thickness = float(normalized["line_thickness"])
	line_gap = float(normalized["line_gap"])
	use_t_shape = bool(normalized["use_t_shape"])
	outline_enabled = bool(normalized["outline_enabled"])
	outline_color_r = float(normalized["outline_color_r"])
	outline_color_g = float(normalized["outline_color_g"])
	outline_color_b = float(normalized["outline_color_b"])
	outline_thickness = float(normalized["outline_thickness"])
	show_center_dot = bool(normalized["show_center_dot"])
	center_dot_size = float(normalized["center_dot_size"])
	center_dot_alpha = float(normalized["center_dot_alpha"])
	enable_dynamic_spread = bool(normalized["enable_dynamic_spread"])
	spread_increase_per_shot = float(normalized["spread_increase_per_shot"])
	recovery_rate = float(normalized["recovery_rate"])
	max_spread_multiplier = float(normalized["max_spread_multiplier"])
	hit_feedback_enabled = bool(normalized["hit_feedback_enabled"])
	hit_feedback_duration = float(normalized["hit_feedback_duration"])
	hit_feedback_scale = float(normalized["hit_feedback_scale"])
	hit_feedback_intensity = float(normalized["hit_feedback_intensity"])
	hit_feedback_expand_ratio = float(normalized["hit_feedback_expand_ratio"])
	hit_feedback_pulse_speed = float(normalized["hit_feedback_pulse_speed"])
	hit_feedback_max_stacks = int(normalized["hit_feedback_max_stacks"])
	hit_feedback_stacking_mode = String(normalized["hit_feedback_stacking_mode"])
	hit_feedback_color_r = float(normalized["hit_feedback_color_r"])
	hit_feedback_color_g = float(normalized["hit_feedback_color_g"])
	hit_feedback_color_b = float(normalized["hit_feedback_color_b"])


func equals(other: CrosshairSettings) -> bool:
	if other == null:
		return false
	if not other is CrosshairSettings:
		return false
	var same_size := is_equal_approx(crosshair_size, other.crosshair_size)
	var same_alpha := is_equal_approx(crosshair_alpha, other.crosshair_alpha)
	var same_shape := crosshair_shape == other.crosshair_shape
	var same_color_mode := color_mode == other.color_mode
	var same_color_preset := color_preset == other.color_preset
	var same_custom_color_r := is_equal_approx(custom_color_r, other.custom_color_r)
	var same_custom_color_g := is_equal_approx(custom_color_g, other.custom_color_g)
	var same_custom_color_b := is_equal_approx(custom_color_b, other.custom_color_b)
	var same_line_length := is_equal_approx(line_length, other.line_length)
	var same_line_thickness := is_equal_approx(line_thickness, other.line_thickness)
	var same_line_gap := is_equal_approx(line_gap, other.line_gap)
	var same_t_shape := use_t_shape == other.use_t_shape
	var same_outline_enabled := outline_enabled == other.outline_enabled
	var same_outline_color_r := is_equal_approx(outline_color_r, other.outline_color_r)
	var same_outline_color_g := is_equal_approx(outline_color_g, other.outline_color_g)
	var same_outline_color_b := is_equal_approx(outline_color_b, other.outline_color_b)
	var same_outline_thickness := is_equal_approx(outline_thickness, other.outline_thickness)
	var same_dot := show_center_dot == other.show_center_dot
	var same_dot_size := is_equal_approx(center_dot_size, other.center_dot_size)
	var same_dot_alpha := is_equal_approx(center_dot_alpha, other.center_dot_alpha)
	var same_dynamic_spread := enable_dynamic_spread == other.enable_dynamic_spread
	var same_spread := is_equal_approx(spread_increase_per_shot, other.spread_increase_per_shot)
	var same_recovery := is_equal_approx(recovery_rate, other.recovery_rate)
	var same_max := is_equal_approx(max_spread_multiplier, other.max_spread_multiplier)
	var same_hit_feedback_enabled := hit_feedback_enabled == other.hit_feedback_enabled
	var same_hit_feedback_duration := is_equal_approx(
		hit_feedback_duration, other.hit_feedback_duration
	)
	var same_hit_feedback_scale := is_equal_approx(hit_feedback_scale, other.hit_feedback_scale)
	var same_hit_feedback_intensity := is_equal_approx(
		hit_feedback_intensity, other.hit_feedback_intensity
	)
	var same_hit_feedback_expand_ratio := is_equal_approx(
		hit_feedback_expand_ratio, other.hit_feedback_expand_ratio
	)
	var same_hit_feedback_pulse_speed := is_equal_approx(
		hit_feedback_pulse_speed, other.hit_feedback_pulse_speed
	)
	var same_hit_feedback_max_stacks := hit_feedback_max_stacks == other.hit_feedback_max_stacks
	var same_hit_feedback_stacking_mode := (
		hit_feedback_stacking_mode == other.hit_feedback_stacking_mode
	)
	var same_hit_feedback_color_r := is_equal_approx(
		hit_feedback_color_r, other.hit_feedback_color_r
	)
	var same_hit_feedback_color_g := is_equal_approx(
		hit_feedback_color_g, other.hit_feedback_color_g
	)
	var same_hit_feedback_color_b := is_equal_approx(
		hit_feedback_color_b, other.hit_feedback_color_b
	)
	return (
		same_size
		and same_alpha
		and same_shape
		and same_color_mode
		and same_color_preset
		and same_custom_color_r
		and same_custom_color_g
		and same_custom_color_b
		and same_line_length
		and same_line_thickness
		and same_line_gap
		and same_t_shape
		and same_outline_enabled
		and same_outline_color_r
		and same_outline_color_g
		and same_outline_color_b
		and same_outline_thickness
		and same_dot
		and same_dot_size
		and same_dot_alpha
		and same_dynamic_spread
		and same_spread
		and same_recovery
		and same_max
		and same_hit_feedback_enabled
		and same_hit_feedback_duration
		and same_hit_feedback_scale
		and same_hit_feedback_intensity
		and same_hit_feedback_expand_ratio
		and same_hit_feedback_pulse_speed
		and same_hit_feedback_max_stacks
		and same_hit_feedback_stacking_mode
		and same_hit_feedback_color_r
		and same_hit_feedback_color_g
		and same_hit_feedback_color_b
	)


static func get_defaults() -> Resource:
	var settings := new()
	settings.from_dictionary(get_default_values())
	return settings


static func get_default_values() -> Dictionary:
	return DEFAULT_VALUES.duplicate(true)


static func get_property_key_aliases() -> Dictionary:
	return PROPERTY_KEY_ALIASES.duplicate(true)


static func get_persisted_key_map() -> Dictionary:
	return PERSISTED_KEY_MAP.duplicate(true)


static func normalize_dictionary(dict: Dictionary) -> Dictionary:
	var normalized := get_default_values()

	for property_name: String in PROPERTY_KEY_ALIASES:
		for key: String in PROPERTY_KEY_ALIASES[property_name]:
			if dict.has(key):
				normalized[property_name] = dict[key]
				break

	return _sanitize_dictionary(normalized)


static func normalize_persisted_dictionary(dict: Dictionary) -> Dictionary:
	var settings := new() as CrosshairSettings
	settings.from_dictionary(dict)
	return settings.to_persisted_dictionary()


static func _sanitize_dictionary(dict: Dictionary) -> Dictionary:
	var defaults := get_default_values()
	return {
		"crosshair_size":
		_sanitize_float(dict, "crosshair_size", SIZE_MIN, SIZE_MAX, defaults["crosshair_size"]),
		"crosshair_alpha":
		_sanitize_float(dict, "crosshair_alpha", ALPHA_MIN, ALPHA_MAX, defaults["crosshair_alpha"]),
		"crosshair_shape":
		_sanitize_enum(dict, "crosshair_shape", VALID_SHAPES, defaults["crosshair_shape"]),
		"color_mode": _sanitize_enum(dict, "color_mode", VALID_COLOR_MODES, defaults["color_mode"]),
		"color_preset":
		_sanitize_enum(dict, "color_preset", VALID_COLOR_PRESETS, defaults["color_preset"]),
		"custom_color_r":
		_sanitize_float(
			dict, "custom_color_r", COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX, defaults["custom_color_r"]
		),
		"custom_color_g":
		_sanitize_float(
			dict, "custom_color_g", COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX, defaults["custom_color_g"]
		),
		"custom_color_b":
		_sanitize_float(
			dict, "custom_color_b", COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX, defaults["custom_color_b"]
		),
		"line_length":
		_sanitize_float(
			dict, "line_length", LINE_LENGTH_MIN, LINE_LENGTH_MAX, defaults["line_length"]
		),
		"line_thickness":
		_sanitize_float(
			dict,
			"line_thickness",
			LINE_THICKNESS_MIN,
			LINE_THICKNESS_MAX,
			defaults["line_thickness"]
		),
		"line_gap":
		_sanitize_float(dict, "line_gap", LINE_GAP_MIN, LINE_GAP_MAX, defaults["line_gap"]),
		"use_t_shape": _sanitize_bool(dict, "use_t_shape", defaults["use_t_shape"]),
		"outline_enabled": _sanitize_bool(dict, "outline_enabled", defaults["outline_enabled"]),
		"outline_color_r":
		_sanitize_float(
			dict,
			"outline_color_r",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["outline_color_r"]
		),
		"outline_color_g":
		_sanitize_float(
			dict,
			"outline_color_g",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["outline_color_g"]
		),
		"outline_color_b":
		_sanitize_float(
			dict,
			"outline_color_b",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["outline_color_b"]
		),
		"outline_thickness":
		_sanitize_float(
			dict,
			"outline_thickness",
			OUTLINE_THICKNESS_MIN,
			OUTLINE_THICKNESS_MAX,
			defaults["outline_thickness"]
		),
		"show_center_dot": _sanitize_bool(dict, "show_center_dot", defaults["show_center_dot"]),
		"center_dot_size":
		_sanitize_float(
			dict, "center_dot_size", DOT_SIZE_MIN, DOT_SIZE_MAX, defaults["center_dot_size"]
		),
		"center_dot_alpha":
		_sanitize_float(
			dict,
			"center_dot_alpha",
			CENTER_DOT_ALPHA_MIN,
			CENTER_DOT_ALPHA_MAX,
			defaults["center_dot_alpha"]
		),
		"enable_dynamic_spread":
		_sanitize_bool(dict, "enable_dynamic_spread", defaults["enable_dynamic_spread"]),
		"spread_increase_per_shot":
		_sanitize_float(
			dict,
			"spread_increase_per_shot",
			SPREAD_INCREASE_MIN,
			SPREAD_INCREASE_MAX,
			defaults["spread_increase_per_shot"]
		),
		"recovery_rate":
		_sanitize_float(
			dict, "recovery_rate", RECOVERY_RATE_MIN, RECOVERY_RATE_MAX, defaults["recovery_rate"]
		),
		"max_spread_multiplier":
		_sanitize_float(
			dict,
			"max_spread_multiplier",
			MAX_SPREAD_MULTIPLIER_MIN,
			MAX_SPREAD_MULTIPLIER_MAX,
			defaults["max_spread_multiplier"]
		),
		"hit_feedback_enabled":
		_sanitize_bool(dict, "hit_feedback_enabled", defaults["hit_feedback_enabled"]),
		"hit_feedback_duration":
		_sanitize_float(
			dict,
			"hit_feedback_duration",
			HIT_FEEDBACK_DURATION_MIN,
			HIT_FEEDBACK_DURATION_MAX,
			defaults["hit_feedback_duration"]
		),
		"hit_feedback_scale":
		_sanitize_float(
			dict,
			"hit_feedback_scale",
			HIT_FEEDBACK_SCALE_MIN,
			HIT_FEEDBACK_SCALE_MAX,
			defaults["hit_feedback_scale"]
		),
		"hit_feedback_intensity":
		_sanitize_float(
			dict,
			"hit_feedback_intensity",
			HIT_FEEDBACK_INTENSITY_MIN,
			HIT_FEEDBACK_INTENSITY_MAX,
			defaults["hit_feedback_intensity"]
		),
		"hit_feedback_expand_ratio":
		_sanitize_float(
			dict,
			"hit_feedback_expand_ratio",
			HIT_FEEDBACK_EXPAND_RATIO_MIN,
			HIT_FEEDBACK_EXPAND_RATIO_MAX,
			defaults["hit_feedback_expand_ratio"]
		),
		"hit_feedback_pulse_speed":
		_sanitize_float(
			dict,
			"hit_feedback_pulse_speed",
			HIT_FEEDBACK_PULSE_SPEED_MIN,
			HIT_FEEDBACK_PULSE_SPEED_MAX,
			defaults["hit_feedback_pulse_speed"]
		),
		"hit_feedback_max_stacks":
		_sanitize_int(
			dict,
			"hit_feedback_max_stacks",
			HIT_FEEDBACK_MAX_STACKS_MIN,
			HIT_FEEDBACK_MAX_STACKS_MAX,
			defaults["hit_feedback_max_stacks"]
		),
		"hit_feedback_stacking_mode":
		_sanitize_enum(
			dict,
			"hit_feedback_stacking_mode",
			VALID_HIT_FEEDBACK_STACKING_MODES,
			defaults["hit_feedback_stacking_mode"]
		),
		"hit_feedback_color_r":
		_sanitize_float(
			dict,
			"hit_feedback_color_r",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["hit_feedback_color_r"]
		),
		"hit_feedback_color_g":
		_sanitize_float(
			dict,
			"hit_feedback_color_g",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["hit_feedback_color_g"]
		),
		"hit_feedback_color_b":
		_sanitize_float(
			dict,
			"hit_feedback_color_b",
			COLOR_CHANNEL_MIN,
			COLOR_CHANNEL_MAX,
			defaults["hit_feedback_color_b"]
		),
	}


static func _sanitize_float(
	dict: Dictionary, key: String, min_value: float, max_value: float, fallback: float
) -> float:
	if not dict.has(key):
		return fallback
	if not _is_numeric(dict[key]):
		return fallback
	return clampf(float(dict[key]), min_value, max_value)


static func _sanitize_int(
	dict: Dictionary, key: String, min_value: int, max_value: int, fallback: int
) -> int:
	if not dict.has(key):
		return fallback
	if not _is_numeric(dict[key]):
		return fallback
	return clampi(int(dict[key]), min_value, max_value)


static func _sanitize_bool(dict: Dictionary, key: String, fallback: bool) -> bool:
	if not dict.has(key):
		return fallback
	var value: Variant = dict[key]
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT and (value == 0 or value == 1):
		return bool(value)
	return fallback


static func _sanitize_enum(
	dict: Dictionary, key: String, valid_values: Array, fallback: String
) -> String:
	if not dict.has(key):
		return fallback
	var value := String(dict[key]).to_lower()
	return value if valid_values.has(value) else fallback


static func _is_numeric(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT
