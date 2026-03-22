class_name WeaponStats
extends Resource

# WeaponStats - 武器数据配置
# 存储武器的静态属性数据，与逻辑分离

@export_group("Basic Info")
@export var weapon_id: String = ""
@export var weapon_name: String = "未命名武器"
@export var description: String = ""

@export_group("Combat Stats")
@export var damage: float = 10.0
@export var fire_rate: float = 1.0  # 每秒射击次数
@export var reload_time: float = 1.5  # 换弹时间（秒）
@export var magazine_size: int = 30
@export var max_ammo: int = 120
@export var projectile_speed: float = 800.0
@export var max_range: float = 1000.0
@export var spread: float = 0.0  # 散布角度（度）
@export var is_automatic: bool = false

@export_group("Visual")
@export var recoil_amount: float = 5.0
@export var screen_shake_amount: float = 0.3
@export var muzzle_flash_effect: String = ""  # EffectManager.play_muzzle_flash() 的 key
@export var shell_casing_scene: PackedScene = null

@export_group("Advanced")
@export var pierce_count: int = 0  # 穿透次数，0表示不穿透
@export var use_ammo_system: bool = true  # true=玩家武器，false=敌人无限弹药


func _init() -> void:
	resource_name = "WeaponStats"
