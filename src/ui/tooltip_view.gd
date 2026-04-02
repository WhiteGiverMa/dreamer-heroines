class_name TooltipView
extends PanelContainer

## Reusable tooltip view component with body-text-only content.
## Handles its own positioning via show_at() and update_position().
## Mouse-filter ignore prevents stealing hover from target controls.

@onready var _body_label: Label = %BodyLabel

var _body_text_content: String = ""


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_apply_default_style()
	if _body_label:
		_body_label.text = _body_text_content


func _apply_default_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.96)
	style.border_color = Color(0.35, 0.35, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)


func set_body_text(text: String) -> void:
	_body_text_content = text
	if _body_label:
		_body_label.text = text


func get_body_text() -> String:
	return _body_text_content


func show_at(screen_position: Vector2) -> void:
	global_position = screen_position
	show()


func hide_tooltip() -> void:
	hide()


func update_position(target: Control) -> void:
	if not target:
		return

	var viewport_size := target.get_viewport_rect().size
	var target_rect := target.get_global_rect()
	var tooltip_size := get_combined_minimum_size()

	var computed_pos: Vector2 = _compute_position(target_rect, tooltip_size, viewport_size)
	global_position = computed_pos


func _compute_position(target_rect: Rect2, tooltip_size: Vector2, viewport_size: Vector2) -> Vector2:
	# Try top-center placement first (above target, horizontally centered)
	var top_position := Vector2(
		target_rect.position.x + (target_rect.size.x - tooltip_size.x) / 2.0,
		target_rect.position.y - tooltip_size.y
	)

	# Check if top placement stays within viewport
	if top_position.y >= 0:
		return top_position

	# Fallback to bottom-center placement (below target, horizontally centered)
	var bottom_position := Vector2(
		target_rect.position.x + (target_rect.size.x - tooltip_size.x) / 2.0,
		target_rect.end.y
	)

	# Check if bottom placement stays within viewport
	if bottom_position.y + tooltip_size.y <= viewport_size.y:
		return bottom_position

	# Viewport clamp: ensure tooltip stays within horizontal bounds
	var clamped_x: float = clamp(top_position.x, 0, viewport_size.x - tooltip_size.x)

	# Use whichever vertical position (top or bottom) is closer to viewport
	var use_top: bool = top_position.y >= 0 or (bottom_position.y + tooltip_size.y > viewport_size.y)

	if use_top:
		return Vector2(clamped_x, max(0, top_position.y))
	else:
		return Vector2(clamped_x, bottom_position.y)
