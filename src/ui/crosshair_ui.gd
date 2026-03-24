class_name CrosshairUI
extends Control

## CrosshairUI - 动态准星UI组件
## 显示可变扩散准星，响应武器状态变化
## 当前为骨架实现，详细绘制逻辑在后续任务完成

# ============================================
# 信号
# ============================================

signal spread_changed(new_spread: float)

# ============================================
# 导出配置 - 外观
# ============================================

## 正常状态下的准星颜色
@export var normal_color: Color = Color.WHITE:
	set(value):
		normal_color = value
		queue_redraw()

## 准星大小（像素）
@export var crosshair_size: float = 20.0:
	set(value):
		crosshair_size = value
		queue_redraw()

## 准星透明度
@export var crosshair_alpha: float = 1.0:
	set(value):
		crosshair_alpha = value
		queue_redraw()

## 是否显示中心点
@export var show_center_dot: bool = true:
	set(value):
		show_center_dot = value
		queue_redraw()

## 中心点大小（像素）
@export var center_dot_size: float = 2.0:
	set(value):
		center_dot_size = value
		queue_redraw()

## 换弹状态颜色
@export var reload_color: Color = Color.YELLOW:
	set(value):
		reload_color = value
		queue_redraw()

## 空弹匣状态颜色
@export var empty_color: Color = Color.RED:
	set(value):
		empty_color = value
		queue_redraw()

## 命中反馈颜色
@export var hit_color: Color = Color.GREEN:
	set(value):
		hit_color = value
		queue_redraw()

# ============================================
# 导出配置 - 扩散行为
# ============================================

## 每次射击增加的扩散量
@export var spread_increase_per_shot: float = 5.0

## 扩散恢复速率（像素/秒）
@export var recovery_rate: float = 30.0

## 最大扩散倍率
@export var max_spread_multiplier: float = 3.0

# ============================================
# 内部状态
# ============================================

## 当前扩散值
var current_spread: float = 0.0

## 基础扩散值（来自武器）
var base_spread: float = 0.0

## 最大扩散值
var max_spread: float = 0.0

## 是否正在换弹
var is_reloading: bool = false

## 弹匣是否为空
var is_empty_mag: bool = false


# ============================================
# 生命周期
# ============================================

func _ready() -> void:
	top_level = true
	queue_redraw()


func _process(delta: float) -> void:
	global_position = get_viewport().get_mouse_position()
	recover(delta)


func _draw() -> void:
	# 计算准星中心点
	var center := size / 2.0
	
	# 确定渲染颜色（优先级：空弹匣 > 换弹 > 正常）
	var draw_color: Color
	if is_empty_mag:
		draw_color = empty_color
	elif is_reloading:
		draw_color = reload_color
	else:
		draw_color = normal_color
	
	# 应用透明度
	draw_color.a *= crosshair_alpha
	
	# 计算线段位置：current_spread 是线段起点离中心的距离
	var inner_offset := current_spread
	var outer_offset := current_spread + crosshair_size
	
	# 绘制四条准星线（上/下/左/右）
	# 上
	draw_line(
		Vector2(center.x, center.y - inner_offset),
		Vector2(center.x, center.y - outer_offset),
		draw_color
	)
	# 下
	draw_line(
		Vector2(center.x, center.y + inner_offset),
		Vector2(center.x, center.y + outer_offset),
		draw_color
	)
	# 左
	draw_line(
		Vector2(center.x - inner_offset, center.y),
		Vector2(center.x - outer_offset, center.y),
		draw_color
	)
	# 右
	draw_line(
		Vector2(center.x + inner_offset, center.y),
		Vector2(center.x + outer_offset, center.y),
		draw_color
	)
	
	# 绘制中心点（可选）
	if show_center_dot:
		draw_circle(center, center_dot_size, draw_color)


# ============================================
# 公开方法 - 扩散控制
# ============================================

## 射击时扩展准星
func expand_on_shot() -> void:
	# visual-only: 扩散增加，不影响实际弹道精度
	var previous_spread := current_spread
	current_spread += spread_increase_per_shot
	current_spread = minf(current_spread, max_spread)
	
	# 仅在值有意义的改变时触发重绘
	if not is_equal_approx(current_spread, previous_spread):
		queue_redraw()


## 恢复准星扩散
func recover(delta: float) -> void:
	# 帧率无关恢复：使用指数平滑
	# t = 1 - exp(-k * delta)，其中 k = recovery_rate / (max_spread - base_spread)
	# 简化：每秒恢复 recovery_rate 像素，帧率无关
	if is_equal_approx(current_spread, base_spread):
		return
	
	var previous_spread := current_spread
	
	# 线性恢复速率（像素/秒），帧率无关
	var recovery_amount := recovery_rate * delta
	
	# 恢复到 base_spread，不能低于
	current_spread -= recovery_amount
	current_spread = maxf(current_spread, base_spread)
	
	# 仅在值有意义的改变时触发重绘
	if not is_equal_approx(current_spread, previous_spread):
		queue_redraw()


## 更新基础扩散（来自武器）
func update_spread(new_current_spread: float, new_base_spread: float) -> void:
	# 更新基础扩散值
	var previous_base := base_spread
	base_spread = new_base_spread
	
	# 计算新的最大扩散
	max_spread = base_spread * max_spread_multiplier
	
	# 更新当前扩散值（来自武器视觉扩散状态）
	var previous_current := current_spread
	current_spread = clampf(new_current_spread, base_spread, max_spread)
	
	# 发射信号通知扩散变化（仅在 base_spread 实际改变时）
	if not is_equal_approx(base_spread, previous_base):
		spread_changed.emit(current_spread)
	
	# 仅在值有意义的改变时触发重绘
	if not is_equal_approx(current_spread, previous_current):
		queue_redraw()


# ============================================
# 回调方法 - 武器事件
# ============================================

## 换弹开始回调
func _on_reload_started(_duration: float) -> void:
	# Task 7: 设置换弹状态，仅在状态改变时重绘
	if is_reloading:
		return
	is_reloading = true
	queue_redraw()


## 换弹结束回调
func _on_reload_finished() -> void:
	# Task 7: 清除换弹状态，仅在状态改变时重绘
	if not is_reloading:
		return
	is_reloading = false
	queue_redraw()


## 弹药变化回调
func _on_ammo_changed(current: int, maximum: int) -> void:
	# Task 7: 检测空弹匣状态，仅在状态改变时重绘
	var new_empty_mag := (current == 0 and maximum > 0)
	if is_empty_mag == new_empty_mag:
		return
	is_empty_mag = new_empty_mag
	queue_redraw()


# ============================================
# 反馈方法
# ============================================

## 显示命中反馈
func show_hit_feedback() -> void:
	# 行为逻辑在 Task 7 实现
	# Task 4: 仅触发重绘以响应反馈状态
	queue_redraw()
