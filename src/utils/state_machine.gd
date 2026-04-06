class_name StateMachine
extends Node

# StateMachine - 通用状态机
# 用于管理复杂的状态转换逻辑

signal state_changed(from_state: String, to_state: String)
signal state_entered(state_name: String)
signal state_exited(state_name: String)

@export var initial_state: String = ""

var states: Dictionary = {}
var current_state: State = null
var current_state_name: String = ""
var previous_state_name: String = ""


func _ready():
	# 自动收集所有子状态节点
	for child in get_children():
		if child is State:
			_register_state(child)

	if initial_state != "" and states.has(initial_state):
		change_state(initial_state)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func change_state(new_state_name: String, data: Dictionary = {}) -> void:
	if not states.has(new_state_name):
		push_error("State not found: " + new_state_name)
		return

	if current_state_name == new_state_name:
		return

	var new_state = states[new_state_name]

	# 退出当前状态
	if current_state:
		current_state.exit()
		state_exited.emit(current_state_name)

	previous_state_name = current_state_name
	current_state_name = new_state_name
	current_state = new_state

	# 进入新状态
	current_state.enter(data)
	state_entered.emit(new_state_name)
	state_changed.emit(previous_state_name, new_state_name)


func add_state(state: State) -> void:
	_register_state(state)


func remove_state(state_name: String) -> void:
	if states.has(state_name):
		var state = states[state_name]
		if state == current_state:
			push_warning("Cannot remove current state")
			return
		states.erase(state_name)
		remove_child(state)


func get_current_state() -> State:
	return current_state


func get_current_state_name() -> String:
	return current_state_name


func get_previous_state_name() -> String:
	return previous_state_name


func is_in_state(state_name: String) -> bool:
	return current_state_name == state_name


func can_transition_to(state_name: String) -> bool:
	if not current_state:
		return true
	return current_state.can_transition_to(state_name)


func _register_state(state: State) -> void:
	states[state.state_name] = state
	state.state_machine = self


# State 基类
class State:
	extends Node
	var state_name: String = ""
	var state_machine: StateMachine = null

	func _init(name: String = ""):
		state_name = name

	func enter(data: Dictionary = {}) -> void:
		pass

	func exit() -> void:
		pass

	func update(delta: float) -> void:
		pass

	func physics_update(delta: float) -> void:
		pass

	func handle_input(event: InputEvent) -> void:
		pass

	func can_transition_to(state_name: String) -> bool:
		return true

	func change_state(new_state_name: String, data: Dictionary = {}) -> void:
		if state_machine:
			state_machine.change_state(new_state_name, data)
