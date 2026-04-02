extends "res://src/base/game_system.gd"

# GameManager - 游戏核心管理器
# 负责游戏状态、分数、关卡切换等全局管理

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }
const INPUT_MODE_GAME_ONLY := 0
const INPUT_MODE_UI_ONLY := 1
const INPUT_MODE_GAME_AND_UI := 2

const PAUSE_MENU_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const GAME_OVER_SCENE := preload("res://scenes/ui/game_over.tscn")
const ROGUELIKE_REWARD_SCENE := preload("res://scenes/ui/roguelike_reward_selection.tscn")

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
var roguelike_reward_modal: Control = null
var runtime_ui_layer: CanvasLayer = null

var is_game_paused: bool = false
var _game_and_ui_request_count: int = 0
var _pending_playtime_seconds: float = 0.0
var roguelike_run_active: bool = false
var roguelike_reward_active: bool = false
var roguelike_transition_in_flight: bool = false
var roguelike_level_sequence: Array[String] = ["arena_01", "arena_02"]
var roguelike_level_index: int = 0
var roguelike_selected_blessings: Array[String] = []

const ROGUELIKE_BLESSINGS = {
	"vitality_boost": {"title_key": "blessing.vitality_boost.title", "description_key": "blessing.vitality_boost.description", "stat": "max_health", "value": 20},
	"swift_step": {"title_key": "blessing.swift_step.title", "description_key": "blessing.swift_step.description", "stat": "max_speed", "value": 30.0},
	"dash_tune": {"title_key": "blessing.dash_tune.title", "description_key": "blessing.dash_tune.description", "stat": "dash_cooldown", "value": -0.15}
}

# 测试注入点（默认使用 autoload 节点）
# 仅用于单元测试注入替身，运行时代码不要设置这些字段。
var _enhanced_input_override: Node = null
var _projectile_spawner_override: Node = null
var _level_manager_override: Node = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "game_manager"
	# 不在这里执行初始化，等待 BootSequence 调用

func _process(delta: float) -> void:
	if is_gameplay_active():
		_pending_playtime_seconds += delta

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

	if level_mgr and level_mgr.has_signal("level_loaded"):
		if not level_mgr.level_loaded.is_connected(_on_roguelike_level_loaded):
			level_mgr.level_loaded.connect(_on_roguelike_level_loaded)

	if save_mgr and save_mgr.has_method("set_gameplay_save_state_provider"):
		save_mgr.set_gameplay_save_state_provider(self)
	
	print("[GameManager] 初始化完成")
	_mark_ready()

func _input(event: InputEvent):
	if roguelike_reward_active:
		return

	if not event.is_action_pressed("pause"):
		return

	if current_state == GameState.PLAYING:
		toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if current_state == GameState.PAUSED:
		if game_over_screen and game_over_screen.visible:
			return
		if pause_menu and pause_menu.visible:
			return
		toggle_pause()
		get_viewport().set_input_as_handled()

func change_state(new_state: GameState) -> void:
	if current_state == new_state:
		return
	
	current_state = new_state
	state_changed.emit(new_state)
	
	match new_state:
		GameState.MENU:
			_apply_runtime_state(false, INPUT_MODE_UI_ONLY)
			_show_menu()
		GameState.PLAYING:
			_apply_runtime_state(false, _resolve_playing_input_mode())
			_hide_menus()
		GameState.PAUSED:
			_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
			_show_pause_menu()
		GameState.GAME_OVER:
			_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
			_show_game_over(false)
		GameState.VICTORY:
			_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
			_show_game_over(true)
	
	_sync_state_to_csharp()

func toggle_pause() -> void:
	set_paused(not is_game_paused)

func set_paused(paused: bool, restore_playing_state: bool = true) -> void:
	if paused:
		if current_state == GameState.PLAYING:
			change_state(GameState.PAUSED)
		else:
			_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
	else:
		if restore_playing_state and current_state == GameState.PAUSED:
			change_state(GameState.PLAYING)
		elif current_state == GameState.PLAYING:
			_apply_runtime_state(false, _resolve_playing_input_mode())
		else:
			_apply_runtime_state(false, INPUT_MODE_UI_ONLY)

	_sync_state_to_csharp()

func is_playing() -> bool:
	return current_state == GameState.PLAYING

func is_gameplay_active() -> bool:
	return is_playing()

func consume_pending_playtime_seconds() -> int:
	var whole_seconds := int(floor(_pending_playtime_seconds))
	if whole_seconds <= 0:
		return 0

	_pending_playtime_seconds -= whole_seconds
	return whole_seconds

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

# Roguelike Run Contract
func start_minimal_roguelike_run(start_level_id := "arena_01") -> void:
	roguelike_run_active = true
	_clear_roguelike_reward_gate_state()
	roguelike_level_sequence = ["arena_01", "arena_02"]
	if start_level_id != "" and not roguelike_level_sequence.is_empty():
		roguelike_level_sequence[0] = start_level_id
	roguelike_level_index = 0
	roguelike_selected_blessings.clear()


func reset_minimal_roguelike_run() -> void:
	roguelike_run_active = false
	_clear_roguelike_reward_gate_state()
	roguelike_level_sequence.clear()
	roguelike_level_index = 0
	roguelike_selected_blessings.clear()


func notify_roguelike_room_cleared(level_id: String) -> void:
	if not roguelike_run_active:
		return
	if level_id == "":
		return
	if roguelike_reward_active or roguelike_transition_in_flight:
		return

	var level_manager_node := _get_level_manager_node()
	if level_manager_node and is_instance_valid(level_manager_node) and "current_level_data" in level_manager_node:
		var current_level_data = level_manager_node.current_level_data
		if current_level_data and "level_id" in current_level_data:
			var current_level_id := String(current_level_data.level_id)
			if current_level_id != "" and current_level_id != level_id:
				push_warning(
					"[GameManager] Ignoring stale roguelike room clear for %s; current level is %s"
					% [level_id, current_level_id]
				)
				return
	roguelike_reward_active = true
	_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
	_ensure_roguelike_reward_modal()
	if roguelike_reward_modal:
		var options: Array[Dictionary] = []
		for blessing_id in ["vitality_boost", "swift_step", "dash_tune"]:
			if ROGUELIKE_BLESSINGS.has(blessing_id):
				var blessing_data: Dictionary = ROGUELIKE_BLESSINGS[blessing_id].duplicate(true)
				blessing_data["id"] = blessing_id
				options.append(blessing_data)
		roguelike_reward_modal.show_rewards(options)


func _ensure_roguelike_reward_modal() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	_reset_stale_roguelike_ui_refs(current_scene)
	if roguelike_reward_modal and is_instance_valid(roguelike_reward_modal):
		return

	if runtime_ui_layer and is_instance_valid(runtime_ui_layer):
		if not current_scene.is_ancestor_of(runtime_ui_layer):
			runtime_ui_layer = null

	if runtime_ui_layer == null or not is_instance_valid(runtime_ui_layer):
		var existing_runtime_ui := current_scene.get_node_or_null("RuntimeUI")
		if existing_runtime_ui is CanvasLayer:
			runtime_ui_layer = existing_runtime_ui as CanvasLayer

	if runtime_ui_layer == null or not is_instance_valid(runtime_ui_layer):
		runtime_ui_layer = CanvasLayer.new()
		runtime_ui_layer.name = "RuntimeUI"
		runtime_ui_layer.layer = 100
		runtime_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		current_scene.add_child(runtime_ui_layer)

	var existing_modal := runtime_ui_layer.get_node_or_null("RoguelikeRewardSelection")
	if existing_modal is Control:
		roguelike_reward_modal = existing_modal as Control
	else:
		var reward_instance = ROGUELIKE_REWARD_SCENE.instantiate()
		if reward_instance is Control:
			reward_instance.name = "RoguelikeRewardSelection"
			runtime_ui_layer.add_child(reward_instance)
			roguelike_reward_modal = reward_instance as Control

	if roguelike_reward_modal and roguelike_reward_modal.has_signal("option_selected"):
		if not roguelike_reward_modal.option_selected.is_connected(_on_reward_option_selected):
			roguelike_reward_modal.option_selected.connect(_on_reward_option_selected)


func _on_reward_option_selected(blessing_id: String) -> void:
	if roguelike_transition_in_flight:
		return

	roguelike_transition_in_flight = true
	roguelike_reward_active = false
	roguelike_selected_blessings.append(blessing_id)

	if player_instance and is_instance_valid(player_instance):
		_reapply_roguelike_blessings_to_player(player_instance)

	if roguelike_reward_modal:
		roguelike_reward_modal.visible = false

	set_paused(false)

	var next_level_id := _get_next_roguelike_level_id()
	var level_manager_node := _get_level_manager_node()
	if level_manager_node == null or not level_manager_node.has_method("load_level"):
		push_warning("[GameManager] Roguelike transition failed: LevelManager unavailable")
		_handle_roguelike_transition_load_failure()
		return

	var loaded = level_manager_node.call("load_level", next_level_id)
	if not loaded:
		push_warning("[GameManager] Roguelike transition failed: unable to load level %s" % next_level_id)
		_handle_roguelike_transition_load_failure()


func _handle_roguelike_transition_load_failure() -> void:
	roguelike_transition_in_flight = false
	roguelike_reward_active = true
	_apply_runtime_state(true, INPUT_MODE_UI_ONLY)
	if roguelike_reward_modal and is_instance_valid(roguelike_reward_modal):
		roguelike_reward_modal.visible = true


func _get_next_roguelike_level_id() -> String:
	if roguelike_level_sequence.is_empty():
		roguelike_level_index = 0
		return "arena_01"

	var next_index := roguelike_level_index + 1
	if next_index >= roguelike_level_sequence.size():
		# Loop back to beginning
		roguelike_level_index = 0
		return roguelike_level_sequence[0]

	roguelike_level_index = next_index
	return roguelike_level_sequence[roguelike_level_index]


func _on_roguelike_level_loaded(level_data: LevelData) -> void:
	_clear_roguelike_reward_gate_state()
	if level_data == null:
		return
	if not roguelike_run_active:
		return

	# 玩家由场景/LevelManager 注册，register_player() 会执行 blessing 重应用。


func _clear_roguelike_reward_gate_state() -> void:
	roguelike_reward_active = false
	roguelike_transition_in_flight = false
	if roguelike_reward_modal and is_instance_valid(roguelike_reward_modal):
		roguelike_reward_modal.visible = false
	_reset_stale_roguelike_ui_refs(get_tree().current_scene if get_tree() else null)


func _reset_stale_roguelike_ui_refs(current_scene: Node = null) -> void:
	if current_scene == null and get_tree():
		current_scene = get_tree().current_scene

	if runtime_ui_layer and is_instance_valid(runtime_ui_layer):
		if current_scene == null or not _node_belongs_to_scene(runtime_ui_layer, current_scene):
			runtime_ui_layer = null
	else:
		runtime_ui_layer = null

	if roguelike_reward_modal and is_instance_valid(roguelike_reward_modal):
		if current_scene == null or not _node_belongs_to_scene(roguelike_reward_modal, current_scene):
			roguelike_reward_modal = null
	else:
		roguelike_reward_modal = null


func _node_belongs_to_scene(node: Node, current_scene: Node) -> bool:
	if node == null or current_scene == null:
		return false
	if not is_instance_valid(node) or not is_instance_valid(current_scene):
		return false
	return node == current_scene or current_scene.is_ancestor_of(node)


func _reapply_roguelike_blessings_to_player(player: Node2D) -> void:
	if player == null:
		return

	var missing_required_stats: Array[String] = []
	for stat_name in ["max_health", "max_speed", "dash_cooldown"]:
		if not (stat_name in player):
			missing_required_stats.append(stat_name)

	if not missing_required_stats.is_empty():
		push_warning("[GameManager] 无法重应用 Roguelike 祝福：玩家缺少属性 %s" % [missing_required_stats])
		return

	var has_current_health := "current_health" in player
	if not has_current_health:
		push_warning("[GameManager] Roguelike blessing reapply skipped full heal: player missing current_health")

	if not player.has_meta("roguelike_base_max_health"):
		player.set_meta("roguelike_base_max_health", int(player.get("max_health")))
	if not player.has_meta("roguelike_base_max_speed"):
		player.set_meta("roguelike_base_max_speed", float(player.get("max_speed")))
	if not player.has_meta("roguelike_base_dash_cooldown"):
		player.set_meta("roguelike_base_dash_cooldown", float(player.get("dash_cooldown")))

	var bonus_max_health := 0
	var bonus_max_speed := 0.0
	var bonus_dash_cooldown := 0.0

	for blessing_id in roguelike_selected_blessings:
		if not ROGUELIKE_BLESSINGS.has(blessing_id):
			continue

		var blessing = ROGUELIKE_BLESSINGS[blessing_id]
		var blessing_stat: String = blessing.get("stat", "")
		var blessing_value = blessing.get("value", 0)

		match blessing_stat:
			"max_health":
				bonus_max_health += int(blessing_value)
			"max_speed":
				bonus_max_speed += float(blessing_value)
			"dash_cooldown":
				bonus_dash_cooldown += float(blessing_value)

	player.set("max_health", int(player.get_meta("roguelike_base_max_health")) + bonus_max_health)
	player.set("max_speed", float(player.get_meta("roguelike_base_max_speed")) + bonus_max_speed)
	player.set(
		"dash_cooldown",
		maxf(0.3, float(player.get_meta("roguelike_base_dash_cooldown")) + bonus_dash_cooldown)
	)

	if has_current_health:
		player.set("current_health", int(player.get("max_health")))

func get_difficulty_multiplier() -> float:
	# 根据关卡返回难度倍率
	return 1.0 + (current_level - 1) * 0.1

func register_player(player: Node2D) -> void:
	if player == null:
		return

	if player_instance and player_instance != player and is_instance_valid(player_instance):
		_disconnect_player_signals(player_instance)

	player_instance = player

	# Roguelike 模式下，新玩家实例注册时重应用祝福。
	if roguelike_run_active:
		_reapply_roguelike_blessings_to_player(player)
		if roguelike_transition_in_flight:
			_clear_roguelike_reward_gate_state()
	
	# 连接玩家信号
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("ammo_changed"):
		if not player.ammo_changed.is_connected(_on_player_ammo_changed):
			player.ammo_changed.connect(_on_player_ammo_changed)
	if player.has_signal("died"):
		if not player.died.is_connected(on_player_death):
			player.died.connect(on_player_death)


func _disconnect_player_signals(player: Node2D) -> void:
	if player == null or not is_instance_valid(player):
		return

	if player.has_signal("health_changed"):
		if player.health_changed.is_connected(_on_player_health_changed):
			player.health_changed.disconnect(_on_player_health_changed)
	if player.has_signal("ammo_changed"):
		if player.ammo_changed.is_connected(_on_player_ammo_changed):
			player.ammo_changed.disconnect(_on_player_ammo_changed)
	if player.has_signal("died"):
		if player.died.is_connected(on_player_death):
			player.died.disconnect(on_player_death)

func _on_player_health_changed(current: int, max_val: int) -> void:
	if hud:
		hud.update_health(current, max_val)

func _on_player_ammo_changed(current: int, max_val: int) -> void:
	if hud:
		# 获取备用弹药
		var reserve = -1
		if player_instance:
			var weapon = player_instance.get("current_weapon")
			if weapon and "current_reserve_ammo" in weapon:
				reserve = weapon.current_reserve_ammo
		hud.update_ammo(current, max_val, reserve)

func get_player() -> Node2D:
	return player_instance

func register_level(level: Node2D) -> void:
	current_level_instance = level

func get_level() -> Node2D:
	return current_level_instance

func restart_game() -> void:
	set_paused(false, false)
	_clear_runtime_combat_artifacts()
	reset_game()
	game_restarted.emit()
	reload_current_scene()

func quit_to_menu() -> void:
	set_paused(false, false)
	_clear_runtime_combat_artifacts()
	change_state(GameState.MENU)
	change_scene("res://scenes/ui/main_menu.tscn")

func quit_to_desktop() -> void:
	get_tree().quit()

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
			var max_val = 0
			if "stats" in weapon and weapon.stats:
				max_val = weapon.stats.magazine_size
			var reserve = weapon.current_reserve_ammo if "current_reserve_ammo" in weapon else -1
			hud.update_ammo(current, max_val, reserve)

func register_pause_menu(menu: Control) -> void:
	pause_menu = menu
	if pause_menu:
		if not pause_menu.resume_requested.is_connected(_on_resume_requested):
			pause_menu.resume_requested.connect(_on_resume_requested)
		if not pause_menu.restart_requested.is_connected(restart_game):
			pause_menu.restart_requested.connect(restart_game)
		if not pause_menu.quit_to_menu_requested.is_connected(quit_to_menu):
			pause_menu.quit_to_menu_requested.connect(quit_to_menu)
		if not pause_menu.quit_to_desktop_requested.is_connected(quit_to_desktop):
			pause_menu.quit_to_desktop_requested.connect(quit_to_desktop)

func register_game_over_screen(screen: Control) -> void:
	game_over_screen = screen
	if game_over_screen:
		if game_over_screen.has_signal("restart_requested") and not game_over_screen.restart_requested.is_connected(restart_game):
			game_over_screen.restart_requested.connect(restart_game)
		if game_over_screen.has_signal("quit_to_menu_requested") and not game_over_screen.quit_to_menu_requested.is_connected(quit_to_menu):
			game_over_screen.quit_to_menu_requested.connect(quit_to_menu)
		if game_over_screen.has_signal("continue_requested") and not game_over_screen.continue_requested.is_connected(_on_continue_requested):
			game_over_screen.continue_requested.connect(_on_continue_requested)

func _show_menu() -> void:
	_hide_menus()

func _show_pause_menu() -> void:
	_ensure_pause_menu()
	if pause_menu:
		pause_menu.show_pause_menu()


func _ensure_pause_menu() -> void:
	if pause_menu and is_instance_valid(pause_menu):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("[GameManager] 无法创建暂停菜单：当前场景为空")
		return

	if runtime_ui_layer == null or not is_instance_valid(runtime_ui_layer):
		runtime_ui_layer = CanvasLayer.new()
		runtime_ui_layer.name = "RuntimeUI"
		runtime_ui_layer.layer = 100
		runtime_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		current_scene.add_child(runtime_ui_layer)

	var pause_menu_instance = PAUSE_MENU_SCENE.instantiate()
	if pause_menu_instance is Control:
		runtime_ui_layer.add_child(pause_menu_instance)
		register_pause_menu(pause_menu_instance as Control)
	else:
		push_warning("[GameManager] 无法创建暂停菜单：场景根节点不是 Control")

func _hide_menus() -> void:
	if pause_menu:
		pause_menu.hide_pause_menu()
	if game_over_screen:
		game_over_screen.hide()

func _show_game_over(victory: bool) -> void:
	_ensure_game_over_screen()
	if game_over_screen:
		if victory:
			game_over_screen.show_victory()
		else:
			game_over_screen.show_defeat()

func _on_resume_requested() -> void:
	set_paused(false)


func _on_continue_requested() -> void:
	set_paused(false, false)
	_clear_runtime_combat_artifacts()

	var next_level_id := "level_%d" % current_level
	var has_next_level_scene := ResourceLoader.exists("res://scenes/levels/%s.tscn" % next_level_id)
	var has_next_level_config := ResourceLoader.exists("res://config/levels/%s.tres" % next_level_id)

	if (has_next_level_scene or has_next_level_config) and LevelManager:
		var loaded := LevelManager.load_level(next_level_id)
		if loaded:
			return

	quit_to_menu()


func _apply_runtime_state(paused: bool, input_mode: int) -> void:
	is_game_paused = paused
	get_tree().paused = paused
	_set_current_level_processing(paused)
	_set_input_mode(input_mode)


func _set_input_mode(mode: int) -> void:
	var enhanced_input_node := _get_enhanced_input_node()
	if enhanced_input_node == null:
		return

	if not enhanced_input_node.has_method("set_input_mode"):
		return

	enhanced_input_node.call("set_input_mode", mode)


func _resolve_playing_input_mode() -> int:
	if _game_and_ui_request_count > 0:
		return INPUT_MODE_GAME_AND_UI
	return INPUT_MODE_GAME_ONLY


func request_game_and_ui_input(_owner: String = "") -> void:
	_game_and_ui_request_count += 1
	if current_state == GameState.PLAYING and not is_game_paused:
		_set_input_mode(_resolve_playing_input_mode())


func release_game_and_ui_input(_owner: String = "") -> void:
	_game_and_ui_request_count = maxi(0, _game_and_ui_request_count - 1)
	if current_state == GameState.PLAYING and not is_game_paused:
		_set_input_mode(_resolve_playing_input_mode())


func _clear_runtime_combat_artifacts() -> void:
	var projectile_spawner_node := _get_projectile_spawner_node()
	if projectile_spawner_node and projectile_spawner_node.has_method("clear_pools"):
		projectile_spawner_node.call("clear_pools")


func _ensure_game_over_screen() -> void:
	if game_over_screen and is_instance_valid(game_over_screen):
		return

	var current_scene := get_tree().current_scene
	if current_scene == null:
		push_warning("[GameManager] 无法创建结算界面：当前场景为空")
		return

	var existing_game_over := current_scene.get_node_or_null("RuntimeUI/GameOver")
	if existing_game_over is Control:
		register_game_over_screen(existing_game_over as Control)
		return

	if runtime_ui_layer and is_instance_valid(runtime_ui_layer):
		if not current_scene.is_ancestor_of(runtime_ui_layer):
			runtime_ui_layer = null

	if runtime_ui_layer == null or not is_instance_valid(runtime_ui_layer):
		var existing_runtime_ui := current_scene.get_node_or_null("RuntimeUI")
		if existing_runtime_ui is CanvasLayer:
			runtime_ui_layer = existing_runtime_ui as CanvasLayer

	if runtime_ui_layer == null or not is_instance_valid(runtime_ui_layer):
		runtime_ui_layer = CanvasLayer.new()
		runtime_ui_layer.name = "RuntimeUI"
		runtime_ui_layer.layer = 100
		runtime_ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		current_scene.add_child(runtime_ui_layer)

	var game_over_instance = GAME_OVER_SCENE.instantiate()
	if game_over_instance is Control:
		game_over_instance.name = "GameOver"
		runtime_ui_layer.add_child(game_over_instance)
		register_game_over_screen(game_over_instance as Control)
	else:
		push_warning("[GameManager] 无法创建结算界面：场景根节点不是 Control")


func _set_current_level_processing(paused: bool) -> void:
	var level_manager_node := _get_level_manager_node()
	if level_manager_node == null:
		return

	var level_node = level_manager_node.get("current_level")
	if level_node == null or not is_instance_valid(level_node):
		return

	if paused:
		(level_node as Node).process_mode = Node.PROCESS_MODE_PAUSABLE
	else:
		(level_node as Node).process_mode = Node.PROCESS_MODE_INHERIT


func _get_enhanced_input_node() -> Node:
	if _enhanced_input_override and is_instance_valid(_enhanced_input_override):
		return _enhanced_input_override
	return get_node_or_null("/root/EnhancedInput")


func _get_projectile_spawner_node() -> Node:
	if _projectile_spawner_override and is_instance_valid(_projectile_spawner_override):
		return _projectile_spawner_override
	return get_node_or_null("/root/ProjectileSpawner")


func _get_level_manager_node() -> Node:
	if _level_manager_override and is_instance_valid(_level_manager_override):
		return _level_manager_override
	return get_node_or_null("/root/LevelManager")

# 场景切换
func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func reload_current_scene() -> void:
	get_tree().reload_current_scene()

# C# 状态同步
func _sync_state_to_csharp() -> void:
	var gsm = get_node_or_null("/root/GameStateManager")
	if gsm:
		var csharp_state = _map_state_to_csharp(current_state)
		gsm.call("SetStateWithoutPause", csharp_state)

func _map_state_to_csharp(gd_state: GameState) -> int:
	match gd_state:
		GameState.MENU: return 1
		GameState.PLAYING: return 3
		GameState.PAUSED: return 4
		GameState.GAME_OVER: return 5
		GameState.VICTORY: return 6
		_: return 0
