extends CanvasLayer

## DeveloperPanel - 开发者面GUI
## 提供调试功能的可视化界面，由 DeveloperMode autoload 管理

# Tab 索引常量
const TAB_PLAYER: int = 0
const TAB_ENEMIES: int = 1
const TAB_WAVES: int = 2
const TAB_SYSTEM: int = 3
const TAB_CONSOLE: int = 4

# UI 引用
@onready var tab_container: TabContainer = $PanelContainer/MarginContainer/VBoxContainer/TabContainer

# Status Labels
@onready var god_mode_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusContainer/GodModeLabel
@onready var infinite_ammo_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusContainer/InfiniteAmmoLabel
@onready var wave_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusContainer/WaveLabel
@onready var enemy_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatusContainer/EnemyLabel

# Player Tab
@onready var god_mode_toggle: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Player/VBox/GodModeToggle
@onready var infinite_ammo_toggle: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Player/VBox/InfiniteAmmoToggle
@onready var heal_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Player/VBox/HealButton
@onready var respawn_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Player/VBox/RespawnButton

# Enemies Tab
@onready var spawn_melee_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Enemies/VBox/SpawnMeleeButton
@onready var spawn_ranged_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Enemies/VBox/SpawnRangedButton
@onready var spawn_random_x10_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Enemies/VBox/SpawnRandomX10Button
@onready var kill_all_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Enemies/VBox/KillAllButton
@onready var tp_to_player_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Enemies/VBox/TPToPlayerButton

# Waves Tab
@onready var next_wave_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Waves/VBox/NextWaveButton
@onready var wave_input: SpinBox = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Waves/VBox/HBox/WaveInput
@onready var jump_wave_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Waves/VBox/HBox/JumpWaveButton

# System Tab
@onready var reload_config_button: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/System/VBox/ReloadConfigButton

# Console Tab
@onready var console_input: LineEdit = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Console/VBox/ConsoleInput
@onready var console_output: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Console/VBox/ConsoleOutput
@onready var console_submit: Button = $PanelContainer/MarginContainer/VBoxContainer/TabContainer/Console/VBox/ConsoleSubmit

# Console state
var _cmd_history: Array[String] = []
var _history_index: int = -1
const MAX_HISTORY: int = 50


func _ready() -> void:
	layer = 100
	visible = false
	_connect_signals()
	_connect_console_signals()
	print("[DeveloperPanel] 面板已初始化")


## 连接控制台信
func _connect_console_signals() -> void:
	console_input.text_submitted.connect(_on_console_input_submitted)
	console_submit.pressed.connect(_on_console_submit_pressed)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if console_input.has_focus() and console_input.visible:
		if event is InputEventKey and event.pressed:
			match event.keycode:
				KEY_UP:
					_navigate_history(-1)
					get_viewport().set_input_as_handled()
				KEY_DOWN:
					_navigate_history(1)
					get_viewport().set_input_as_handled()


## 连接所有按钮信
func _connect_signals() -> void:
	# Player Tab - Toggle 按钮使用 toggled 信号
	god_mode_toggle.toggled.connect(_on_god_mode_toggled)
	infinite_ammo_toggle.toggled.connect(_on_infinite_ammo_toggled)
	# Player Tab - 普通按钮使pressed 信号
	heal_button.pressed.connect(_on_heal_pressed)
	respawn_button.pressed.connect(_on_respawn_pressed)
	# Enemies Tab
	spawn_melee_button.pressed.connect(_on_spawn_melee_pressed)
	spawn_ranged_button.pressed.connect(_on_spawn_ranged_pressed)
	spawn_random_x10_button.pressed.connect(_on_spawn_random_x10_pressed)
	kill_all_button.pressed.connect(_on_kill_all_pressed)
	tp_to_player_button.pressed.connect(_on_tp_to_player_pressed)
	# Waves Tab
	next_wave_button.pressed.connect(_on_next_wave_pressed)
	jump_wave_button.pressed.connect(_on_jump_wave_pressed)
	# System Tab
	reload_config_button.pressed.connect(_on_reload_config_pressed)
	# 连接 DeveloperMode 状态变化信
	DeveloperMode.state_changed.connect(_on_state_changed)
	DeveloperMode.mode_changed.connect(_on_mode_changed)
	# 初始化状态显
	_update_status_display()


## 显示面板
func show_panel() -> void:
	visible = true


## 隐藏面板
func hide_panel() -> void:
	visible = false


## 切换面板可见
func toggle_visibility() -> void:
	visible = not visible


## 添加控制台输
## color_mode: 0=normal(white), 1=success(green), 2=error(red)
func add_console_output(text: String, color_mode: int = 0) -> void:
	match color_mode:
		1:
			console_output.push_color(Color.GREEN)
		2:
			console_output.push_color(Color.RED)
		_:
			console_output.push_color(Color.WHITE)
	console_output.append_text(text + "\n")
	console_output.pop()


## 清空控制
func clear_console() -> void:
	console_output.clear()


## 更新 God Mode 按钮状
func update_god_mode_button(enabled: bool) -> void:
	if god_mode_toggle:
		god_mode_toggle.button_pressed = enabled


## 更新 Infinite Ammo 按钮状
func update_infinite_ammo_button(enabled: bool) -> void:
	if infinite_ammo_toggle:
		infinite_ammo_toggle.button_pressed = enabled


# === Player Tab 信号处理 ===

func _on_god_mode_toggled(enabled: bool) -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_god_mode(enabled)


func _on_infinite_ammo_toggled(enabled: bool) -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_infinite_ammo(enabled)


func _on_heal_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_heal(100)


func _on_respawn_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_respawn_player()


# === Enemies Tab 信号处理 ===

func _on_spawn_melee_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_spawn_enemy("melee")


func _on_spawn_ranged_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_spawn_enemy("ranged")


func _on_spawn_random_x10_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_spawn_random_enemies(10)


func _on_kill_all_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_kill_all_enemies()


func _on_tp_to_player_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_teleport_enemies_to_player()


# === Waves Tab 信号处理 ===

func _on_next_wave_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_next_wave()


func _on_jump_wave_pressed() -> void:
	if DeveloperMode.is_active:
		var wave_num = int(wave_input.value)
		DeveloperMode.cmd_jump_to_wave(wave_num)


# === System Tab 信号处理 ===

func _on_reload_config_pressed() -> void:
	if DeveloperMode.is_active:
		DeveloperMode.cmd_reload_config("all")


# === DeveloperMode 状态变化处===

func _on_state_changed(key: String, value: Variant) -> void:
	match key:
		"god_mode":
			god_mode_toggle.button_pressed = value
			_update_god_mode_label(value)
		"infinite_ammo":
			infinite_ammo_toggle.button_pressed = value
			_update_infinite_ammo_label(value)
	_update_status_display()


func _on_mode_changed(enabled: bool) -> void:
	visible = enabled
	if enabled:
		_update_status_display()


## 更新所有状态显
func _update_status_display() -> void:
	_update_god_mode_label(DeveloperMode.god_mode)
	_update_infinite_ammo_label(DeveloperMode.infinite_ammo)
	_update_wave_label()
	_update_enemy_label()


## 更新 God Mode 标签
func _update_god_mode_label(enabled: bool) -> void:
	if not god_mode_label:
		return
	god_mode_label.text = "God Mode: " + ("ON" if enabled else "OFF")
	god_mode_label.modulate = Color.GREEN if enabled else Color.GRAY


## 更新 Infinite Ammo 标签
func _update_infinite_ammo_label(enabled: bool) -> void:
	if not infinite_ammo_label:
		return
	infinite_ammo_label.text = "Infinite Ammo: " + ("ON" if enabled else "OFF")
	infinite_ammo_label.modulate = Color.GREEN if enabled else Color.GRAY


## 更新波次标签
func _update_wave_label() -> void:
	if not wave_label:
		return
	var wave_info = DeveloperMode.cmd_get_wave_info()
	if wave_info.has("error"):
		wave_label.text = "Wave: N/A"
		wave_label.modulate = Color.GRAY
	else:
		var current = wave_info.get("current_wave", 1)
		var total = wave_info.get("total_waves", 5)
		wave_label.text = "Wave: %d/%d" % [current, total]
		wave_label.modulate = Color.WHITE


## 更新敌人数量标签
func _update_enemy_label() -> void:
	if not enemy_label:
		return
	var enemies = get_tree().get_nodes_in_group("enemy")
	var count = enemies.size() if enemies else 0
	enemy_label.text = "Enemies: %d" % count
	enemy_label.modulate = Color.WHITE


# === Console Tab 信号处理 ===

func _on_console_input_submitted(text: String) -> void:
	_submit_command(text)


func _on_console_submit_pressed() -> void:
	var text = console_input.text
	console_input.clear()
	_submit_command(text)


func _submit_command(text: String) -> void:
	if text.is_empty():
		return
	_add_to_history(text)
	console_input.clear()
	_history_index = -1
	# Parse command
	var parts = text.split(" ")
	var cmd = parts[0]
	var args: Array = []
	if parts.size() > 1:
		args = parts.slice(1)
	# Handle built-in commands
	if cmd == "help":
		_show_help()
		return
	if cmd == "clear":
		clear_console()
		return
	# Handle special "dev" prefix for DeveloperCommands
	if cmd == "dev":
		if args.is_empty():
			add_console_output("Error: No subcommand provided", 2)
			return
		var subcmd = args[0]
		var subargs: Array = []
		if args.size() > 1:
			subargs = args.slice(1)
		var sub_result = DeveloperCommands.handle_dev_cmd({"cmd": subcmd, "args": subargs})
		_display_command_result(sub_result)
		return
	# Forward to DeveloperCommands
	var result = DeveloperCommands.handle_dev_cmd({"cmd": cmd, "args": args})
	_display_command_result(result)


func _display_command_result(result: Dictionary) -> void:
	if result.get("success", false):
		var message = result.get("message", "")
		var data_keys = result.keys()
		var data_info = ""
		for key in data_keys:
			if key in ["success", "message"]:
				continue
			data_info += "\n  %s: %s" % [key, str(result[key])]
		if data_info.is_empty():
			add_console_output(message, false)
		else:
			add_console_output(message + data_info, false)
	else:
		var error = result.get("error", "Unknown error")
		add_console_output("Error: " + error, 2)


func _add_to_history(text: String) -> void:
	_cmd_history.append(text)
	if _cmd_history.size() > MAX_HISTORY:
		_cmd_history.pop_front()
	_history_index = -1


func _navigate_history(direction: int) -> void:
	if _cmd_history.is_empty():
		return
	var new_index = _history_index + direction
	if new_index < -1:
		new_index = -1
	elif new_index >= _cmd_history.size():
		new_index = _cmd_history.size() - 1
	_history_index = new_index
	if _history_index == -1:
		console_input.clear()
	else:
		console_input.text = _cmd_history[_cmd_history.size() - 1 - _history_index]
		console_input.caret_position = console_input.text.length()


func _show_help() -> void:
	var help_text = """Available commands:
  help              - Show this help message
  clear             - Clear console output
  Player commands:
  god_mode [on|off]  - Toggle god mode
  health <value>     - Set player health
  heal <amount>      - Heal player
  teleport <x> <y>   - Teleport player
  respawn           - Respawn player
  Ammo commands:
  ammo infinite [on|off] - Toggle infinite ammo
  ammo refill       - Refill ammo
  ammo set <cur> <res> - Set ammo
  Enemy commands:
	spawn <key> [x] [y] - Spawn enemy
	spawn enemy x10     - Spawn 10 random enemies
  kill_all          - Kill all enemies
  enemies_to_player - TP enemies to player
  enemies_to <x> <y> - TP enemies to position
  damage_all <amount> - Damage all enemies
  Wave commands:
  wave next         - Next wave
  wave jump <n>     - Jump to wave
  wave pause        - Pause waves
  wave resume       - Resume waves
  wave info         - Show wave info
  Config commands:
  reload [name]     - Reload config(s)
  config get <name> - Get config value
  Shortcuts (prefix with 'dev'):
  dev spawn melee 0 0
Type any command and press Enter or click Submit."""
	add_console_output(help_text, false)
