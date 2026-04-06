extends Node2D

# ImpactEffect - 撞击特效
# 在子弹撞击地面/墙壁时显示

@export var lifetime: float = 0.2
@export var color: Color = Color(0.8, 0.6, 0.4, 0.7)


func _ready() -> void:
	# 创建视觉特效
	var sprite = ColorRect.new()
	sprite.color = color
	sprite.size = Vector2(12, 12)
	sprite.position = Vector2(-6, -6)
	add_child(sprite)

	# 缩放和淡出动画
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), lifetime)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)
