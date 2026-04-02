class_name TooltipHost
extends CanvasLayer

const TOOLTIP_LAYER_NAME := "TooltipLayer"
const TooltipViewClass = preload("res://src/ui/tooltip_view.gd")

@export var tooltip_view_scene: PackedScene = preload("res://scenes/ui/tooltip_view.tscn")

var current_trigger: Node = null
var current_target: Control = null

var _tooltip_view: TooltipView = null


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if current_target == null or not is_instance_valid(current_target):
		return

	update_current_tooltip_position()


func show_tooltip(trigger: Node, target: Control, body_text: String) -> void:
	if target == null or not is_instance_valid(target):
		return

	var tooltip_view := _ensure_tooltip_view()
	if tooltip_view == null:
		return

	current_trigger = trigger
	current_target = target
	tooltip_view.set_body_text(body_text)

	update_current_tooltip_position()
	tooltip_view.call_deferred("show")


func hide_tooltip() -> void:
	current_trigger = null
	current_target = null

	if _tooltip_view == null or not is_instance_valid(_tooltip_view):
		return

	_tooltip_view.hide_tooltip()
	_tooltip_view.set_body_text("")


func update_current_tooltip_position() -> void:
	if current_target == null or not is_instance_valid(current_target):
		hide_tooltip()
		return

	var tooltip_view := _ensure_tooltip_view()
	if tooltip_view == null:
		return

	if not current_target.is_inside_tree():
		tooltip_view.hide_tooltip()
		return

	tooltip_view.update_position(current_target)
	tooltip_view.call_deferred("show")


func _ensure_tooltip_view() -> TooltipView:
	if _tooltip_view != null and is_instance_valid(_tooltip_view):
		return _tooltip_view

	if tooltip_view_scene == null:
		return null

	var tooltip_instance := tooltip_view_scene.instantiate()
	if not tooltip_instance is TooltipViewClass:
		tooltip_instance.queue_free()
		return null

	_tooltip_view = tooltip_instance as TooltipView
	_tooltip_view.visible = false
	_tooltip_view.name = "TooltipView"
	add_child(_tooltip_view)
	return _tooltip_view
