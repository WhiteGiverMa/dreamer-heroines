extends Node

# EffectManager - 特效管理器
# 统一管理游戏中所有特效的创建、缓存和回收
# 支持多级 fallback：正式资源 -> 占位符资源 -> 运行时创建

# 特效路径配置
const EFFECT_PATHS = {
	# 命中特效
	"hit_bullet": {
		"primary": "res://assets/effects/hit_bullet.tscn",
		"placeholder": "res://src/weapons/effects/hit_effect.tscn",
		"type": "hit_effect"
	},
	"hit_enemy": {
		"primary": "res://assets/effects/hit_enemy.tscn",
		"placeholder": "res://src/weapons/effects/hit_effect.tscn",
		"type": "hit_effect"
	},
	
	# 撞击特效
	"impact_ground": {
		"primary": "res://assets/effects/impact_ground.tscn",
		"placeholder": "res://src/weapons/effects/impact_effect.tscn",
		"type": "impact_effect"
	},
	"impact_wall": {
		"primary": "res://assets/effects/impact_wall.tscn",
		"placeholder": "res://src/weapons/effects/impact_effect.tscn",
		"type": "impact_effect"
	},
	
	# 枪口火焰
	"muzzle_rifle": {
		"primary": "res://assets/effects/muzzle_rifle.tscn",
		"placeholder": "res://src/weapons/effects/muzzle_flash.tscn",
		"type": "muzzle_flash"
	},
	"muzzle_shotgun": {
		"primary": "res://assets/effects/muzzle_shotgun.tscn",
		"placeholder": "res://src/weapons/effects/muzzle_flash.tscn",
		"type": "muzzle_flash"
	},
	
	# 爆炸特效
	"explosion_small": {
		"primary": "res://assets/effects/explosion_small.tscn",
		"placeholder": "",
		"type": "explosion"
	},
	"explosion_large": {
		"primary": "res://assets/effects/explosion_large.tscn",
		"placeholder": "",
		"type": "explosion"
	},
	
	# 敌人特效
	"enemy_death": {
		"primary": "res://assets/effects/enemy_death.tscn",
		"placeholder": "",
		"type": "enemy_death"
	},
	
	# 玩家特效
	"player_damage": {
		"primary": "res://assets/effects/player_damage.tscn",
		"placeholder": "",
		"type": "player_damage"
	},
	"player_heal": {
		"primary": "res://assets/effects/player_heal.tscn",
		"placeholder": "",
		"type": "heal"
	},
	
	# 拾取特效
	"pickup_ammo": {
		"primary": "res://assets/effects/pickup_ammo.tscn",
		"placeholder": "",
		"type": "pickup"
	},
	"pickup_health": {
		"primary": "res://assets/effects/pickup_health.tscn",
		"placeholder": "",
		"type": "pickup"
	},
	"pickup_weapon": {
		"primary": "res://assets/effects/pickup_weapon.tscn",
		"placeholder": "",
		"type": "pickup"
	}
}

# 缓存的特效场景
var _cached_scenes: Dictionary = {}

# 对象池
var _effect_pools: Dictionary = {}

# 是否使用运行时占位符（当没有文件时）
@export var use_runtime_placeholders: bool = true

# 最大池大小
@export var max_pool_size: int = 20

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("EffectManager initialized")
	
	# 预加载常用特效
	_preload_common_effects()

# 预加载常用特效
func _preload_common_effects():
	var common_effects = ["hit_bullet", "impact_ground", "muzzle_rifle"]
	for effect_name in common_effects:
		_cache_effect(effect_name)

# 缓存特效
func _cache_effect(effect_name: String) -> bool:
	if effect_name in _cached_scenes:
		return true
	
	var config = EFFECT_PATHS.get(effect_name)
	if not config:
		return false
	
	var scene = ResourceLoaderUtils.load_scene_with_fallback(
		config.primary,
		config.placeholder
	)
	
	if scene:
		_cached_scenes[effect_name] = scene
		return true
	
	return false

# 播放特效（主要接口）
func play_effect(
	effect_name: String,
	position: Vector2,
	rotation: float = 0.0,
	parent: Node = null
) -> Node:
	var effect := _create_effect(effect_name)
	
	if not effect:
		return null
	
	# 设置位置和旋转
	effect.global_position = position
	effect.rotation = rotation
	
	# 添加到场景
	var target_parent = parent if parent else get_tree().current_scene
	if target_parent:
		target_parent.add_child(effect)
	
	return effect

# 创建特效实例
func _create_effect(effect_name: String) -> Node:
	var config = EFFECT_PATHS.get(effect_name)
	if not config:
		push_warning("Unknown effect: " + effect_name)
		return null
	
	# 1. 尝试从缓存创建
	if effect_name in _cached_scenes:
		return _cached_scenes[effect_name].instantiate()
	
	# 2. 尝试加载并缓存
	if _cache_effect(effect_name):
		return _cached_scenes[effect_name].instantiate()
	
	# 3. 运行时创建占位符
	if use_runtime_placeholders:
		return ResourceLoaderUtils.create_runtime_effect(config.type)
	
	return null

# 从对象池获取特效
func get_effect_from_pool(effect_name: String) -> Node:
	if not effect_name in _effect_pools:
		_effect_pools[effect_name] = []
	
	var pool: Array = _effect_pools[effect_name]
	
	# 查找可用的特效
	for effect in pool:
		if is_instance_valid(effect) and not effect.visible:
			effect.visible = true
			return effect
	
	# 创建新的特效
	var new_effect = _create_effect(effect_name)
	if new_effect:
		pool.append(new_effect)
		
		# 限制池大小
		if pool.size() > max_pool_size:
			var old = pool.pop_front()
			if is_instance_valid(old):
				old.queue_free()
	
	return new_effect

# 回收特效到对象池
func return_effect_to_pool(effect: Node, effect_name: String):
	if not effect:
		return
	
	effect.visible = false
	
	if not effect_name in _effect_pools:
		_effect_pools[effect_name] = []
	
	_effect_pools[effect_name].append(effect)

# 清理对象池
func clear_pools():
	for pool_name in _effect_pools:
		var pool: Array = _effect_pools[pool_name]
		for effect in pool:
			if is_instance_valid(effect):
				effect.queue_free()
		pool.clear()
	
	_effect_pools.clear()

# 清理缓存
func clear_cache():
	_cached_scenes.clear()

# 快捷方法：播放命中特效
func play_hit_effect(position: Vector2, is_enemy: bool = true) -> Node:
	var effect_name = "hit_enemy" if is_enemy else "hit_bullet"
	return play_effect(effect_name, position)

# 快捷方法：播放撞击特效
func play_impact_effect(position: Vector2, is_ground: bool = true) -> Node:
	var effect_name = "impact_ground" if is_ground else "impact_wall"
	return play_effect(effect_name, position)

# 快捷方法：播放枪口火焰
func play_muzzle_flash(position: Vector2, rotation: float, weapon_type: String = "rifle") -> Node:
	var effect_name = "muzzle_" + weapon_type
	return play_effect(effect_name, position, rotation)

# 快捷方法：播放爆炸
func play_explosion(position: Vector2, size: String = "small") -> Node:
	var effect_name = "explosion_" + size
	return play_effect(effect_name, position)

# 快捷方法：播放敌人死亡特效
func play_enemy_death(position: Vector2) -> Node:
	return play_effect("enemy_death", position)

# 快捷方法：播放玩家受伤特效
func play_player_damage(position: Vector2) -> Node:
	return play_effect("player_damage", position)

# 快捷方法：播放治疗特效
func play_heal_effect(position: Vector2) -> Node:
	return play_effect("player_heal", position)

# 快捷方法：播放拾取特效
func play_pickup_effect(position: Vector2, pickup_type: String = "ammo") -> Node:
	var effect_name = "pickup_" + pickup_type
	return play_effect(effect_name, position)

# 创建自定义特效（使用运行时占位符）
func create_custom_effect(
	position: Vector2,
	color: Color,
	size: Vector2,
	lifetime: float,
	animation_type: String = "fade_out"
) -> Node2D:
	var effect := Node2D.new()
	effect.global_position = position
	
	# 创建视觉
	var rect := ColorRect.new()
	rect.size = size
	rect.position = -size / 2
	rect.color = color
	effect.add_child(rect)
	
	# 添加动画
	var script := GDScript.new()
	match animation_type:
		"fade_out":
			script.source_code = """
extends Node2D
func _ready():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, %f)
	tween.tween_callback(queue_free)
""" % lifetime
		
		"scale_up":
			script.source_code = """
extends Node2D
func _ready():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(2, 2), %f)
	tween.parallel().tween_property(self, "modulate:a", 0.0, %f)
	tween.tween_callback(queue_free)
""" % [lifetime, lifetime]
		
		"float_up":
			script.source_code = """
extends Node2D
func _ready():
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 50, %f)
	tween.parallel().tween_property(self, "modulate:a", 0.0, %f)
	tween.tween_callback(queue_free)
""" % [lifetime, lifetime]
	
	script.reload()
	effect.set_script(script)
	
	get_tree().current_scene.add_child(effect)
	return effect

# 获取特效信息
func get_effect_info(effect_name: String) -> Dictionary:
	var config = EFFECT_PATHS.get(effect_name, {})
	var is_cached = effect_name in _cached_scenes
	var pool_size = _effect_pools.get(effect_name, []).size()
	
	return {
		"name": effect_name,
		"config": config,
		"is_cached": is_cached,
		"pool_size": pool_size,
		"has_primary": ResourceLoader.exists(config.get("primary", "")),
		"has_placeholder": ResourceLoader.exists(config.get("placeholder", ""))
	}

# 列出所有可用特效
func list_available_effects() -> Array[String]:
	var available: Array[String] = []
	
	for effect_name in EFFECT_PATHS:
		var info = get_effect_info(effect_name)
		if info.has_primary or info.has_placeholder or use_runtime_placeholders:
			available.append(effect_name)
	
	return available
