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

## 准星形状
@export var crosshair_shape: String = "cross":
	set(value):
		crosshair_shape = value
		queue_redraw()

## 颜色模式（preset/custom）
@export var color_mode: String = "preset":
	set(value):
		color_mode = value
		_sync_normal_color()

## 颜色预设 key
@export var color_preset: String = "green":
	set(value):
		color_preset = value
		_sync_normal_color()

## 自定义颜色通道
@export var custom_color_r: float = 0.0:
	set(value):
		custom_color_r = clampf(value, 0.0, 1.0)
		_sync_normal_color()

@export var custom_color_g: float = 1.0:
	set(value):
		custom_color_g = clampf(value, 0.0, 1.0)
		_sync_normal_color()

@export var custom_color_b: float = 0.0:
	set(value):
		custom_color_b = clampf(value, 0.0, 1.0)
		_sync_normal_color()

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

## 中心点透明度
@export var center_dot_alpha: float = 1.0:
	set(value):
		center_dot_alpha = clampf(value, 0.0, 1.0)
		queue_redraw()

## 线段长度
@export var line_length: float = 20.0:
	set(value):
		line_length = maxf(value, 1.0)
		queue_redraw()

## 线段粗细
@export var line_thickness: float = 2.0:
	set(value):
		line_thickness = maxf(value, 1.0)
		queue_redraw()

## 基础线段间距
@export var line_gap: float = 0.0:
	set(value):
		line_gap = maxf(value, 0.0)
		queue_redraw()

## 是否使用 T 形准星
@export var use_t_shape: bool = false:
	set(value):
		use_t_shape = value
		queue_redraw()

## 是否启用轮廓
@export var outline_enabled: bool = false:
	set(value):
		outline_enabled = value
		queue_redraw()

## 轮廓粗细
@export var outline_thickness: float = 1.0:
	set(value):
		outline_thickness = clampf(value, 0.0, 6.0)
		queue_redraw()

## 轮廓颜色红色通道
@export var outline_color_r: float = 0.0:
	set(value):
		outline_color_r = clampf(value, 0.0, 1.0)
		queue_redraw()

## 轮廓颜色绿色通道
@export var outline_color_g: float = 0.0:
	set(value):
		outline_color_g = clampf(value, 0.0, 1.0)
		queue_redraw()

## 轮廓颜色蓝色通道
@export var outline_color_b: float = 0.0:
	set(value):
		outline_color_b = clampf(value, 0.0, 1.0)
		queue_redraw()

## 是否启用动态扩散表现
@export var enable_dynamic_spread: bool = true:
	set(value):
		enable_dynamic_spread = value
		if not enable_dynamic_spread and not is_equal_approx(current_spread, base_spread):
			current_spread = base_spread
		queue_redraw()

## 换弹状态颜色
@export var reload_color: Color = Color.YELLOW:
	set(value):
		reload_color = value
		queue_redraw()

## 部署状态颜色
@export var deploy_color: Color = Color(0.24, 0.52, 1.0, 1.0):
	set(value):
		deploy_color = value
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

## 是否正在部署
var is_deploying: bool = false

## 弹匣是否为空
var is_empty_mag: bool = false

var _service_connected: bool = false


# ============================================
# 生命周期
# ============================================

func _ready() -> void:
	top_level = true
	_initialize_from_settings_service()
	_sync_normal_color()
	queue_redraw()


func _process(delta: float) -> void:
	global_position = get_viewport().get_mouse_position()
	recover(delta)


func _draw() -> void:
	# 计算准星中心点
	var center := size / 2.0
	var draw_color := _get_state_aware_color()
	var spread_offset := _get_visual_spread_offset()
	var inner_offset := line_gap + spread_offset
	var segment_length := _get_line_length()
	var outer_offset := inner_offset + segment_length
	var outline_color := _get_outline_color(draw_color)

	match crosshair_shape:
		"dot":
			_draw_center_dot(center, draw_color)

		"circle":
			_draw_ring_outline(center, outline_color, inner_offset, segment_length)
			_draw_ring(center, draw_color, inner_offset, segment_length)
			if show_center_dot:
				_draw_center_dot(center, draw_color)

		"combined":
			_draw_cross_segments_outline(center, outline_color, inner_offset, outer_offset)
			_draw_cross_segments(center, draw_color, inner_offset, outer_offset)
			_draw_ring_outline(center, outline_color, inner_offset, segment_length)
			_draw_ring(center, draw_color, inner_offset, segment_length)
			if show_center_dot:
				_draw_center_dot(center, draw_color)

		_:
			_draw_cross_segments_outline(center, outline_color, inner_offset, outer_offset)
			_draw_cross_segments(center, draw_color, inner_offset, outer_offset)
			if show_center_dot:
				_draw_center_dot(center, draw_color)


func _initialize_from_settings_service() -> void:
	if _service_connected or not CrosshairSettingsService:
		return

	if not CrosshairSettingsService.settings_changed.is_connected(_on_crosshair_settings_changed):
		CrosshairSettingsService.settings_changed.connect(_on_crosshair_settings_changed)

	if not CrosshairSettingsService.settings_loaded.is_connected(_on_crosshair_settings_changed):
		CrosshairSettingsService.settings_loaded.connect(_on_crosshair_settings_changed)

	_service_connected = true
	CrosshairSettingsService.reload_settings()
	_apply_settings(CrosshairSettingsService.get_settings())


func _on_crosshair_settings_changed(settings) -> void:
	_apply_settings(settings)


func _apply_settings(settings) -> void:
	if settings == null:
		return

	crosshair_size = settings.crosshair_size
	crosshair_alpha = settings.crosshair_alpha
	crosshair_shape = settings.crosshair_shape
	color_mode = settings.color_mode
	color_preset = settings.color_preset
	custom_color_r = settings.custom_color_r
	custom_color_g = settings.custom_color_g
	custom_color_b = settings.custom_color_b
	line_length = settings.line_length
	line_thickness = settings.line_thickness
	line_gap = settings.line_gap
	use_t_shape = settings.use_t_shape
	outline_enabled = settings.outline_enabled
	outline_thickness = settings.outline_thickness
	outline_color_r = settings.outline_color_r
	outline_color_g = settings.outline_color_g
	outline_color_b = settings.outline_color_b
	show_center_dot = settings.show_center_dot
	center_dot_size = settings.center_dot_size
	center_dot_alpha = settings.center_dot_alpha
	enable_dynamic_spread = settings.enable_dynamic_spread
	spread_increase_per_shot = settings.spread_increase_per_shot
	recovery_rate = settings.recovery_rate
	max_spread_multiplier = settings.max_spread_multiplier

	_sync_normal_color()


func _sync_normal_color() -> void:
	normal_color = _resolve_normal_color()


func _resolve_normal_color() -> Color:
	if color_mode == "custom":
		return Color(custom_color_r, custom_color_g, custom_color_b, 1.0)

	if CrosshairSettingsService and CrosshairSettingsService.COLOR_PRESETS.has(color_preset):
		return CrosshairSettingsService.COLOR_PRESETS[color_preset]

	return Color.WHITE


func _get_state_aware_color() -> Color:
	var draw_color := normal_color
	if is_empty_mag:
		draw_color = empty_color
	elif is_deploying:
		draw_color = deploy_color
	elif is_reloading:
		draw_color = reload_color

	draw_color.a *= crosshair_alpha
	return draw_color


func _get_visual_spread_offset() -> float:
	if not enable_dynamic_spread:
		return 0.0
	return current_spread


func _get_outline_color(base_color: Color) -> Color:
	if not outline_enabled or outline_thickness <= 0.0:
		return Color.TRANSPARENT

	return Color(outline_color_r, outline_color_g, outline_color_b, base_color.a)


func _get_line_length() -> float:
	return maxf(line_length, 1.0)


func _get_outline_width() -> float:
	return line_thickness + (outline_thickness * 2.0)


func _draw_cross_segments_outline(center: Vector2, outline_color: Color, inner_offset: float, outer_offset: float) -> void:
	if outline_color.a <= 0.0:
		return

	_draw_segment(
		Vector2(center.x, center.y - inner_offset),
		Vector2(center.x, center.y - outer_offset),
		outline_color,
		_get_outline_width()
	)

	if not use_t_shape:
		_draw_segment(
			Vector2(center.x, center.y + inner_offset),
			Vector2(center.x, center.y + outer_offset),
			outline_color,
			_get_outline_width()
		)

	_draw_segment(
		Vector2(center.x - inner_offset, center.y),
		Vector2(center.x - outer_offset, center.y),
		outline_color,
		_get_outline_width()
	)
	_draw_segment(
		Vector2(center.x + inner_offset, center.y),
		Vector2(center.x + outer_offset, center.y),
		outline_color,
		_get_outline_width()
	)


func _draw_cross_segments(center: Vector2, draw_color: Color, inner_offset: float, outer_offset: float) -> void:
	if not use_t_shape:
		_draw_segment(
			Vector2(center.x, center.y - inner_offset),
			Vector2(center.x, center.y - outer_offset),
			draw_color
		)

	_draw_segment(
		Vector2(center.x, center.y + inner_offset),
		Vector2(center.x, center.y + outer_offset),
		draw_color
	)

	_draw_segment(
		Vector2(center.x - inner_offset, center.y),
		Vector2(center.x - outer_offset, center.y),
		draw_color
	)
	_draw_segment(
		Vector2(center.x + inner_offset, center.y),
		Vector2(center.x + outer_offset, center.y),
		draw_color
	)


func _draw_ring(center: Vector2, draw_color: Color, inner_offset: float, segment_length: float) -> void:
	var radius := maxf(center_dot_size, inner_offset + (segment_length * 0.5))
	draw_arc(center, radius, 0.0, TAU, 48, draw_color, line_thickness)


func _draw_ring_outline(center: Vector2, outline_color: Color, inner_offset: float, segment_length: float) -> void:
	if outline_color.a <= 0.0:
		return

	var radius := maxf(center_dot_size, inner_offset + (segment_length * 0.5))
	draw_arc(center, radius, 0.0, TAU, 48, outline_color, _get_outline_width())


func _draw_center_dot(center: Vector2, draw_color: Color) -> void:
	var dot_color := draw_color
	dot_color.a *= center_dot_alpha
	draw_circle(center, center_dot_size, dot_color)


func _draw_segment(from: Vector2, to: Vector2, draw_color: Color, width: float = -1.0) -> void:
	draw_line(from, to, draw_color, width if width > 0.0 else line_thickness)


# ============================================
# 公开方法 - 扩散控制
# ============================================

## 射击时扩展准星
func expand_on_shot() -> void:
	# visual-only: 扩散增加，不影响实际弹道精度
	if not enable_dynamic_spread:
		return

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
@warning_ignore("unused_parameter")
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


## 部署开始回调
func _on_deploy_started() -> void:
	# 设置部署状态，仅在状态改变时重绘
	if is_deploying:
		return
	is_deploying = true
	# 清除换弹状态
	is_reloading = false
	queue_redraw()


## 部署结束回调
func _on_deploy_finished() -> void:
	# 清除部署状态，仅在状态改变时重绘
	if not is_deploying:
		return
	is_deploying = false
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
