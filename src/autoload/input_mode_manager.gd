# src/autoload/input_mode_manager.gd
# 注意：不使用 class_name，因为与 autoload 名称冲突
extends Node

## 平台检测和输入模式管理单例

#region 信号
signal input_mode_changed(mode: int)
#endregion

#region 枚举
enum InputMode { PC, MOBILE }
#endregion

#region 属性
## 是否为移动平台（Android/iOS/Web）
var is_mobile_platform: bool:
	get:
		return _is_mobile_platform

var _is_mobile_platform: bool = false

## 当前输入模式
var input_mode: InputMode:
	get:
		return _input_mode

var _input_mode: InputMode = InputMode.PC
#endregion

#region 单例
static var instance: Node
#endregion


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_detect_platform()


func _detect_platform() -> void:
	var os_name := OS.get_name()
	_is_mobile_platform = os_name in ["Android", "iOS", "Web"]

	if _is_mobile_platform:
		_input_mode = InputMode.MOBILE
	else:
		_input_mode = InputMode.PC

	print("[InputModeManager] 平台检测: %s, 移动端: %s, 模式: %s" % [
		os_name,
		_is_mobile_platform,
		_input_mode
	])


## 设置移动端模式
func set_mobile_mode(enabled: bool) -> void:
	var new_mode := InputMode.MOBILE if enabled else InputMode.PC

	if new_mode == _input_mode:
		return

	_input_mode = new_mode
	input_mode_changed.emit(_input_mode)
	print("[InputModeManager] 模式切换: %s" % _input_mode)


## 检查当前是否为移动端模式
func is_mobile_mode() -> bool:
	return _input_mode == InputMode.MOBILE