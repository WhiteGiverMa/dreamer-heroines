extends GutTest

## GUIDE 输入测试基类
## 提供 GUIDE 系统的输入注入辅助方法

var _guide_context: GUIDEMappingContext


func before_all() -> void:
	# 加载并启用游戏玩法上下文
	_guide_context = load("res://config/input/contexts/gameplay_context.tres")
	if _guide_context:
		GUIDE.enable_mapping_context(_guide_context)
	await get_tree().process_frame


func after_all() -> void:
	if _guide_context:
		GUIDE.disable_mapping_context(_guide_context)


## 模拟按键按下
func simulate_key_down(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	GUIDE.inject_input(event)
	await get_tree().process_frame


## 模拟按键释放
func simulate_key_up(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = false
	GUIDE.inject_input(event)
	await get_tree().process_frame


## 模拟按键按下并保持一段时间
func simulate_key_hold(keycode: int, duration: float = 0.1) -> void:
	await simulate_key_down(keycode)
	await wait_seconds(duration)
	await simulate_key_up(keycode)


## 获取玩家节点 (用于测试)
func get_test_player() -> Node:
	return get_tree().get_first_node_in_group("player")
