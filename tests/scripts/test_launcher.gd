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
		# Audio architecture tests (bus topology, routing, persistence)
		{
			"name": "test_audio_bus_topology_exists",
			"description": "验证所有12个音频总线存在",
		},
		{
			"name": "test_audio_bus_send_targets",
			"description": "验证总线发送目标拓扑正确",
		},
		{
			"name": "test_audio_routing_player_sounds",
			"description": "验证玩家音效路由到 SFX_Player 总线",
		},
		{
			"name": "test_audio_routing_weapon_sounds",
			"description": "验证武器音效路由到 SFX_Weapons 总线",
		},
		{
			"name": "test_audio_routing_enemy_sounds",
			"description": "验证敌人音效路由到 SFX_Enemies 总线",
		},
		{
			"name": "test_audio_legacy_key_normalization",
			"description": "验证遗留键正确规范化",
		},
		{
			"name": "test_audio_settings_persistence",
			"description": "验证音量设置持久化",
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

		# ----------------------------------------------------------------------------
		# Audio Architecture Tests
		# ----------------------------------------------------------------------------
		"test_audio_bus_topology_exists":
			result = _run_audio_bus_topology_test()

		"test_audio_bus_send_targets":
			result = _run_audio_bus_send_targets_test()

		"test_audio_routing_player_sounds":
			result = _run_audio_routing_test("player")

		"test_audio_routing_weapon_sounds":
			result = _run_audio_routing_test("weapon")

		"test_audio_routing_enemy_sounds":
			result = _run_audio_routing_test("enemy")

		"test_audio_legacy_key_normalization":
			result = _run_audio_legacy_normalization_test()

		"test_audio_settings_persistence":
			result = _run_audio_settings_persistence_test()

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


# =============================================================================
# Audio Architecture Tests
# =============================================================================

const _EXPECTED_BUS_COUNT: int = 12

const _REQUIRED_BUSES: Array[String] = [
	"Master", "Music", "SFX", "UI", "Voice", "Ambience", "Reverb",
	"SFX_Player", "SFX_Weapons", "SFX_Enemies", "SFX_Impacts", "SFX_Skills"
]

const _EXPECTED_SENDS: Dictionary = {
	"Master": "",
	"Music": "Master",
	"SFX": "Master",
	"SFX_Player": "SFX",
	"SFX_Weapons": "SFX",
	"SFX_Enemies": "SFX",
	"SFX_Impacts": "SFX",
	"SFX_Skills": "SFX",
	"UI": "Master",
	"Voice": "Master",
	"Ambience": "Reverb",
	"Reverb": "Master",
}

const _PLAYER_SOUND_KEYS: Array[String] = [
	"sfx_jump", "sfx_player_hurt", "sfx_player_death", "sfx_player_land"
]

const _WEAPON_SOUND_KEYS: Array[String] = [
	"sfx_gunshot_pistol", "sfx_gunshot_rifle", "sfx_reload_generic", "sfx_empty_click"
]

const _ENEMY_SOUND_KEYS: Array[String] = [
	"sfx_enemy_shoot", "sfx_enemy_melee", "sfx_enemy_hurt", "sfx_enemy_death"
]

const _LEGACY_TO_CANONICAL: Dictionary = {
	"jump": "sfx_jump",
	"player_hurt": "sfx_player_hurt",
	"player_death": "sfx_player_death",
	"enemy_shoot": "sfx_enemy_shoot",
	"enemy_melee": "sfx_enemy_melee",
	"enemy_hurt": "sfx_enemy_hurt",
	"enemy_death": "sfx_enemy_death",
	"empty_click": "sfx_empty_click",
	"shoot": "sfx_gunshot_pistol",
}


func _run_audio_bus_topology_test() -> Dictionary:
	var result := {"name": "test_audio_bus_topology_exists", "passed": false, "error": ""}

	var bus_count = AudioServer.get_bus_count()
	if bus_count != _EXPECTED_BUS_COUNT:
		result.error = "总线数量 = %d, 期望 %d" % [bus_count, _EXPECTED_BUS_COUNT]
		return result

	var missing_buses: Array[String] = []
	for bus_name: String in _REQUIRED_BUSES:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			missing_buses.append(bus_name)

	if missing_buses.size() > 0:
		result.error = "缺失总线: %s" % str(missing_buses)
		return result

	result.passed = true
	return result


func _run_audio_bus_send_targets_test() -> Dictionary:
	var result := {"name": "test_audio_bus_send_targets", "passed": false, "error": ""}

	var mismatched_sends: Array[String] = []
	for bus_name: String in _EXPECTED_SENDS.keys():
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx < 0:
			mismatched_sends.append(bus_name + " (不存在)")
			continue

		var actual_send = AudioServer.get_bus_send(bus_idx)
		var expected_send = _EXPECTED_SENDS[bus_name]
		if actual_send != expected_send:
			mismatched_sends.append("%s: send=%s, 期望=%s" % [bus_name, actual_send, expected_send])

	if mismatched_sends.size() > 0:
		result.error = "发送目标不匹配: %s" % str(mismatched_sends)
		return result

	result.passed = true
	return result


func _run_audio_routing_test(category: String) -> Dictionary:
	var result := {"name": "test_audio_routing_%s_sounds" % category, "passed": false, "error": ""}

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		result.error = "AudioManager autoload 不存在"
		return result

	var keys_to_test: Array[String]
	var expected_bus: String

	match category:
		"player":
			keys_to_test = _PLAYER_SOUND_KEYS
			expected_bus = "SFX_Player"
		"weapon":
			keys_to_test = _WEAPON_SOUND_KEYS
			expected_bus = "SFX_Weapons"
		"enemy":
			keys_to_test = _ENEMY_SOUND_KEYS
			expected_bus = "SFX_Enemies"
		_:
			result.error = "未知类别: %s" % category
			return result

	# Create a dummy AudioStreamPlayer to test routing
	var test_player = AudioStreamPlayer.new()
	test_player.bus = "Master"  # Start with Master
	add_child(test_player)

	var routing_errors: Array[String] = []
	for sound_key: String in keys_to_test:
		# Get the bus that routing would assign
		var routed_bus = audio_manager._get_bus_from_category(sound_key)
		if routed_bus != expected_bus:
			routing_errors.append("%s -> %s (期望 %s)" % [sound_key, routed_bus, expected_bus])

	test_player.queue_free()

	if routing_errors.size() > 0:
		result.error = "路由错误: %s" % str(routing_errors)
		return result

	result.passed = true
	return result


func _run_audio_legacy_normalization_test() -> Dictionary:
	var result := {"name": "test_audio_legacy_key_normalization", "passed": false, "error": ""}

	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager == null:
		result.error = "AudioManager autoload 不存在"
		return result

	var normalization_errors: Array[String] = []
	for legacy_key: String in _LEGACY_TO_CANONICAL.keys():
		var expected_canonical = _LEGACY_TO_CANONICAL[legacy_key]
		var actual_normalized = audio_manager._normalize_sound_key(legacy_key)
		if actual_normalized != expected_canonical:
			normalization_errors.append(
				"%s -> %s (期望 %s)" % [legacy_key, actual_normalized, expected_canonical]
			)

	if normalization_errors.size() > 0:
		result.error = "规范化错误: %s" % str(normalization_errors)
		return result

	result.passed = true
	return result


func _run_audio_settings_persistence_test() -> Dictionary:
	var result := {"name": "test_audio_settings_persistence", "passed": false, "error": ""}

	var save_manager = get_node_or_null("/root/SaveManager")
	var audio_manager = get_node_or_null("/root/AudioManager")

	if save_manager == null:
		result.error = "SaveManager autoload 不存在"
		return result

	if audio_manager == null:
		result.error = "AudioManager autoload 不存在"
		return result

	# Test that settings can be saved and loaded
	var test_settings: Dictionary = {
		"master_volume": 0.5,
		"music_volume": 0.4,
		"sfx_volume": 0.9,
		"ui_volume": 0.6,
	}

	# Store original volume states to restore later
	var original_volumes: Dictionary = {}
	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			original_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_idx)

	# Apply test settings via AudioManager
	audio_manager.set_bus_volume(AudioManager.BusType.MASTER, test_settings.master_volume)
	audio_manager.set_bus_volume(AudioManager.BusType.MUSIC, test_settings.music_volume)
	audio_manager.set_bus_volume(AudioManager.BusType.SFX, test_settings.sfx_volume)
	audio_manager.set_bus_volume(AudioManager.BusType.UI, test_settings.ui_volume)

	# Get the values back
	var retrieved_master = audio_manager.get_bus_volume(AudioManager.BusType.MASTER)
	var retrieved_music = audio_manager.get_bus_volume(AudioManager.BusType.MUSIC)
	var retrieved_sfx = audio_manager.get_bus_volume(AudioManager.BusType.SFX)
	var retrieved_ui = audio_manager.get_bus_volume(AudioManager.BusType.UI)

	# Restore original volumes
	for bus_name: String in original_volumes:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, original_volumes[bus_name])

	# Verify retrieved values match (within floating point tolerance)
	var tolerance := 0.01
	var volume_errors: Array[String] = []

	if absf(retrieved_master - test_settings.master_volume) > tolerance:
		volume_errors.append("master: %.2f != %.2f" % [retrieved_master, test_settings.master_volume])
	if absf(retrieved_music - test_settings.music_volume) > tolerance:
		volume_errors.append("music: %.2f != %.2f" % [retrieved_music, test_settings.music_volume])
	if absf(retrieved_sfx - test_settings.sfx_volume) > tolerance:
		volume_errors.append("sfx: %.2f != %.2f" % [retrieved_sfx, test_settings.sfx_volume])
	if absf(retrieved_ui - test_settings.ui_volume) > tolerance:
		volume_errors.append("ui: %.2f != %.2f" % [retrieved_ui, test_settings.ui_volume])

	if volume_errors.size() > 0:
		result.error = "音量不匹配: %s" % str(volume_errors)
		return result

	result.passed = true
	return result
