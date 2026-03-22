extends Node

# Main - 主游戏场景控制器
# 负责初始化游戏状态和启动关卡

func _ready() -> void:
	# 等待所有节点初始化完成
	await get_tree().process_frame
	
	# 手动初始化关卡（因为场景是直接加载的，没经过LevelManager.load_level）
	_initialize_level()

func _initialize_level() -> void:
	# 设置LevelManager当前关卡
	LevelManager.current_level = get_tree().current_scene
	
	# 查找玩家
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		LevelManager.player = players[0]
	
	# 设置状态为READY
	LevelManager.current_state = LevelManager.LevelState.READY
	
	# 启动关卡
	LevelManager.start_level()
