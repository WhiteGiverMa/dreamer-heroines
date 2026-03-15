class_name Projectile
extends Area2D

# Projectile - 投射物基类
# 子弹、火箭等飞行物的基础实现

@export var speed: float = 1000.0
@export var damage: int = 10
@export var lifetime: float = 3.0
@export var gravity_affected: bool = false
@export var gravity_strength: float = 500.0
@export var pierce_count: int = 0  # 穿透次数，0表示不穿透
@export var explosion_radius: float = 0.0  # 爆炸半径，0表示不爆炸
@export var explosion_damage: int = 0

var direction: Vector2 = Vector2.RIGHT
var velocity: Vector2 = Vector2.ZERO
var owner_player: Node2D = null
var pierced_targets: Array = []
var current_pierces: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: GPUParticles2D = $Trail
@onready var lifetime_timer: Timer = $LifetimeTimer

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	velocity = direction * speed
	
	lifetime_timer.wait_time = lifetime
	lifetime_timer.timeout.connect(_on_lifetime_timeout)
	lifetime_timer.start()
	
	# 旋转精灵以匹配方向
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	if gravity_affected:
		velocity.y += gravity_strength * delta
		rotation = velocity.angle()
	
	position += velocity * delta

func _on_body_entered(body: Node2D) -> void:
	if body == owner_player:
		return
	
	if body.is_in_group("enemy"):
		_deal_damage(body)
		
		if pierce_count > 0 and current_pierces < pierce_count:
			current_pierces += 1
			pierced_targets.append(body)
			return
		
		_impact()
	elif body.is_in_group("ground") or body.collision_layer & 8 != 0:
		_impact()

func _on_area_entered(area: Area2D) -> void:
	if area.owner == owner_player:
		return
	
	if area.is_in_group("hittable"):
		_deal_damage(area)
		_impact()

func _deal_damage(target) -> void:
	if target.has_method("take_damage"):
		target.take_damage(damage, velocity.normalized() * 100)
	
	# 创建命中特效
	_spawn_hit_effect()

func _impact() -> void:
	if explosion_radius > 0:
		_explode()
	
	# 创建撞击特效
	_spawn_impact_effect()
	
	queue_free()

func _explode() -> void:
	# 爆炸伤害
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	query.shape = circle
	query.transform = global_transform
	query.collision_mask = 0b1110  # 敌人、世界、玩家
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var body = result.collider
		if body.has_method("take_damage"):
			var distance = global_position.distance_to(body.global_position)
			var damage_factor = 1.0 - (distance / explosion_radius)
			var final_damage = int(explosion_damage * damage_factor)
			body.take_damage(final_damage, (body.global_position - global_position).normalized() * 200)

func _spawn_hit_effect() -> void:
	# 使用 EffectManager 播放命中特效
	if EffectManager:
		EffectManager.play_hit_effect(global_position, true)

func _spawn_impact_effect() -> void:
	# 使用 EffectManager 播放撞击特效
	if EffectManager:
		EffectManager.play_impact_effect(global_position, true)

func _on_lifetime_timeout() -> void:
	queue_free()
