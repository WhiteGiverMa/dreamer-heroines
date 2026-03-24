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
var owner_node: Node2D = null

## 阵营类型（使用 Faction 枚举）- 延迟初始化
var faction_type: int = 0  # 默认值，在 _ready() 中设置

## 向后兼容：faction 字符串属性
var faction: String:
	get:
		return Faction.type_to_string(faction_type)
	set(value):
		faction_type = Faction.string_to_type(value)
		_update_collision_mask()
var pierced_targets: Array = []
var current_pierces: int = 0
var _is_active: bool = false
var _has_entered_screen: bool = false

# Backward compatibility: owner_player is an alias for owner_node
var owner_player: Node2D:
	get:
		return owner_node
	set(value):
		owner_node = value

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: GPUParticles2D = $Trail
@onready var lifetime_timer: Timer = $LifetimeTimer
var screen_notifier: VisibleOnScreenNotifier2D = null

func _ready():
	# 确保阵营已初始化
	if faction_type == 0:
		faction_type = Faction.Type.PLAYER

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not lifetime_timer.timeout.is_connected(_on_lifetime_timeout):
		lifetime_timer.timeout.connect(_on_lifetime_timeout)

	screen_notifier = get_node_or_null("VisibleOnScreenNotifier2D")
	if screen_notifier:
		if not screen_notifier.screen_entered.is_connected(_on_screen_entered):
			screen_notifier.screen_entered.connect(_on_screen_entered)
		if not screen_notifier.screen_exited.is_connected(_on_screen_exited):
			screen_notifier.screen_exited.connect(_on_screen_exited)

	# 对象池模式：实例创建后默认进入非激活状态
	deactivate_for_pool()


## 根据阵营动态设置碰撞掩码
func _update_collision_mask() -> void:
	collision_mask = Faction.get_projectile_collision_mask(faction_type)


## 发射投射物（由 ProjectileSpawner 调用）
## 用于对象池模式：重新初始化投射物状态
func fire() -> void:
	_is_active = true
	visible = true
	call_deferred("_apply_active_state")

	velocity = direction * speed
	rotation = direction.angle()
	_update_collision_mask()

	if lifetime_timer:
		lifetime_timer.stop()
		lifetime_timer.wait_time = lifetime
		lifetime_timer.start()

	if trail:
		trail.emitting = false
		trail.restart()
		trail.emitting = true

	_has_entered_screen = false

	# 重置穿透计数
	current_pierces = 0
	pierced_targets.clear()


func _apply_active_state() -> void:
	if not _is_active:
		return
	if not is_inside_tree():
		return

	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_physics_process(true)
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)


func _apply_pool_disabled_state() -> void:
	if _is_active:
		return
	if not is_inside_tree():
		return

	process_mode = Node.PROCESS_MODE_DISABLED
	set_physics_process(false)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func deactivate_for_pool() -> void:
	_is_active = false
	_has_entered_screen = false
	visible = false
	velocity = Vector2.ZERO
	call_deferred("_apply_pool_disabled_state")

	if lifetime_timer:
		lifetime_timer.stop()

	if trail:
		trail.emitting = false


func is_available_for_pool() -> bool:
	return is_inside_tree() and not _is_active


func is_pool_active() -> bool:
	return _is_active

func _physics_process(delta: float) -> void:
	if not _is_active:
		return

	if gravity_affected:
		velocity.y += gravity_strength * delta
		rotation = velocity.angle()
	
	position += velocity * delta

func _is_valid_target(body: Node2D) -> bool:
	"""Check if body is a valid target based on faction."""
	var target_type := Faction.get_target_type(faction_type)

	if target_type == Faction.Type.PLAYER:
		return body.is_in_group("player")
	if target_type == Faction.Type.ENEMY:
		return body.is_in_group("enemy")
	return false

func _on_body_entered(body: Node2D) -> void:
	if not _is_active:
		return

	if body == owner_node:
		return
	
	if _is_valid_target(body):
		_deal_damage(body)
		
		if pierce_count > 0 and current_pierces < pierce_count:
			current_pierces += 1
			pierced_targets.append(body)
			return
		
		_impact()
	elif body.is_in_group("ground") or body.collision_layer & 8 != 0:
		_impact()

func _on_area_entered(area: Area2D) -> void:
	if not _is_active:
		return

	if area.owner == owner_node:
		return
	
	if area.is_in_group("hittable") and _is_valid_target(area):
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

	_recycle_to_pool()

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
	var effect_manager = get_tree().get_root().get_node_or_null("EffectManager")
	if effect_manager:
		effect_manager.play_hit_effect(global_position, true)

func _spawn_impact_effect() -> void:
	# 使用 EffectManager 播放撞击特效
	var effect_manager = get_tree().get_root().get_node_or_null("EffectManager")
	if effect_manager:
		effect_manager.play_impact_effect(global_position, true)

func _on_lifetime_timeout() -> void:
	_recycle_to_pool()


func _on_screen_entered() -> void:
	if _is_active:
		_has_entered_screen = true


func _on_screen_exited() -> void:
	if _is_active and _has_entered_screen:
		_recycle_to_pool()


func _recycle_to_pool() -> void:
	if not _is_active:
		return

	if not is_inside_tree():
		queue_free()
		return

	deactivate_for_pool()

	var spawner = get_tree().get_root().get_node_or_null("ProjectileSpawner")
	if spawner and spawner.has_method("return_to_pool"):
		spawner.return_to_pool(self)
	else:
		queue_free()
