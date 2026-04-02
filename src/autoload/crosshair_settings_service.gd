extends Node

const CrosshairSettingsResource = preload("res://src/data/crosshair_settings.gd")

## CrosshairSettingsService - 准星设置服务层
## 解耦表现层与数据层的直接依赖，提供准星配置的集中管理

# ============================================
# 信号（解耦关键）
# ============================================

## 设置整体变更时发射
signal settings_changed(settings: Resource)

## 单个属性变更时发射
signal setting_changed(property_name: StringName, value: Variant)

## 设置加载完成时发射
signal settings_loaded(settings: Resource)

## 设置保存完成时发射
signal settings_saved(success: bool)

# ============================================
# 常量（范围限制）
# ============================================

const SIZE_MIN := 2.0
const SIZE_MAX := 60.0
const ALPHA_MIN := 0.0
const ALPHA_MAX := 1.0
const LINE_LENGTH_MIN := 1.0
const LINE_LENGTH_MAX := 40.0
const LINE_THICKNESS_MIN := 1.0
const LINE_THICKNESS_MAX := 10.0
const LINE_GAP_MIN := 0.0
const LINE_GAP_MAX := 30.0
const COLOR_CHANNEL_MIN := 0.0
const COLOR_CHANNEL_MAX := 1.0
const OUTLINE_THICKNESS_MIN := 0.0
const OUTLINE_THICKNESS_MAX := 6.0

const DOT_SIZE_MIN := 1.0
const DOT_SIZE_MAX := 10.0
const DOT_ALPHA_MIN := 0.0
const DOT_ALPHA_MAX := 1.0

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

const SETTINGS_FILE_KEY := "crosshair"

const COLOR_PRESETS := {
	"white": Color(1.0, 1.0, 1.0, 1.0),
	"green": Color(0.0, 1.0, 0.0, 1.0),
	"yellow": Color(1.0, 1.0, 0.0, 1.0),
	"cyan": Color(0.0, 1.0, 1.0, 1.0),
	"red": Color(1.0, 0.0, 0.0, 1.0),
	"magenta": Color(1.0, 0.0, 1.0, 1.0),
	"blue": Color(0.24, 0.52, 1.0, 1.0),
	"orange": Color(1.0, 0.56, 0.0, 1.0),
}

const CROSSHAIR_PROPERTIES: Array[StringName] = [
	&"crosshair_size",
	&"crosshair_alpha",
	&"crosshair_shape",
	&"color_mode",
	&"color_preset",
	&"custom_color_r",
	&"custom_color_g",
	&"custom_color_b",
	&"line_length",
	&"line_thickness",
	&"line_gap",
	&"use_t_shape",
	&"outline_enabled",
	&"outline_color_r",
	&"outline_color_g",
	&"outline_color_b",
	&"outline_thickness",
	&"show_center_dot",
	&"center_dot_size",
	&"center_dot_alpha",
	&"enable_dynamic_spread",
	&"spread_increase_per_shot",
	&"recovery_rate",
	&"max_spread_multiplier",
	&"hit_feedback_enabled",
	&"hit_feedback_duration",
	&"hit_feedback_scale",
	&"hit_feedback_intensity",
	&"hit_feedback_expand_ratio",
	&"hit_feedback_pulse_speed",
	&"hit_feedback_max_stacks",
	&"hit_feedback_stacking_mode",
	&"hit_feedback_color_r",
	&"hit_feedback_color_g",
	&"hit_feedback_color_b",
]

# ============================================
# 内部状态
# ============================================

var _settings: CrosshairSettings
var _is_initialized: bool = false
var _pending_persistence_migration: bool = false

# ============================================
# 生命周期
# ============================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_settings()


# ============================================
# 公共API - 设置管理
# ============================================

## 获取当前设置的副本
func get_settings() -> CrosshairSettings:
	return _settings.copy()


## 更新完整设置
func update_settings(new_settings: CrosshairSettings) -> void:
	if new_settings == null:
		push_warning("[CrosshairSettingsService] Cannot update with null settings")
		return

	# 应用范围限制
	_clamp_settings(new_settings)

	if _apply_settings_values(new_settings):
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 更新单个属性
func update_setting(property_name: StringName, value: Variant) -> void:
	var new_settings: CrosshairSettings = _settings.copy()
	var normalized_value: Variant

	match property_name:
		&"crosshair_size":
			normalized_value = clampf(float(value), SIZE_MIN, SIZE_MAX)

		&"crosshair_alpha":
			normalized_value = clampf(float(value), ALPHA_MIN, ALPHA_MAX)

		&"crosshair_shape":
			normalized_value = _validate_enum(String(value).to_lower(), CrosshairSettingsResource.VALID_SHAPES, _settings.crosshair_shape)

		&"color_mode":
			normalized_value = _validate_enum(String(value).to_lower(), CrosshairSettingsResource.VALID_COLOR_MODES, _settings.color_mode)

		&"color_preset":
			normalized_value = _validate_enum(String(value).to_lower(), CrosshairSettingsResource.VALID_COLOR_PRESETS, _settings.color_preset)

		&"custom_color_r":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"custom_color_g":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"custom_color_b":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"line_length":
			normalized_value = clampf(float(value), LINE_LENGTH_MIN, LINE_LENGTH_MAX)

		&"line_thickness":
			normalized_value = clampf(float(value), LINE_THICKNESS_MIN, LINE_THICKNESS_MAX)

		&"line_gap":
			normalized_value = clampf(float(value), LINE_GAP_MIN, LINE_GAP_MAX)

		&"use_t_shape":
			normalized_value = _validate_bool(value, _settings.use_t_shape)

		&"outline_enabled":
			normalized_value = _validate_bool(value, _settings.outline_enabled)

		&"outline_color_r":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"outline_color_g":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"outline_color_b":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"outline_thickness":
			normalized_value = clampf(float(value), OUTLINE_THICKNESS_MIN, OUTLINE_THICKNESS_MAX)

		&"show_center_dot":
			normalized_value = _validate_bool(value, _settings.show_center_dot)

		&"center_dot_size":
			normalized_value = clampf(float(value), DOT_SIZE_MIN, DOT_SIZE_MAX)

		&"center_dot_alpha":
			normalized_value = clampf(float(value), DOT_ALPHA_MIN, DOT_ALPHA_MAX)

		&"enable_dynamic_spread":
			normalized_value = _validate_bool(value, _settings.enable_dynamic_spread)

		&"spread_increase_per_shot":
			normalized_value = clampf(float(value), SPREAD_INCREASE_MIN, SPREAD_INCREASE_MAX)

		&"recovery_rate":
			normalized_value = clampf(float(value), RECOVERY_RATE_MIN, RECOVERY_RATE_MAX)

		&"max_spread_multiplier":
			normalized_value = clampf(float(value), MAX_SPREAD_MULTIPLIER_MIN, MAX_SPREAD_MULTIPLIER_MAX)

		&"hit_feedback_enabled":
			normalized_value = _validate_bool(value, _settings.hit_feedback_enabled)

		&"hit_feedback_duration":
			normalized_value = clampf(float(value), HIT_FEEDBACK_DURATION_MIN, HIT_FEEDBACK_DURATION_MAX)

		&"hit_feedback_scale":
			normalized_value = clampf(float(value), HIT_FEEDBACK_SCALE_MIN, HIT_FEEDBACK_SCALE_MAX)

		&"hit_feedback_intensity":
			normalized_value = clampf(float(value), HIT_FEEDBACK_INTENSITY_MIN, HIT_FEEDBACK_INTENSITY_MAX)

		&"hit_feedback_expand_ratio":
			normalized_value = clampf(float(value), HIT_FEEDBACK_EXPAND_RATIO_MIN, HIT_FEEDBACK_EXPAND_RATIO_MAX)

		&"hit_feedback_pulse_speed":
			normalized_value = clampf(float(value), HIT_FEEDBACK_PULSE_SPEED_MIN, HIT_FEEDBACK_PULSE_SPEED_MAX)

		&"hit_feedback_max_stacks":
			normalized_value = clampi(int(value), HIT_FEEDBACK_MAX_STACKS_MIN, HIT_FEEDBACK_MAX_STACKS_MAX)

		&"hit_feedback_stacking_mode":
			normalized_value = _validate_enum(
				String(value).to_lower(),
				CrosshairSettingsResource.VALID_HIT_FEEDBACK_STACKING_MODES,
				_settings.hit_feedback_stacking_mode
			)

		&"hit_feedback_color_r":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"hit_feedback_color_g":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		&"hit_feedback_color_b":
			normalized_value = clampf(float(value), COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)

		_:
			push_warning("[CrosshairSettingsService] Unknown property: %s" % property_name)
			return

	new_settings.set(property_name, normalized_value)

	if _apply_settings_values(new_settings):
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 重置为默认值
func reset_to_defaults() -> void:
	var default_settings := CrosshairSettingsResource.get_defaults() as CrosshairSettings
	_clamp_settings(default_settings)

	if _apply_settings_values(default_settings):
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 从磁盘重新加载设置
func reload_settings() -> void:
	var loaded_settings: CrosshairSettings = _load_settings_from_disk()
	if loaded_settings != null:
		_clamp_settings(loaded_settings)

		if _apply_settings_values(loaded_settings):
			settings_changed.emit(_settings.copy())
		else:
			settings_changed.emit(_settings.copy())
		settings_loaded.emit(_settings.copy())
		if _pending_persistence_migration:
			_pending_persistence_migration = false
			_save_settings_deferred()


# ============================================
# 公共API - Getter/Setter 便捷方法
# ============================================

func set_crosshair_size(value: float) -> void:
	update_setting(&"crosshair_size", value)


func get_crosshair_size() -> float:
	return _settings.crosshair_size


func set_crosshair_alpha(value: float) -> void:
	update_setting(&"crosshair_alpha", value)


func get_crosshair_alpha() -> float:
	return _settings.crosshair_alpha


func set_crosshair_shape(value: String) -> void:
	update_setting(&"crosshair_shape", value)


func get_crosshair_shape() -> String:
	return _settings.crosshair_shape


func set_color_mode(value: String) -> void:
	update_setting(&"color_mode", value)


func get_color_mode() -> String:
	return _settings.color_mode


func set_color_preset(value: String) -> void:
	update_setting(&"color_preset", value)


func get_color_preset() -> String:
	return _settings.color_preset


func set_custom_color_r(value: float) -> void:
	update_setting(&"custom_color_r", value)


func get_custom_color_r() -> float:
	return _settings.custom_color_r


func set_custom_color_g(value: float) -> void:
	update_setting(&"custom_color_g", value)


func get_custom_color_g() -> float:
	return _settings.custom_color_g


func set_custom_color_b(value: float) -> void:
	update_setting(&"custom_color_b", value)


func get_custom_color_b() -> float:
	return _settings.custom_color_b


func set_line_length(value: float) -> void:
	update_setting(&"line_length", value)


func get_line_length() -> float:
	return _settings.line_length


func set_line_thickness(value: float) -> void:
	update_setting(&"line_thickness", value)


func get_line_thickness() -> float:
	return _settings.line_thickness


func set_line_gap(value: float) -> void:
	update_setting(&"line_gap", value)


func get_line_gap() -> float:
	return _settings.line_gap


func set_use_t_shape(value: bool) -> void:
	update_setting(&"use_t_shape", value)


func get_use_t_shape() -> bool:
	return _settings.use_t_shape


func set_outline_enabled(value: bool) -> void:
	update_setting(&"outline_enabled", value)


func get_outline_enabled() -> bool:
	return _settings.outline_enabled


func set_outline_color_r(value: float) -> void:
	update_setting(&"outline_color_r", value)


func get_outline_color_r() -> float:
	return _settings.outline_color_r


func set_outline_color_g(value: float) -> void:
	update_setting(&"outline_color_g", value)


func get_outline_color_g() -> float:
	return _settings.outline_color_g


func set_outline_color_b(value: float) -> void:
	update_setting(&"outline_color_b", value)


func get_outline_color_b() -> float:
	return _settings.outline_color_b


func set_outline_thickness(value: float) -> void:
	update_setting(&"outline_thickness", value)


func get_outline_thickness() -> float:
	return _settings.outline_thickness


func set_show_center_dot(value: bool) -> void:
	update_setting(&"show_center_dot", value)


func get_show_center_dot() -> bool:
	return _settings.show_center_dot


func set_center_dot_size(value: float) -> void:
	update_setting(&"center_dot_size", value)


func get_center_dot_size() -> float:
	return _settings.center_dot_size


func set_center_dot_alpha(value: float) -> void:
	update_setting(&"center_dot_alpha", value)


func get_center_dot_alpha() -> float:
	return _settings.center_dot_alpha


func set_enable_dynamic_spread(value: bool) -> void:
	update_setting(&"enable_dynamic_spread", value)


func get_enable_dynamic_spread() -> bool:
	return _settings.enable_dynamic_spread


func set_spread_increase_per_shot(value: float) -> void:
	update_setting(&"spread_increase_per_shot", value)


func get_spread_increase_per_shot() -> float:
	return _settings.spread_increase_per_shot


func set_recovery_rate(value: float) -> void:
	update_setting(&"recovery_rate", value)


func get_recovery_rate() -> float:
	return _settings.recovery_rate


func set_max_spread_multiplier(value: float) -> void:
	update_setting(&"max_spread_multiplier", value)


func get_max_spread_multiplier() -> float:
	return _settings.max_spread_multiplier


func set_hit_feedback_enabled(value: bool) -> void:
	update_setting(&"hit_feedback_enabled", value)


func get_hit_feedback_enabled() -> bool:
	return _settings.hit_feedback_enabled


func set_hit_feedback_duration(value: float) -> void:
	update_setting(&"hit_feedback_duration", value)


func get_hit_feedback_duration() -> float:
	return _settings.hit_feedback_duration


func set_hit_feedback_scale(value: float) -> void:
	update_setting(&"hit_feedback_scale", value)


func get_hit_feedback_scale() -> float:
	return _settings.hit_feedback_scale


func set_hit_feedback_intensity(value: float) -> void:
	update_setting(&"hit_feedback_intensity", value)


func get_hit_feedback_intensity() -> float:
	return _settings.hit_feedback_intensity


func set_hit_feedback_expand_ratio(value: float) -> void:
	update_setting(&"hit_feedback_expand_ratio", value)


func get_hit_feedback_expand_ratio() -> float:
	return _settings.hit_feedback_expand_ratio


func set_hit_feedback_pulse_speed(value: float) -> void:
	update_setting(&"hit_feedback_pulse_speed", value)


func get_hit_feedback_pulse_speed() -> float:
	return _settings.hit_feedback_pulse_speed


func set_hit_feedback_max_stacks(value: int) -> void:
	update_setting(&"hit_feedback_max_stacks", value)


func get_hit_feedback_max_stacks() -> int:
	return _settings.hit_feedback_max_stacks


func set_hit_feedback_stacking_mode(value: String) -> void:
	update_setting(&"hit_feedback_stacking_mode", value)


func get_hit_feedback_stacking_mode() -> String:
	return _settings.hit_feedback_stacking_mode


func set_hit_feedback_color_r(value: float) -> void:
	update_setting(&"hit_feedback_color_r", value)


func get_hit_feedback_color_r() -> float:
	return _settings.hit_feedback_color_r


func set_hit_feedback_color_g(value: float) -> void:
	update_setting(&"hit_feedback_color_g", value)


func get_hit_feedback_color_g() -> float:
	return _settings.hit_feedback_color_g


func set_hit_feedback_color_b(value: float) -> void:
	update_setting(&"hit_feedback_color_b", value)


func get_hit_feedback_color_b() -> float:
	return _settings.hit_feedback_color_b


# ============================================
# 私有方法
# ============================================

func _initialize_settings() -> void:
	_pending_persistence_migration = false
	_settings = CrosshairSettingsResource.get_defaults() as CrosshairSettings
	var loaded_settings := _load_settings_from_disk()
	if loaded_settings != null:
		_settings = loaded_settings
	_clamp_settings(_settings)
	_is_initialized = true
	settings_loaded.emit(_settings.copy())
	if _pending_persistence_migration:
		_pending_persistence_migration = false
		_save_settings_deferred()


func _clamp_settings(settings: CrosshairSettings) -> void:
	settings.crosshair_shape = _validate_enum(
		settings.crosshair_shape,
		CrosshairSettingsResource.VALID_SHAPES,
		CrosshairSettingsResource.DEFAULT_VALUES["crosshair_shape"]
	)
	settings.color_mode = _validate_enum(
		settings.color_mode,
		CrosshairSettingsResource.VALID_COLOR_MODES,
		CrosshairSettingsResource.DEFAULT_VALUES["color_mode"]
	)
	settings.color_preset = _validate_enum(
		settings.color_preset,
		CrosshairSettingsResource.VALID_COLOR_PRESETS,
		CrosshairSettingsResource.DEFAULT_VALUES["color_preset"]
	)
	settings.crosshair_size = clampf(settings.crosshair_size, SIZE_MIN, SIZE_MAX)
	settings.crosshair_alpha = clampf(settings.crosshair_alpha, ALPHA_MIN, ALPHA_MAX)
	settings.custom_color_r = clampf(settings.custom_color_r, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.custom_color_g = clampf(settings.custom_color_g, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.custom_color_b = clampf(settings.custom_color_b, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.line_length = clampf(settings.line_length, LINE_LENGTH_MIN, LINE_LENGTH_MAX)
	settings.line_thickness = clampf(settings.line_thickness, LINE_THICKNESS_MIN, LINE_THICKNESS_MAX)
	settings.line_gap = clampf(settings.line_gap, LINE_GAP_MIN, LINE_GAP_MAX)
	settings.outline_color_r = clampf(settings.outline_color_r, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.outline_color_g = clampf(settings.outline_color_g, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.outline_color_b = clampf(settings.outline_color_b, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.outline_thickness = clampf(settings.outline_thickness, OUTLINE_THICKNESS_MIN, OUTLINE_THICKNESS_MAX)
	settings.center_dot_size = clampf(
		settings.center_dot_size, DOT_SIZE_MIN, DOT_SIZE_MAX
	)
	settings.center_dot_alpha = clampf(settings.center_dot_alpha, DOT_ALPHA_MIN, DOT_ALPHA_MAX)
	settings.spread_increase_per_shot = clampf(
		settings.spread_increase_per_shot, SPREAD_INCREASE_MIN, SPREAD_INCREASE_MAX
	)
	settings.recovery_rate = clampf(
		settings.recovery_rate, RECOVERY_RATE_MIN, RECOVERY_RATE_MAX
	)
	settings.max_spread_multiplier = clampf(
		settings.max_spread_multiplier, MAX_SPREAD_MULTIPLIER_MIN, MAX_SPREAD_MULTIPLIER_MAX
	)
	settings.hit_feedback_duration = clampf(
		settings.hit_feedback_duration, HIT_FEEDBACK_DURATION_MIN, HIT_FEEDBACK_DURATION_MAX
	)
	settings.hit_feedback_scale = clampf(
		settings.hit_feedback_scale, HIT_FEEDBACK_SCALE_MIN, HIT_FEEDBACK_SCALE_MAX
	)
	settings.hit_feedback_intensity = clampf(
		settings.hit_feedback_intensity, HIT_FEEDBACK_INTENSITY_MIN, HIT_FEEDBACK_INTENSITY_MAX
	)
	settings.hit_feedback_expand_ratio = clampf(
		settings.hit_feedback_expand_ratio, HIT_FEEDBACK_EXPAND_RATIO_MIN, HIT_FEEDBACK_EXPAND_RATIO_MAX
	)
	settings.hit_feedback_pulse_speed = clampf(
		settings.hit_feedback_pulse_speed, HIT_FEEDBACK_PULSE_SPEED_MIN, HIT_FEEDBACK_PULSE_SPEED_MAX
	)
	settings.hit_feedback_max_stacks = clampi(
		settings.hit_feedback_max_stacks, HIT_FEEDBACK_MAX_STACKS_MIN, HIT_FEEDBACK_MAX_STACKS_MAX
	)
	settings.hit_feedback_stacking_mode = _validate_enum(
		settings.hit_feedback_stacking_mode,
		CrosshairSettingsResource.VALID_HIT_FEEDBACK_STACKING_MODES,
		CrosshairSettingsResource.DEFAULT_VALUES["hit_feedback_stacking_mode"]
	)
	settings.hit_feedback_color_r = clampf(settings.hit_feedback_color_r, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.hit_feedback_color_g = clampf(settings.hit_feedback_color_g, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)
	settings.hit_feedback_color_b = clampf(settings.hit_feedback_color_b, COLOR_CHANNEL_MIN, COLOR_CHANNEL_MAX)


func _save_settings_deferred() -> void:
	call_deferred("_save_settings_to_disk")


func _save_settings_to_disk() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("[CrosshairSettingsService] SaveManager not found, settings will not be persisted")
		settings_saved.emit(false)
		return

	var settings_dict := _settings.to_persisted_dictionary()

	# 使用 SaveManager 保存设置
	if save_manager.has_method("save_settings"):
		save_manager.save_settings(settings_dict)
		settings_saved.emit(true)
	else:
		push_warning("[CrosshairSettingsService] SaveManager does not have save_settings method")
		settings_saved.emit(false)


func _load_settings_from_disk() -> CrosshairSettings:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("[CrosshairSettingsService] SaveManager not found, using default settings")
		return null

	if not save_manager.has_method("load_settings"):
		push_warning("[CrosshairSettingsService] SaveManager does not have load_settings method")
		return null

	var loaded_dict: Dictionary = save_manager.load_settings()
	if loaded_dict.is_empty():
		return null

	var settings := CrosshairSettingsResource.get_defaults() as CrosshairSettings
	settings.from_dictionary(loaded_dict)
	var normalized_persisted := settings.to_persisted_dictionary()
	if _requires_persisted_migration(loaded_dict, normalized_persisted):
		_pending_persistence_migration = true

	return settings


func _requires_persisted_migration(raw_settings: Dictionary, normalized_persisted: Dictionary) -> bool:
	for persisted_key in normalized_persisted.keys():
		if not raw_settings.has(persisted_key):
			return true

	var persisted_key_map: Dictionary = CrosshairSettingsResource.get_persisted_key_map()
	var property_aliases: Dictionary = CrosshairSettingsResource.get_property_key_aliases()

	for property_name in persisted_key_map.keys():
		var persisted_key := String(persisted_key_map[property_name])
		var aliases: Array = property_aliases.get(property_name, [])
		for alias in aliases:
			var alias_key := String(alias)
			if alias_key == String(property_name) or alias_key == persisted_key:
				continue
			if raw_settings.has(alias_key):
				return true

	return false


func _apply_settings_values(source_settings: CrosshairSettings) -> bool:
	var has_changed := false

	for property_name in CROSSHAIR_PROPERTIES:
		var current_value: Variant = _settings.get(property_name)
		var incoming_value: Variant = source_settings.get(property_name)
		if _values_match(current_value, incoming_value):
			continue

		_settings.set(property_name, incoming_value)
		setting_changed.emit(property_name, _settings.get(property_name))
		has_changed = true

	return has_changed


func _values_match(current_value: Variant, incoming_value: Variant) -> bool:
	match typeof(current_value):
		TYPE_FLOAT:
			return is_equal_approx(float(current_value), float(incoming_value))
		TYPE_INT:
			return int(current_value) == int(incoming_value)
		_:
			return current_value == incoming_value


func _validate_enum(value: String, valid_values: Array, fallback: String) -> String:
	return value if valid_values.has(value) else fallback


func _validate_bool(value: Variant, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT and (value == 0 or value == 1):
		return bool(value)
	return fallback
