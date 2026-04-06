class_name LoadingScreen
extends Control

## LoadingScreen - 加载界面
## 显示加载进度和状态，支持淡出动画和错误显示

## 信号
signal fade_complete

## 节点引用
@onready var background: ColorRect = $Background
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var status_label: Label = $VBoxContainer/StatusLabel

## 配置
@export_group("Animation")
@export var fade_duration: float = 0.5

@export_group("Colors")
@export var background_color: Color = Color(0.05, 0.05, 0.08, 0.95)
@export var error_color: Color = Color(1.0, 0.3, 0.3)

## 内部状态
var _original_status_color: Color


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	modulate.a = 1.0

	if status_label:
		_original_status_color = status_label.get_theme_color("font_color")

	visible = false
	print("LoadingScreen initialized")


## 设置进度和状态
func set_progress(progress: float, status: String = "") -> void:
	if progress_bar:
		progress_bar.value = clamp(progress, 0.0, 1.0) * 100.0

	if status_label and not status.is_empty():
		status_label.text = status
		# 重置颜色（如果之前显示过错误）
		if _original_status_color:
			status_label.add_theme_color_override("font_color", _original_status_color)


## 显示加载界面
func show_loading() -> void:
	visible = true
	modulate.a = 1.0

	# 重置进度
	if progress_bar:
		progress_bar.value = 0.0

	if status_label:
		status_label.text = "加载中..."
		if _original_status_color:
			status_label.add_theme_color_override("font_color", _original_status_color)


## 淡出动画
func fade_out() -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(_on_fade_complete)


## 显示错误信息
func show_error(message: String) -> void:
	if status_label:
		status_label.text = "错误: " + message
		status_label.add_theme_color_override("font_color", error_color)

	# 停止进度条动画（如果有的话）
	if progress_bar:
		progress_bar.modulate = Color(1.0, 0.5, 0.5)


## 隐藏加载界面（立即）
func hide_loading() -> void:
	visible = false
	modulate.a = 1.0


## 获取当前进度
func get_progress() -> float:
	if progress_bar:
		return progress_bar.value / 100.0
	return 0.0


## 检查是否显示中
func is_showing() -> bool:
	return visible


## 回调：淡出完成
func _on_fade_complete() -> void:
	visible = false
	modulate.a = 1.0
	fade_complete.emit()
