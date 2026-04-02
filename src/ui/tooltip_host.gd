class_name TooltipHost
extends CanvasLayer

const TOOLTIP_LAYER_NAME := "TooltipLayer"

@export var tooltip_view_scene: PackedScene = preload("res://scenes/ui/tooltip_view.tscn")

var current_trigger: Node = null
var current_target: Control = null

var _tooltip_view: Control = null


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

	var host := _resolve_runtime_host()
	if host != self:
		host.show_tooltip(trigger, target, body_text)
		return

	var tooltip_view := _ensure_tooltip_view()
	if tooltip_view == null:
		return

	current_trigger = trigger
	current_target = target

	if tooltip_view.has_method("set_body_text"):
		tooltip_view.call("set_body_text", body_text)

	update_current_tooltip_position()
	tooltip_view.call_deferred("show")


func hide_tooltip() -> void:
	var host := _resolve_runtime_host(false)
	if host != null and host != self:
		host.hide_tooltip()
		return

	current_trigger = null
	current_target = null

	if _tooltip_view == null or not is_instance_valid(_tooltip_view):
		return

	if _tooltip_view.has_method("hide_tooltip"):
		_tooltip_view.call("hide_tooltip")
	else:
		_tooltip_view.hide()

	if _tooltip_view.has_method("set_body_text"):
		_tooltip_view.call("set_body_text", "")


func update_current_tooltip_position() -> void:
	if current_target == null or not is_instance_valid(current_target):
		hide_tooltip()
		return

	var tooltip_view := _ensure_tooltip_view()
	if tooltip_view == null:
		return

	if not current_target.is_inside_tree():
		if tooltip_view.has_method("hide_tooltip"):
			tooltip_view.call("hide_tooltip")
		else:
			tooltip_view.hide()
		return

	if tooltip_view.has_method("update_position"):
		tooltip_view.call("update_position", current_target)
		tooltip_view.call_deferred("show")
		return

	var tooltip_size := tooltip_view.get_combined_minimum_size()
	var tooltip_position := _compute_tooltip_position(
		current_target.get_global_rect(),
		tooltip_size,
		current_target.get_viewport_rect()
	)

	if tooltip_view.has_method("show_at"):
		tooltip_view.call("show_at", tooltip_position)
	else:
		tooltip_view.global_position = tooltip_position
		tooltip_view.call_deferred("show")
func _compute_tooltip_position(target_rect: Rect2, tooltip_size: Vector2, viewport_rect: Rect2) -> Vector2:
	var viewport_left := viewport_rect.position.x
	var viewport_top := viewport_rect.position.y
	var viewport_right := viewport_rect.position.x + viewport_rect.size.x
	var viewport_bottom := viewport_rect.position.y + viewport_rect.size.y
	var max_x: float = max(viewport_left, viewport_right - tooltip_size.x)
	var max_y: float = max(viewport_top, viewport_bottom - tooltip_size.y)

	var top_position := Vector2(
		target_rect.position.x + (target_rect.size.x - tooltip_size.x) / 2.0,
		target_rect.position.y - tooltip_size.y
	)

	if top_position.y >= viewport_top:
		return Vector2(
			clamp(top_position.x, viewport_left, max_x),
			top_position.y
		)

	var bottom_position := Vector2(
		target_rect.position.x + (target_rect.size.x - tooltip_size.x) / 2.0,
		target_rect.end.y
	)

	if bottom_position.y + tooltip_size.y <= viewport_bottom:
		return Vector2(
			clamp(bottom_position.x, viewport_left, max_x),
			bottom_position.y
		)

	var clamped_x: float = clamp(top_position.x, viewport_left, max_x)

	if top_position.y >= viewport_top:
		return Vector2(clamped_x, clamp(top_position.y, viewport_top, max_y))

	return Vector2(clamped_x, clamp(bottom_position.y, viewport_top, max_y))


func _ensure_tooltip_view() -> Control:
	if _tooltip_view != null and is_instance_valid(_tooltip_view):
		return _tooltip_view

	if tooltip_view_scene == null:
		return null

	var tooltip_instance := tooltip_view_scene.instantiate()
	if not tooltip_instance is Control:
		tooltip_instance.queue_free()
		return null

	_tooltip_view = tooltip_instance as Control
	_tooltip_view.visible = false
	add_child(_tooltip_view)
	return _tooltip_view


func _resolve_runtime_host(create_if_missing: bool = true) -> TooltipHost:
	if get_parent() != null:
		return self

	if not is_inside_tree():
		return self

	var tree := get_tree()
	if tree == null:
		return self

	var current_scene := tree.current_scene
	if current_scene == null:
		return self

	var existing_host := current_scene.get_node_or_null(TOOLTIP_LAYER_NAME)
	if existing_host is TooltipHost:
		return existing_host as TooltipHost

	if not create_if_missing:
		return null

	name = TOOLTIP_LAYER_NAME
	current_scene.add_child(self)
	return self
