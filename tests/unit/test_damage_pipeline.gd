extends GutTest


const DamageDataScript = preload("res://src/utils/damage_data.gd")
const DamageSystemScript = preload("res://src/utils/damage_system.gd")
const HealthComponentScript = preload("res://src/utils/health_component.gd")
const HurtboxScript = preload("res://src/utils/hurtbox.gd")
const HitboxScript = preload("res://src/utils/hitbox.gd")
const ProjectileScript = preload("res://src/weapons/projectile.gd")
const PROJECTILE_SCENE_PATH := "res://scenes/weapons/projectile.tscn"
const PLAYER_SCENE_PATH := "res://scenes/player.tscn"
const MELEE_ENEMY_SCENE_PATH := "res://scenes/enemies/melee_enemy.tscn"


func _create_damage_target() -> Dictionary:
	var target := Node2D.new()
	target.name = "Target"

	var health := HealthComponentScript.new() as HealthComponent
	health.max_health = 100

	var hurtbox := HurtboxScript.new() as Hurtbox
	hurtbox.name = "Hurtbox"
	hurtbox.health_component = health

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	hurtbox.add_child(collision_shape)

	target.add_child(health)
	target.add_child(hurtbox)
	add_child_autofree(target)
	return {"target": target, "health": health, "hurtbox": hurtbox}


func _create_hitbox_owner() -> Dictionary:
	var attacker := Node2D.new()
	attacker.name = "Attacker"

	var hitbox := HitboxScript.new() as Hitbox
	hitbox.name = "Hitbox"
	hitbox.active_duration = 0.0

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	hitbox.add_child(collision_shape)

	attacker.add_child(hitbox)
	add_child_autofree(attacker)
	return {"attacker": attacker, "hitbox": hitbox}


func test_damage_system_routes_to_child_hurtbox_and_health_component() -> void:
	var attacker := Node2D.new()
	add_child_autofree(attacker)
	var damage_system: Variant = DamageSystemScript.new()

	var target_setup := _create_damage_target()
	await get_tree().process_frame

	var health := target_setup["health"] as HealthComponent

	var damage_data := DamageDataScript.new(12, Vector2.RIGHT * 30.0, attacker, attacker)
	assert_true(
		bool(damage_system.call("apply_damage", target_setup["target"], damage_data)),
		"DamageSystem should resolve a nested Hurtbox and apply damage"
	)
	assert_eq(health.current_health, 88, "Damage should reduce health through unified pipeline")


func test_hitbox_uses_unified_damage_pipeline() -> void:
	var attacker_setup := _create_hitbox_owner()
	var hitbox := attacker_setup["hitbox"] as Hitbox
	hitbox.damage = 15
	hitbox.knockback_force = 120.0

	var target_setup := _create_damage_target()
	await get_tree().process_frame

	hitbox.enable()
	hitbox._try_hit_hurtbox(target_setup["hurtbox"] as Hurtbox)

	var health := target_setup["health"] as HealthComponent
	assert_eq(health.current_health, 85, "Hitbox should deal damage through DamageSystem/Hurtbox pipeline")


func test_projectile_damage_resolves_target_hurtbox_via_damage_system() -> void:
	var projectile_scene := load(PROJECTILE_SCENE_PATH) as PackedScene
	assert_not_null(projectile_scene, "Projectile scene should load for damage pipeline tests")
	if projectile_scene == null:
		return

	var projectile = projectile_scene.instantiate()
	assert_not_null(projectile, "Projectile scene should instantiate")
	if projectile == null:
		return
	if not projectile.has_method("_deal_damage"):
		projectile.set_script(ProjectileScript)

	add_child_autofree(projectile)

	var attacker := Node2D.new()
	add_child_autofree(attacker)

	var target_setup := _create_damage_target()
	await get_tree().process_frame

	projectile.set("owner_node", attacker)
	projectile.set("damage", 9)
	projectile.set("velocity", Vector2.RIGHT * 100.0)
	projectile.call("_deal_damage", target_setup["target"])

	var health := target_setup["health"] as HealthComponent
	assert_eq(health.current_health, 91, "Projectile should use the unified damage pipeline against hurtbox targets")


func test_player_scene_uses_real_hurtbox_health_pipeline() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	assert_not_null(player_scene, "Player scene should load")
	if player_scene == null:
		return

	var player = player_scene.instantiate()
	assert_not_null(player, "Player scene should instantiate")
	if player == null:
		return

	add_child_autofree(player)
	await get_tree().process_frame

	var damage_system: Variant = DamageSystemScript.new()
	var damage_data := DamageDataScript.new(10, Vector2.LEFT * 50.0, null, null)
	assert_true(
		bool(damage_system.call("apply_damage", player, damage_data)),
		"DamageSystem should resolve the real player scene to its Hurtbox pipeline"
	)
	assert_eq(int(player.get("current_health")), 90, "Player scene should sync current_health through HealthComponent")
	assert_true(player.get_node_or_null("Hurtbox") != null, "Player scene should have a real Hurtbox node")
	assert_true(player.get_node_or_null("HealthComponent") != null, "Player scene should have a real HealthComponent node")


func test_player_scene_invulnerability_expires_and_allows_next_hit() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	assert_not_null(player_scene, "Player scene should load for invulnerability test")
	if player_scene == null:
		return

	var player = player_scene.instantiate()
	assert_not_null(player, "Player scene should instantiate for invulnerability test")
	if player == null:
		return

	add_child_autofree(player)
	await get_tree().process_frame

	var damage_system: Variant = DamageSystemScript.new()
	var damage_data := DamageDataScript.new(10, Vector2.ZERO, null, null)
	assert_true(bool(damage_system.call("apply_damage", player, damage_data)), "First hit should apply")
	assert_eq(int(player.get("current_health")), 90, "First hit should reduce health")

	assert_true(bool(damage_system.call("apply_damage", player, damage_data)), "Second hit should still route")
	assert_eq(int(player.get("current_health")), 90, "Second immediate hit should be blocked by invulnerability")

	await get_tree().create_timer(0.6).timeout
	assert_true(bool(damage_system.call("apply_damage", player, damage_data)), "Third hit should still route after invulnerability")
	assert_eq(int(player.get("current_health")), 80, "Health should drop again after invulnerability expires")


func test_player_scene_heal_and_respawn_sync_with_health_component() -> void:
	var player_scene := load(PLAYER_SCENE_PATH) as PackedScene
	assert_not_null(player_scene, "Player scene should load for heal/respawn test")
	if player_scene == null:
		return

	var player = player_scene.instantiate()
	assert_not_null(player, "Player scene should instantiate for heal/respawn test")
	if player == null:
		return

	add_child_autofree(player)
	await get_tree().process_frame

	var health_component = player.get_node("HealthComponent")
	player.call("apply_damage", DamageDataScript.new(25, Vector2.ZERO, null, null))
	assert_eq(int(player.get("current_health")), 75, "Damage should reduce player root health")
	assert_eq(int(health_component.get("current_health")), 75, "Damage should reduce component health")

	player.heal(10)
	assert_eq(int(player.get("current_health")), 85, "Heal should update player root health")
	assert_eq(int(health_component.get("current_health")), 85, "Heal should update component health")

	player.respawn(Vector2(32, 16))
	assert_eq(int(player.get("current_health")), int(player.get("max_health")), "Respawn should restore root health")
	assert_eq(
		int(health_component.get("current_health")),
		int(player.get("max_health")),
		"Respawn should restore component health"
	)


func test_enemy_scene_uses_real_hurtbox_health_pipeline() -> void:
	var enemy_scene := load(MELEE_ENEMY_SCENE_PATH) as PackedScene
	assert_not_null(enemy_scene, "Melee enemy scene should load")
	if enemy_scene == null:
		return

	var enemy = enemy_scene.instantiate()
	assert_not_null(enemy, "Melee enemy scene should instantiate")
	if enemy == null:
		return

	add_child_autofree(enemy)
	await get_tree().process_frame
	var initial_health := int(enemy.get("current_health"))

	var damage_system: Variant = DamageSystemScript.new()
	var damage_data := DamageDataScript.new(10, Vector2.RIGHT * 50.0, null, null)
	assert_true(
		bool(damage_system.call("apply_damage", enemy, damage_data)),
		"DamageSystem should resolve the real enemy scene to its Hurtbox pipeline"
	)
	assert_eq(
		int(enemy.get("current_health")),
		initial_health - 10,
		"Enemy scene should sync current_health through HealthComponent"
	)
	assert_true(enemy.get_node_or_null("Hurtbox") != null, "Enemy scene should have a real Hurtbox node")
	assert_true(enemy.get_node_or_null("HealthComponent") != null, "Enemy scene should have a real HealthComponent node")
