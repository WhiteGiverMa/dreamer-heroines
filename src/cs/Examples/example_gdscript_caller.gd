# GDScript 调用 C# SaveManager 示例
# 这个文件展示了如何从 GDScript 调用 C# 的方法

class_name GdScriptSaveExample
extends Node

# 引用 C# 节点
@onready var cs_caller: Node = $"../GdScriptCaller"


func _ready():
	# 示例：检查 C# 节点是否存在
	if cs_caller == null:
		push_error("[GDScript] GdScriptCaller node not found!")
		return

	# 示例：获取所有存档摘要
	var summaries = cs_caller.get_all_save_summaries()

	# 示例：获取特定槽位的存档信息
	var summary = cs_caller.get_save_summary(0)


# 创建新存档
func create_new_save(slot_index: int, save_name: String) -> void:
	if cs_caller == null:
		push_error("[GDScript] C# caller not available")
		return

	cs_caller.create_new_save(slot_index, save_name)


# 保存游戏
func save_game(slot_index: int) -> void:
	if cs_caller == null:
		push_error("[GDScript] C# caller not available")
		return

	cs_caller.save_game(slot_index)


# 加载游戏
func load_game(slot_index: int) -> void:
	if cs_caller == null:
		push_error("[GDScript] C# caller not available")
		return

	cs_caller.load_game(slot_index)


# 删除存档
func delete_save(slot_index: int) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.delete_save(slot_index)


# 检查存档槽是否有存档
func has_save(slot_index: int) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.has_save_in_slot(slot_index)


# 获取玩家数据
func get_player_data() -> Dictionary:
	if cs_caller == null:
		return {}

	return cs_caller.get_player_data()


# 添加金币
func add_gold(amount: int) -> void:
	if cs_caller == null:
		return

	cs_caller.add_gold(amount)


# 添加经验值
func add_experience(amount: int) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.add_experience(amount)


# 解锁武器
func unlock_weapon(weapon_id: String) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.unlock_weapon(weapon_id)


# 检查武器是否已解锁
func is_weapon_unlocked(weapon_id: String) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.is_weapon_unlocked(weapon_id)


# 完成关卡
func complete_level(level_id: String) -> bool:
	if cs_caller == null:
		return false

	return cs_caller.complete_level(level_id)


# 记录武器击杀
func record_kill(weapon_id: String) -> void:
	if cs_caller == null:
		return

	cs_caller.record_weapon_kill(weapon_id)


# 获取武器击杀统计
func get_weapon_kills() -> Dictionary:
	if cs_caller == null:
		return {}

	return cs_caller.get_weapon_kills()


# 获取总击杀数
func get_total_kills() -> int:
	if cs_caller == null:
		return 0

	return cs_caller.get_total_kills()


# 切换游戏状态
func change_game_state(state_name: String) -> void:
	if cs_caller == null:
		return

	cs_caller.change_game_state(state_name)


# 获取当前游戏状态
func get_current_game_state() -> String:
	if cs_caller == null:
		return "None"

	return cs_caller.get_current_game_state()


# 暂停/恢复游戏
func toggle_pause() -> void:
	if cs_caller == null:
		return

	cs_caller.toggle_pause()


# 设置自动保存
func set_auto_save(enabled: bool) -> void:
	if cs_caller == null:
		return

	cs_caller.set_auto_save_enabled(enabled)


# 检查自动保存是否启用
func is_auto_save_enabled() -> bool:
	if cs_caller == null:
		return false

	return cs_caller.is_auto_save_enabled()


# 获取距离下次自动保存的时间
func get_time_until_auto_save() -> float:
	if cs_caller == null:
		return 0.0

	return cs_caller.get_time_until_auto_save()


# 触发自动保存
func trigger_auto_save() -> void:
	if cs_caller == null:
		return

	cs_caller.trigger_auto_save()


# 信号连接示例
func _connect_signals() -> void:
	if cs_caller == null:
		return

	# 连接 C# 信号到 GDScript 方法
	cs_caller.connect("save_completed", _on_save_completed)
	cs_caller.connect("load_completed", _on_load_completed)
	cs_caller.connect("player_leveled_up", _on_player_leveled_up)


# 保存完成回调
func _on_save_completed(slot: int, success: bool) -> void:
	if not success:
		push_error("[GDScript] Failed to save game!")


# 加载完成回调
func _on_load_completed(slot: int, success: bool) -> void:
	if success:
		_update_ui_after_load()
	else:
		push_error("[GDScript] Failed to load game!")


# 玩家升级回调
func _on_player_leveled_up(new_level: int) -> void:
	_play_level_up_effect()
	_show_level_up_notification(new_level)


# 加载后更新UI
func _update_ui_after_load() -> void:
	var player_data = get_player_data()
	# TODO: 更新UI元素


# 播放升级特效
func _play_level_up_effect() -> void:
	# TODO: 实例化升级特效
	pass


# 显示升级提示
func _show_level_up_notification(level: int) -> void:
	# TODO: 显示UI提示
	pass
