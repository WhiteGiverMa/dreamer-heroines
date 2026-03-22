class_name CameraShake
extends Camera2D

## CameraShake - 屏幕震动组件
## 附加到 Camera2D 上使用

var _shake_amount: float = 0.0
var _shake_decay: float = 5.0
var _original_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_original_offset = offset


func _process(delta: float) -> void:
	if _shake_amount > 0:
		# 应用随机偏移
		offset = _original_offset + Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		)
		
		# 衰减
		_shake_amount = max(_shake_amount - _shake_decay * delta, 0)
	else:
		offset = _original_offset


## 应用屏幕震动
## amount: 震动强度 (像素)
func apply_shake(amount: float) -> void:
	_shake_amount = max(_shake_amount, amount * 10)  # 放大震动效果


## 立即停止震动
func stop_shake() -> void:
	_shake_amount = 0
	offset = _original_offset
