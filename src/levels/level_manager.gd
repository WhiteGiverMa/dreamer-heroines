extends "res://src/base/game_system.gd"

# LevelManager - 关卡管理器
# 负责关卡加载、进度追踪、检查点管理

signal level_loaded(level_data: LevelData)
signal level_started(level_data: LevelData)
signal level_completed(level_data: LevelData)
signal level_failed(reason: String)
signal checkpoint_reached(checkpoint: Checkpoint)
signal objective_updated(objective_type: int, progress: float)

enum LevelState { LOADING, READY, PLAYING, PAUSED, COMPLETED, FAILED }

var current_level: Node = null
var current_level_data: LevelData = null
var current_state: LevelState = LevelState.LOADING

# 检查点管理
var checkpoints: Array[Checkpoint] = []
var active_checkpoint: Checkpoint = null
var last_checkpoint_position: Vector2 = Vector2.ZERO

# 关卡进度
var level_start_time: float = 0.0
var elapsed_time: float = 0.0
var enemies_killed: int = 0
var total_enemies: int = 0
var objectives_completed: int = 0

# 玩家引用
var player: Node2D = null
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const MAX_INIT_ATTEMPTS := 10
var _initialize_attempts := 0

func _ready() -> void:
	var is_autoload_instance := get_path() == NodePath("/root/LevelManager")
	process_mode = Node.PROCESS_MODE_ALWAYS if is_autoload_instance else Node.PROCESS_MODE_PAUSABLE
	system_name = "level_manager"
	# 不在这里执行初始化，等待 BootSequence 调用

func initialize() -> void:
	print("[LevelManager] 开始初始化...")
	
	# 等待 SaveManager 依赖
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and not save_mgr.is_initialized:
		print("[LevelManager] 等待 SaveManager 初始化...")
		await save_mgr.system_ready
	
	print("[LevelManager] 初始化完成")
	_mark_ready()

func _process(delta: float) -> void:
	if GameManager and GameManager.is_game_paused:
		return

	if current_state == LevelState.PLAYING:
		elapsed_time += delta
		_check_objectives()
		_check_time_limit()

# 关卡加载
func load_level(level_id: String) -> bool:
	current_state = LevelState.LOADING
	_initialize_attempts = 0
	
	# 加载关卡数据
	var level_data = _load_level_data(level_id)
	if not level_data:
		push_error("Failed to load level data: " + level_id)
		return false
	
	current_level_data = level_data
	
	# 加载关卡场景
	var level_scene_path = "res://scenes/levels/" + level_id + ".tscn"
	if not ResourceLoader.exists(level_scene_path):
		level_scene_path = "res://scenes/test_level.tscn"
	
	var err = get_tree().change_scene_to_file(level_scene_path)
	if err != OK:
		push_error("Failed to load level scene: " + level_scene_path)
		return false
	
	# 使用call_deferred延迟初始化，避免await问题
	call_deferred("_initialize_level")
	return true

func _load_level_data(level_id: String) -> LevelData:
	# 尝试从配置文件加载
	var config_path = "res://config/levels/" + level_id + ".tres"
	if ResourceLoader.exists(config_path):
		var loaded_resource := load(config_path)
		if loaded_resource is LevelData:
			return loaded_resource
		if loaded_resource and loaded_resource.get_script() == preload("res://src/levels/level_data.gd"):
			return loaded_resource as LevelData
		push_warning("Level config exists but is not LevelData: " + config_path)
	
	# 创建默认关卡数据
	var default_data = LevelData.new()
	default_data.level_id = level_id
	default_data.level_name = level_id.capitalize()
	return default_data

func _initialize_level() -> void:
	_initialize_attempts += 1
	current_level = get_tree().current_scene
	if current_level == null:
		if _initialize_attempts < MAX_INIT_ATTEMPTS:
			call_deferred("_initialize_level")
		return
	
	# 查找/生成玩家
	_ensure_player_instance()
	_ensure_hud_instance()
	
	# 查找检查点
	_find_checkpoints()
	
	# 计算敌人数量
	_count_enemies()
	
	# 设置初始检查点
	if checkpoints.size() > 0:
		set_active_checkpoint(checkpoints[0])
	
	current_state = LevelState.READY
	level_start_time = Time.get_time_dict_from_system()["second"]
	elapsed_time = 0.0
	enemies_killed = 0
	
	# 发送关卡加载完成信号
	call_deferred("_emit_level_loaded")


func _ensure_player_instance() -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as Node2D
		if GameManager and player:
			GameManager.register_player(player)
		return

	if not ResourceLoader.exists(PLAYER_SCENE_PATH):
		push_error("LevelManager: Player scene not found at %s" % PLAYER_SCENE_PATH)
		return

	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	if player_scene == null:
		push_error("LevelManager: Failed to load player scene")
		return

	var player_instance := player_scene.instantiate() as Node2D
	if player_instance == null:
		push_error("LevelManager: Failed to instantiate player scene")
		return

	player_instance.name = "Player"
	current_level.add_child(player_instance)
	player_instance.global_position = _resolve_player_spawn_position()
	player = player_instance

	if GameManager:
		GameManager.register_player(player)


func _ensure_hud_instance() -> void:
	if GameManager and GameManager.hud and is_instance_valid(GameManager.hud):
		return

	var scene_root := get_tree().current_scene
	if scene_root:
		var existing_hud := scene_root.get_node_or_null("UI/HUD")
		if existing_hud == null:
			existing_hud = scene_root.get_node_or_null("HUD")

		if existing_hud and existing_hud is CanvasLayer:
			if GameManager:
				GameManager.register_hud(existing_hud)
			return

	if not ResourceLoader.exists(HUD_SCENE_PATH):
		push_warning("LevelManager: HUD scene not found at %s" % HUD_SCENE_PATH)
		return

	var hud_scene := load(HUD_SCENE_PATH) as PackedScene
	if hud_scene == null:
		push_error("LevelManager: Failed to load HUD scene")
		return

	var hud_instance := hud_scene.instantiate() as CanvasLayer
	if hud_instance == null:
		push_error("LevelManager: Failed to instantiate HUD scene")
		return

	if current_level:
		current_level.add_child(hud_instance)
	else:
		get_tree().root.add_child(hud_instance)


func _resolve_player_spawn_position() -> Vector2:
	if current_level:
		var spawn_marker := current_level.get_node_or_null("SpawnPoints/PlayerSpawn") as Marker2D
		if spawn_marker:
			return spawn_marker.global_position

	if current_level_data:
		return current_level_data.player_spawn_position

	return Vector2.ZERO

func _emit_level_loaded() -> void:
	level_loaded.emit(current_level_data)

func _find_checkpoints() -> void:
	checkpoints.clear()
	var checkpoint_nodes = get_tree().get_nodes_in_group("checkpoint")
	for node in checkpoint_nodes:
		if node is Checkpoint:
			checkpoints.append(node)
			if node.has_signal("checkpoint_activated"):
				node.checkpoint_activated.connect(_on_checkpoint_activated)

func _count_enemies() -> void:
	total_enemies = get_tree().get_nodes_in_group("enemy").size()

# 关卡控制
func start_level() -> void:
	if current_state != LevelState.READY:
		return
	
	current_state = LevelState.PLAYING
	level_started.emit(current_level_data)
	GameManager.change_state(GameManager.GameState.PLAYING)

func pause_level() -> void:
	if current_state == LevelState.PLAYING:
		current_state = LevelState.PAUSED
		GameManager.set_paused(true)

func resume_level() -> void:
	if current_state == LevelState.PAUSED:
		current_state = LevelState.PLAYING
		GameManager.set_paused(false)

func restart_level() -> void:
	if current_level_data:
		load_level(current_level_data.level_id)

func complete_level() -> void:
	current_state = LevelState.COMPLETED
	
	# 更新存档数据
	if SaveManager.has_current_save():
		var save_data = SaveManager.current_save_data
		if save_data and save_data.has_method("complete_level"):
			save_data.complete_level(current_level_data.level_id)
		SaveManager.save_current_game()
	
	level_completed.emit(current_level_data)
	GameManager.complete_level()

func fail_level(reason: String = "") -> void:
	current_state = LevelState.FAILED
	level_failed.emit(reason)
	GameManager.change_state(GameManager.GameState.GAME_OVER)

# 检查点管理
func set_active_checkpoint(checkpoint: Checkpoint) -> void:
	if active_checkpoint and active_checkpoint != checkpoint:
		active_checkpoint.deactivate()
	
	active_checkpoint = checkpoint
	last_checkpoint_position = checkpoint.get_respawn_position()
	checkpoint_reached.emit(checkpoint)

func respawn_player() -> void:
	if not player:
		return
	
	if active_checkpoint:
		player.respawn(last_checkpoint_position)
	else:
		# 使用关卡起始位置
		if current_level_data:
			player.respawn(current_level_data.player_spawn_position)
		else:
			player.respawn(Vector2.ZERO)

func _on_checkpoint_activated(_checkpoint: Checkpoint) -> void:
	# 自动保存
	if SaveManager.has_current_save():
		SaveManager.save_current_game()

func _on_player_died() -> void:
	# 延迟重生
	var timer = get_tree().create_timer(1.0)
	timer.timeout.connect(_handle_player_death)

func _handle_player_death() -> void:
	if GameManager.player_lives > 0:
		respawn_player()
	else:
		fail_level("所有生命已耗尽")

# 目标检查
func _check_objectives() -> void:
	if not current_level_data:
		return
	
	match current_level_data.primary_objective:
		LevelData.ObjectiveType.ELIMINATE_ALL:
			var remaining = get_tree().get_nodes_in_group("enemy").size()
			if remaining == 0 and total_enemies > 0:
				complete_level()
			else:
				var progress = float(enemies_killed) / float(total_enemies)
				objective_updated.emit(LevelData.ObjectiveType.ELIMINATE_ALL, progress)
		
		LevelData.ObjectiveType.SURVIVE_TIME:
			if current_level_data.time_limit > 0:
				var progress = elapsed_time / current_level_data.time_limit
				if elapsed_time >= current_level_data.time_limit:
					complete_level()
				else:
					objective_updated.emit(LevelData.ObjectiveType.SURVIVE_TIME, progress)

func _check_time_limit() -> void:
	if current_level_data and current_level_data.time_limit > 0:
		if elapsed_time >= current_level_data.time_limit:
			if current_level_data.primary_objective != LevelData.ObjectiveType.SURVIVE_TIME:
				fail_level("时间耗尽")

# 敌人管理
func on_enemy_killed(_enemy: Node) -> void:
	enemies_killed += 1
	GameManager.add_score(100)

# 获取关卡信息
func get_level_progress() -> Dictionary:
	return {
		"elapsed_time": elapsed_time,
		"enemies_killed": enemies_killed,
		"total_enemies": total_enemies,
		"progress_percent": float(enemies_killed) / float(total_enemies) if total_enemies > 0 else 0.0
	}

func get_formatted_time() -> String:
	@warning_ignore("integer_division")
	var minutes := int(elapsed_time) / 60
	var seconds := int(elapsed_time) % 60
	return "%02d:%02d" % [minutes, seconds]

# 保存/加载
func save_level_state() -> Dictionary:
	var checkpoint_states = []
	for cp in checkpoints:
		checkpoint_states.append(cp.save_state())
	
	return {
		"level_id": current_level_data.level_id if current_level_data else "",
		"elapsed_time": elapsed_time,
		"enemies_killed": enemies_killed,
		"checkpoints": checkpoint_states,
		"active_checkpoint_id": active_checkpoint.checkpoint_id if active_checkpoint else ""
	}

func load_level_state(data: Dictionary) -> void:
	elapsed_time = data.get("elapsed_time", 0.0)
	enemies_killed = data.get("enemies_killed", 0)
	
	var checkpoint_states = data.get("checkpoints", [])
	for i in range(min(checkpoint_states.size(), checkpoints.size())):
		checkpoints[i].load_state(checkpoint_states[i])
	
	var active_id = data.get("active_checkpoint_id", "")
	for cp in checkpoints:
		if cp.checkpoint_id == active_id:
			set_active_checkpoint(cp)
			break
