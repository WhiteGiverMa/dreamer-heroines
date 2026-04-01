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
const SIZE_DEFAULT := 20.0

const ALPHA_MIN := 0.0
const ALPHA_MAX := 1.0
const ALPHA_DEFAULT := 1.0

const DOT_SIZE_MIN := 1.0
const DOT_SIZE_MAX := 10.0
const DOT_SIZE_DEFAULT := 2.0

const SPREAD_INCREASE_MIN := 0.0
const SPREAD_INCREASE_MAX := 20.0
const SPREAD_INCREASE_DEFAULT := 5.0

const RECOVERY_RATE_MIN := 1.0
const RECOVERY_RATE_MAX := 120.0
const RECOVERY_RATE_DEFAULT := 30.0

const MAX_SPREAD_MULTIPLIER_MIN := 1.0
const MAX_SPREAD_MULTIPLIER_MAX := 6.0
const MAX_SPREAD_MULTIPLIER_DEFAULT := 3.0

const SHOW_CENTER_DOT_DEFAULT := true

const SETTINGS_FILE_KEY := "crosshair"

# ============================================
# 内部状态
# ============================================

var _settings: CrosshairSettings
var _is_initialized: bool = false

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

	var has_changed := false

	# 检查每个属性是否有变化
	if not is_equal_approx(_settings.crosshair_size, new_settings.crosshair_size):
		_settings.crosshair_size = new_settings.crosshair_size
		has_changed = true
		setting_changed.emit(&"crosshair_size", _settings.crosshair_size)

	if not is_equal_approx(_settings.crosshair_alpha, new_settings.crosshair_alpha):
		_settings.crosshair_alpha = new_settings.crosshair_alpha
		has_changed = true
		setting_changed.emit(&"crosshair_alpha", _settings.crosshair_alpha)

	if _settings.show_center_dot != new_settings.show_center_dot:
		_settings.show_center_dot = new_settings.show_center_dot
		has_changed = true
		setting_changed.emit(&"show_center_dot", _settings.show_center_dot)

	if not is_equal_approx(_settings.center_dot_size, new_settings.center_dot_size):
		_settings.center_dot_size = new_settings.center_dot_size
		has_changed = true
		setting_changed.emit(&"center_dot_size", _settings.center_dot_size)

	if not is_equal_approx(_settings.spread_increase_per_shot, new_settings.spread_increase_per_shot):
		_settings.spread_increase_per_shot = new_settings.spread_increase_per_shot
		has_changed = true
		setting_changed.emit(&"spread_increase_per_shot", _settings.spread_increase_per_shot)

	if not is_equal_approx(_settings.recovery_rate, new_settings.recovery_rate):
		_settings.recovery_rate = new_settings.recovery_rate
		has_changed = true
		setting_changed.emit(&"recovery_rate", _settings.recovery_rate)

	if not is_equal_approx(_settings.max_spread_multiplier, new_settings.max_spread_multiplier):
		_settings.max_spread_multiplier = new_settings.max_spread_multiplier
		has_changed = true
		setting_changed.emit(&"max_spread_multiplier", _settings.max_spread_multiplier)

	if has_changed:
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 更新单个属性
func update_setting(property_name: StringName, value: Variant) -> void:
	var has_changed := false
	var clamped_value: Variant

	match property_name:
		&"crosshair_size":
			clamped_value = clampf(float(value), SIZE_MIN, SIZE_MAX)
			if not is_equal_approx(_settings.crosshair_size, clamped_value):
				_settings.crosshair_size = clamped_value
				has_changed = true

		&"crosshair_alpha":
			clamped_value = clampf(float(value), ALPHA_MIN, ALPHA_MAX)
			if not is_equal_approx(_settings.crosshair_alpha, clamped_value):
				_settings.crosshair_alpha = clamped_value
				has_changed = true

		&"show_center_dot":
			clamped_value = bool(value)
			if _settings.show_center_dot != clamped_value:
				_settings.show_center_dot = clamped_value
				has_changed = true

		&"center_dot_size":
			clamped_value = clampf(float(value), DOT_SIZE_MIN, DOT_SIZE_MAX)
			if not is_equal_approx(_settings.center_dot_size, clamped_value):
				_settings.center_dot_size = clamped_value
				has_changed = true

		&"spread_increase_per_shot":
			clamped_value = clampf(float(value), SPREAD_INCREASE_MIN, SPREAD_INCREASE_MAX)
			if not is_equal_approx(_settings.spread_increase_per_shot, clamped_value):
				_settings.spread_increase_per_shot = clamped_value
				has_changed = true

		&"recovery_rate":
			clamped_value = clampf(float(value), RECOVERY_RATE_MIN, RECOVERY_RATE_MAX)
			if not is_equal_approx(_settings.recovery_rate, clamped_value):
				_settings.recovery_rate = clamped_value
				has_changed = true

		&"max_spread_multiplier":
			clamped_value = clampf(float(value), MAX_SPREAD_MULTIPLIER_MIN, MAX_SPREAD_MULTIPLIER_MAX)
			if not is_equal_approx(_settings.max_spread_multiplier, clamped_value):
				_settings.max_spread_multiplier = clamped_value
				has_changed = true

		_:
			push_warning("[CrosshairSettingsService] Unknown property: %s" % property_name)
			return

	if has_changed:
		setting_changed.emit(property_name, _settings.get(property_name))
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 重置为默认值
func reset_to_defaults() -> void:
	var old_settings: CrosshairSettings = _settings.copy()
	_settings = CrosshairSettingsResource.new()
	_clamp_settings(_settings)

	var has_changed := false

	if not is_equal_approx(old_settings.crosshair_size, _settings.crosshair_size):
		setting_changed.emit(&"crosshair_size", _settings.crosshair_size)
		has_changed = true

	if not is_equal_approx(old_settings.crosshair_alpha, _settings.crosshair_alpha):
		setting_changed.emit(&"crosshair_alpha", _settings.crosshair_alpha)
		has_changed = true

	if old_settings.show_center_dot != _settings.show_center_dot:
		setting_changed.emit(&"show_center_dot", _settings.show_center_dot)
		has_changed = true

	if not is_equal_approx(old_settings.center_dot_size, _settings.center_dot_size):
		setting_changed.emit(&"center_dot_size", _settings.center_dot_size)
		has_changed = true

	if not is_equal_approx(old_settings.spread_increase_per_shot, _settings.spread_increase_per_shot):
		setting_changed.emit(&"spread_increase_per_shot", _settings.spread_increase_per_shot)
		has_changed = true

	if not is_equal_approx(old_settings.recovery_rate, _settings.recovery_rate):
		setting_changed.emit(&"recovery_rate", _settings.recovery_rate)
		has_changed = true

	if not is_equal_approx(old_settings.max_spread_multiplier, _settings.max_spread_multiplier):
		setting_changed.emit(&"max_spread_multiplier", _settings.max_spread_multiplier)
		has_changed = true

	if has_changed:
		settings_changed.emit(_settings.copy())
		_save_settings_deferred()


## 从磁盘重新加载设置
func reload_settings() -> void:
	var loaded_settings: CrosshairSettings = _load_settings_from_disk()
	if loaded_settings != null:
		var old_settings: CrosshairSettings = _settings.copy()
		_settings = loaded_settings
		_clamp_settings(_settings)

		# 检查哪些属性发生了变化
		if not is_equal_approx(old_settings.crosshair_size, _settings.crosshair_size):
			setting_changed.emit(&"crosshair_size", _settings.crosshair_size)

		if not is_equal_approx(old_settings.crosshair_alpha, _settings.crosshair_alpha):
			setting_changed.emit(&"crosshair_alpha", _settings.crosshair_alpha)

		if old_settings.show_center_dot != _settings.show_center_dot:
			setting_changed.emit(&"show_center_dot", _settings.show_center_dot)

		if not is_equal_approx(old_settings.center_dot_size, _settings.center_dot_size):
			setting_changed.emit(&"center_dot_size", _settings.center_dot_size)

		if not is_equal_approx(old_settings.spread_increase_per_shot, _settings.spread_increase_per_shot):
			setting_changed.emit(&"spread_increase_per_shot", _settings.spread_increase_per_shot)

		if not is_equal_approx(old_settings.recovery_rate, _settings.recovery_rate):
			setting_changed.emit(&"recovery_rate", _settings.recovery_rate)

		if not is_equal_approx(old_settings.max_spread_multiplier, _settings.max_spread_multiplier):
			setting_changed.emit(&"max_spread_multiplier", _settings.max_spread_multiplier)

		settings_changed.emit(_settings.copy())
		settings_loaded.emit(_settings.copy())


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


func set_show_center_dot(value: bool) -> void:
	update_setting(&"show_center_dot", value)


func get_show_center_dot() -> bool:
	return _settings.show_center_dot


func set_center_dot_size(value: float) -> void:
	update_setting(&"center_dot_size", value)


func get_center_dot_size() -> float:
	return _settings.center_dot_size


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


# ============================================
# 私有方法
# ============================================

func _initialize_settings() -> void:
	_settings = CrosshairSettingsResource.new()
	var loaded_settings := _load_settings_from_disk()
	if loaded_settings != null:
		_settings = loaded_settings
	_clamp_settings(_settings)
	_is_initialized = true
	settings_loaded.emit(_settings.copy())


func _clamp_settings(settings: CrosshairSettings) -> void:
	settings.crosshair_size = clampf(settings.crosshair_size, SIZE_MIN, SIZE_MAX)
	settings.crosshair_alpha = clampf(settings.crosshair_alpha, ALPHA_MIN, ALPHA_MAX)
	settings.center_dot_size = clampf(
		settings.center_dot_size, DOT_SIZE_MIN, DOT_SIZE_MAX
	)
	settings.spread_increase_per_shot = clampf(
		settings.spread_increase_per_shot, SPREAD_INCREASE_MIN, SPREAD_INCREASE_MAX
	)
	settings.recovery_rate = clampf(
		settings.recovery_rate, RECOVERY_RATE_MIN, RECOVERY_RATE_MAX
	)
	settings.max_spread_multiplier = clampf(
		settings.max_spread_multiplier, MAX_SPREAD_MULTIPLIER_MIN, MAX_SPREAD_MULTIPLIER_MAX
	)


func _save_settings_deferred() -> void:
	call_deferred("_save_settings_to_disk")


func _save_settings_to_disk() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("[CrosshairSettingsService] SaveManager not found, settings will not be persisted")
		settings_saved.emit(false)
		return

	var settings_dict := {
		"crosshair_size": _settings.crosshair_size,
		"crosshair_alpha": _settings.crosshair_alpha,
		"show_center_dot": _settings.show_center_dot,
		"center_dot_size": _settings.center_dot_size,
		"spread_increase_per_shot": _settings.spread_increase_per_shot,
		"crosshair_recovery_rate": _settings.recovery_rate,
		"max_spread_multiplier": _settings.max_spread_multiplier
	}

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

	var settings := CrosshairSettingsResource.new()

	if loaded_dict.has("crosshair_size"):
		settings.crosshair_size = float(loaded_dict["crosshair_size"])
	if loaded_dict.has("crosshair_alpha"):
		settings.crosshair_alpha = float(loaded_dict["crosshair_alpha"])
	if loaded_dict.has("show_center_dot"):
		settings.show_center_dot = bool(loaded_dict["show_center_dot"])
	if loaded_dict.has("center_dot_size"):
		settings.center_dot_size = float(loaded_dict["center_dot_size"])
	if loaded_dict.has("spread_increase_per_shot"):
		settings.spread_increase_per_shot = float(loaded_dict["spread_increase_per_shot"])
	if loaded_dict.has("crosshair_recovery_rate"):
		settings.recovery_rate = float(loaded_dict["crosshair_recovery_rate"])
	elif loaded_dict.has("recovery_rate"):
		settings.recovery_rate = float(loaded_dict["recovery_rate"])
	if loaded_dict.has("max_spread_multiplier"):
		settings.max_spread_multiplier = float(loaded_dict["max_spread_multiplier"])

	return settings
