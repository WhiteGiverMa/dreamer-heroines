extends Node

## UISettingsService - UI设置服务层
## 提供UI相关设置的集中管理，支持运行时信号传播

# ============================================
# 信号（解耦关键）
# ============================================

## 设置整体变更时发射
signal settings_changed(settings: Dictionary)

## 单个属性变更时发射
signal setting_changed(property_name: StringName, value: Variant)

## 设置加载完成时发射
signal settings_loaded(settings: Dictionary)

## 设置保存完成时发射
signal settings_saved(success: bool)

# ============================================
# 常量（默认值）
# ============================================

const DEFAULT_UI_SETTINGS := {
	"slider_wheel_on_slider": true,  # 悬停时消费滚轮
}

const SETTINGS_FILE_KEY := "ui_settings"

# ============================================
# 内部状态
# ============================================

var _settings: Dictionary = DEFAULT_UI_SETTINGS.duplicate()
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
func get_settings() -> Dictionary:
	return _settings.duplicate()


## 获取单个设置值
func get_setting(key: StringName) -> Variant:
	return _settings.get(key, DEFAULT_UI_SETTINGS.get(key, null))


## 更新单个属性
func set_setting(key: StringName, value: Variant, save: bool = true) -> void:
	if not DEFAULT_UI_SETTINGS.has(key):
		push_warning("[UISettingsService] Unknown setting key: %s" % key)
		return

	var normalized_value: Variant = _normalize_value(key, value)

	if _settings.get(key) == normalized_value:
		return  # 无变化

	_settings[key] = normalized_value
	setting_changed.emit(key, normalized_value)
	settings_changed.emit(_settings.duplicate())

	if save:
		_save_settings_deferred()


## 重置为默认值
func reset_to_defaults() -> void:
	_settings = DEFAULT_UI_SETTINGS.duplicate()
	settings_changed.emit(_settings.duplicate())
	_save_settings_deferred()


## 从磁盘重新加载设置
func reload_settings() -> void:
	var loaded_settings: Dictionary = _load_settings_from_disk()

	for key in DEFAULT_UI_SETTINGS.keys():
		if loaded_settings.has(key):
			_settings[key] = loaded_settings[key]
		else:
			_settings[key] = DEFAULT_UI_SETTINGS[key]

	_is_initialized = true
	settings_loaded.emit(_settings.duplicate())


# ============================================
# 公共API - 便捷方法
# ============================================


func set_slider_wheel_on_slider(enabled: bool) -> void:
	set_setting(&"slider_wheel_on_slider", enabled)


func get_slider_wheel_on_slider() -> bool:
	return _settings.get("slider_wheel_on_slider", DEFAULT_UI_SETTINGS["slider_wheel_on_slider"])


# ============================================
# 私有方法
# ============================================


func _initialize_settings() -> void:
	var loaded_settings := _load_settings_from_disk()

	for key in DEFAULT_UI_SETTINGS.keys():
		if loaded_settings.has(key):
			_settings[key] = loaded_settings[key]

	_is_initialized = true
	settings_loaded.emit(_settings.duplicate())


func _normalize_value(key: StringName, value: Variant) -> Variant:
	match key:
		&"slider_wheel_on_slider":
			return _validate_bool(value, DEFAULT_UI_SETTINGS["slider_wheel_on_slider"])
		_:
			return value


func _validate_bool(value: Variant, fallback: bool) -> bool:
	if typeof(value) == TYPE_BOOL:
		return value
	if typeof(value) == TYPE_INT and (value == 0 or value == 1):
		return bool(value)
	return fallback


func _save_settings_deferred() -> void:
	call_deferred("_save_settings_to_disk")


func _save_settings_to_disk() -> void:
	if not is_inside_tree() or get_tree() == null:
		settings_saved.emit(false)
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("[UISettingsService] SaveManager not found, settings will not be persisted")
		settings_saved.emit(false)
		return

	# 加载现有设置以保留非UI设置
	var all_settings: Dictionary = save_manager.load_settings()

	# 合并UI设置
	for key in _settings.keys():
		all_settings[key] = _settings[key]

	# 保存
	if save_manager.has_method("save_settings"):
		save_manager.save_settings(all_settings)
		settings_saved.emit(true)
	else:
		push_warning("[UISettingsService] SaveManager does not have save_settings method")
		settings_saved.emit(false)


func _load_settings_from_disk() -> Dictionary:
	if not is_inside_tree() or get_tree() == null:
		return {}

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		push_warning("[UISettingsService] SaveManager not found, using default settings")
		return {}

	if not save_manager.has_method("load_settings"):
		push_warning("[UISettingsService] SaveManager does not have load_settings method")
		return {}

	return save_manager.load_settings()
