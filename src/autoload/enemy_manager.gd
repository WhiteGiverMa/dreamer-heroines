extends "res://src/base/game_system.gd"

# EnemyManager - 全局敌人管理器
# 集中管理所有敌人的生命周期和实时计数
# 解决 HUD 敌人计数延迟更新的问题

# ============================================
# Signals
# ============================================

## 敌人注册时发射
signal enemy_registered(enemy: Node)

## 敌人注销时发射（敌人死亡或被销毁）
signal enemy_unregistered(enemy: Node)

## 敌人数量变化时发射（实时计数）
signal enemy_count_changed(count: int)

## 敌人死亡时发射（敌人状态变为 DEAD）
signal enemy_died(enemy: Node, enemy_type: String)

## 所有敌人被清除时发射
signal all_enemies_cleared

# ============================================
# Private Fields
# ============================================

# 活跃敌人字典 {instance_id: enemy_node}
var _active_enemies: Dictionary = {}

# 敌人类型计数 {enemy_type: count}
var _enemy_type_counts: Dictionary = {}

# 总计击杀数
var _total_kills: int = 0

# 本波次击杀数（由波次系统重置）
var _wave_kills: int = 0

# ============================================
# Lifecycle
# ============================================

func initialize() -> void:
	"""初始化敌人管理器"""
	print("[EnemyManager] Initialized")
	_mark_ready()

# ============================================
# Public API - Enemy Registration
# ============================================

## 注册敌人（由 EnemyBase._ready() 调用）
func register_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		push_warning("[EnemyManager] Attempted to register invalid enemy")
		return

	var enemy_id: int = enemy.get_instance_id()
	if _active_enemies.has(enemy_id):
		return  # 已注册，忽略

	_active_enemies[enemy_id] = enemy

	# 统计敌人类型
	var enemy_type := _get_enemy_type(enemy)
	if not _enemy_type_counts.has(enemy_type):
		_enemy_type_counts[enemy_type] = 0
	_enemy_type_counts[enemy_type] += 1

	# 连接死亡信号
	if enemy.has_signal("died"):
		if not enemy.died.is_connected(_on_enemy_died.bind(enemy)):
			enemy.died.connect(_on_enemy_died.bind(enemy), CONNECT_ONE_SHOT)

	# 连接离开场景树信号（确保注销）
	if not enemy.tree_exiting.is_connected(_on_enemy_tree_exiting.bind(enemy_id)):
		enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy_id), CONNECT_ONE_SHOT)

	var current_count := _active_enemies.size()
	enemy_registered.emit(enemy)
	enemy_count_changed.emit(current_count)

	print("[EnemyManager] Enemy registered: %s (ID: %d, Total: %d)" % [enemy_type, enemy_id, current_count])


## 注销敌人（由 EnemyBase._die() 调用，或在节点离开树时自动调用）
func unregister_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return

	var enemy_id: int = enemy.get_instance_id()
	if not _active_enemies.has(enemy_id):
		return  # 未注册或已注销

	_active_enemies.erase(enemy_id)

	# 减少类型计数
	var enemy_type := _get_enemy_type(enemy)
	if _enemy_type_counts.has(enemy_type):
		_enemy_type_counts[enemy_type] -= 1
		if _enemy_type_counts[enemy_type] <= 0:
			_enemy_type_counts.erase(enemy_type)

	var current_count := _active_enemies.size()
	enemy_unregistered.emit(enemy)
	enemy_count_changed.emit(current_count)

	print("[EnemyManager] Enemy unregistered: %s (ID: %d, Remaining: %d)" % [enemy_type, enemy_id, current_count])


# ============================================
# Public API - Queries
# ============================================

## 获取当前活跃敌人数量
func get_active_enemy_count() -> int:
	return _active_enemies.size()


## 获取特定类型敌人的数量
func get_enemy_count_by_type(enemy_type: String) -> int:
	return _enemy_type_counts.get(enemy_type, 0)


## 获取所有活跃敌人
func get_active_enemies() -> Array[Node]:
	var enemies: Array[Node] = []
	enemies.assign(_active_enemies.values())
	return enemies


## 获取总击杀数
func get_total_kills() -> int:
	return _total_kills


## 获取本波次击杀数
func get_wave_kills() -> int:
	return _wave_kills


# ============================================
# Public API - Operations
# ============================================

## 击杀所有活跃敌人（开发者命令用）
func kill_all_enemies() -> int:
	var enemies_to_kill := get_active_enemies()
	var kill_count := 0

	for enemy in enemies_to_kill:
		if enemy.has_method("die"):
			enemy.die()
			kill_count += 1

	print("[EnemyManager] Kill all executed: %d enemies" % kill_count)
	return kill_count


## 清除所有敌人追踪（波次结束或关卡切换时调用）
func clear_all_enemies() -> void:
	var had_enemies := not _active_enemies.is_empty()
	_active_enemies.clear()
	_enemy_type_counts.clear()

	if had_enemies:
		enemy_count_changed.emit(0)
		all_enemies_cleared.emit()
		print("[EnemyManager] All enemies cleared")


## 重置波次击杀计数
func reset_wave_kills() -> void:
	_wave_kills = 0


## 增加击杀计数（由敌人死亡时调用）
func add_kill() -> void:
	_total_kills += 1
	_wave_kills += 1


# ============================================
# Private Methods
# ============================================

func _on_enemy_died(enemy: Node) -> void:
	"""敌人死亡回调（敌人状态变为 DEAD 时）"""
	if not is_instance_valid(enemy):
		return

	var enemy_type := _get_enemy_type(enemy)
	add_kill()
	enemy_died.emit(enemy, enemy_type)

	# 注意：不在这里注销敌人，等待 tree_exiting 确保计数准确
	print("[EnemyManager] Enemy died: %s (Wave kills: %d, Total kills: %d)" % [enemy_type, _wave_kills, _total_kills])


func _on_enemy_tree_exiting(enemy_id: int) -> void:
	"""敌人离开场景树时注销"""
	if not _active_enemies.has(enemy_id):
		return

	var enemy: Node = _active_enemies[enemy_id]
	unregister_enemy(enemy)


func _get_enemy_type(enemy: Node) -> String:
	"""获取敌人类型标识"""
	if enemy is EnemyBase:
		return enemy.get_class_name() if enemy.has_method("get_class_name") else enemy.get_script().resource_path.get_file().get_basename()
	return enemy.get_class()


# ============================================
# Debug API
# ============================================

## 打印当前状态（调试用）
func print_status() -> void:
	print("[EnemyManager] Status:")
	print("  Active enemies: %d" % get_active_enemy_count())
	print("  Wave kills: %d" % _wave_kills)
	print("  Total kills: %d" % _total_kills)
	print("  Enemy types: %s" % str(_enemy_type_counts))
