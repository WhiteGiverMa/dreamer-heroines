extends Node

## 开发者模式核心管理器
## 提供游戏内调试功能的状态管理，不直接修改玩家/敌人属性
# 核心属性
var is_active: bool = false
var god_mode: bool = false
var infinite_ammo: bool = false

# 状态追踪 - 记录原始状态以便重置
var _original_state: Dictionary = {}

# 配置缓存 - 热重载配置
var _config_cache: Dictionary = {}

# 开发者模式配置
var _hotkey_config: Dictionary = {}
var _enabled_in_release: bool = false
var _user_enabled_by_settings: bool = false
var _spawn_rng := RandomNumberGenerator.new()

# 面板引用
var _panel: CanvasLayer = null

const PANEL_SCENE := preload("res://scenes/ui/developer_panel.tscn")

# 信号定义
signal mode_changed(enabled: bool)
signal state_changed(key: String, value: Variant)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_spawn_rng.randomize()
	_load_dev_mode_config()
	_mount_panel()
	print("[DeveloperMode] 开发者模式已加载")


## 加载开发者模式配
func _load_dev_mode_config() -> void:
	var config_path := "res://config/developer_mode.json"
	if FileAccess.file_exists(config_path):
		var config = _load_config(config_path)
		if not config.is_empty():
			_hotkey_config = config.get("hotkey", {})
			var enabled_config = config.get("enabled_in_release", {})
			_enabled_in_release = enabled_config.get("value", false)
			print("[DeveloperMode] 配置已加- 热键: ", _hotkey_config.get("value", "F12"))
	else:
		_enabled_in_release = false
		print("[DeveloperMode] 未找到配置文件，使用默认设置")


## 挂载开发者面板到场景
func _mount_panel() -> void:
	_panel = PANEL_SCENE.instantiate()
	_panel.visible = false
	get_tree().root.call_deferred("add_child", _panel)
	print("[DeveloperPanel] 面板已挂")


## 切换面板可见
func toggle_panel() -> void:
	if _panel:
		if _panel.visible:
			hide_panel()
		else:
			show_panel()


## 显示面板
func show_panel() -> void:
	if _panel == null or _panel.visible:
		return

	_panel.visible = true
	if GameManager and GameManager.has_method("request_game_and_ui_input"):
		GameManager.request_game_and_ui_input("developer_panel")


## 隐藏面板
func hide_panel() -> void:
	if _panel == null or not _panel.visible:
		return

	_panel.visible = false
	if GameManager and GameManager.has_method("release_game_and_ui_input"):
		GameManager.release_game_and_ui_input("developer_panel")


func _get_state() -> Dictionary:
	return {"is_active": is_active, "god_mode": god_mode, "infinite_ammo": infinite_ammo}


func _save_original_state() -> void:
	_original_state = _get_state()


func _restore_original_state() -> void:
	if _original_state.is_empty():
		return
	for key in _original_state:
		match key:
			"god_mode":
				god_mode = _original_state[key]
			"infinite_ammo":
				infinite_ammo = _original_state[key]
		state_changed.emit(key, _original_state[key])


## 启用开发者模
func enable() -> void:
	if is_active:
		return
	_save_original_state()
	is_active = true
	mode_changed.emit(true)
	print("[DeveloperMode] 开发者模式已启用")


## 禁用开发者模式并重置所有状
func disable() -> void:
	if not is_active:
		return

	hide_panel()
	# 重置所有修改的状
	god_mode = false
	infinite_ammo = false
	# 恢复原始状
	_restore_original_state()
	is_active = false
	mode_changed.emit(false)
	print("[DeveloperMode] 开发者模式已禁用")


## 切换开发者模式状
func toggle() -> void:
	if is_active:
		disable()
	else:
		if _is_available():
			enable()
			if _panel:
				show_panel()
		else:
			print("[DeveloperMode] 当前构建不支持开发者模")


## 检查开发者模式是否可
func _is_available() -> bool:
	if not _user_enabled_by_settings:
		return false
	if OS.is_debug_build():
		return true
	return _enabled_in_release


func set_user_enabled(enabled: bool) -> void:
	_user_enabled_by_settings = enabled
	if not enabled and is_active:
		disable()


func is_user_enabled() -> bool:
	return _user_enabled_by_settings


## 监听热键输入
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("dev_mode_toggle"):
		toggle()


## 设置特定调试状
func set_state(key: String, value: bool) -> void:
	match key:
		"god_mode":
			god_mode = value
		"infinite_ammo":
			infinite_ammo = value
		_:
			push_warning("[DeveloperMode] 未知状态键: ", key)
			return
	state_changed.emit(key, value)
	print("[DeveloperMode] 状态已更新 - ", key, ": ", value)


## 获取调试状
func get_state(key: String) -> bool:
	match key:
		"god_mode":
			return god_mode
		"infinite_ammo":
			return infinite_ammo
		"is_active":
			return is_active
	return false


## 切换无限弹药
func cmd_infinite_ammo(enabled: bool) -> void:
	var player = GameManager.player_instance
	if not player or not player.current_weapon:
		push_warning("[DeveloperMode] 无法访问玩家或当前武")
		return
	var weapon = player.current_weapon
	if enabled:
		_original_state["use_ammo_system"] = weapon.is_using_ammo_system()
		weapon.set_use_ammo_system(false)
	else:
		weapon.set_use_ammo_system(_original_state.get("use_ammo_system", true))
	infinite_ammo = enabled
	state_changed.emit("infinite_ammo", enabled)
	print("[DeveloperMode] 无限弹药: ", enabled)


## 补满当前武器弹药
func cmd_refill_ammo() -> void:
	var player = GameManager.player_instance
	if not player or not player.current_weapon:
		push_warning("[DeveloperMode] 无法访问玩家或当前武")
		return
	var weapon = player.current_weapon
	if not weapon.stats:
		push_warning("[DeveloperMode] 武器缺少统计数据")
		return
	weapon.current_ammo_in_mag = weapon.stats.magazine_size
	weapon.current_reserve_ammo = weapon.stats.max_ammo
	weapon._emit_ammo_changed()
	state_changed.emit("ammo_refilled", true)
	print("[DeveloperMode] 弹药已补")


## 设置弹药数量
func cmd_set_ammo(current: int, reserve: int) -> void:
	var player = GameManager.player_instance
	if not player or not player.current_weapon:
		push_warning("[DeveloperMode] 无法访问玩家或当前武")
		return
	var weapon = player.current_weapon
	if not weapon.stats:
		push_warning("[DeveloperMode] 武器缺少统计数据")
		return
	weapon.current_ammo_in_mag = clampi(current, 0, weapon.stats.magazine_size)
	weapon.current_reserve_ammo = clampi(reserve, 0, weapon.stats.max_ammo)
	weapon._emit_ammo_changed()
	state_changed.emit("ammo_set", {"current": current, "reserve": reserve})
	print("[DeveloperMode] 弹药已设置为: 当前 ", current, " / 备用 ", reserve)


## 玩家控制命令


## 切换无敌状(god_mode)
func cmd_god_mode(enabled: bool) -> void:
	var player = GameManager.player_instance
	if not player:
		push_warning("[DeveloperMode] 玩家实例不存")
		return
	if enabled:
		_original_state["player_invulnerable"] = player.is_invulnerable
		player.is_invulnerable = true
	else:
		# 恢复原始状
		if "player_invulnerable" in _original_state:
			player.is_invulnerable = _original_state["player_invulnerable"]
		else:
			player.is_invulnerable = false
	god_mode = enabled
	state_changed.emit("god_mode", enabled)
	print("[DeveloperMode] God mode: ", enabled)


## 设置玩家生命
func cmd_set_health(value: int) -> void:
	var player = GameManager.player_instance
	if not player:
		push_warning("[DeveloperMode] 玩家实例不存")
		return
	if not "player_health" in _original_state:
		_original_state["player_health"] = player.current_health
	player.current_health = clampi(value, 0, player.max_health)
	player.health_changed.emit(player.current_health, player.max_health)
	state_changed.emit("health", player.current_health)
	print("[DeveloperMode] Health set to: ", player.current_health)


## 回复生命
func cmd_heal(amount: int) -> void:
	var player = GameManager.player_instance
	if not player:
		push_warning("[DeveloperMode] 玩家实例不存")
		return
	player.heal(amount)
	state_changed.emit("healed", amount)
	print("[DeveloperMode] Healed ", amount, " (current: ", player.current_health, ")")


## 传送玩家到指定位置
func cmd_teleport_player(x: float, y: float) -> void:
	var player = GameManager.player_instance
	if not player:
		push_warning("[DeveloperMode] 玩家实例不存")
		return
	var old_pos = player.global_position
	player.global_position = Vector2(x, y)
	state_changed.emit("teleported", old_pos)
	print("[DeveloperMode] Teleported from ", old_pos, " to ", player.global_position)


## 复活玩家
func cmd_respawn_player() -> void:
	var player = GameManager.player_instance
	if not player:
		push_warning("[DeveloperMode] 玩家实例不存")
		return
	# 调用玩家的复活方
	if player.has_method("respawn"):
		# 获取复活位置（检查点或初始位置）
		var spawn_pos = Vector2(0, 0)
		if LevelManager and LevelManager.current_level:
			spawn_pos = LevelManager.get_spawn_position()
		player.respawn(spawn_pos)
		state_changed.emit("respawned", spawn_pos)
		print("[DeveloperMode] Player respawned at ", spawn_pos)
	else:
		push_warning("[DeveloperMode] 玩家没有 respawn 方法")


## 获取WaveSpawner引用（双重查找）
func _get_wave_spawner() -> Node:
	# 方法1: 通过LevelManager
	if LevelManager and LevelManager.current_level:
		var level = LevelManager.current_level
		if "_wave_spawner" in level:
			return level.get("_wave_spawner")
	# 方法2: 搜索场景
	var spawners = get_tree().get_nodes_in_group("wave_spawner")
	if spawners.size() > 0:
		return spawners[0]
	return null


## 波次控制命令


## 立即开始下一
func cmd_next_wave() -> void:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] No wave spawner found")
		return
	var current = spawner.get_current_wave()
	spawner.skip_to_wave(current + 1)
	print("[DeveloperMode] Skipped to next wave: ", current + 1)


## 跳转到指定波
func cmd_jump_to_wave(wave_number: int) -> void:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] No wave spawner found")
		return
	spawner.skip_to_wave(wave_number)
	print("[DeveloperMode] Jumped to wave: ", wave_number)


## 暂停波次生成
func cmd_pause_waves() -> void:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] No wave spawner found")
		return
	spawner.stop()
	print("[DeveloperMode] Waves paused")


## 恢复波次生成
func cmd_resume_waves() -> void:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] No wave spawner found")
		return
	spawner.start()
	print("[DeveloperMode] Waves resumed")


## 获取当前波次信息
func cmd_get_wave_info() -> Dictionary:
	var spawner = _get_wave_spawner()
	if not spawner:
		return {"error": "No wave spawner found"}
	return {"current_wave": spawner.get_current_wave(), "total_waves": spawner.get_total_waves()}


## === 敌人控制命令 ===


## 获取玩家引用
func _get_player() -> Node:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0]
	return null


## 生成敌人
## @param enemy_key: 敌人类型键名（如 "melee", "ranged_basic", "flying_basic"
## @param x: 生成位置X坐标（默
## @param y: 生成位置Y坐标（默
## @return: 生成敌人节点，失败返回null
func cmd_spawn_enemy(enemy_key: String, x: float = 0, y: float = 0) -> Node:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] WaveSpawner not found")
		return null
	var pos := Vector2(x, y) if x != 0 or y != 0 else Vector2.ZERO
	var enemy = spawner.spawn_enemy_now(enemy_key, pos)
	if enemy:
		print("[DeveloperMode] Spawned enemy: ", enemy_key, " at ", pos)
	else:
		push_error("[DeveloperMode] Failed to spawn enemy: ", enemy_key)
	return enemy


func cmd_spawn_random_enemies(count: int, x: float = 0, y: float = 0) -> Array[Node]:
	var spawner = _get_wave_spawner()
	if not spawner:
		push_error("[DeveloperMode] WaveSpawner not found")
		return []
	var pos := Vector2(x, y) if x != 0 or y != 0 else Vector2.ZERO
	var enemies := _spawn_random_enemies_with_spawner(spawner, count, pos)
	if enemies.is_empty():
		push_error("[DeveloperMode] Failed to spawn random enemies x%d" % count)
	else:
		print("[DeveloperMode] Spawned %d random enemies at %s" % [enemies.size(), pos])
	return enemies


func _spawn_random_enemies_with_spawner(
	spawner: Node, count: int, position: Vector2 = Vector2.ZERO
) -> Array[Node]:
	if count <= 0:
		return []
	if (
		spawner == null
		or not spawner.has_method("get_spawnable_enemy_keys")
		or not spawner.has_method("spawn_enemy_now")
	):
		return []

	var spawnable_enemy_keys_variant: Variant = spawner.call("get_spawnable_enemy_keys")
	if not (spawnable_enemy_keys_variant is Array) or spawnable_enemy_keys_variant.is_empty():
		return []

	var spawnable_enemy_keys: Array = spawnable_enemy_keys_variant
	var enemies: Array[Node] = []
	for _i in count:
		var enemy_key := _pick_random_spawn_enemy_key(spawnable_enemy_keys)
		if enemy_key.is_empty():
			continue
		var enemy_variant: Variant = spawner.call("spawn_enemy_now", enemy_key, position)
		if enemy_variant is Node:
			enemies.append(enemy_variant as Node)
	return enemies


func _pick_random_spawn_enemy_key(spawnable_enemy_keys: Array) -> String:
	if spawnable_enemy_keys.is_empty():
		return ""
	var index := _spawn_rng.randi_range(0, spawnable_enemy_keys.size() - 1)
	return String(spawnable_enemy_keys[index])


## 杀死所有敌
func cmd_kill_all_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count := 0
	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()
			count += 1
	print("[DeveloperMode] Killed %d enemies" % count)


## 瞬移所有敌人到玩家身边
func cmd_teleport_enemies_to_player() -> void:
	var player = _get_player()
	if not player:
		push_error("[DeveloperMode] Player not found")
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count := 0
	for enemy in enemies:
		if enemy is Node2D:
			# 随机分布在玩家周0-150像素范围
			var offset = (
				Vector2(randf_range(-1, 1), randf_range(-1, 0)).normalized() * randf_range(50, 150)
			)
			enemy.global_position = player.global_position + offset
			count += 1
	print("[DeveloperMode] Teleported %d enemies to player" % count)


## 瞬移所有敌人到指定位置
## @param x: 目标位置X坐标
## @param y: 目标位置Y坐标
func cmd_teleport_enemies_to(x: float, y: float) -> void:
	var target := Vector2(x, y)
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count := 0
	for enemy in enemies:
		if enemy is Node2D:
			enemy.global_position = target
			count += 1
	print("[DeveloperMode] Teleported %d enemies to (%s)" % [count, target])


## 对所有敌人造成伤害
## @param amount: 伤害数
func cmd_damage_all_enemies(amount: int) -> void:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count := 0
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.take_damage(amount)
			count += 1
	print("[DeveloperMode] Damaged %d enemies for %d HP" % [count, amount])


## 配置热重载功
## 加载配置文件
func _load_config(config_path: String) -> Dictionary:
	if not FileAccess.file_exists(config_path):
		push_error("[DeveloperMode] Config file not found: " + config_path)
		return {}
	var file = FileAccess.open(config_path, FileAccess.READ)
	if not file:
		push_error(
			(
				"[DeveloperMode] Failed to open config: "
				+ config_path
				+ " - "
				+ str(FileAccess.get_open_error())
			)
		)
		return {}
	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()
	if error != OK:
		push_error("[DeveloperMode] Failed to parse config: " + config_path)
		return {}
	return json.data


## 重新加载配置
func cmd_reload_config(config_name: String = "all") -> Dictionary:
	match config_name:
		"gameplay", "all":
			_config_cache["gameplay_params"] = _load_config("res://config/gameplay_params.json")
		"enemy", "all":
			_config_cache["enemy_stats"] = _load_config("res://config/enemy_stats.json")
		_:
			return {"success": false, "error": "Unknown config: " + config_name}
	print("[DeveloperMode] Reloaded config: " + config_name)
	return {"success": true, "config": config_name}


## 获取配置
func cmd_get_config(config_name: String) -> Dictionary:
	if config_name in _config_cache:
		return {"success": true, "config": config_name, "data": _config_cache[config_name]}
	# Load on demand if not cached
	match config_name:
		"gameplay", "gameplay_params":
			_config_cache["gameplay_params"] = _load_config("res://config/gameplay_params.json")
			return {
				"success": true, "config": config_name, "data": _config_cache["gameplay_params"]
			}
		"enemy", "enemy_stats":
			_config_cache["enemy_stats"] = _load_config("res://config/enemy_stats.json")
			return {"success": true, "config": config_name, "data": _config_cache["enemy_stats"]}
		_:
			return {"success": false, "error": "Unknown config: " + config_name}
