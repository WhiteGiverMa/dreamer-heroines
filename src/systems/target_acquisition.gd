class_name TargetAcquisition
extends Node

## TargetAcquisition - 目标选择与锁定系统
## 定义目标选择+锁定逻辑的核心接口
## 具体算法在后续实现（Task 5）

signal target_locked(target: Node2D)
signal target_unlocked()

var _locked_target: Node2D = null
var skill_override_target: Node2D = null


## 已锁定目标属性
## 设置时自动发射对应信号
var locked_target: Node2D:
	get:
		return _locked_target
	set(value):
		if _locked_target != value:
			if value == null:
				target_unlocked.emit()
			else:
				target_locked.emit(value)
		_locked_target = value


## 获取当前锁定目标
## @return: 当前锁定的 Node2D，无则返回 null
func get_locked_target() -> Node2D:
	return _locked_target


## 执行目标获取
## 按夹角+距离加权选择最优目标
## @param origin: 发起位置
## @param direction: 方向向量
## @param max_angle: 最大偏转角（度数，内部转换为弧度）
## @return: 目标节点，无则返回 null
func acquire_target(origin: Vector2, direction: Vector2, max_angle: float) -> Node2D:
	var enemy_manager := get_node_or_null("/root/EnemyManager")
	if not enemy_manager:
		clear_lock()
		return null

	var enemies := enemy_manager.get_active_enemies()
	if enemies.is_empty():
		clear_lock()
		return null

	var normalized_dir := direction.normalized()
	var max_angle_rad := deg_to_rad(max_angle)
	var best_target: Node2D = null
	var best_score: float = INF

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue

		# 排除死亡敌人
		if enemy is EnemyBase and enemy.current_state == EnemyBase.State.DEAD:
			continue

		var to_enemy: Vector2 = enemy.global_position - origin
		var distance: float = to_enemy.length()
		if is_zero_approx(distance):
			# 敌人在正中心，夹角为 0
			best_target = enemy
			break

		var angle: float = abs(normalized_dir.angle_to(to_enemy.normalized()))
		if angle > max_angle_rad:
			continue

		# 加权评分：角度权重 0.7，距离权重 0.3（归一化到 0-1）
		var score: float = 0.7 * angle + 0.3 * (distance / 1000.0)

		if score < best_score:
			best_score = score
			best_target = enemy

	if best_target:
		locked_target = best_target
	else:
		clear_lock()

	return best_target


## 更新锁定目标（每帧调用）
func update_lock(origin: Vector2, direction: Vector2, max_angle: float) -> void:
	acquire_target(origin, direction, max_angle)


## 清除当前锁定
func clear_lock() -> void:
	locked_target = null