extends "res://src/base/game_system.gd"

## EnhancedInput - G.U.I.D.E 输入包装器
## 提供简洁的 API 供游戏代码使用，支持上下文管理和瞄准方向

#region Singleton
static var instance: EnhancedInput
#endregion

#region 瞄准方向 (保留自 InputManager)
var aim_direction: Vector2 = Vector2.RIGHT
var mouse_world_position: Vector2 = Vector2.ZERO

# 跟踪动作边沿状态（按 tick 缓存，避免多调用方消费同一边沿）
var _previous_states: Dictionary = {}
var _edge_cache: Dictionary = {}
#endregion


func _process(_delta: float) -> void:
	_update_aim_direction()


func _update_aim_direction() -> void:
	# 鼠标瞄准 - 基于玩家位置计算方向
	if get_viewport():
		var player := _get_player()
		if player:
			mouse_world_position = get_viewport().get_camera_2d().get_global_mouse_position()
			var aim_origin := player.global_position
			if player.has_method("get_weapon_aim_origin"):
				aim_origin = player.get_weapon_aim_origin()

			var aim_vector := mouse_world_position - aim_origin
			if aim_vector.length_squared() > 0.0001:
				aim_direction = aim_vector.normalized()
			else:
				aim_direction = Vector2.RIGHT
		else:
			aim_direction = Vector2.RIGHT


func _get_tick_key() -> String:
	return "%d:%d" % [Engine.get_process_frames(), Engine.get_physics_frames()]


func _evaluate_action_edge(action: GUIDEAction) -> Dictionary:
	var action_id: int = action.get_instance_id()
	var tick_key: String = _get_tick_key()
	var cached = _edge_cache.get(action_id, null)
	if cached != null and cached.get("tick", "") == tick_key:
		return cached

	# 使用 value_bool 检测按下状态（TRIGGERED 或 ONGOING 都为 true）
	var is_currently_pressed: bool = action.value_bool
	var was_previously_pressed: bool = _previous_states.get(action_id, false)
	var result := {
		"tick": tick_key,
		"just_pressed": is_currently_pressed and not was_previously_pressed,
		"just_released": (not is_currently_pressed) and was_previously_pressed,
	}

	_edge_cache[action_id] = result
	_previous_states[action_id] = is_currently_pressed
	return result


func _get_player() -> Node2D:
	var tree := get_tree()
	if tree:
		var players := tree.get_nodes_in_group("player")
		if players.size() > 0:
			return players[0] as Node2D
	return null


## 获取当前瞄准方向
func get_aim_direction() -> Vector2:
	return aim_direction


## 获取鼠标世界坐标
func get_mouse_world_position() -> Vector2:
	return mouse_world_position
#endregion

#region 上下文管理
## 游戏玩法输入上下文资源
@export var gameplay_context: GUIDEMappingContext

## UI 输入上下文资源
@export var ui_context: GUIDEMappingContext

enum InputMode {
	GAME_ONLY,
	UI_ONLY,
	GAME_AND_UI
}

## 上下文启用状态
var _gameplay_context_enabled: bool = false
var _ui_context_enabled: bool = false
var _current_input_mode: InputMode = InputMode.GAME_ONLY


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "enhanced_input"
	# 不在这里执行初始化，等待 BootSequence 调用


func initialize() -> void:
	print("[EnhancedInput] 开始初始化...")
	# GUIDE 已作为 autoload 加载，检查可用性
	var guide = get_node_or_null("/root/GUIDE")
	if guide == null:
		push_error("[EnhancedInput] GUIDE 未就绪")
		return
	_initialize_contexts()
	print("[EnhancedInput] 初始化完成")
	_mark_ready()


func _initialize_contexts() -> void:
	# 尝试加载默认游戏玩法上下文
	if gameplay_context == null:
		gameplay_context = load("res://config/input/contexts/gameplay_context.tres") as GUIDEMappingContext
		if gameplay_context == null:
			push_error("EnhancedInput: Failed to load gameplay_context.tres")
			return

	# 尝试加载 UI 上下文
	if ui_context == null:
		ui_context = load("res://config/input/contexts/ui_context.tres") as GUIDEMappingContext
		if ui_context == null:
			push_error("EnhancedInput: Failed to load ui_context.tres")
			return
	
	# 默认进入 GAME_ONLY（与历史行为一致）
	set_input_mode(InputMode.GAME_ONLY)


func set_input_mode(mode: InputMode) -> void:
	if gameplay_context == null or ui_context == null:
		push_error("EnhancedInput: Context not ready, cannot set input mode")
		return

	if _current_input_mode == mode and _is_mode_applied(mode):
		return

	# 先清空上下文，再按模式启用，避免残留
	GUIDE.disable_mapping_context(gameplay_context)
	GUIDE.disable_mapping_context(ui_context)
	_gameplay_context_enabled = false
	_ui_context_enabled = false

	match mode:
		InputMode.GAME_ONLY:
			GUIDE.enable_mapping_context(gameplay_context, false, 10)
			_gameplay_context_enabled = true
		InputMode.UI_ONLY:
			GUIDE.enable_mapping_context(ui_context, false, 0)
			_ui_context_enabled = true
		InputMode.GAME_AND_UI:
			GUIDE.enable_mapping_context(ui_context, false, 0)
			GUIDE.enable_mapping_context(gameplay_context, false, 10)
			_ui_context_enabled = true
			_gameplay_context_enabled = true

	_current_input_mode = mode
	print("[EnhancedInput] Input mode set to: %s" % _input_mode_to_string(mode))


func get_input_mode() -> InputMode:
	return _current_input_mode


func _is_mode_applied(mode: InputMode) -> bool:
	match mode:
		InputMode.GAME_ONLY:
			return _gameplay_context_enabled and not _ui_context_enabled
		InputMode.UI_ONLY:
			return _ui_context_enabled and not _gameplay_context_enabled
		InputMode.GAME_AND_UI:
			return _ui_context_enabled and _gameplay_context_enabled
		_:
			return false


func _input_mode_to_string(mode: InputMode) -> String:
	match mode:
		InputMode.GAME_ONLY:
			return "GAME_ONLY"
		InputMode.UI_ONLY:
			return "UI_ONLY"
		InputMode.GAME_AND_UI:
			return "GAME_AND_UI"
		_:
			return "UNKNOWN"


## 启用游戏玩法上下文
func enable_gameplay_context() -> void:
	if _ui_context_enabled:
		set_input_mode(InputMode.GAME_AND_UI)
		return

	set_input_mode(InputMode.GAME_ONLY)


## 禁用游戏玩法上下文
func disable_gameplay_context() -> void:
	if _ui_context_enabled:
		set_input_mode(InputMode.UI_ONLY)
		return

	if gameplay_context == null:
		return

	GUIDE.disable_mapping_context(gameplay_context)
	_gameplay_context_enabled = false
	print("EnhancedInput: Gameplay context disabled")


## 检查游戏玩法上下文是否启用
func is_gameplay_context_enabled() -> bool:
	return _gameplay_context_enabled


func enable_ui_context() -> void:
	if _gameplay_context_enabled:
		set_input_mode(InputMode.GAME_AND_UI)
		return

	set_input_mode(InputMode.UI_ONLY)


func disable_ui_context() -> void:
	if _gameplay_context_enabled:
		set_input_mode(InputMode.GAME_ONLY)
		return

	if ui_context == null:
		return

	GUIDE.disable_mapping_context(ui_context)
	_ui_context_enabled = false
	print("EnhancedInput: UI context disabled")


func is_ui_context_enabled() -> bool:
	return _ui_context_enabled
#endregion

#region 输入查询 (G.U.I.D.E 包装)
## 检查动作是否正在按下
## 使用 value_bool，在 TRIGGERED 或 ONGOING 状态都返回 true
func is_action_pressed(action: GUIDEAction) -> bool:
	if action == null:
		return false
	return action.value_bool


## 检查动作是否刚按下
## 正确实现：检查当前帧是 TRIGGERED 且上一帧不是 TRIGGERED
func is_action_just_pressed(action: GUIDEAction) -> bool:
	if action == null:
		return false
	return _evaluate_action_edge(action).get("just_pressed", false)


## 检查动作是否刚释放
## 正确实现：检查当前帧是 COMPLETED 且上一帧是 TRIGGERED
func is_action_just_released(action: GUIDEAction) -> bool:
	if action == null:
		return false
	return _evaluate_action_edge(action).get("just_released", false)


## 获取动作强度 (1D)
## 包装 GUIDEAction.value_axis_1d
func get_action_strength(action: GUIDEAction) -> float:
	if action == null:
		return 0.0
	return action.value_axis_1d


## 获取 2D 向量输入
## 组合四个方向的 GUIDEAction
func get_vector(
	negative_x: GUIDEAction,
	positive_x: GUIDEAction,
	negative_y: GUIDEAction,
	positive_y: GUIDEAction
) -> Vector2:
	var x := 0.0
	var y := 0.0
	
	if negative_x != null:
		x -= negative_x.value_axis_1d
	if positive_x != null:
		x += positive_x.value_axis_1d
	if negative_y != null:
		y -= negative_y.value_axis_1d
	if positive_y != null:
		y += positive_y.value_axis_1d
	
	return Vector2(x, y).limit_length(1.0)


## 获取 2D 轴输入 (单个 GUIDEAction)
## 用于读取 action_value_type = AXIS_2D 的动作
func get_axis_2d(action: GUIDEAction) -> Vector2:
	if action == null:
		return Vector2.ZERO
	return action.value_axis_2d
#endregion
