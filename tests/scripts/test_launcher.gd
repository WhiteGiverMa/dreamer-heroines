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
		{
			"name": "test_settings_slider_value_inputs",
			"description": "验证设置页滑条输入框格式与联动",
		},
		# Crosshair settings integration tests (Task 11)
		{
			"name": "test_crosshair_settings_panel_open",
			"description": "验证设置面板可打开且准星子面板挂载成功",
		},
		{
			"name": "test_crosshair_tab_switching",
			"description": "验证 Basic/Crosshair 标签切换",
		},
		{
			"name": "test_crosshair_shape_updates_hud",
			"description": "验证准星形状设置更新 HUD",
		},
		{
			"name": "test_crosshair_color_updates_hud",
			"description": "验证准星颜色设置更新 HUD",
		},
		{
			"name": "test_crosshair_runtime_preview_updates",
			"description": "验证运行时预览实时反映设置变更",
		},
		{
			"name": "test_crosshair_settings_persistence",
			"description": "验证准星设置可保存并重新加载",
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

		"test_settings_slider_value_inputs":
			result = _run_settings_slider_value_inputs_test()

		# ----------------------------------------------------------------------------
		# Crosshair Settings Integration Tests
		# ----------------------------------------------------------------------------
		"test_crosshair_settings_panel_open":
			result = _run_crosshair_settings_panel_open_test()

		"test_crosshair_tab_switching":
			result = _run_crosshair_tab_switching_test()

		"test_crosshair_shape_updates_hud":
			result = _run_crosshair_shape_updates_hud_test()

		"test_crosshair_color_updates_hud":
			result = _run_crosshair_color_updates_hud_test()

		"test_crosshair_runtime_preview_updates":
			result = _run_crosshair_runtime_preview_updates_test()

		"test_crosshair_settings_persistence":
			result = _run_crosshair_settings_persistence_test()

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
	"enemy_dive": "sfx_enemy_dive",
	"checkpoint_unlock": "sfx_checkpoint_unlock",
	"checkpoint_activate": "sfx_checkpoint_activate",
	"empty_click": "sfx_empty_click",
	"shoot": "sfx_gunshot_pistol",
}

const _SETTINGS_PANEL_SCENE := preload("res://scenes/ui/settings_panel.tscn")
const _HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const _CROSSHAIR_SETTINGS_RESOURCE := preload("res://src/data/crosshair_settings.gd")


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

	# Test that settings can be saved and loaded through SaveManager persistence path
	var test_settings: Dictionary = {
		"master_volume": 0.5,
		"music_volume": 0.4,
		"sfx_volume": 0.9,
		"ui_volume": 0.6,
	}

	# backup existing saved settings to avoid polluting developer environment
	var original_settings: Dictionary = save_manager.load_settings()

	# Store original volume states to restore later
	var original_volumes: Dictionary = {}
	for bus_name: String in ["Master", "Music", "SFX", "UI"]:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			original_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_idx)

	# Persist through SaveManager, then load and apply through AudioManager
	save_manager.save_settings(test_settings)
	var loaded_settings: Dictionary = save_manager.load_settings()
	audio_manager._load_saved_volumes()

	# Get values from both persisted payload and runtime buses
	var loaded_master = float(loaded_settings.get("master_volume", -1.0))
	var loaded_music = float(loaded_settings.get("music_volume", -1.0))
	var loaded_sfx = float(loaded_settings.get("sfx_volume", -1.0))
	var loaded_ui = float(loaded_settings.get("ui_volume", -1.0))

	var runtime_master = audio_manager.get_bus_volume(AudioManager.BusType.MASTER)
	var runtime_music = audio_manager.get_bus_volume(AudioManager.BusType.MUSIC)
	var runtime_sfx = audio_manager.get_bus_volume(AudioManager.BusType.SFX)
	var runtime_ui = audio_manager.get_bus_volume(AudioManager.BusType.UI)

	# Restore original runtime volumes
	for bus_name: String in original_volumes:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		AudioServer.set_bus_volume_db(bus_idx, original_volumes[bus_name])

	# Restore original persisted settings
	save_manager.save_settings(original_settings)

	# Verify retrieved values match (within floating point tolerance)
	var tolerance := 0.01
	var volume_errors: Array[String] = []

	if absf(loaded_master - test_settings.master_volume) > tolerance:
		volume_errors.append("saved master: %.2f != %.2f" % [loaded_master, test_settings.master_volume])
	if absf(loaded_music - test_settings.music_volume) > tolerance:
		volume_errors.append("saved music: %.2f != %.2f" % [loaded_music, test_settings.music_volume])
	if absf(loaded_sfx - test_settings.sfx_volume) > tolerance:
		volume_errors.append("saved sfx: %.2f != %.2f" % [loaded_sfx, test_settings.sfx_volume])
	if absf(loaded_ui - test_settings.ui_volume) > tolerance:
		volume_errors.append("saved ui: %.2f != %.2f" % [loaded_ui, test_settings.ui_volume])

	if absf(runtime_master - test_settings.master_volume) > tolerance:
		volume_errors.append("runtime master: %.2f != %.2f" % [runtime_master, test_settings.master_volume])
	if absf(runtime_music - test_settings.music_volume) > tolerance:
		volume_errors.append("runtime music: %.2f != %.2f" % [runtime_music, test_settings.music_volume])
	if absf(runtime_sfx - test_settings.sfx_volume) > tolerance:
		volume_errors.append("runtime sfx: %.2f != %.2f" % [runtime_sfx, test_settings.sfx_volume])
	if absf(runtime_ui - test_settings.ui_volume) > tolerance:
		volume_errors.append("runtime ui: %.2f != %.2f" % [runtime_ui, test_settings.ui_volume])

	if volume_errors.size() > 0:
		result.error = "音量不匹配: %s" % str(volume_errors)
		return result

	result.passed = true
	return result


func _run_settings_slider_value_inputs_test() -> Dictionary:
	var result := {"name": "test_settings_slider_value_inputs", "passed": false, "error": ""}
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		result.error = "SaveManager autoload 不存在"
		return result

	var original_settings: Dictionary = save_manager.load_settings()
	var panel = _SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
	add_child(panel)
	panel.show_panel()

	var volume_input := panel.get_node_or_null("TabContainer/BasicTab/BasicScrollContainer/BasicContent/VolumeSliderContainer/VolumeSliderInput") as LineEdit
	var sensitivity_input := panel.get_node_or_null("TabContainer/BasicTab/BasicScrollContainer/BasicContent/SensitivitySliderContainer/SensitivitySliderInput") as LineEdit
	var size_input := panel.get_node_or_null("TabContainer/CrosshairTab/CrosshairPanelHost/CrosshairSettingsPanel/MarginContainer/ScrollContainer/Content/ShapeSection/Grid/SizeSliderContainer/SizeSliderInput") as LineEdit

	if volume_input == null:
		result.error = "未找到 VolumeSliderInput 节点"
	elif sensitivity_input == null:
		result.error = "未找到 SensitivitySliderInput 节点"
	elif size_input == null:
		result.error = "未找到 SizeSliderInput 节点"
	else:
		panel.volume_slider.value = 64.0
		panel.sensitivity_slider.value = 125.0

		var volume_format_ok := volume_input.text == "64%"
		var sensitivity_format_ok := sensitivity_input.text == "1.25x"

		volume_input.text = "37%"
		volume_input.text_submitted.emit(volume_input.text)

		var slider_sync_ok := is_equal_approx(panel.volume_slider.value, 37.0)
		var saved_settings: Dictionary = save_manager.load_settings()
		var saved_master := float(saved_settings.get("master_volume", -1.0))
		var persistence_ok := absf(saved_master - 0.37) <= 0.01

		panel.tab_container.current_tab = 1
		var crosshair_panel: CrosshairSettingsPanel = panel.get_node_or_null("TabContainer/CrosshairTab/CrosshairPanelHost/CrosshairSettingsPanel") as CrosshairSettingsPanel
		if crosshair_panel == null:
			result.error = "未找到 CrosshairSettingsPanel 节点"
		else:
			crosshair_panel.alpha_slider.value = 0.42
			var crosshair_format_ok: bool = crosshair_panel._slider_value_inputs.get(crosshair_panel.alpha_slider).line_edit.text == "42%"
			if not volume_format_ok:
				result.error = "音量输入框格式错误: %s" % volume_input.text
			elif not sensitivity_format_ok:
				result.error = "灵敏度输入框格式错误: %s" % sensitivity_input.text
			elif not slider_sync_ok:
				result.error = "输入框提交未同步滑条: %.2f" % panel.volume_slider.value
			elif not persistence_ok:
				result.error = "输入框提交未持久化主音量: %.2f" % saved_master
			elif not crosshair_format_ok:
				result.error = "准星百分比输入框格式错误"
			else:
				result.passed = true

	if is_instance_valid(panel):
		panel.queue_free()
	save_manager.save_settings(original_settings)
	return result


# =============================================================================
# Crosshair Settings Integration Tests
# =============================================================================

func _run_crosshair_settings_panel_open_test() -> Dictionary:
	var result := {"name": "test_crosshair_settings_panel_open", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var settings_panel: SettingsPanel = context.settings_panel
	var tab_container: TabContainer = context.tab_container
	var crosshair_panel = context.crosshair_panel

	settings_panel.show_panel()

	if not settings_panel.visible:
		result.error = "SettingsPanel 未显示"
	elif tab_container.get_tab_count() < 2:
		result.error = "Tab 数量不足: %d" % tab_container.get_tab_count()
	elif crosshair_panel == null:
		result.error = "CrosshairSettingsPanel 未挂载到 CrosshairPanelHost"
	else:
		result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _run_crosshair_tab_switching_test() -> Dictionary:
	var result := {"name": "test_crosshair_tab_switching", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var tab_container: TabContainer = context.tab_container
	if tab_container.get_tab_count() < 2:
		result.error = "Tab 数量不足，无法切换"
	else:
		tab_container.current_tab = 0
		var basic_selected := tab_container.current_tab == 0

		tab_container.current_tab = 1
		var crosshair_selected := tab_container.current_tab == 1

		tab_container.current_tab = 0
		var switched_back := tab_container.current_tab == 0

		if not basic_selected or not crosshair_selected or not switched_back:
			result.error = "Tab 切换失败: basic=%s, crosshair=%s, back=%s" % [basic_selected, crosshair_selected, switched_back]
		else:
			result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _run_crosshair_shape_updates_hud_test() -> Dictionary:
	var result := {"name": "test_crosshair_shape_updates_hud", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	_set_crosshair_test_baseline()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var crosshair_panel: CrosshairSettingsPanel = context.crosshair_panel
	var crosshair_ui = context.crosshair_ui

	# 切换形状为 dot
	crosshair_panel.shape_option.item_selected.emit(1)

	var service_shape := CrosshairSettingsService.get_crosshair_shape()
	if service_shape != "dot":
		result.error = "Service shape = %s, 期望 dot" % service_shape
	elif crosshair_ui.crosshair_shape != "dot":
		result.error = "HUD shape = %s, 期望 dot" % crosshair_ui.crosshair_shape
	else:
		result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _run_crosshair_color_updates_hud_test() -> Dictionary:
	var result := {"name": "test_crosshair_color_updates_hud", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	_set_crosshair_test_baseline()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var crosshair_panel: CrosshairSettingsPanel = context.crosshair_panel
	var crosshair_ui = context.crosshair_ui

	# 使用预设红色
	crosshair_panel.color_mode_option.item_selected.emit(0)
	crosshair_panel.color_preset_option.item_selected.emit(4)

	var service_preset := CrosshairSettingsService.get_color_preset()
	var expected_color: Color = CrosshairSettingsService.COLOR_PRESETS["red"]
	var actual_color: Color = crosshair_ui.normal_color

	if service_preset != "red":
		result.error = "Service color_preset = %s, 期望 red" % service_preset
	elif not _is_color_close(actual_color, expected_color):
		result.error = "HUD color = %s, 期望 %s" % [actual_color, expected_color]
	else:
		result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _run_crosshair_runtime_preview_updates_test() -> Dictionary:
	var result := {"name": "test_crosshair_runtime_preview_updates", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	_set_crosshair_test_baseline()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var crosshair_panel: CrosshairSettingsPanel = context.crosshair_panel
	var crosshair_ui = context.crosshair_ui

	# 调整大小滑杆，验证 HUD 运行时预览即时更新
	crosshair_panel.size_slider.value = 36.0
	var service_size := CrosshairSettingsService.get_crosshair_size()
	var hud_size: float = crosshair_ui.crosshair_size

	if not is_equal_approx(service_size, 36.0):
		result.error = "Service size = %.2f, 期望 36.0" % service_size
	elif not is_equal_approx(hud_size, 36.0):
		result.error = "HUD size = %.2f, 期望 36.0" % hud_size
	else:
		result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _run_crosshair_settings_persistence_test() -> Dictionary:
	var result := {"name": "test_crosshair_settings_persistence", "passed": false, "error": ""}
	var snapshot := _snapshot_crosshair_persisted_settings()
	_set_crosshair_test_baseline()
	var context := _create_crosshair_test_context()

	if context.has("error"):
		result.error = String(context.error)
		_restore_crosshair_persisted_settings(snapshot)
		return result

	var crosshair_panel: CrosshairSettingsPanel = context.crosshair_panel
	var crosshair_ui = context.crosshair_ui

	# 通过设置面板写入目标值
	crosshair_panel.shape_option.item_selected.emit(2)  # circle
	crosshair_panel.color_mode_option.item_selected.emit(0)  # preset
	crosshair_panel.color_preset_option.item_selected.emit(6)  # blue
	_flush_crosshair_settings_to_disk()

	# 改成本次测试以外的值，再 reload 验证持久化回放
	CrosshairSettingsService.update_setting(&"crosshair_shape", "cross")
	CrosshairSettingsService.update_setting(&"color_preset", "green")
	CrosshairSettingsService.reload_settings()

	var loaded_shape := CrosshairSettingsService.get_crosshair_shape()
	var loaded_preset := CrosshairSettingsService.get_color_preset()
	var expected_color: Color = CrosshairSettingsService.COLOR_PRESETS["blue"]
	var runtime_color: Color = crosshair_ui.normal_color

	if loaded_shape != "circle":
		result.error = "Reload shape = %s, 期望 circle" % loaded_shape
	elif loaded_preset != "blue":
		result.error = "Reload preset = %s, 期望 blue" % loaded_preset
	elif crosshair_ui.crosshair_shape != "circle":
		result.error = "HUD shape = %s, 期望 circle" % crosshair_ui.crosshair_shape
	elif not _is_color_close(runtime_color, expected_color):
		result.error = "HUD color = %s, 期望 %s" % [runtime_color, expected_color]
	else:
		result.passed = true

	_cleanup_crosshair_test_context(context)
	_restore_crosshair_persisted_settings(snapshot)
	return result


func _create_crosshair_test_context() -> Dictionary:
	if CrosshairSettingsService == null:
		return {"error": "CrosshairSettingsService autoload 不存在"}

	if _SETTINGS_PANEL_SCENE == null:
		return {"error": "无法加载 settings_panel.tscn"}

	if _HUD_SCENE == null:
		return {"error": "无法加载 hud.tscn"}

	var settings_panel = _SETTINGS_PANEL_SCENE.instantiate() as SettingsPanel
	var hud = _HUD_SCENE.instantiate()

	add_child(settings_panel)
	add_child(hud)
	settings_panel.show_panel()

	var tab_container := settings_panel.get_node_or_null("TabContainer") as TabContainer
	if tab_container == null:
		settings_panel.queue_free()
		hud.queue_free()
		return {"error": "SettingsPanel/TabContainer 节点不存在"}

	var crosshair_host := settings_panel.get_node_or_null("TabContainer/CrosshairTab/CrosshairPanelHost") as Control
	if crosshair_host == null:
		settings_panel.queue_free()
		hud.queue_free()
		return {"error": "CrosshairPanelHost 节点不存在"}

	var crosshair_panel := crosshair_host.get_node_or_null("CrosshairSettingsPanel") as CrosshairSettingsPanel
	if crosshair_panel == null:
		settings_panel.queue_free()
		hud.queue_free()
		return {"error": "CrosshairSettingsPanel 子节点不存在"}

	var crosshair_ui = hud.get_node_or_null("MainContainer/BottomBar/CenterSection/CrosshairUI")
	if crosshair_ui == null:
		settings_panel.queue_free()
		hud.queue_free()
		return {"error": "HUD CrosshairUI 节点不存在"}

	return {
		"settings_panel": settings_panel,
		"hud": hud,
		"tab_container": tab_container,
		"crosshair_panel": crosshair_panel,
		"crosshair_ui": crosshair_ui,
	}


func _cleanup_crosshair_test_context(context: Dictionary) -> void:
	if context.has("hud") and is_instance_valid(context.hud):
		context.hud.queue_free()

	if context.has("settings_panel") and is_instance_valid(context.settings_panel):
		context.settings_panel.queue_free()


func _set_crosshair_test_baseline() -> void:
	if CrosshairSettingsService == null:
		return

	CrosshairSettingsService.reset_to_defaults()
	_flush_crosshair_settings_to_disk()
	CrosshairSettingsService.reload_settings()


func _flush_crosshair_settings_to_disk() -> void:
	if CrosshairSettingsService == null:
		return

	if CrosshairSettingsService.has_method("_save_settings_to_disk"):
		CrosshairSettingsService.call("_save_settings_to_disk")


func _snapshot_crosshair_persisted_settings() -> Dictionary:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return {}

	var settings: Dictionary = save_manager.load_settings()
	var persisted_key_map: Dictionary = _CROSSHAIR_SETTINGS_RESOURCE.get_persisted_key_map()
	var snapshot: Dictionary = {}

	for property_name in persisted_key_map.keys():
		var persisted_key: String = persisted_key_map[property_name]
		if settings.has(persisted_key):
			snapshot[persisted_key] = settings[persisted_key]

	return snapshot


func _restore_crosshair_persisted_settings(snapshot: Dictionary) -> void:
	var save_manager = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	var defaults := (_CROSSHAIR_SETTINGS_RESOURCE.get_defaults() as CrosshairSettings).to_persisted_dictionary()
	var restore_payload: Dictionary = {}

	for persisted_key in defaults.keys():
		if snapshot.has(persisted_key):
			restore_payload[persisted_key] = snapshot[persisted_key]
		else:
			restore_payload[persisted_key] = defaults[persisted_key]

	save_manager.save_settings(restore_payload)
	if CrosshairSettingsService:
		CrosshairSettingsService.reload_settings()


func _is_color_close(actual: Color, expected: Color, tolerance: float = 0.01) -> bool:
	return absf(actual.r - expected.r) <= tolerance and \
		absf(actual.g - expected.g) <= tolerance and \
		absf(actual.b - expected.b) <= tolerance and \
		absf(actual.a - expected.a) <= tolerance
