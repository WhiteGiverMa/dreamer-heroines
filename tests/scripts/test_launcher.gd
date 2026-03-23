extends Node

## 集成测试启动器
## 执行自动化测试，包括本地化集成测试

class_name TestLauncher

@export var auto_exit: bool = true

var _test_results: Array[Dictionary] = []


func _ready() -> void:
	_print_header()

	# Load translations manually since they aren't auto-loaded from project.godot in test context
	_load_translations_manually()

	# Run tests immediately in _ready() before boot sequence redirect
	_run_all_tests_sync()

	_print_summary()
	_save_results()

	if auto_exit:
		var failed = _test_results.filter(func(r): return not r.passed).size()
		get_tree().quit(0 if failed == 0 else 1)


## Load translations manually from .po files
func _load_translations_manually() -> void:
	var translation_files := [
		"res://localization/zh_CN.po",
		"res://localization/en.po",
	]

	for file_path in translation_files:
		if ResourceLoader.exists(file_path):
			var translation = load(file_path)
			if translation is Translation:
				TranslationServer.add_translation(translation)


func _print_header() -> void:
	print("\n" + "=".repeat(60))
	print("  自动化集成测试启动器")
	print("=".repeat(60))
	print("  测试类型: 本地化集成测试")
	print("=".repeat(60) + "\n")


func _run_all_tests_sync() -> void:
	var tests := _get_test_cases()
	print("执行 %d 个测试用例...\n" % tests.size())

	for test in tests:
		var result := _run_test_sync(test)
		_test_results.append(result)

		if result.passed:
			print("  [PASS] %s" % test.name)
		else:
			print("  [FAIL] %s: %s" % [test.name, result.error])


func _get_test_cases() -> Array[Dictionary]:
	return [
		# Localization integration tests (Task 8)
		{
			"name": "test_localization_manager_exists",
			"description": "验证 LocalizationManager autoload 存在",
		},
		{
			"name": "test_locale_switch_zh_cn",
			"description": "测试切换到中文语言",
		},
		{
			"name": "test_locale_switch_en",
			"description": "测试切换到英文语言",
		},
		{
			"name": "test_weapon_name_zh_cn",
			"description": "测试武器中文名称显示",
		},
		{
			"name": "test_weapon_name_en",
			"description": "测试武器英文名称显示",
		},
		{
			"name": "test_weapon_description_zh_cn",
			"description": "测试武器中文描述显示",
		},
		{
			"name": "test_weapon_description_en",
			"description": "测试武器英文描述显示",
		},
		{
			"name": "test_weapon_class_description_delegates",
			"description": "测试武器类描述委托到 LocalizationManager",
		},
	]


func _run_test_sync(test: Dictionary) -> Dictionary:
	var result := {"name": test.name, "description": test.description, "passed": false, "error": ""}
	var loc_manager = get_node_or_null("/root/LocalizationManager")

	match test.name:
		"test_localization_manager_exists":
			# Just check if the autoload exists - don't require initialization
			if loc_manager == null:
				result.error = "LocalizationManager autoload 不存在"
			else:
				result.passed = true

		"test_locale_switch_zh_cn":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("zh_CN")
				if loc_manager.get_locale() != "zh_CN":
					result.error = "当前语言 = %s, 期望 zh_CN" % loc_manager.get_locale()
				else:
					result.passed = true

		"test_locale_switch_en":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("en")
				if loc_manager.get_locale() != "en":
					result.error = "当前语言 = %s, 期望 en" % loc_manager.get_locale()
				else:
					result.passed = true
				loc_manager.set_locale("zh_CN")

		"test_weapon_name_zh_cn":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("zh_CN")
				var stats = _load_weapon_stats("rifle_basic")
				if stats == null:
					result.error = "无法加载 rifle_basic 武器资源"
				else:
					var display_name = stats.get_display_name()
					if display_name != "基础步枪":
						result.error = "武器名称 = '%s', 期望 '基础步枪'" % display_name
					else:
						result.passed = true

		"test_weapon_name_en":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("en")
				var stats = _load_weapon_stats("rifle_basic")
				if stats == null:
					result.error = "无法加载 rifle_basic 武器资源"
				else:
					var display_name = stats.get_display_name()
					if display_name != "Basic Rifle":
						result.error = "武器名称 = '%s', 期望 'Basic Rifle'" % display_name
					else:
						result.passed = true
				loc_manager.set_locale("zh_CN")

		"test_weapon_description_zh_cn":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("zh_CN")
				var stats = _load_weapon_stats("shotgun_basic")
				if stats == null:
					result.error = "无法加载 shotgun_basic 武器资源"
				else:
					var display_desc = stats.get_display_description()
					if display_desc != "近距离高伤害，远距离衰减严重":
						result.error = "武器描述 = '%s', 期望 '近距离高伤害，远距离衰减严重'" % display_desc
					else:
						result.passed = true

		"test_weapon_description_en":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("en")
				var stats = _load_weapon_stats("shotgun_basic")
				if stats == null:
					result.error = "无法加载 shotgun_basic 武器资源"
				else:
					var display_desc = stats.get_display_description()
					if display_desc != "High damage at close range, severe falloff at distance":
						result.error = "武器描述 = '%s', 期望 'High damage at close range, severe falloff at distance'" % display_desc
					else:
						result.passed = true
				loc_manager.set_locale("zh_CN")

		"test_weapon_class_description_delegates":
			if loc_manager == null:
				result.error = "LocalizationManager 不存在"
			else:
				loc_manager.set_locale("zh_CN")
				var weapon_script = load("res://src/weapons/rifle_weapon.gd")
				var weapon = weapon_script.new()
				var stats = _load_weapon_stats("rifle_basic")
				if stats == null:
					result.error = "无法加载 rifle_basic 武器资源"
					weapon.queue_free()
				else:
					weapon.stats = stats
					var desc = weapon.get_weapon_description()
					if desc != "标准突击步枪，射速快，精度高":
						result.error = "武器类描述 = '%s', 期望 '标准突击步枪，射速快，精度高'" % desc
					else:
						result.passed = true
					weapon.queue_free()

	return result


## 加载武器统计数据资源
func _load_weapon_stats(weapon_id: String) -> Resource:
	var resource_name := weapon_id.replace("_basic", "")
	var stats_path := "res://resources/weapon_stats/%s.tres" % resource_name
	if ResourceLoader.exists(stats_path):
		return load(stats_path)
	return null


func _print_summary() -> void:
	var passed := _test_results.filter(func(r): return r.passed).size()
	var failed := _test_results.size() - passed

	print("\n" + "=".repeat(60))
	print("  测试结果汇总")
	print("=".repeat(60))
	print("  通过: %d" % passed)
	print("  失败: %d" % failed)
	print("  总计: %d" % _test_results.size())
	if _test_results.size() > 0:
		print("  成功率: %.1f%%" % (100.0 * passed / _test_results.size()))
	print("=".repeat(60))


func _save_results() -> void:
	var data := {
		"timestamp": Time.get_datetime_string_from_system(),
		"total": _test_results.size(),
		"passed": _test_results.filter(func(r): return r.passed).size(),
		"failed": _test_results.filter(func(r): return not r.passed).size(),
		"tests": _test_results,
	}

	var path := "user://test_results.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "  "))
		file.close()
		print("\n结果已保存: %s" % path)
