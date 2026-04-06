extends Panel

# CharacterConfigPanel - 角色配置界面
# 支持角色选择、武器配置、外观选择

signal close_requested
signal config_changed(config: CharacterConfig)

# 武器列表定义
const WEAPONS := [
	{
		"id": "rifle_basic",
		"name": "基础突击步枪",
		"description": "标准突击步枪，射速快，精度高。",
		"stats": "伤害: 15 | 射速: 高 | 弹匣: 30",
		"fire_rate_text": "高"
	},
	{
		"id": "shotgun_basic",
		"name": "基础霰弹枪",
		"description": "近距离高伤害，适合近战突围。",
		"stats": "伤害: 12x8 | 射速: 慢 | 弹匣: 6",
		"fire_rate_text": "慢"
	},
	{
		"id": "sniper_basic",
		"name": "狙击步枪",
		"description": "高伤害，精准，但射速极慢。",
		"stats": "伤害: 80 | 射速: 极慢 | 弹匣: 5",
		"fire_rate_text": "极慢"
	},
	{
		"id": "smg_basic",
		"name": "冲锋枪",
		"description": "极高射速，低单发伤害，适合近距离。",
		"stats": "伤害: 8 | 射速: 极高 | 弹匣: 45",
		"fire_rate_text": "极高"
	}
]

# 角色列表定义
const CHARACTERS := [{"id": "heroine_default", "name": "默认角色", "description": "标准突击战士，均衡的能力配置。"}]

# UI 节点引用
@onready var character_list: ItemList = %CharacterList
@onready var character_name_label: Label = %CharacterNameLabel
@onready var character_desc_label: Label = %CharacterDescLabel
@onready var skin_option: OptionButton = %SkinOption

@onready var primary_weapon_option: OptionButton = %PrimaryWeaponOption
@onready var primary_weapon_name: Label = %PrimaryWeaponName
@onready var primary_weapon_stats: Label = %PrimaryWeaponStats
@onready var primary_weapon_desc: Label = %PrimaryWeaponDesc

@onready var secondary_weapon_option: OptionButton = %SecondaryWeaponOption
@onready var secondary_weapon_name: Label = %SecondaryWeaponName
@onready var secondary_weapon_stats: Label = %SecondaryWeaponStats
@onready var secondary_weapon_desc: Label = %SecondaryWeaponDesc

@onready var back_button: Button = %BackButton

# 当前配置
var _current_config: CharacterConfig


func _ready() -> void:
	# 确保武器面板有正确的最小尺寸（修复场景缓存问题）
	var primary_panel = $HSplitContainer/RightPanel/WeaponSection/PrimaryWeaponPanel
	var secondary_panel = $HSplitContainer/RightPanel/WeaponSection/SecondaryWeaponPanel
	if primary_panel:
		primary_panel.custom_minimum_size = Vector2(0, 120)
	if secondary_panel:
		secondary_panel.custom_minimum_size = Vector2(0, 120)

	_connect_signals()
	_populate_ui()
	_load_config()


func _connect_signals() -> void:
	character_list.item_selected.connect(_on_character_selected)
	skin_option.item_selected.connect(_on_skin_selected)
	primary_weapon_option.item_selected.connect(_on_primary_weapon_selected)
	secondary_weapon_option.item_selected.connect(_on_secondary_weapon_selected)

	back_button.pressed.connect(_on_back_pressed)


func _populate_ui() -> void:
	# 填充角色列表
	character_list.clear()
	for char_data in CHARACTERS:
		character_list.add_item(char_data.name)
	character_list.select(0)

	# 填充武器下拉框
	_populate_weapon_options(primary_weapon_option)
	_populate_weapon_options(secondary_weapon_option)

	# 默认选择第一个
	primary_weapon_option.select(0)
	secondary_weapon_option.select(1)  # 默认副武器为霰弹枪

	# 更新武器信息显示
	_update_weapon_info(0, true)
	_update_weapon_info(1, false)


func _populate_weapon_options(option: OptionButton) -> void:
	option.clear()
	for weapon in WEAPONS:
		option.add_item(weapon.name)


func _load_config() -> void:
	# 从存档加载配置
	var save_data := _get_character_config_from_save()
	if save_data.is_empty():
		_current_config = CharacterConfig.create_default()
	else:
		_current_config = CharacterConfig.from_dictionary(save_data)

	_apply_config_to_ui(_current_config)


func _get_character_config_from_save() -> Dictionary:
	if not SaveManager:
		return {}

	var settings := SaveManager.load_settings()
	return settings.get("character_config", {})


func _apply_config_to_ui(config: CharacterConfig) -> void:
	# 应用角色选择
	var char_index := 0
	for i in range(CHARACTERS.size()):
		if CHARACTERS[i].id == config.character_id:
			char_index = i
			break
	character_list.select(char_index)
	_update_character_info(char_index)

	# 应用武器选择
	var primary_index := _find_weapon_index(config.primary_weapon_id)
	var secondary_index := _find_weapon_index(config.secondary_weapon_id)

	primary_weapon_option.select(primary_index)
	secondary_weapon_option.select(secondary_index)

	_update_weapon_info(primary_index, true)
	_update_weapon_info(secondary_index, false)


func _find_weapon_index(weapon_id: String) -> int:
	for i in range(WEAPONS.size()):
		if WEAPONS[i].id == weapon_id:
			return i
	return 0


func _update_character_info(index: int) -> void:
	if index < 0 or index >= CHARACTERS.size():
		return

	var char_data: Dictionary = CHARACTERS[index]
	character_name_label.text = char_data.name
	character_desc_label.text = char_data.description


func _update_weapon_info(index: int, is_primary: bool) -> void:
	if index < 0 or index >= WEAPONS.size():
		return

	var weapon: Dictionary = WEAPONS[index]

	if is_primary:
		primary_weapon_name.text = weapon.name
		primary_weapon_stats.text = weapon.stats
		primary_weapon_desc.text = weapon.description
	else:
		secondary_weapon_name.text = weapon.name
		secondary_weapon_stats.text = weapon.stats
		secondary_weapon_desc.text = weapon.description


func _save_config() -> void:
	_current_config.mark_modified()

	# 保存到存档
	if SaveManager:
		var settings := SaveManager.load_settings()
		settings["character_config"] = _current_config.to_dictionary()
		SaveManager.save_settings(settings)

	config_changed.emit(_current_config)
	print(
		(
			"Character config saved: primary=%s, secondary=%s"
			% [_current_config.primary_weapon_id, _current_config.secondary_weapon_id]
		)
	)


# === 信号回调 ===


func _on_character_selected(index: int) -> void:
	_update_character_info(index)
	if index < CHARACTERS.size():
		_current_config.character_id = CHARACTERS[index].id
		_current_config.character_name = CHARACTERS[index].name
		_save_config()


func _on_skin_selected(_index: int) -> void:
	# 预留扩展
	pass


func _on_primary_weapon_selected(index: int) -> void:
	_update_weapon_info(index, true)
	if index < WEAPONS.size():
		_current_config.primary_weapon_id = WEAPONS[index].id
		_save_config()


func _on_secondary_weapon_selected(index: int) -> void:
	_update_weapon_info(index, false)
	if index < WEAPONS.size():
		_current_config.secondary_weapon_id = WEAPONS[index].id
		_save_config()


func _on_back_pressed() -> void:
	close_requested.emit()


# === 公共方法 ===


func show_panel() -> void:
	visible = true
	modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)

	# 刷新配置
	_load_config()


func hide_panel() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)


func get_current_config() -> CharacterConfig:
	return _current_config.duplicate_config()
