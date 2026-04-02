# src/autoload/localization_manager.gd
extends "res://src/base/game_system.gd"

## LocalizationManager - 多语言本地化管理器
## 负责管理游戏文本翻译和语言切换

## 支持的语言列表
const AVAILABLE_LOCALES: Array[String] = ["zh_CN", "en"]

## 信号定义
signal locale_changed(new_locale: String)
signal ready_changed(is_ready: bool)

## 当前语言
var _current_locale: String = "zh_CN"
var _registered_translation_paths: Dictionary = {}
var _source_translations_by_locale: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "localization_manager"
	# 尽早加载翻译资源，避免 UI 在初始化时读到 raw key
	_load_configured_translations()


func initialize() -> void:
	_load_configured_translations()

	# 设置初始语言（使用系统语言或默认值）
	var system_locale := TranslationServer.get_locale()
	if system_locale in AVAILABLE_LOCALES:
		_current_locale = system_locale
	else:
		# 尝试匹配语言前缀
		var lang_code := system_locale.split("_")[0]
		for locale in AVAILABLE_LOCALES:
			if locale.begins_with(lang_code):
				_current_locale = locale
				break

	TranslationServer.set_locale(_current_locale)
	# 初始化完成后主动广播一次，确保已加载 UI 刷新文本
	locale_changed.emit(_current_locale)

	_mark_ready()
	ready_changed.emit(true)


func _load_configured_translations() -> void:
	var translation_paths: PackedStringArray = ProjectSettings.get_setting(
		"internationalization/translations",
		PackedStringArray()
	)

	for path in translation_paths:
		_load_source_translation(path)

		if _registered_translation_paths.has(path):
			continue

		var resource := load(path)
		if resource is Translation:
			TranslationServer.add_translation(resource)
			_registered_translation_paths[path] = true
		else:
			push_warning("[LocalizationManager] 无法加载翻译资源: %s" % path)


func _load_source_translation(path: String) -> void:
	var locale_code := path.get_file().get_basename()
	if locale_code.is_empty():
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	_source_translations_by_locale[locale_code] = _parse_po_translation(file.get_as_text())


func _parse_po_translation(file_text: String) -> Dictionary:
	var parsed_entries: Dictionary = {}
	var lines := file_text.split("\n", false)
	var current_msgid := ""
	var current_msgstr := ""
	var active_field := ""

	for raw_line in lines:
		var line := raw_line.strip_edges()

		if line.is_empty():
			_finalize_po_entry(parsed_entries, current_msgid, current_msgstr)
			current_msgid = ""
			current_msgstr = ""
			active_field = ""
			continue

		if line.begins_with("#"):
			continue

		if line.begins_with("msgid "):
			_finalize_po_entry(parsed_entries, current_msgid, current_msgstr)
			current_msgid = _decode_po_string(line.trim_prefix("msgid "))
			current_msgstr = ""
			active_field = "msgid"
			continue

		if line.begins_with("msgstr "):
			current_msgstr = _decode_po_string(line.trim_prefix("msgstr "))
			active_field = "msgstr"
			continue

		if line.begins_with("\""):
			var decoded := _decode_po_string(line)
			if active_field == "msgid":
				current_msgid += decoded
			elif active_field == "msgstr":
				current_msgstr += decoded

	_finalize_po_entry(parsed_entries, current_msgid, current_msgstr)
	return parsed_entries


func _finalize_po_entry(parsed_entries: Dictionary, msgid: String, msgstr: String) -> void:
	if msgid.is_empty():
		return

	parsed_entries[msgid] = msgstr


func _decode_po_string(value: String) -> String:
	var decoded := value.strip_edges()
	if decoded.begins_with("\"") and decoded.ends_with("\"") and decoded.length() >= 2:
		decoded = decoded.substr(1, decoded.length() - 2)

	decoded = decoded.replace("\\n", "\n")
	decoded = decoded.replace("\\\"", "\"")
	decoded = decoded.replace("\\\\", "\\")
	return decoded


## 翻译文本
## 签名匹配 Godot 内置 Object.tr() 以避免解析错误
## 使用 Variant 作为第二参数类型以支持 Dictionary 传递
## @param message: 翻译键 (StringName 兼容 String)
## @param context: 可选上下文或插值参数字典
## @return: 翻译后的文本，如果找不到则返回原始键
@warning_ignore("native_method_override")
func tr(message: StringName, context: Variant = &"") -> String:
	var key := String(message)
	var translated := key
	var params: Dictionary = {}

	# context 可能是 StringName (默认) 或 Dictionary (通过 call() 传递)
	if context is Dictionary:
		params = context

	# 使用 TranslationServer 获取翻译
	var server_result := TranslationServer.translate(key)
	if not server_result.is_empty() and server_result != key:
		translated = server_result

	var source_translations: Dictionary = _source_translations_by_locale.get(_current_locale, {}) as Dictionary
	if source_translations.has(key):
		translated = String(source_translations[key])

	# 插值参数替换
	for param_key in params:
		var placeholder := "{%s}" % param_key
		var value := str(params[param_key])
		translated = translated.replace(placeholder, value)

	return translated


## 设置当前语言
## @param locale_code: 语言代码（如 "zh_CN", "en"）
func set_locale(locale_code: String) -> void:
	# 空字符串不执行任何操作
	if locale_code.is_empty():
		return

	# 如果语言未变化，跳过
	if locale_code == _current_locale:
		return

	# 验证语言是否支持
	if locale_code not in AVAILABLE_LOCALES:
		push_warning("[LocalizationManager] 不支持的语言: %s" % locale_code)
		return

	_current_locale = locale_code
	TranslationServer.set_locale(_current_locale)

	locale_changed.emit(_current_locale)


## 获取当前语言
## @return: 当前语言代码
func get_locale() -> String:
	return _current_locale


## 获取支持的语言列表
## @return: 支持的语言代码数组
func get_available_locales() -> Array[String]:
	return AVAILABLE_LOCALES
