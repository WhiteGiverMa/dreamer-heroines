class_name Hitbox
extends Area2D

# Hitbox - 攻击判定框
# 用于检测攻击命中

signal hit_hurtbox(hurtbox: Hurtbox, damage: int)

@export var damage: int = 10
@export var knockback_force: float = 100.0
@export var active_duration: float = 0.1
@export var one_shot: bool = true
@export var damage_cooldown: float = 0.0

var is_active: bool = false
var hit_targets: Array = []
var cooldown_timer: float = 0.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready():
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	disable()

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta

func enable() -> void:
	is_active = true
	hit_targets.clear()
	monitoring = true
	monitorable = true
	if collision_shape:
		collision_shape.disabled = false
	
	if active_duration > 0:
		await get_tree().create_timer(active_duration).timeout
		disable()

func disable() -> void:
	is_active = false
	monitoring = false
	monitorable = false
	if collision_shape:
		collision_shape.disabled = true

func set_damage(new_damage: int) -> void:
	damage = new_damage

func _on_area_entered(area: Area2D) -> void:
	if not is_active:
		return
	
	if area is Hurtbox:
		_try_hit_hurtbox(area)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	
	# 检查身体是否有Hurtbox子节点
	for child in body.get_children():
		if child is Hurtbox:
			_try_hit_hurtbox(child)
			return

func _try_hit_hurtbox(hurtbox: Hurtbox) -> void:
	if cooldown_timer > 0:
		return
	
	if one_shot and hit_targets.has(hurtbox):
		return
	
	if hurtbox.can_take_damage():
		hit_targets.append(hurtbox)
		
		# 计算击退方向
		var knockback_dir = Vector2.ZERO
		if hurtbox.get_parent() is Node2D and get_parent() is Node2D:
			knockback_dir = (hurtbox.get_parent() as Node2D).global_position - (get_parent() as Node2D).global_position
			knockback_dir = knockback_dir.normalized()
		
		hurtbox.take_damage(damage, knockback_dir * knockback_force, self)
		hit_hurtbox.emit(hurtbox, damage)
		
		if damage_cooldown > 0:
			cooldown_timer = damage_cooldown

func clear_hit_targets() -> void:
	hit_targets.clear()
