# slider_container_input_handler.gd
# SliderValueInput 容器的滚轮事件处理脚本
# 用于在 ScrollContainer 中阻止滚轮事件冒泡

extends HBoxContainer


func _gui_input(event: InputEvent) -> void:
	var svi = get_meta("slider_value_input")
	if svi == null:
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if (
			mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP
			or mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			# 调用 SliderValueInput 处理滚轮
			if svi._on_container_wheel_event(mouse_event):
				# 阻止事件冒泡到 ScrollContainer
				accept_event()
