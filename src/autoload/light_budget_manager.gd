extends "res://src/base/game_system.gd"

# LightBudgetManager - 光效预算管理器
# 管理游戏中的光源数量预算，避免超过 Godot 4 的 16 光源硬限制
# 预留 1 个系统光源，实际可用 15 个

# 优先级枚举
enum Priority {
	HIGH = 1,    # 手电筒 - 最高优先级
	MEDIUM = 2,  # 枪口闪光 - 中等优先级
	LOW = 3      # 曳光弹 - 低优先级，可排队等待
}

# 最大光源数量 (Godot 4 有 16 光源硬限制，预留 1 个给系统)
const MAX_LIGHTS: int = 15

# 活跃光源数据结构
class LightSource:
	var priority: int
	var source_name: String

	func _init(p_priority: int, p_name: String = "") -> void:
		priority = p_priority
		source_name = p_name

# 活跃光源列表
var _active_lights: Array[LightSource] = []

# 等待队列 (仅存储低优先级光源)
var _light_queue: Array[LightSource] = []

# 全局光效开关 (可由设置面板控制)
var _lighting_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "light_budget_manager"
	_mark_ready()

# 请求光源
# @param priority: 优先级 (1=高, 2=中, 3=低)
# @return: 是否成功获取光源槽位
func request_light(priority: int) -> bool:
	# 检查全局光效开关
	if not _lighting_enabled:
		return false

	# 验证优先级范围
	if priority < Priority.HIGH or priority > Priority.LOW:
		push_warning("[LightBudgetManager] 无效优先级: %d" % priority)
		return false

	# 如果有空槽位，直接分配
	if _active_lights.size() < MAX_LIGHTS:
		var light := LightSource.new(priority, _get_source_name(priority))
		_active_lights.append(light)
		_active_lights.sort_custom(_compare_priority)

		return true

	# 槽位已满，检查是否可以替换低优先级光源
	if priority < _get_lowest_active_priority():
		# 有低优先级光源在队列中等待，优先替换
		if not _light_queue.is_empty():
			_light_queue.pop_front()

		# 移除最低优先级活跃光源
		_remove_lowest_priority_light()

		# 重新尝试分配
		var light := LightSource.new(priority, _get_source_name(priority))
		_active_lights.append(light)
		_active_lights.sort_custom(_compare_priority)

		return true

	# 优先级不够高，加入队列等待
	if priority == Priority.LOW:
		var queued_light := LightSource.new(priority, _get_source_name(priority))
		_light_queue.append(queued_light)


	return false

# 释放光源
# 释放一个活跃光源（通常是最低优先级的）
func release_light() -> void:
	if _active_lights.is_empty():
		return

	# 移除最低优先级的光源（排序后数组末尾）
	var removed: LightSource = _active_lights.pop_back()

	# 如果队列中有等待的光源，尝试激活一个
	_process_queue()

# 处理等待队列
func _process_queue() -> void:
	if _light_queue.is_empty():
		return

	if _active_lights.size() < MAX_LIGHTS:
		var next_light: LightSource = _light_queue.pop_front()
		_active_lights.append(next_light)
		_active_lights.sort_custom(_compare_priority)

# 获取活跃光源数量
func get_active_count() -> int:
	return _active_lights.size()

# 获取可用槽位数量
func get_available_slots() -> int:
	return maxi(MAX_LIGHTS - _active_lights.size(), 0)

# 获取当前最低活跃优先级
func _get_lowest_active_priority() -> int:
	if _active_lights.is_empty():
		return Priority.LOW + 1
	return _active_lights[-1].priority  # 排序后最后一个是最低优先级

# 移除最低优先级光源
func _remove_lowest_priority_light() -> void:
	if _active_lights.is_empty():
		return
	_active_lights.pop_back()  # 移除最低优先级

# 优先级比较函数 (用于排序)
func _compare_priority(a: LightSource, b: LightSource) -> bool:
	return a.priority < b.priority  # 优先级数字越小越靠前

# 获取光源来源名称
func _get_source_name(priority: int) -> String:
	match priority:
		Priority.HIGH:
			return "Flashlight"
		Priority.MEDIUM:
			return "MuzzleFlash"
		Priority.LOW:
			return "TracerRound"
		_:
			return "Unknown"

# 获取调试信息
func get_debug_info() -> Dictionary:
	return {
		"max_lights": MAX_LIGHTS,
		"active_count": _active_lights.size(),
		"available_slots": get_available_slots(),
		"queue_length": _light_queue.size(),
		"active_lights": _get_active_lights_info()
	}

func _get_active_lights_info() -> Array:
	var info: Array = []
	for light in _active_lights:
		info.append({"priority": light.priority, "source": light.source_name})
	return info

# 清除所有光源（用于关卡切换）
func clear_all_lights() -> void:
	_active_lights.clear()
	_light_queue.clear()


# 设置全局光效开关
func set_lighting_enabled(enabled: bool) -> void:
	_lighting_enabled = enabled


# 获取全局光效开关状态
func is_lighting_enabled() -> bool:
	return _lighting_enabled
