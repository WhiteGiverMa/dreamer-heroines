extends Node2D

# HitEffect - 命中特效
# 在子弹命中敌人时显示

@export var lifetime: float = 0.15
@export var color: Color = Color(1, 0.8, 0.2, 0.8)


func _ready() -> void:
	# 创建视觉特效
	var sprite = ColorRect.new()
	sprite.color = color
	sprite.size = Vector2(16, 16)
	sprite.position = Vector2(-8, -8)
	add_child(sprite)

	# 缩放动画
	var tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(2, 2), lifetime)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)
