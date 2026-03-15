class_name Hurtbox
extends Area2D

# Hurtbox - 受击判定框
# 用于接收伤害

signal damage_taken(amount: int, knockback: Vector2, source: Hitbox)
signal invulnerability_started
signal invulnerability_ended

@export var health_component: HealthComponent
@export var invulnerability_duration: float = 0.0
@export var damage_multiplier: float = 1.0
@export var knockback_multiplier: float = 1.0

var is_invulnerable: bool = false
var invulnerability_timer: Timer

func _ready():
	# 确保碰撞层设置正确
	collision_layer = 0
	collision_mask = 0
	
	# 设置无敌计时器
	if invulnerability_duration > 0:
		invulnerability_timer = Timer.new()
		invulnerability_timer.one_shot = true
		invulnerability_timer.wait_time = invulnerability_duration
		invulnerability_timer.timeout.connect(_on_invulnerability_timeout)
		add_child(invulnerability_timer)

func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO, source: Hitbox = null) -> void:
	if is_invulnerable:
		return
	
	var final_damage = int(amount * damage_multiplier)
	var final_knockback = knockback * knockback_multiplier
	
	# 如果有HealthComponent，使用它来处理伤害
	if health_component:
		var damage_source = source.get_parent() if source else null
		health_component.take_damage(final_damage, damage_source)
	else:
		# 直接通知父节点
		_notify_parent_damage(final_damage, final_knockback, source)
	
	damage_taken.emit(final_damage, final_knockback, source)
	
	# 启动无敌时间
	if invulnerability_duration > 0:
		start_invulnerability()

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
	is_invulnerable = false
	invulnerability_ended.emit()

func _on_invulnerability_timeout() -> void:
	stop_invulnerability()

func can_take_damage() -> bool:
	return not is_invulnerable

func _notify_parent_damage(amount: int, knockback: Vector2, source: Hitbox) -> void:
	var parent = get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(amount, knockback)

func _flash_sprite() -> void:
	var parent = get_parent()
	if parent and parent.has_node("Sprite2D"):
		var sprite = parent.get_node("Sprite2D")
		var tween = create_tween()
		sprite.modulate = Color(1, 0.3, 0.3, 0.7)
		tween.tween_property(sprite, "modulate", Color.WHITE, invulnerability_duration)
