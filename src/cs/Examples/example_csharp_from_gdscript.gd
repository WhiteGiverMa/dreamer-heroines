# C# 调用 GDScript 示例
# 这个文件展示了 C# 如何调用这个 GDScript 的方法和访问属性
# 对应的 C# 代码在 CSharpToGdScript.cs 中

class_name CSharpCallableExample
extends Node

# 信号定义 - C# 可以连接这些信号
signal level_started(level_number: int)
signal level_completed(level_number: int, completion_time: float)
signal player_died(death_position: Vector2)
signal score_changed(new_score: int, delta: int)
signal weapon_switched(weapon_id: String)
signal health_changed(current_health: int, max_health: int)

# 属性 - C# 可以读取和设置这些属性
var current_level: int = 1
var player_score: int = 0
var player_health: int = 100
var player_max_health: int = 100
var current_weapon: String = "pistol"
var is_game_paused: bool = false

# 内部变量
var _level_start_time: float = 0.0
var _enemies_defeated: int = 0


func _ready():
	_level_start_time = Time.get_time_dict_from_system()["second"]


# ========== C# 可调用的方法 ==========


# 播放音效 - 被 C# AudioManager 调用
func play_sound(sound_name: String) -> void:
	# TODO: 实际播放音效
	pass


# 播放音乐 - 被 C# AudioManager 调用
func play_music(music_name: String, loop: bool = true) -> void:
	# TODO: 实际播放音乐
	pass


# 停止音乐 - 被 C# AudioManager 调用
func stop_music() -> void:
	# TODO: 停止音乐
	pass


# 检查输入 - 被 C# InputManager 调用
func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


# 获取输入向量 - 被 C# InputManager 调用
func get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


# 开始关卡 - 被 C# 调用
func start_level(level_number: int) -> void:
	current_level = level_number
	_level_start_time = Time.get_time_dict_from_system()["second"]
	_enemies_defeated = 0
	emit_signal("level_started", level_number)


# 完成关卡 - 被 C# 调用
func complete_level() -> void:
	var completion_time = Time.get_time_dict_from_system()["second"] - _level_start_time
	emit_signal("level_completed", current_level, completion_time)


# 玩家死亡 - 被 C# 调用
func player_die(death_position: Vector2) -> void:
	emit_signal("player_died", death_position)


# 添加分数 - 被 C# 调用
func add_score(points: int) -> void:
	var old_score = player_score
	player_score += points
	emit_signal("score_changed", player_score, points)


# 设置分数 - 被 C# 调用
func set_score(new_score: int) -> void:
	var delta = new_score - player_score
	player_score = new_score
	emit_signal("score_changed", player_score, delta)


# 切换武器 - 被 C# 调用
func switch_weapon(weapon_id: String) -> void:
	current_weapon = weapon_id
	emit_signal("weapon_switched", weapon_id)


# 造成伤害 - 被 C# 调用
func take_damage(amount: int) -> void:
	player_health = max(0, player_health - amount)
	emit_signal("health_changed", player_health, player_max_health)

	if player_health <= 0:
		# 获取父节点的位置（如果是Node2D），否则使用零向量
		var death_pos := Vector2.ZERO
		if get_parent() is Node2D:
			death_pos = (get_parent() as Node2D).global_position
		player_die(death_pos)


# 治疗 - 被 C# 调用
func heal(amount: int) -> void:
	player_health = min(player_max_health, player_health + amount)
	emit_signal("health_changed", player_health, player_max_health)


# 设置最大生命值 - 被 C# 调用
func set_max_health(max_hp: int) -> void:
	player_max_health = max_hp
	player_health = min(player_health, player_max_health)
	emit_signal("health_changed", player_health, player_max_health)


# 暂停游戏 - 被 C# 调用
func pause_game() -> void:
	is_game_paused = true
	get_tree().paused = true


# 恢复游戏 - 被 C# 调用
func resume_game() -> void:
	is_game_paused = false
	get_tree().paused = false


# 切换暂停状态 - 被 C# 调用
func toggle_pause() -> void:
	if is_game_paused:
		resume_game()
	else:
		pause_game()


# 生成敌人 - 被 C# 调用
func spawn_enemy(enemy_type: String, position: Vector2) -> Node:
	# TODO: 实例化敌人
	return null


# 生成特效 - 被 C# 调用
func spawn_effect(effect_name: String, position: Vector2) -> Node:
	# TODO: 实例化特效
	return null


# 记录击败敌人 - 被 C# 调用
func record_enemy_defeated() -> void:
	_enemies_defeated += 1


# 获取击败敌人数 - 被 C# 调用
func get_enemies_defeated() -> int:
	return _enemies_defeated


# 获取关卡用时 - 被 C# 调用
func get_level_time() -> float:
	return Time.get_time_dict_from_system()["second"] - _level_start_time


# 保存游戏数据到字典 - 被 C# 调用
func get_save_data() -> Dictionary:
	return {
		"current_level": current_level,
		"player_score": player_score,
		"player_health": player_health,
		"player_max_health": player_max_health,
		"current_weapon": current_weapon,
		"enemies_defeated": _enemies_defeated
	}


# 从字典加载游戏数据 - 被 C# 调用
func load_save_data(data: Dictionary) -> void:
	current_level = data.get("current_level", 1)
	player_score = data.get("player_score", 0)
	player_health = data.get("player_health", 100)
	player_max_health = data.get("player_max_health", 100)
	current_weapon = data.get("current_weapon", "pistol")
	_enemies_defeated = data.get("enemies_defeated", 0)


# 重置游戏状态 - 被 C# 调用
func reset_game() -> void:
	current_level = 1
	player_score = 0
	player_health = player_max_health
	current_weapon = "pistol"
	_enemies_defeated = 0
	is_game_paused = false


# 获取游戏状态信息 - 被 C# 调用
func get_game_status() -> Dictionary:
	return {
		"level": current_level,
		"score": player_score,
		"health": player_health,
		"max_health": player_max_health,
		"weapon": current_weapon,
		"is_paused": is_game_paused,
		"enemies_defeated": _enemies_defeated,
		"level_time": get_level_time()
	}


# 设置游戏难度 - 被 C# 调用
func set_difficulty(difficulty: int) -> void:
	# TODO: 根据难度调整游戏参数
	pass


# 显示消息 - 被 C# 调用
func show_message(message: String, duration: float = 2.0) -> void:
	# TODO: 显示UI消息
	pass


# 震动屏幕 - 被 C# 调用
func shake_screen(intensity: float, duration: float) -> void:
	# TODO: 实现屏幕震动
	pass


# 播放动画 - 被 C# 调用
func play_animation(anim_name: String) -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play(anim_name)


# 停止动画 - 被 C# 调用
func stop_animation() -> void:
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()


# 检查是否有动画 - 被 C# 调用
func has_animation(anim_name: String) -> bool:
	if has_node("AnimationPlayer"):
		return $AnimationPlayer.has_animation(anim_name)
	return false
