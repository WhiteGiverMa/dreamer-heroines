class_name HealthComponent
extends Node

const DamageDataClass = preload("res://src/utils/damage_data.gd")

# HealthComponent - 生命值组件
# 可复用的生命值管理系统

signal health_changed(current: int, max: int, change_amount: int)
signal health_depleted
signal damage_taken(amount: int, source: Node)
signal healed(amount: int)
signal invulnerability_started
signal invulnerability_ended

@export var max_health: int = 100:
	set(value):
		max_health = max(1, value)
		current_health = min(current_health, max_health)

@export var invulnerability_duration: float = 0.0
@export var destroy_on_death: bool = false
@export var parent_node: Node = null

var current_health: int = 0
var is_invulnerable: bool = false
var is_dead: bool = false

@onready var invulnerability_timer: Timer = Timer.new()


func _ready():
	current_health = max_health

	# 设置无敌计时器
	if invulnerability_duration > 0:
		add_child(invulnerability_timer)
		invulnerability_timer.one_shot = true
		invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.timeout.connect(_on_invulnerability_timeout)

	if not parent_node:
		parent_node = get_parent()


func apply_damage(damage_data: DamageDataClass) -> void:
	if damage_data == null:
		return

	var amount := damage_data.amount
	if is_invulnerable or is_dead or amount <= 0:
		return

	var previous_health = current_health
	current_health = max(0, current_health - amount)
	var actual_damage = previous_health - current_health

	health_changed.emit(current_health, max_health, -actual_damage)
	damage_taken.emit(actual_damage, damage_data.source)

	if invulnerability_duration > 0:
		start_invulnerability()

	if current_health <= 0:
		_die()


func take_damage(amount: int, source: Node = null) -> void:
	apply_damage(DamageDataClass.new(amount, Vector2.ZERO, source, source))


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return

	var previous_health = current_health
	current_health = min(max_health, current_health + amount)
	var actual_heal = current_health - previous_health

	health_changed.emit(current_health, max_health, actual_heal)
	healed.emit(actual_heal)


func heal_full() -> void:
	heal(max_health)


func start_invulnerability() -> void:
	if is_invulnerable:
		return

	is_invulnerable = true
	invulnerability_started.emit()

	if invulnerability_timer:
		invulnerability_timer.start()


func stop_invulnerability() -> void:
	is_invulnerable = false
	invulnerability_ended.emit()


func _on_invulnerability_timeout() -> void:
	stop_invulnerability()


func _die() -> void:
	is_dead = true
	health_depleted.emit()

	if destroy_on_death and parent_node:
		parent_node.queue_free()


func reset() -> void:
	current_health = max_health
	is_dead = false
	is_invulnerable = false
	health_changed.emit(current_health, max_health, 0)


func get_health_percent() -> float:
	return float(current_health) / float(max_health)


func is_full_health() -> bool:
	return current_health >= max_health


func is_low_health(threshold: float = 0.25) -> bool:
	return get_health_percent() <= threshold


func set_health(value: int) -> void:
	current_health = clamp(value, 0, max_health)
	health_changed.emit(current_health, max_health, 0)

	if current_health <= 0 and not is_dead:
		_die()
