extends Node

# Main - 主游戏场景控制器
# 负责初始化游戏状态和启动关卡


func _ready() -> void:
	# 等待所有节点初始化完成
	await get_tree().process_frame

	# 协程恢复时节点可能已因场景切换退出树（例如直跑 main.tscn 时 BootSequence 切场景）
	if not is_inside_tree():
		return

	# 手动初始化关卡（因为场景是直接加载的，没经过LevelManager.load_level）
	_initialize_level()


func _initialize_level() -> void:
	if not is_inside_tree():
		return

	var tree := get_tree()
	if tree == null:
		return

	# 设置LevelManager当前关卡（兼容 --scene 直跑时 current_scene 可能为空的情况）
	LevelManager.current_level = _resolve_level_root()

	# 查找玩家
	var players = tree.get_nodes_in_group("player")
	if players.size() > 0:
		LevelManager.player = players[0]

	# 设置状态为READY
	LevelManager.current_state = LevelManager.LevelState.READY

	# 启动关卡
	LevelManager.start_level()


func _resolve_level_root() -> Node:
	# main.gd 挂在 main.tscn 根节点，使用 self 可同时兼容
	# 1) 正常 change_scene_to_file 进入
	# 2) --scene 直跑（current_scene 可能暂时为空）
	return self
