class_name HK416Weapon
extends RifleWeapon

# HK416 独立武器脚本
# 基于 RifleWeapon 行为，使用外部素材进行独立显示

const HK416_TEXTURE_PATH := "G:/dev/Assets/Premium Weapon Pack/Tactical Weapon Pack/Tactical Weapon Pack v1.0/images/generic/rifles/wpn_hk416.png"
const HK416_SCALE := Vector2(0.2, 0.2)


func _ready() -> void:
	super._ready()
	_apply_hk416_texture()


func _apply_hk416_texture() -> void:
	var weapon_sprite := get_node_or_null("Sprite2D") as Sprite2D
	if weapon_sprite == null:
		push_warning("HK416 sprite node not found")
		return

	if not FileAccess.file_exists(HK416_TEXTURE_PATH):
		push_warning("HK416 texture not found: %s" % HK416_TEXTURE_PATH)
		return

	var image := Image.new()
	var error := image.load(HK416_TEXTURE_PATH)
	if error != OK:
		push_warning("Failed to load HK416 texture, error code: %d" % error)
		return

	weapon_sprite.texture = ImageTexture.create_from_image(image)
	weapon_sprite.scale = HK416_SCALE
