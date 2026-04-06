class_name ResourceLoaderUtils
extends RefCounted

# ResourceLoaderUtils - 资源加载工具类
# 提供带 fallback 的资源加载功能

const PLACEHOLDER_COLORS: Dictionary[String, Color] = {
	"hit_effect": Color(1, 0.8, 0.2, 0.8),  # 黄色 - 命中
	"impact_effect": Color(0.8, 0.6, 0.4, 0.7),  # 棕色 - 撞击
	"muzzle_flash": Color(1, 0.9, 0.5, 0.9),  # 亮黄 - 枪口火焰
	"explosion": Color(1, 0.4, 0.1, 0.8),  # 橙色 - 爆炸
	"enemy_death": Color(0.8, 0.2, 0.2, 0.7),  # 红色 - 敌人死亡
	"player_damage": Color(1, 0.2, 0.2, 0.5),  # 红色 - 玩家受伤
	"heal": Color(0.2, 1, 0.4, 0.7),  # 绿色 - 治疗
	"pickup": Color(0.2, 0.8, 1, 0.8),  # 青色 - 拾取
	"default": Color(1, 1, 1, 0.7)  # 白色 - 默认
}


# 加载场景资源，带多级 fallback
static func load_scene_with_fallback(
	primary_path: String, placeholder_path: String = "", _effect_type: String = "default"
) -> PackedScene:
	# 1. 尝试加载正式资源
	if ResourceLoader.exists(primary_path):
		return load(primary_path)

	# 2. 尝试加载占位符资源
	if not placeholder_path.is_empty() and ResourceLoader.exists(placeholder_path):
		return load(placeholder_path)

	# 3. 返回 null，让调用者创建运行时占位符
	return null


# 实例化特效，自动处理 fallback
static func instantiate_effect(
	primary_path: String,
	placeholder_path: String = "",
	effect_type: String = "default",
	parent: Node = null
) -> Node:
	var scene := load_scene_with_fallback(primary_path, placeholder_path, effect_type)

	var instance: Node
	if scene:
		instance = scene.instantiate()
	else:
		# 创建运行时占位符
		instance = create_runtime_effect(effect_type)

	if parent and instance:
		parent.add_child(instance)

	return instance


# 创建运行时占位符特效
static func create_runtime_effect(effect_type: String) -> Node2D:
	var effect := Node2D.new()
	effect.name = "Runtime" + effect_type.capitalize()

	# 添加视觉效果
	var color: Color
	if PLACEHOLDER_COLORS.has(effect_type):
		color = PLACEHOLDER_COLORS[effect_type]
	else:
		color = PLACEHOLDER_COLORS["default"]
	var visual := _create_visual_for_type(effect_type, color)
	effect.add_child(visual)

	# 添加动画脚本
	var script := _create_effect_script(effect_type)
	effect.set_script(script)

	return effect


# 根据特效类型创建视觉
static func _create_visual_for_type(effect_type: String, color: Color) -> Node:
	match effect_type:
		"muzzle_flash":
			# 枪口火焰 - 锥形
			var polygon := Polygon2D.new()
			polygon.polygon = PackedVector2Array([Vector2(0, -4), Vector2(20, 0), Vector2(0, 4)])
			polygon.color = color
			return polygon

		"explosion":
			# 爆炸 - 圆形
			var circle := _create_circle_sprite(20, color)
			return circle

		"hit_effect", "enemy_death":
			# 命中/死亡 - 十字形
			var container := Node2D.new()
			var h_rect := ColorRect.new()
			h_rect.size = Vector2(16, 4)
			h_rect.position = Vector2(-8, -2)
			h_rect.color = color
			var v_rect := ColorRect.new()
			v_rect.size = Vector2(4, 16)
			v_rect.position = Vector2(-2, -8)
			v_rect.color = color
			container.add_child(h_rect)
			container.add_child(v_rect)
			return container

		"impact_effect":
			# 撞击 - 小方块
			var rect := ColorRect.new()
			rect.size = Vector2(8, 8)
			rect.position = Vector2(-4, -4)
			rect.color = color
			return rect

		"heal", "pickup":
			# 治疗/拾取 - 菱形
			var polygon := Polygon2D.new()
			polygon.polygon = PackedVector2Array(
				[Vector2(0, -10), Vector2(10, 0), Vector2(0, 10), Vector2(-10, 0)]
			)
			polygon.color = color
			return polygon

		_:
			# 默认 - 小方块
			var rect := ColorRect.new()
			rect.size = Vector2(12, 12)
			rect.position = Vector2(-6, -6)
			rect.color = color
			return rect


# 创建圆形精灵
static func _create_circle_sprite(radius: float, color: Color) -> Node:
	var polygon := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 16
	for i in range(segments):
		var angle := TAU * i / segments
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	polygon.polygon = points
	polygon.color = color
	return polygon


# 创建特效脚本
static func _create_effect_script(effect_type: String) -> GDScript:
	var script := GDScript.new()

	match effect_type:
		"muzzle_flash":
			script.source_code = """
extends Node2D

func _ready():
	# 快速淡出
	var tween = create_tween()
	modulate.a = 1.0
	tween.tween_property(self, "modulate:a", 0.0, 0.05)
	tween.tween_callback(queue_free)
"""

		"explosion":
			script.source_code = """
extends Node2D

func _ready():
	# 爆炸动画：扩大并淡出
	var tween = create_tween()
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(2.0, 2.0), 0.3)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
"""

		"hit_effect", "enemy_death":
			script.source_code = """
extends Node2D

func _ready():
	# 命中动画：闪烁后淡出
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.1)
	tween.tween_callback(queue_free)
"""

		"impact_effect":
			script.source_code = """
extends Node2D

func _ready():
	# 撞击动画：小范围扩散
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.15)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)
"""

		"heal", "pickup":
			script.source_code = """
extends Node2D

func _ready():
	# 治疗动画：上升并淡出
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - 30, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
"""

		_:
			script.source_code = """
extends Node2D

func _ready():
	# 默认动画：简单淡出
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)
"""

	script.reload()
	return script


# 加载纹理，带颜色占位符 fallback
static func load_texture_with_fallback(
	path: String,
	_placeholder_color: Color = Color(0.5, 0.5, 0.5, 1),
	size: Vector2 = Vector2(32, 32)
) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)

	# 创建 PlaceholderTexture2D
	var placeholder := PlaceholderTexture2D.new()
	placeholder.size = size
	return placeholder


# 预加载多个资源，返回成功加载的列表
static func preload_resources(paths: Array[String]) -> Dictionary:
	var result := {"loaded": {}, "failed": []}

	for path in paths:
		if ResourceLoader.exists(path):
			result.loaded[path] = load(path)
		else:
			result.failed.append(path)

	return result


# 检查资源是否存在，支持多个路径
static func exists_any(paths: Array[String]) -> bool:
	for path in paths:
		if ResourceLoader.exists(path):
			return true
	return false
