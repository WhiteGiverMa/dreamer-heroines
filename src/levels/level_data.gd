class_name LevelData
extends Resource

# LevelData - 关卡数据配置
# 存储关卡的静态配置数据

enum ObjectiveType {
	ELIMINATE_ALL, SURVIVE_TIME, REACH_LOCATION, DEFEND_OBJECT, COLLECT_ITEMS, BOSS_FIGHT  # 消灭所有敌人  # 存活一定时间  # 到达指定地点  # 保护目标  # 收集物品  # Boss战
}


# 目标数据
class ObjectiveData:
	extends Resource
	var objective_type: ObjectiveType
	var target_count: int = 0
	var target_id: String = ""
	var description: String = ""
	var is_completed: bool = false


# 敌人生成组
class EnemySpawnGroup:
	extends Resource
	var group_id: String = ""
	var enemy_type: String = ""
	var spawn_count: int = 1
	var spawn_positions: Array[Vector2] = []
	var spawn_delay: float = 0.0
	var is_boss: bool = false


# 检查点数据
class CheckpointData:
	extends Resource
	var checkpoint_id: String = ""
	var position: Vector2 = Vector2.ZERO
	var is_unlocked: bool = false
	var unlock_condition: String = ""  # 解锁条件描述


@export_group("Level Info")
@export var level_id: String = ""
@export var level_name: String = "未命名关卡"
@export var level_description: String = ""
@export var level_index: int = 0
@export var is_unlocked: bool = true
@export var is_completed: bool = false

@export_group("Gameplay Settings")
@export var time_limit: float = 0.0  # 0表示无时间限制
@export var max_lives: int = 3
@export var starting_health: int = 100
@export var starting_ammo: Dictionary = {}  # weapon_id: ammo_count

@export_group("Objectives")
@export var primary_objective: ObjectiveType = ObjectiveType.ELIMINATE_ALL
@export var secondary_objectives: Array[ObjectiveData] = []

@export_group("Rewards")
@export var completion_exp: int = 100
@export var completion_gold: int = 50
@export var unlocks_on_complete: Array[String] = []  # 完成后解锁的关卡ID

@export_group("Spawn Settings")
@export var player_spawn_position: Vector2 = Vector2.ZERO
@export var enemy_spawn_groups: Array[EnemySpawnGroup] = []
@export var checkpoints: Array[CheckpointData] = []


func _init() -> void:
	resource_name = "LevelData"


func get_objective_description() -> String:
	match primary_objective:
		ObjectiveType.ELIMINATE_ALL:
			return "消灭所有敌人"
		ObjectiveType.SURVIVE_TIME:
			return "存活 %d 秒" % int(time_limit)
		ObjectiveType.REACH_LOCATION:
			return "到达目标地点"
		ObjectiveType.DEFEND_OBJECT:
			return "保护目标"
		ObjectiveType.COLLECT_ITEMS:
			return "收集物品"
		ObjectiveType.BOSS_FIGHT:
			return "击败Boss"
		_:
			return "完成目标"


func get_formatted_time_limit() -> String:
	if time_limit <= 0:
		return "无限制"
	@warning_ignore("integer_division")
	var minutes := int(time_limit) / 60
	var seconds := int(time_limit) % 60
	return "%02d:%02d" % [minutes, seconds]


func create_default_checkpoints() -> void:
	checkpoints.clear()
	var cp = CheckpointData.new()
	cp.checkpoint_id = "start"
	cp.position = player_spawn_position
	cp.is_unlocked = true
	checkpoints.append(cp)


func get_starting_checkpoint() -> CheckpointData:
	for cp in checkpoints:
		if cp.is_unlocked:
			return cp
	return null


func unlock_checkpoint(checkpoint_id: String) -> bool:
	for cp in checkpoints:
		if cp.checkpoint_id == checkpoint_id and not cp.is_unlocked:
			cp.is_unlocked = true
			return true
	return false
