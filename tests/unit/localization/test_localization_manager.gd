# tests/unit/localization/test_localization_manager.gd
# TDD Red Phase: These tests define the expected API contract
# They will FAIL cleanly until LocalizationManager is implemented
extends GutTest

## Path to the class under test - file does not exist yet (red phase)
const LOCALIZATION_MANAGER_PATH := "res://src/autoload/localization_manager.gd"

## Cached class reference (null if file missing)
var _localization_manager_class: Variant = null
## System under test
var localization_manager: Variant = null


func before_all() -> void:
	# Load class once - this will be null if file doesn't exist
	_localization_manager_class = load(LOCALIZATION_MANAGER_PATH)


func before_each() -> void:
	# Guard: skip instantiation if class not found
	if not _is_class_available():
		return

	# Instantiate and configure
	localization_manager = _localization_manager_class.new()
	localization_manager.system_name = "localization_manager"
	add_child(localization_manager)

	# Setup test translations (test-only scaffolding)
	_setup_test_translations()


func after_each() -> void:
	if localization_manager:
		localization_manager.queue_free()
		localization_manager = null


## Guard helper: Check if LocalizationManager class is available
## Returns true if class loaded successfully, false otherwise
func _is_class_available() -> bool:
	if _localization_manager_class == null:
		return false
	return true


## Guard helper: Fail test with clear message if class not available
## Returns true if should continue, false if test should return
func _guard_class_exists() -> bool:
	if _is_class_available():
		return true
	# Fail with explicit message - this is the expected red phase failure
	fail_test("LocalizationManager not found at %s - implement the class to make this test pass" % LOCALIZATION_MANAGER_PATH)
	return false


## Guard helper: Fail test if instance not created
func _guard_instance_exists() -> bool:
	if localization_manager != null:
		return true
	fail_test("LocalizationManager instance not created - check before_each() setup")
	return false


## Setup test translations for unit tests only
func _setup_test_translations() -> void:
	# 中文翻译
	var zh_translation := Translation.new()
	zh_translation.locale = "zh_CN"
	zh_translation.add_message("test.hello", "你好")
	TranslationServer.add_translation(zh_translation)

	# 英文翻译
	var en_translation := Translation.new()
	en_translation.locale = "en"
	en_translation.add_message("test.greeting", "Hello, {name}!")
	TranslationServer.add_translation(en_translation)


#region tr() Method Tests

func test_tr_returns_key_when_missing() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	var result: String = localization_manager.call("tr", "nonexistent.key.that.does.not.exist")
	assert_eq(result, "nonexistent.key.that.does.not.exist",
		"tr() should return the key unchanged when translation is missing")


func test_tr_returns_translation_when_exists() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	localization_manager.call("set_locale", "zh_CN")
	var result: String = localization_manager.call("tr", "test.hello")

	assert_ne(result, "test.hello",
		"tr() should return a translated string when translation exists")


func test_tr_with_params() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	localization_manager.call("set_locale", "en")
	var result: String = localization_manager.call("tr", "test.greeting", {"name": "Player"})

	assert_eq(result, "Hello, Player!",
		"tr() should substitute {placeholder} with params values")


#endregion


#region set_locale() Method Tests

func test_set_locale() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	localization_manager.call("set_locale", "en")
	var result: String = localization_manager.call("get_locale")

	assert_eq(result, "en", "set_locale() should change the current locale")


#endregion


#region get_locale() Method Tests

func test_get_locale() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	var result: String = localization_manager.call("get_locale")

	assert_typeof(result, TYPE_STRING, "get_locale() should return a String")
	assert_true(result.length() > 0, "get_locale() should return non-empty string")


#endregion


#region get_available_locales() Method Tests

func test_get_available_locales() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	var locales: Array = localization_manager.call("get_available_locales")

	assert_typeof(locales, TYPE_ARRAY, "get_available_locales() should return an Array")
	assert_eq(locales.size(), 2, "Should have exactly 2 supported locales")
	assert_true("zh_CN" in locales, "Should include zh_CN (Chinese)")
	assert_true("en" in locales, "Should include en (English)")


#endregion


#region Signal Tests

func test_locale_changed_signal() -> void:
	if not _guard_class_exists(): return
	if not _guard_instance_exists(): return

	watch_signals(localization_manager)
	localization_manager.call("set_locale", "en")

	assert_signal_emitted(localization_manager, "locale_changed",
		"locale_changed signal should be emitted on set_locale()")

	# Verify signal count (should be 1 for one locale change)
	var signal_count = get_signal_emit_count(localization_manager, "locale_changed")
	assert_eq(signal_count, 1, "locale_changed should be emitted exactly once")


#endregion
