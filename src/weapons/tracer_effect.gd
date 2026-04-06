class_name TracerEffect
extends Node2D

# TracerEffect - 弹道追踪光效组件
# 跟随投射物，渲染发光轨迹效果
# 使用Sprite2D + additive混合代替PointLight2D（性能优化）

@export var config: LightSettings = null
@export var lifetime: float = 0.3

var sprite: Sprite2D = null
var _tween: Tween = null

func _ready() -> void:
	# 创建Sprite2D子节点
	sprite = Sprite2D.new()
	sprite.name = "TracerSprite"
	add_child(sprite)

	# 应用tracer_glow材质（additive混合）
	var material = preload("res://resources/materials/tracer_glow.tres")
	if material:
		sprite.material = material

	# 设置渐变纹理（圆形）
	var gradient = _create_circular_gradient()
	sprite.texture = gradient

	# 应用config配置
	if config:
		sprite.modulate = config.color
		# scale根据config.range设置
		scale = Vector2.ONE * (config.light_range / 100.0)
	else:
		# 默认配置
		sprite.modulate = Color(1, 1, 0, 1)
		scale = Vector2.ONE

	# 默认隐藏，等待激活
	visible = false


func _create_circular_gradient() -> GradientTexture2D:
	# 创建圆形渐变纹理
	var gradient_tex = GradientTexture2D.new()
	gradient_tex.width = 64
	gradient_tex.height = 64
	gradient_tex.fill = GradientTexture2D.FILL_RADIAL
	gradient_tex.fill_from = Vector2(0.5, 0.5)
	gradient_tex.fill_to = Vector2(1.0, 0.5)
	gradient_tex.origin = Vector2(32, 32)

	# 创建渐变：中心亮，边缘暗
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))  # 中心白色
	gradient.set_color(1, Color(1, 1, 1, 0))  # 边缘透明
	gradient_tex.gradient = gradient

	return gradient_tex


func _process(_delta: float) -> void:
	# 跟随父节点（子弹）
	if get_parent():
		global_position = get_parent().global_position
		global_rotation = get_parent().global_rotation


func activate() -> void:
	"""激活追踪光效"""
	visible = true

	# 确保从完全不透明开始
	if sprite:
		var current_color = sprite.modulate
		sprite.modulate = Color(current_color.r, current_color.g, current_color.b, 1.0)

	# 重置scale
	if config:
		scale = Vector2.ONE * (config.light_range / 100.0)


func deactivate() -> void:
	"""渐隐并释放"""
	if not is_inside_tree():
		queue_free()
		return

	# 停止跟随
	set_process(false)

	# 创建Tween进行渐隐动画
	_tween = create_tween()
	_tween.set_parallel(true)

	if sprite:
		# 渐隐动画
		_tween.tween_property(sprite, "modulate:a", 0.0, lifetime)
		# 缩小动画
		_tween.tween_property(self, "scale", scale * 0.5, lifetime)

	# 延迟释放
	_tween.chain().tween_callback(queue_free)


func _exit_tree() -> void:
	# 清理tween
	if _tween and _tween.is_valid():
		_tween.kill()
