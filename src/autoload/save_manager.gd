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
	# 始终使用 GDScript 实现，以保持与 load_settings 的格式一致
	_save_settings_to_file(settings)

func load_settings() -> Dictionary:
	# 始终使用 GDScript 实现，因为 C# LoadSettings 返回 SettingsSaveData 对象而非 Dictionary
	return _load_settings_from_file()

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

func _save_settings_to_file(settings: Dictionary) -> void:
	var file = FileAccess.open("user://settings.json", FileAccess.WRITE)
	if file:
		var json = JSON.stringify(settings)
		file.store_string(json)
		file.close()

func _load_settings_from_file() -> Dictionary:
	var file_path = "user://settings.json"
	
	if not FileAccess.file_exists(file_path):
		return _get_default_settings()
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json = file.get_as_text()
		file.close()
		
		var settings = JSON.parse_string(json)
		if settings:
			return settings
	
	return _get_default_settings()

func _get_default_settings() -> Dictionary:
	return {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 1.0,
		"mouse_sensitivity": 1.0,
		"fullscreen": false,
		"vsync": true,
		"window_mode": 0  # 0=Windowed, 1=Fullscreen, 2=Borderless
	}

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
