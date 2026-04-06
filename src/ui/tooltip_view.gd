class_name TooltipView
extends PanelContainer

## Reusable tooltip view component with body-text-only content.
## Handles its own positioning via update_position().
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


func hide_tooltip() -> void:
	hide()


func update_position(target: Control) -> void:
	if not target:
		return

	var viewport_rect := target.get_viewport_rect()
	var target_rect := target.get_global_rect()
	var tooltip_size := get_combined_minimum_size()

	var computed_pos: Vector2 = _compute_position(target_rect, tooltip_size, viewport_rect)
	global_position = computed_pos


func _compute_position(target_rect: Rect2, tooltip_size: Vector2, viewport_rect: Rect2) -> Vector2:
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
		return Vector2(clamp(top_position.x, viewport_left, max_x), top_position.y)

	var bottom_position := Vector2(
		target_rect.position.x + (target_rect.size.x - tooltip_size.x) / 2.0, target_rect.end.y
	)

	if bottom_position.y + tooltip_size.y <= viewport_bottom:
		return Vector2(clamp(bottom_position.x, viewport_left, max_x), bottom_position.y)

	var clamped_x: float = clamp(top_position.x, viewport_left, max_x)

	if top_position.y >= viewport_top:
		return Vector2(clamped_x, clamp(top_position.y, viewport_top, max_y))

	return Vector2(clamped_x, clamp(bottom_position.y, viewport_top, max_y))
