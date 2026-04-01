@tool
class_name HK416Weapon
extends RifleWeapon

# HK416 独立武器脚本
# 使用 @tool + @export 模式实现编辑器预览和调参
# 所有视觉参数可在 Inspector 中配置

# === 导出属性 ===

## 武器贴图 - 拖入 res:// 格式的纹理资源
@export var weapon_texture: Texture2D:
	set(value):
		weapon_texture = value
		_queue_visual_refresh()

## 武器缩放 - 控制贴图显示大小
@export var weapon_scale: Vector2 = Vector2(0.2, 0.2):
	set(value):
		weapon_scale = value
		_queue_visual_refresh()

## 贴图偏移 - Sprite2D 相对武器原点的偏移
@export var texture_offset: Vector2 = Vector2.ZERO:
	set(value):
		texture_offset = value
		_queue_visual_refresh()

## 枪口位置 - 子弹发射点
@export var muzzle_position: Vector2 = Vector2(35, 0):
	set(value):
		muzzle_position = value
		if _syncing_from_scene_nodes:
			return
		_queue_visual_refresh()

## 弹壳抛出口位置 - 弹壳抛出点
@export var ejection_port_position: Vector2 = Vector2(-10, -8):
	set(value):
		ejection_port_position = value
		if _syncing_from_scene_nodes:
			return
		_queue_visual_refresh()

# === 节点引用 ===

var _weapon_sprite: Sprite2D = null
var _muzzle_marker: Marker2D = null
var _ejection_port_marker: Marker2D = null
var _visual_refresh_queued: bool = false
var _initial_sprite_texture: Texture2D = null
var _syncing_from_scene_nodes: bool = false

# === 生命周期 ===


func _enter_tree() -> void:
	_queue_visual_refresh()


func _ready() -> void:
	super._ready()
	_queue_visual_refresh()


func _process(delta: float) -> void:
	super._process(delta)

	if not Engine.is_editor_hint():
		return

	_sync_exported_positions_from_scene_nodes()


func _cache_node_references() -> void:
	_weapon_sprite = get_node_or_null("Sprite2D") as Sprite2D
	_muzzle_marker = get_node_or_null("Muzzle") as Marker2D
	_ejection_port_marker = get_node_or_null("EjectionPort") as Marker2D

	if _weapon_sprite and _initial_sprite_texture == null:
		_initial_sprite_texture = _weapon_sprite.texture


# === 应用视觉属性 ===


func _apply_all_visual_properties() -> void:
	_cache_node_references()
	_apply_sprite_texture()
	_apply_sprite_scale()
	_apply_sprite_offset()

	if Engine.is_editor_hint():
		_apply_muzzle_position()
		_apply_ejection_port_position()
	else:
		_capture_runtime_positions_from_scene_nodes()


func _queue_visual_refresh() -> void:
	if not is_inside_tree():
		return

	if _visual_refresh_queued:
		return

	_visual_refresh_queued = true
	call_deferred("_refresh_visual_properties")


func _refresh_visual_properties() -> void:
	_visual_refresh_queued = false

	if not is_inside_tree():
		return

	_apply_all_visual_properties()


func _apply_sprite_texture() -> void:
	if _weapon_sprite == null:
		return

	if weapon_texture == null:
		_weapon_sprite.texture = _initial_sprite_texture
		return

	_weapon_sprite.texture = weapon_texture


func _apply_sprite_scale() -> void:
	if _weapon_sprite == null:
		return

	_weapon_sprite.scale = weapon_scale


func _apply_sprite_offset() -> void:
	if _weapon_sprite == null:
		return

	_weapon_sprite.offset = texture_offset


func _apply_muzzle_position() -> void:
	if _muzzle_marker == null:
		return

	_muzzle_marker.position = muzzle_position


func _apply_ejection_port_position() -> void:
	if _ejection_port_marker == null:
		return

	_ejection_port_marker.position = ejection_port_position


func _sync_exported_positions_from_scene_nodes() -> void:
	_cache_node_references()

	if _muzzle_marker == null or _ejection_port_marker == null:
		return

	if (
		_muzzle_marker.position == muzzle_position
		and _ejection_port_marker.position == ejection_port_position
	):
		return

	_syncing_from_scene_nodes = true
	muzzle_position = _muzzle_marker.position
	ejection_port_position = _ejection_port_marker.position
	_syncing_from_scene_nodes = false


func _capture_runtime_positions_from_scene_nodes() -> void:
	_cache_node_references()

	if _muzzle_marker == null or _ejection_port_marker == null:
		return

	_syncing_from_scene_nodes = true
	muzzle_position = _muzzle_marker.position
	ejection_port_position = _ejection_port_marker.position
	_syncing_from_scene_nodes = false


# === 工具方法 ===


## 获取枪口世界坐标（重写以支持动态位置）
func get_muzzle_position() -> Vector2:
	if _muzzle_marker:
		return _muzzle_marker.global_position
	return global_position


## 获取弹壳抛出口世界坐标
func get_ejection_port_world_position() -> Vector2:
	if _ejection_port_marker:
		return _ejection_port_marker.global_position
	return global_position
