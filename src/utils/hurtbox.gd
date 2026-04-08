class_name Hurtbox
extends Area2D

const DamageDataClass = preload("res://src/utils/damage_data.gd")

# Hurtbox - 受击判定框
# 用于接收伤害

signal damage_taken(amount: int, knockback: Vector2, source: Node)
signal invulnerability_started
signal invulnerability_ended

@export var health_component: HealthComponent
@export var invulnerability_duration: float = 0.0:
	set(value):
		invulnerability_duration = maxf(value, 0.0)
		_ensure_invulnerability_timer()
@export var damage_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0

var is_invulnerable: bool = false
var invulnerability_timer: Timer


func _ready():
	add_to_group("hittable")
	_ensure_invulnerability_timer()


func _ensure_invulnerability_timer() -> void:
	if not is_inside_tree():
		return

	if invulnerability_duration <= 0.0:
		if invulnerability_timer and is_instance_valid(invulnerability_timer):
			invulnerability_timer.queue_free()
			invulnerability_timer = null
		return

	if invulnerability_timer == null or not is_instance_valid(invulnerability_timer):
		invulnerability_timer = Timer.new()
		invulnerability_timer.one_shot = true
		invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
		add_child(invulnerability_timer)

	invulnerability_timer.wait_time = invulnerability_duration


func apply_damage(damage_data: DamageDataClass) -> void:
	if is_invulnerable or damage_data == null or damage_data.amount <= 0:
		return

	var final_damage = int(damage_data.amount * damage_multiplier)
	var final_knockback = damage_data.knockback * knockback_multiplier
	var final_data := DamageDataClass.new(
		final_damage,
		final_knockback,
		damage_data.source,
		damage_data.causer
	)

	# 如果有HealthComponent，使用它来处理伤害
	if health_component and health_component.has_method("apply_damage"):
		health_component.apply_damage(final_data)
	elif health_component and health_component.has_method("take_damage"):
		health_component.take_damage(final_damage, final_data.source)
	else:
		# 直接通知父节点
		_notify_parent_damage(final_data)

	damage_taken.emit(final_damage, final_knockback, final_data.causer)

	# 启动无敌时间
	if invulnerability_duration > 0:
		start_invulnerability()


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source: Node = null) -> void:
	var damage_source := source
	if source is Area2D and source.get_parent() != null:
		damage_source = source.get_parent()

	apply_damage(DamageDataClass.new(amount, knockback, damage_source, source))


func start_invulnerability() -> void:
	if is_invulnerable:
		return

	is_invulnerable = true
	invulnerability_started.emit()

	if invulnerability_timer:
		invulnerability_timer.start()

	# 视觉反馈
	_flash_sprite()


func stop_invulnerability() -> void:
	if not is_invulnerable:
		return

	is_invulnerable = false
	invulnerability_ended.emit()


func _on_invulnerability_timeout() -> void:
	stop_invulnerability()


func can_take_damage() -> bool:
	return not is_invulnerable


func _notify_parent_damage(damage_data: DamageDataClass) -> void:
	var parent = get_parent()
	if parent == null:
		return

	if parent.has_method("apply_damage"):
		parent.apply_damage(damage_data)
		return

	if parent.has_method("take_damage"):
		parent.take_damage(damage_data.amount, damage_data.knockback)


func _flash_sprite() -> void:
	var parent = get_parent()
	if parent and parent.has_node("Sprite2D"):
		var sprite = parent.get_node("Sprite2D")
		var tween = create_tween()
		sprite.modulate = Color(1, 0.3, 0.3, 0.7)
		tween.tween_property(sprite, "modulate", Color.WHITE, invulnerability_duration)
