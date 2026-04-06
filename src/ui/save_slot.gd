class_name SaveSlot
extends PanelContainer

## SaveSlot - 存档槽位组件
## 显示单个存档槽位的状态（空/已占用）
## 用于加载游戏菜单

# 信号
signal slot_clicked(slot_index: int)  # 点击槽位主区域时触发
signal load_requested(slot_index: int)  # 点击加载按钮时触发
signal delete_requested(slot_index: int)  # 点击删除按钮时触发

# 公共属性
var slot_index: int = 0
var is_occupied: bool = false

# 私有属性 - 节点引用
@onready var _slot_number_label: Label = $HBoxContainer/SlotNumber
@onready var _level_label: Label = $HBoxContainer/SlotInfo/LevelLabel
@onready var _time_label: Label = $HBoxContainer/SlotInfo/TimeLabel
@onready var _load_button: Button = $HBoxContainer/LoadButton
@onready var _delete_button: Button = $HBoxContainer/DeleteButton

# 颜色常量
const EMPTY_BG_COLOR := Color(0.15, 0.15, 0.18)
const OCCUPIED_BG_COLOR := Color(0.2, 0.22, 0.25)
const EMPTY_TEXT_COLOR := Color(0.5, 0.5, 0.5)
const OCCUPIED_TEXT_COLOR := Color(1.0, 1.0, 1.0)


func _ready() -> void:
	# 连接按钮信号
	if _load_button:
		_load_button.pressed.connect(_on_load_button_pressed)
	if _delete_button:
		_delete_button.pressed.connect(_on_delete_button_pressed)
	if LocalizationManager:
		LocalizationManager.locale_changed.connect(_on_locale_changed)

	# 连接面板点击信号 (通过 gui_input)
	gui_input.connect(_on_gui_input)

	# 初始化为空状态
	_set_empty_state()


## 设置槽位 - 主入口方法
## summary 格式: {slot_index, has_save, level_name, save_time, play_time}
func setup(summary: Dictionary, index: int) -> void:
	slot_index = index

	if summary.get("has_save", false):
		is_occupied = true
		_set_occupied_state(summary)
	else:
		is_occupied = false
		_set_empty_state()


## 设置空槽位状态
func _set_empty_state() -> void:
	# 背景色
	var style := StyleBoxFlat.new()
	style.bg_color = EMPTY_BG_COLOR
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	# 虚线边框效果（通过较暗的边框模拟）
	style.border_color = Color(0.25, 0.25, 0.3)
	add_theme_stylebox_override("panel", style)

	# 槽位编号
	if _slot_number_label:
		_slot_number_label.text = LocalizationManager.call(
			"tr", "ui.save_slot.slot_number", {"slot": slot_index + 1}
		)
		_slot_number_label.add_theme_color_override("font_color", EMPTY_TEXT_COLOR)

	# 关卡名称
	if _level_label:
		_level_label.text = LocalizationManager.tr("ui.save_slot.empty")
		_level_label.add_theme_color_override("font_color", EMPTY_TEXT_COLOR)

	# 时间标签隐藏
	if _time_label:
		_time_label.visible = false

	# 加载按钮
	if _load_button:
		_load_button.text = LocalizationManager.tr("ui.save_slot.button.start_game")
		_load_button.disabled = false

	# 删除按钮隐藏
	if _delete_button:
		_delete_button.visible = false


## 设置已占用槽位状态
func _set_occupied_state(summary: Dictionary) -> void:
	# 背景色
	var style := StyleBoxFlat.new()
	style.bg_color = OCCUPIED_BG_COLOR
	style.border_color = Color(0.4, 0.45, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)

	# 槽位编号
	if _slot_number_label:
		_slot_number_label.text = LocalizationManager.call(
			"tr", "ui.save_slot.slot_number", {"slot": slot_index + 1}
		)
		_slot_number_label.add_theme_color_override("font_color", OCCUPIED_TEXT_COLOR)

	# 关卡名称
	if _level_label:
		var level_name = summary.get(
			"level_name", LocalizationManager.tr("ui.save_slot.unknown_level")
		)
		_level_label.text = level_name
		_level_label.add_theme_color_override("font_color", OCCUPIED_TEXT_COLOR)

	# 时间标签显示
	if _time_label:
		_time_label.visible = true
		var play_time_seconds = summary.get("play_time", 0)
		var formatted_time = _format_play_time(play_time_seconds)
		_time_label.text = LocalizationManager.call(
			"tr", "ui.save_slot.play_time", {"time": formatted_time}
		)
		_time_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	# 加载按钮
	if _load_button:
		_load_button.text = LocalizationManager.tr("ui.save_slot.button.load")
		_load_button.disabled = false

	# 删除按钮显示
	if _delete_button:
		_delete_button.visible = true
		_delete_button.disabled = false


## 格式化游戏时间
## 将秒数转换为 "X小时Y分" 或 "X分Y秒" 格式
func _format_play_time(seconds: int) -> String:
	if seconds <= 0:
		return LocalizationManager.call("tr", "ui.save_slot.time.minutes", {"minutes": 0})

	@warning_ignore("integer_division")
	var hours: int = seconds / 3600
	@warning_ignore("integer_division")
	var minutes: int = (seconds % 3600) / 60
	var secs: int = seconds % 60

	if hours > 0:
		return LocalizationManager.call(
			"tr", "ui.save_slot.time.hours_minutes", {"hours": hours, "minutes": minutes}
		)
	elif minutes > 0:
		return LocalizationManager.call(
			"tr", "ui.save_slot.time.minutes_seconds", {"minutes": minutes, "seconds": secs}
		)
	else:
		return LocalizationManager.call("tr", "ui.save_slot.time.seconds", {"seconds": secs})


@warning_ignore("unused_parameter")
func _on_locale_changed(__new_locale: String) -> void:
	if is_occupied:
		_set_occupied_state(SaveManager.get_save_summary(slot_index))
	else:
		_set_empty_state()


## 加载按钮点击回调
func _on_load_button_pressed() -> void:
	load_requested.emit(slot_index)


## 删除按钮点击回调
func _on_delete_button_pressed() -> void:
	delete_requested.emit(slot_index)


## 面板点击回调（点击非按钮区域）
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# 检查点击是否在按钮区域外
			var in_load_button := false
			var in_delete_button := false

			if (
				_load_button
				and _load_button.get_global_rect().has_point(get_global_mouse_position())
			):
				in_load_button = true
			if (
				_delete_button
				and _delete_button.visible
				and _delete_button.get_global_rect().has_point(get_global_mouse_position())
			):
				in_delete_button = true

			if not in_load_button and not in_delete_button:
				slot_clicked.emit(slot_index)
