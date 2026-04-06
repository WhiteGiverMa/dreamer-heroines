class_name Checkpoint
extends Area2D

# Checkpoint - 检查点系统
# 玩家触碰后激活，死亡后从此重生

signal checkpoint_activated(checkpoint: Checkpoint)
signal checkpoint_unlocked(checkpoint: Checkpoint)

@export_group("Checkpoint Settings")
@export var checkpoint_id: String = ""
@export var checkpoint_name: String = "检查点"
@export var is_unlocked: bool = false
@export var is_active: bool = false
@export var one_time_use: bool = false

@export_group("Visual")
@export var active_color: Color = Color(0.2, 0.8, 0.2, 1.0)
@export var inactive_color: Color = Color(0.5, 0.5, 0.5, 1.0)
@export var locked_color: Color = Color(0.8, 0.2, 0.2, 1.0)

@export_group("Effects")
@export var activation_effect: PackedScene
@export var heal_on_activate: bool = true
@export var heal_amount: int = 25
@export var restore_ammo: bool = true
@export var ammo_restore_percent: float = 0.3

var respawn_position: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var particles: GPUParticles2D = $Particles
@onready var label: Label = $Label


func _ready() -> void:
	# 设置碰撞层
	collision_layer = 0
	collision_mask = 1  # 只检测玩家层

	# 连接信号
	body_entered.connect(_on_body_entered)

	# 初始化位置
	respawn_position = global_position + Vector2(0, -20)

	# 更新视觉
	_update_visual()

	# 更新标签
	if label:
		label.text = checkpoint_name
		label.visible = false

	# 如果初始就是解锁的，确保状态正确
	if is_unlocked and not is_active:
		_update_visual()


func _update_visual() -> void:
	if not sprite:
		return

	if not is_unlocked:
		sprite.modulate = locked_color
		if animation_player:
			animation_player.play("locked")
	elif is_active:
		sprite.modulate = active_color
		if animation_player:
			animation_player.play("active")
	else:
		sprite.modulate = inactive_color
		if animation_player:
			animation_player.play("inactive")


func unlock() -> void:
	if is_unlocked:
		return

	is_unlocked = true
	_update_visual()
	checkpoint_unlocked.emit(self)

	# 播放解锁特效
	_play_effect()
	AudioManager.play_sfx("checkpoint_unlock")


func activate() -> void:
	if not is_unlocked or is_active:
		return

	is_active = true
	_update_visual()
	checkpoint_activated.emit(self)

	# 播放激活特效
	_play_effect()
	AudioManager.play_sfx("checkpoint_activate")

	# 显示标签
	if label:
		label.visible = true
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 2.0).from(1.0)
		tween.tween_callback(func(): label.visible = false)

	# 通知LevelManager
	if LevelManager and LevelManager.current_level:
		LevelManager.set_active_checkpoint(self)


func deactivate() -> void:
	is_active = false
	_update_visual()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return

	if not is_unlocked:
		# 尝试解锁
		if _can_unlock():
			unlock()
		else:
			return

	if is_unlocked and not is_active:
		activate()

		# 治疗玩家
		if heal_on_activate and body.has_method("heal"):
			body.heal(heal_amount)

		# 恢复弹药
		if restore_ammo and body.has_method("restore_ammo"):
			body.restore_ammo(ammo_restore_percent)


func _can_unlock() -> bool:
	# 默认检查点可以直接解锁
	# 子类可以覆盖此方法添加自定义解锁条件
	return true


func _play_effect() -> void:
	if activation_effect:
		var effect = activation_effect.instantiate()
		get_tree().current_scene.add_child(effect)
		effect.global_position = global_position

	if particles:
		particles.emitting = true


func get_respawn_position() -> Vector2:
	return respawn_position


func save_state() -> Dictionary:
	return {"checkpoint_id": checkpoint_id, "is_unlocked": is_unlocked, "is_active": is_active}


func load_state(data: Dictionary) -> void:
	checkpoint_id = data.get("checkpoint_id", checkpoint_id)
	is_unlocked = data.get("is_unlocked", is_unlocked)
	is_active = data.get("is_active", is_active)
	_update_visual()
