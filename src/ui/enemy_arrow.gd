class_name EnemyArrow
extends TextureRect

## EnemyArrow - 敌人指示器箭头UI组件
## 显示屏幕边缘或头顶的箭头，指向屏幕外或头顶敌人

# ============================================
# 信号
# ============================================

## 淡出完成信号
signal fade_out_complete

# ============================================
# 常量
# ============================================

## 淡入动画时长
const FADE_IN_DURATION := 0.2

## 淡出动画时长
const FADE_OUT_DURATION := 0.15

## 状态转换动画时长
const TRANSITION_DURATION := 0.15

## 贴图默认朝向（你当前新图是朝下）
const BASE_FORWARD_ANGLE := PI / 2.0

# ============================================
# 枚举
# ============================================

## 箭头显示状态
enum ArrowState {
	EDGE,  ## 屏幕边缘指示
	OVERHEAD,  ## 头顶指示
	HIDDEN,  ## 隐藏
}

# ============================================
# 导出配置 - 外观
# ============================================

## 边缘指示箭头纹理
@export var arrow_edge_texture: Texture2D:
	set(value):
		arrow_edge_texture = value
		if _state == ArrowState.EDGE:
			texture = arrow_edge_texture

## 头顶指示箭头纹理
@export var arrow_overhead_texture: Texture2D:
	set(value):
		arrow_overhead_texture = value
		if _state == ArrowState.OVERHEAD:
			texture = arrow_overhead_texture

# ============================================
# 内部状态
# ============================================

## 当前箭头状态
var _state: ArrowState = ArrowState.HIDDEN

## 前一状态（用于检测状态转换）
var _previous_state: ArrowState = ArrowState.HIDDEN

## 目标世界坐标
var _target_position: Vector2 = Vector2.ZERO

## 世界目标位置（用于边缘箭头旋转计算）
var _world_target: Vector2 = Vector2.ZERO

## 淡入淡出动画Tween
var _fade_tween: Tween

## 状态转换动画Tween
var _transition_tween: Tween

## 状态转换起始位置
var _transition_start_pos: Vector2 = Vector2.ZERO

## 状态转换起始旋转
var _transition_start_rot: float = 0.0

## 是否有待处理的状态转换
var _pending_transition: bool = false

# ============================================
# 生命周期
# ============================================


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0  # 初始隐藏，等待 fade_in 调用
	_state = ArrowState.HIDDEN


# ============================================
# 公开方法 - 状态控制
# ============================================


## 设置箭头显示状态
func set_state(state: ArrowState) -> void:
	# 检测EDGE↔OVERHEAD转换
	if (
		_state in [ArrowState.EDGE, ArrowState.OVERHEAD]
		and state in [ArrowState.EDGE, ArrowState.OVERHEAD]
		and _state != state
	):
		# 记录转换起始位置和旋转
		_transition_start_pos = global_position
		_transition_start_rot = rotation
		_pending_transition = true

	_previous_state = _state
	_state = state
	match state:
		ArrowState.EDGE:
			texture = arrow_edge_texture
		ArrowState.OVERHEAD:
			texture = arrow_overhead_texture
		ArrowState.HIDDEN:
			texture = null

	if texture:
		size = texture.get_size()
		custom_minimum_size = size
		pivot_offset = size * 0.5
	else:
		pivot_offset = Vector2.ZERO


## 设置目标世界坐标
func set_target_position(world_pos: Vector2) -> void:
	_target_position = world_pos
	_world_target = world_pos

	# 计算目标旋转
	var target_rot: float
	match _state:
		ArrowState.OVERHEAD:
			target_rot = 0.0
		ArrowState.EDGE:
			var source_pos := global_position + get_visual_size() * 0.5
			if source_pos.distance_to(_world_target) <= 0.001:
				target_rot = rotation
			else:
				target_rot = source_pos.direction_to(_world_target).angle() - BASE_FORWARD_ANGLE
		_:
			target_rot = rotation

	# 如果有待处理的状态转换，应用过渡动画
	if _pending_transition:
		_tween_transition(
			_transition_start_pos,
			_transition_start_rot,
			global_position,
			target_rot,
			TRANSITION_DURATION
		)
		_pending_transition = false
	else:
		rotation = target_rot


## 淡入动画
func fade_in() -> void:
	# 停止之前的淡入淡出动画
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_fade_tween = tween


## 淡出动画
func fade_out() -> void:
	# 停止之前的淡入淡出动画
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.finished.connect(_on_fade_out_complete)
	_fade_tween = tween


# ============================================
# 私有方法
# ============================================


## 状态转换动画
func _tween_transition(
	from_pos: Vector2, from_rot: float, to_pos: Vector2, to_rot: float, duration: float
) -> void:
	# 停止之前的转换动画
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	# 设置起始位置和旋转
	global_position = from_pos
	rotation = from_rot

	# 创建并行tween
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "global_position", to_pos, duration)
	tween.tween_property(self, "rotation", to_rot, duration)
	_transition_tween = tween


## 淡出完成回调
func _on_fade_out_complete() -> void:
	fade_out_complete.emit()


func get_visual_size() -> Vector2:
	if texture:
		return texture.get_size()
	if size.x > 0.0 and size.y > 0.0:
		return size
	return Vector2(24, 24)
