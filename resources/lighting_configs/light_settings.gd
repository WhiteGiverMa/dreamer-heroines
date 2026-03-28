class_name LightSettings
extends Resource

# LightSettings - 光照配置资源
# 存储灯光的静态属性数据

@export_group("Light Properties")
@export var color: Color = Color.WHITE
@export_range(0.5, 2.0, 0.1) var energy: float = 1.0
@export var texture: Texture2D = null
@export var range: float = 200.0
@export var shadows_enabled: bool = false
@export_range(1, 3, 1) var priority: int = 1

func _init() -> void:
	resource_name = "LightSettings"