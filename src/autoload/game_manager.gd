extends "res://src/base/game_system.gd"

# GameManager - 游戏核心管理器
# 负责游戏状态、分数、关卡切换等全局管理

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

signal state_changed(new_state: GameState)
signal score_changed(new_score: int)
signal player_died
signal level_completed
signal game_started
signal game_restarted

var current_state: GameState = GameState.MENU
var current_score: int = 0
var current_level: int = 1
var player_lives: int = 3
var player_instance: Node2D = null
var current_level_instance: Node2D = null

# UI引用
var hud: CanvasLayer = null
var pause_menu: Control = null
var game_over_screen: Control = null

var is_game_paused: bool = false:
	get:
		return is_game_paused
	set(value):
		is_game_paused = value
		get_tree().paused = value
		if value:
			change_state(GameState.PAUSED)
		else:
			change_state(GameState.PLAYING)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "game_manager"
	# 不在这里执行初始化，等待 BootSequence 调用

func initialize() -> void:
	print("[GameManager] 开始初始化...")
	
	# 等待 SaveManager 依赖
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and not save_mgr.is_initialized:
		print("[GameManager] 等待 SaveManager 初始化...")
		await save_mgr.system_ready
	
	# 等待 LevelManager 依赖
	var level_mgr = get_node_or_null("/root/LevelManager")
	if level_mgr and not level_mgr.is_initialized:
		print("[GameManager] 等待 LevelManager 初始化...")
		await level_mgr.system_ready
	
	print("[GameManager] 初始化完成")
	_mark_ready()

func _input(event: InputEvent):
	if event.is_action_pressed("pause") and current_state in [GameState.PLAYING, GameState.PAUSED]:
		toggle_pause()

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	state_changed.emit(new_state)
	
	match new_state:
		GameState.MENU:
			print("State: MENU")
			_show_menu()
		GameState.PLAYING:
			print("State: PLAYING")
			_hide_menus()
		GameState.PAUSED:
			print("State: PAUSED")
			_show_pause_menu()
		GameState.GAME_OVER:
			print("State: GAME_OVER")
			_show_game_over(false)
		GameState.VICTORY:
			print("State: VICTORY")
			_show_game_over(true)

func toggle_pause() -> void:
	is_game_paused = !is_game_paused

func add_score(points: int) -> void:
	current_score += points
	score_changed.emit(current_score)

func reset_game() -> void:
	current_score = 0
	current_level = 1
	player_lives = 3
	change_state(GameState.PLAYING)

func on_player_death() -> void:
	player_lives -= 1
	player_died.emit()
	
	# 更新HUD
	if hud:
		hud.update_lives(player_lives)
	
	if player_lives <= 0:
		change_state(GameState.GAME_OVER)
	else:
		# 重生逻辑
		if LevelManager.current_level:
			LevelManager.respawn_player()

func complete_level() -> void:
	level_completed.emit()
	current_level += 1
	
	# 保存进度
	if SaveManager.has_current_save():
		SaveManager.save_current_game()
	
	# 显示胜利画面或加载下一关
	change_state(GameState.VICTORY)

func get_difficulty_multiplier() -> float:
	# 根据关卡返回难度倍率
	return 1.0 + (current_level - 1) * 0.1

func register_player(player: Node2D) -> void:
	player_instance = player
	
	# 连接玩家信号
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("ammo_changed"):
		player.ammo_changed.connect(_on_player_ammo_changed)
	if player.has_signal("died"):
		player.died.connect(on_player_death)

func _on_player_health_changed(current: int, max: int) -> void:
	if hud:
		hud.update_health(current, max)

func _on_player_ammo_changed(current: int, max: int) -> void:
	if hud:
		# 获取备用弹药
		var reserve = -1
		if player_instance:
			var weapon = player_instance.get("current_weapon")
			if weapon and "current_reserve_ammo" in weapon:
				reserve = weapon.current_reserve_ammo
		hud.update_ammo(current, max, reserve)

func get_player() -> Node2D:
	return player_instance

func register_level(level: Node2D) -> void:
	current_level_instance = level

func get_level() -> Node2D:
	return current_level_instance

func restart_game() -> void:
	reset_game()
	game_restarted.emit()
	get_tree().reload_current_scene()

func quit_to_menu() -> void:
	change_state(GameState.MENU)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func start_new_game() -> void:
	# 创建新存档
	var slot = SaveManager.get_first_empty_slot()
	if slot < 0:
		slot = 0
	
	SaveManager.save_to_slot(slot)
	
	# 重置游戏状态
	reset_game()
	game_started.emit()
	
	# 加载第一关
	LevelManager.load_level("level_1")

func continue_game() -> void:
	# 加载最近的存档
	if SaveManager.has_current_save():
		game_started.emit()
		var level_id = SaveManager.current_save_data.get("level_id", "level_1")
		LevelManager.load_level(level_id)

# UI管理
func register_hud(hud_instance: CanvasLayer) -> void:
	hud = hud_instance
	
	# 如果玩家已存在，主动获取弹药状态（解决初始化顺序问题）
	if player_instance:
		var weapon = player_instance.get("current_weapon")
		if weapon:
			var current = weapon.current_ammo_in_mag if "current_ammo_in_mag" in weapon else 0
			var max_val = weapon.magazine_size if "magazine_size" in weapon else 0
			var reserve = weapon.current_reserve_ammo if "current_reserve_ammo" in weapon else -1
			hud.update_ammo(current, max_val, reserve)

func register_pause_menu(menu: Control) -> void:
	pause_menu = menu
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.restart_requested.connect(restart_game)
		pause_menu.quit_to_menu_requested.connect(quit_to_menu)

func register_game_over_screen(screen: Control) -> void:
	game_over_screen = screen
	if game_over_screen:
		game_over_screen.restart_requested.connect(restart_game)
		game_over_screen.quit_to_menu_requested.connect(quit_to_menu)

func _show_menu() -> void:
	_hide_menus()
	get_tree().paused = false

func _show_pause_menu() -> void:
	if pause_menu:
		pause_menu.show_pause_menu()

func _hide_menus() -> void:
	if pause_menu:
		pause_menu.hide_pause_menu()
	if game_over_screen:
		game_over_screen.hide()

func _show_game_over(victory: bool) -> void:
	if game_over_screen:
		if victory:
			game_over_screen.show_victory()
		else:
			game_over_screen.show_defeat()

func _on_resume_requested() -> void:
	is_game_paused = false

# 场景切换
func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func reload_current_scene() -> void:
	get_tree().reload_current_scene()
