extends "res://src/base/game_system.gd"

# SaveManager - GDScript 存档管理器包装器
# 提供GDScript接口调用C# SaveManager

signal save_completed(slot: int, success: bool)
signal load_completed(slot: int, success: bool)
signal save_deleted(slot: int)
signal auto_save_triggered

const MAX_SLOTS = 10

var _csharp_save_manager = null
var current_save_data = null
var current_slot: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "save_manager"
	# 不在这里执行初始化，等待 BootSequence 调用

func initialize() -> void:
	print("[SaveManager] 开始初始化...")
	_migrate_legacy_save_data()
	
	# 等待 CSharpSaveManager 依赖
	var csharp_manager = get_node_or_null("/root/CSharpSaveManager")
	if csharp_manager:
		# 检查是否已初始化 (C# 属性 IsInitialized)
		if "IsInitialized" in csharp_manager and not csharp_manager.IsInitialized:
			print("[SaveManager] 等待 CSharpSaveManager 初始化...")
			await csharp_manager.SystemReady
	
	_initialize_csharp_manager()
	
	print("[SaveManager] 初始化完成")
	_mark_ready()

func _initialize_csharp_manager() -> void:
	# 检查C# SaveManager是否已在autoload中
	var csharp_manager = get_node_or_null("/root/CSharpSaveManager")
	
	if csharp_manager:
		_csharp_save_manager = csharp_manager
		_connect_csharp_signals()
	else:
		# 如果没有，尝试动态加载C#脚本
		var script = load("res://src/cs/Systems/SaveManager.cs")
		if script:
			_csharp_save_manager = script.new()
			_csharp_save_manager.name = "CSharpSaveManager"
			get_tree().root.add_child.call_deferred(_csharp_save_manager)
			call_deferred("_connect_csharp_signals")

func _connect_csharp_signals() -> void:
	if not _csharp_save_manager:
		return
	
	# 连接C#信号
	if _csharp_save_manager.has_signal("SaveCompleted"):
		_csharp_save_manager.SaveCompleted.connect(_on_csharp_save_completed)
	if _csharp_save_manager.has_signal("LoadCompleted"):
		_csharp_save_manager.LoadCompleted.connect(_on_csharp_load_completed)
	if _csharp_save_manager.has_signal("SaveDeleted"):
		_csharp_save_manager.SaveDeleted.connect(_on_csharp_save_deleted)
	if _csharp_save_manager.has_signal("AutoSaveTriggered"):
		_csharp_save_manager.AutoSaveTriggered.connect(_on_auto_save_triggered)

# 保存操作
func save_to_slot(slot: int, show_notification: bool = true) -> void:
	if _csharp_save_manager:
		_csharp_save_manager.SaveToSlot(slot, show_notification)
	else:
		# 备用：使用GDScript实现
		_save_to_file(slot)

func quick_save() -> void:
	if _csharp_save_manager:
		_csharp_save_manager.QuickSave()
	elif current_slot >= 0:
		save_to_slot(current_slot)

func save_current_game() -> void:
	if current_slot >= 0:
		save_to_slot(current_slot)
	else:
		# 找到第一个空槽位
		for i in range(MAX_SLOTS):
			if not has_save_in_slot(i):
				save_to_slot(i)
				break

# 加载操作
func load_from_slot(slot: int) -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.LoadFromSlot(slot)
	else:
		return _load_from_file(slot)

func has_current_save() -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.HasCurrentSave
	return current_save_data != null

func has_save_in_slot(slot: int) -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.HasSaveInSlot(slot)
	
	var file_path = _get_save_file_path(slot)
	return FileAccess.file_exists(file_path)

# 删除操作
func delete_save(slot: int) -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.DeleteSave(slot)
	else:
		return _delete_save_file(slot)

# 存档摘要
func get_save_summary(slot: int) -> Dictionary:
	# 直接使用GDScript文件实现，避免C#互操作问题
	return _get_file_summary(slot)

func get_all_save_summaries() -> Array:
	var summaries = []
	for i in range(MAX_SLOTS):
		summaries.append(get_save_summary(i))
	return summaries

# 获取第一个空槽位
func get_first_empty_slot() -> int:
	for i in range(MAX_SLOTS):
		if not has_save_in_slot(i):
			return i
	return -1

# 玩家数据
func get_player_data():
	if _csharp_save_manager:
		return _csharp_save_manager.GetPlayerData()
	return current_save_data.get("player", null) if current_save_data else null

func update_player_data(player_data) -> void:
	if _csharp_save_manager:
		_csharp_save_manager.UpdatePlayerData(player_data)
	elif current_save_data:
		current_save_data["player"] = player_data

# 设置
func save_settings(settings: Dictionary) -> void:
	if _csharp_save_manager and _csharp_save_manager.has_method("SaveSettings"):
		_csharp_save_manager.SaveSettings(settings)
		return

	_save_settings_to_file(settings)

func load_settings() -> Dictionary:
	if _csharp_save_manager:
		if _csharp_save_manager.has_method("LoadSettingsDictionary"):
			var loaded_settings = _csharp_save_manager.LoadSettingsDictionary()
			if loaded_settings is Dictionary:
				return loaded_settings
		if _csharp_save_manager.has_method("LoadSettings"):
			var csharp_settings = _csharp_save_manager.LoadSettings()
			if csharp_settings:
				return _convert_csharp_settings_to_dict(csharp_settings)

	return _load_settings_from_file()

func _save_settings_to_file(settings: Dictionary) -> void:
	var merged_settings: Dictionary = _get_default_settings()
	for key in settings.keys():
		merged_settings[key] = settings[key]

	var file := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(merged_settings, "\t"))
		file.close()
		print("[SaveManager] 已通过 GDScript 后备路径保存设置")
		return

	push_error("[SaveManager] 设置文件写入失败: user://settings.json")

func _load_settings_from_file() -> Dictionary:
	var file_path := "user://settings.json"
	if not FileAccess.file_exists(file_path):
		return _get_default_settings()

	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_warning("[SaveManager] 设置文件读取失败，使用默认设置")
		return _get_default_settings()

	var text := file.get_as_text()
	file.close()

	if text.strip_edges().is_empty():
		return _get_default_settings()

	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		var merged_settings: Dictionary = _get_default_settings()
		for key in parsed.keys():
			merged_settings[key] = parsed[key]
		return merged_settings

	push_warning("[SaveManager] 设置文件格式无效，使用默认设置")
	return _get_default_settings()

# 信号回调
func _on_csharp_save_completed(slot: int, success: bool) -> void:
	if success:
		current_slot = slot
		_update_current_save_data()
	save_completed.emit(slot, success)

func _on_csharp_load_completed(slot: int, success: bool) -> void:
	if success:
		current_slot = slot
		_update_current_save_data()
	load_completed.emit(slot, success)

func _on_csharp_save_deleted(slot: int) -> void:
	if current_slot == slot:
		current_slot = -1
		current_save_data = null
	save_deleted.emit(slot)

func _on_auto_save_triggered() -> void:
	auto_save_triggered.emit()

func _update_current_save_data() -> void:
	if _csharp_save_manager:
		current_save_data = _csharp_save_manager.CurrentSaveData

# 备用GDScript实现
func _get_save_file_path(slot: int) -> String:
	return "user://saves/save_%02d.sav" % slot

func _save_to_file(slot: int) -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")
	
	var file_path = _get_save_file_path(slot)
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	
	if file:
		var save_data = _create_save_data()
		var json = JSON.stringify(save_data)
		file.store_string(json)
		file.close()
		
		current_slot = slot
		current_save_data = save_data
		save_completed.emit(slot, true)
	else:
		save_completed.emit(slot, false)

func _load_from_file(slot: int) -> bool:
	var file_path = _get_save_file_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		
		var result = JSON.parse_string(json)
		if result:
			current_save_data = result
			current_slot = slot
			load_completed.emit(slot, true)
			return true
	
	load_completed.emit(slot, false)
	return false

func _delete_save_file(slot: int) -> bool:
	var file_path = _get_save_file_path(slot)
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		
		if current_slot == slot:
			current_slot = -1
			current_save_data = null
		
		save_deleted.emit(slot)
		return true
	
	return false

func _get_file_summary(slot: int) -> Dictionary:
	var file_path = _get_save_file_path(slot)
	
	if not FileAccess.file_exists(file_path):
		return {
			"slot_index": slot,
			"has_save": false
		}
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		
		var data = JSON.parse_string(json)
		if data:
			return {
				"slot_index": slot,
				"has_save": true,
				"level_name": data.get("level_name", "Unknown"),
				"save_time": data.get("save_time", "Unknown"),
				"play_time": data.get("play_time", 0)
			}
	
	return {
		"slot_index": slot,
		"has_save": false
	}

func _create_save_data() -> Dictionary:
	var save_data = {
		"version": ProjectSettings.get_setting("application/config/version", "0.1.0"),
		"save_time": Time.get_datetime_string_from_system(),
		"play_time": 0,
		"level_name": "",
		"level_id": "",
		"score": 0,
		"player": {}
	}
	
	# 从GameManager获取数据
	if GameManager.current_level > 0:
		save_data["level_id"] = str(GameManager.current_level)
		save_data["score"] = GameManager.current_score
	
	return save_data

func _migrate_legacy_save_data() -> void:
	var current_project_name: String = str(ProjectSettings.get_setting("application/config/name", ""))
	if current_project_name != "Dreamer Heroines":
		return

	var app_data_dir := OS.get_data_dir()
	if app_data_dir.is_empty():
		return

	var new_base := app_data_dir.path_join("Godot/app_userdata/Dreamer Heroines")
	var old_base := app_data_dir.path_join("Godot/app_userdata/DreamerHeroines")

	if new_base == old_base:
		return

	var old_settings_path := old_base.path_join("settings.json")
	var old_saves_dir := old_base.path_join("saves")

	if not FileAccess.file_exists(old_settings_path) and not DirAccess.dir_exists_absolute(old_saves_dir):
		return

	DirAccess.make_dir_recursive_absolute(new_base)

	var marker_path := new_base.path_join("migration_from_dreamerheroines_legacy.done")
	if FileAccess.file_exists(marker_path):
		return

	if not FileAccess.file_exists("user://settings.json") and FileAccess.file_exists(old_settings_path):
		DirAccess.copy_absolute(old_settings_path, "user://settings.json")

	if DirAccess.dir_exists_absolute(old_saves_dir):
		DirAccess.make_dir_recursive_absolute("user://saves")
		for slot in range(MAX_SLOTS):
			var file_name := "save_%02d.sav" % slot
			var old_slot_path := old_saves_dir.path_join(file_name)
			var new_slot_path := "user://saves/%s" % file_name
			if FileAccess.file_exists(old_slot_path) and not FileAccess.file_exists(new_slot_path):
				DirAccess.copy_absolute(old_slot_path, new_slot_path)

	var marker_file := FileAccess.open(marker_path, FileAccess.WRITE)
	if marker_file:
		marker_file.store_string("migrated")
		marker_file.close()

func _get_default_settings() -> Dictionary:
	return {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 1.0,
		"ui_volume": 0.7,
		"mouse_sensitivity": 1.0,
		"crosshair_size": 20.0,
		"crosshair_alpha": 1.0,
		"show_center_dot": true,
		"center_dot_size": 2.0,
		"spread_increase_per_shot": 5.0,
		"crosshair_recovery_rate": 30.0,
		"max_spread_multiplier": 3.0,
		"fullscreen": false,
		"vsync": true,
		"window_mode": 0,  # 0=Windowed, 1=Fullscreen, 2=Borderless
		"locale": "zh_CN",
		"developer_mode_enabled": false
	}

func _convert_csharp_settings_to_dict(csharp_settings) -> Dictionary:
	if csharp_settings is Dictionary:
		var dict: Dictionary = csharp_settings
		if not dict.has("developer_mode_enabled"):
			dict["developer_mode_enabled"] = false
		return dict

	var master_volume: float = float(_read_csharp_property(csharp_settings, "MasterVolume", 0.8))
	var music_volume: float = float(_read_csharp_property(csharp_settings, "MusicVolume", 0.7))
	var sfx_volume: float = float(_read_csharp_property(csharp_settings, "SFXVolume", 1.0))
	var ui_volume: float = float(_read_csharp_property(csharp_settings, "UiVolume", 0.7))
	var mouse_sensitivity: float = float(_read_csharp_property(csharp_settings, "MouseSensitivity", 1.0))
	var crosshair_size: float = float(_read_csharp_property(csharp_settings, "CrosshairSize", 20.0))
	var crosshair_alpha: float = float(_read_csharp_property(csharp_settings, "CrosshairAlpha", 1.0))
	var show_center_dot: bool = bool(_read_csharp_property(csharp_settings, "ShowCenterDot", true))
	var center_dot_size: float = float(_read_csharp_property(csharp_settings, "CenterDotSize", 2.0))
	var spread_increase_per_shot: float = float(_read_csharp_property(csharp_settings, "SpreadIncreasePerShot", 5.0))
	var crosshair_recovery_rate: float = float(_read_csharp_property(csharp_settings, "CrosshairRecoveryRate", 30.0))
	var max_spread_multiplier: float = float(_read_csharp_property(csharp_settings, "MaxSpreadMultiplier", 3.0))
	var fullscreen: bool = bool(_read_csharp_property(csharp_settings, "Fullscreen", false))
	var vsync: bool = bool(_read_csharp_property(csharp_settings, "VSync", true))
	var window_mode: int = int(_read_csharp_property(csharp_settings, "WindowMode", 0))
	var locale: String = str(_read_csharp_property(csharp_settings, "Language", "zh_CN"))
	var developer_mode_enabled: bool = bool(_read_csharp_property(csharp_settings, "DeveloperModeEnabled", false))

	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"mouse_sensitivity": mouse_sensitivity,
		"crosshair_size": crosshair_size,
		"crosshair_alpha": crosshair_alpha,
		"show_center_dot": show_center_dot,
		"center_dot_size": center_dot_size,
		"spread_increase_per_shot": spread_increase_per_shot,
		"crosshair_recovery_rate": crosshair_recovery_rate,
		"max_spread_multiplier": max_spread_multiplier,
		"fullscreen": fullscreen,
		"vsync": vsync,
		"window_mode": window_mode,
		"locale": locale,
		"developer_mode_enabled": developer_mode_enabled,
	}

func _read_csharp_property(obj, property_name: String, fallback):
	if property_name in obj:
		return obj.get(property_name)
	return fallback

func _convert_csharp_summary(summary) -> Dictionary:
	# 转换C# SaveSummary到GDScript Dictionary
	if summary == null:
		return {"has_save": false}
	
	return {
		"slot_index": summary.SlotIndex if summary.get("SlotIndex") != null else 0,
		"has_save": summary.HasSave if summary.get("HasSave") != null else false,
		"level_name": summary.LevelName if summary.get("LevelName") != null else "",
		"save_time": summary.SaveTime if summary.get("SaveTime") != null else "",
		"play_time": summary.PlayTime if summary.get("PlayTime") != null else 0
	}

# 工具函数
func export_save(slot: int, export_path: String) -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.ExportSave(slot, export_path)
	return false

func import_save(import_path: String, target_slot: int) -> bool:
	if _csharp_save_manager:
		return _csharp_save_manager.ImportSave(import_path, target_slot)
	return false
