extends "res://src/base/game_system.gd"

# 预加载 WeaponStats 类型（autoload 加载顺序问题）
const WeaponStats = preload("res://src/weapons/weapon_stats.gd")

# ProjectileSpawner - 投射物生成器
# 统一管理游戏中所有投射物的创建、缓存和回收
# 使用对象池模式优化性能，避免频繁创建/销毁

# 投射物场景路径
const PROJECTILE_SCENE := "res://scenes/weapons/projectile.tscn"

# 对象池：按场景路径分类存储
var _projectile_pools: Dictionary[String, Array] = {}

# 缓存的场景资源
var _cached_scene: PackedScene = null

# 最大池大小（防止内存无限增长）
@export var max_pool_size: int = 50

# 预加载的投射物数量
@export var preload_count: int = 10

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	system_name = "projectile_spawner"
	# 不在这里执行初始化，等待 BootSequence 调用

# 初始化方法 - 由 BootSequence 调用
func initialize() -> void:
	print("[ProjectileSpawner] 开始初始化...")
	_preload_projectile_scene()
	_preload_pool()
	print("[ProjectileSpawner] 初始化完成")
	_mark_ready()

# 预加载投射物场景
func _preload_projectile_scene() -> void:
	if ResourceLoader.exists(PROJECTILE_SCENE):
		_cached_scene = load(PROJECTILE_SCENE)
		print("[ProjectileSpawner] 投射物场景已缓存")
	else:
		push_warning("[ProjectileSpawner] 投射物场景不存在: " + PROJECTILE_SCENE)

# 预填充对象池
func _preload_pool() -> void:
	if not _cached_scene:
		return
	
	var pool: Array = []
	for i in range(preload_count):
		var projectile = _cached_scene.instantiate()
		projectile.visible = false
		projectile.process_mode = Node.PROCESS_MODE_DISABLED
		pool.append(projectile)
		add_child(projectile)
	
	_projectile_pools[PROJECTILE_SCENE] = pool
	print("[ProjectileSpawner] 对象池预填充完成，数量: %d" % preload_count)

# 生成投射物（主要接口）
# @param position: 生成位置
# @param direction: 飞行方向（归一化向量）
# @param stats: 武器属性数据
# @param faction: 阵营（"player" 或 "enemy"）
# @param owner: 发射者节点（可选）
# @return: 生成的投射物实例
func spawn_projectile(
	position: Vector2,
	direction: Vector2,
	stats: WeaponStats,
	faction: String,
	owner_node: Node2D = null
) -> Node:
	var projectile = _get_from_pool(PROJECTILE_SCENE)
	
	if not projectile:
		push_warning("[ProjectileSpawner] 无法获取投射物实例")
		return null
	
	# 设置基本属性
	projectile.global_position = position
	
	# 设置投射物数据（假设投射物有这些属性）
	if "direction" in projectile:
		projectile.direction = direction
	if "speed" in projectile and stats:
		projectile.speed = stats.projectile_speed if "projectile_speed" in stats else 500.0
	if "damage" in projectile and stats:
		projectile.damage = stats.damage if "damage" in stats else 10.0
	if "lifetime" in projectile and stats:
		projectile.lifetime = stats.projectile_lifetime if "projectile_lifetime" in stats else 2.0
	if "faction" in projectile:
		projectile.faction = faction
	if "owner_node" in projectile:
		projectile.owner_node = owner_node
	
	# 设置旋转（朝向飞行方向）
	projectile.rotation = direction.angle()
	
	# 启用处理
	projectile.visible = true
	projectile.process_mode = Node.PROCESS_MODE_INHERIT
	
	# 触发发射信号或方法
	if projectile.has_method("fire"):
		projectile.fire()
	
	return projectile

# 从对象池获取投射物
# @param scene_path: 场景资源路径
# @return: 可用的投射物实例
func _get_from_pool(scene_path: String) -> Node:
	# 确保池存在
	if not scene_path in _projectile_pools:
		_projectile_pools[scene_path] = []
	
	var pool: Array = _projectile_pools[scene_path]
	
	# 查找可用的投射物（不可见且有效的）
	for projectile in pool:
		if is_instance_valid(projectile) and not projectile.visible:
			# 重置状态
			projectile.visible = false
			projectile.process_mode = Node.PROCESS_MODE_DISABLED
			return projectile
	
	# 池中没有可用投射物，创建新的
	var scene = _cached_scene if scene_path == PROJECTILE_SCENE else load(scene_path)
	if not scene:
		push_warning("[ProjectileSpawner] 无法加载场景: " + scene_path)
		return null
	
	var new_projectile = scene.instantiate()
	add_child(new_projectile)
	pool.append(new_projectile)
	
	# 限制池大小
	if pool.size() > max_pool_size:
		var old = pool.pop_front()
		if is_instance_valid(old):
			old.queue_free()
		print("[ProjectileSpawner] 对象池达到上限，清理旧实例")
	
	return new_projectile

# 回收投射物到对象池
# @param projectile: 要回收的投射物实例
# @param scene_path: 场景资源路径（用于分类存储）
func return_to_pool(projectile: Node, scene_path: String = PROJECTILE_SCENE) -> void:
	if not projectile:
		return
	
	# 隐藏并禁用处理
	projectile.visible = false
	projectile.process_mode = Node.PROCESS_MODE_DISABLED
	
	# 重置位置到安全区域（可选）
	projectile.global_position = Vector2(-10000, -10000)
	
	# 添加到池
	if not scene_path in _projectile_pools:
		_projectile_pools[scene_path] = []
	
	# 避免重复添加
	if not projectile in _projectile_pools[scene_path]:
		_projectile_pools[scene_path].append(projectile)

# 清理所有对象池
func clear_pools() -> void:
	for pool_name in _projectile_pools:
		var pool: Array = _projectile_pools[pool_name]
		for projectile in pool:
			if is_instance_valid(projectile):
				projectile.queue_free()
		pool.clear()
	
	_projectile_pools.clear()
	print("[ProjectileSpawner] 所有对象池已清理")

# 获取池信息（用于调试）
func get_pool_info() -> Dictionary:
	var info = {
		"cached_scene": _cached_scene != null,
		"pools": {}
	}
	
	for pool_name in _projectile_pools:
		var pool: Array = _projectile_pools[pool_name]
		var active_count = 0
		for p in pool:
			if is_instance_valid(p) and p.visible:
				active_count += 1
		
		info["pools"][pool_name] = {
			"total": pool.size(),
			"active": active_count,
			"inactive": pool.size() - active_count
		}
	
	return info

# 快捷方法：生成玩家投射物
func spawn_player_projectile(
	position: Vector2,
	direction: Vector2,
	stats: WeaponStats,
	owner_node: Node2D = null
) -> Node:
	return spawn_projectile(position, direction, stats, "player", owner_node)

# 快捷方法：生成敌人投射物
func spawn_enemy_projectile(
	position: Vector2,
	direction: Vector2,
	stats: WeaponStats,
	owner_node: Node2D = null
) -> Node:
	return spawn_projectile(position, direction, stats, "enemy", owner_node)
