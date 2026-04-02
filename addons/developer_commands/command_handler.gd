extends Node


# Developer mode state
var _dev_mode_enabled: bool = false


func _ready() -> void:
	# Ensure this autoload runs even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("DeveloperCommands: Command handler ready")


func handle_dev_mode(params: Dictionary) -> Dictionary:
	var enabled_result := _parse_enabled_param(params)
	if not bool(enabled_result.get("success", false)):
		return enabled_result
	var enabled := bool(enabled_result.get("value", false))
	if not DeveloperMode:
		return {"success": false, "error": "DeveloperMode autoload not available"}

	if enabled:
		if not DeveloperMode.is_active:
			DeveloperMode.toggle()
	else:
		if DeveloperMode.is_active:
			DeveloperMode.toggle()

	_dev_mode_enabled = DeveloperMode.is_active
	print("DeveloperCommands: Dev mode %s" % ("enabled" if _dev_mode_enabled else "disabled"))
	return {"success": true, "dev_mode": _dev_mode_enabled}


func _parse_enabled_param(params: Dictionary) -> Dictionary:
	var raw_value: Variant = params.get("enabled", false)
	if raw_value is bool:
		return {"success": true, "value": raw_value}
	if raw_value is int:
		return {"success": true, "value": raw_value != 0}
	if raw_value is float:
		return {"success": true, "value": not is_zero_approx(float(raw_value))}
	var normalized := str(raw_value).strip_edges().to_lower()
	if normalized in ["true", "1", "yes", "on"]:
		return {"success": true, "value": true}
	if normalized in ["false", "0", "no", "off"]:
		return {"success": true, "value": false}
	return {"success": false, "error": "Invalid enabled parameter: %s" % str(raw_value)}


func handle_dev_cmd(params: Dictionary) -> Dictionary:
	var cmd = str(params.get("cmd", "")).strip_edges()
	if cmd.is_empty():
		return {"success": false, "error": "No command provided"}

	var args: Array = []
	var raw_args: Variant = params.get("args", [])
	if raw_args is Array:
		args = raw_args

	# MCP curl compatibility: supports cmd="god_mode on" single-string format
	if args.is_empty() and cmd.contains(" "):
		var parts: PackedStringArray = cmd.split(" ", false)
		cmd = parts[0]
		for i in range(1, parts.size()):
			args.append(parts[i])

	cmd = cmd.to_lower()
	# Route commands to DeveloperMode
	match cmd:
		"wave":
			return _handle_wave_command(args)
		"reload":
			return _handle_reload_command(args)
		"config":
			return _handle_config_command(args)
		"spawn":
			return _handle_spawn_command(args)
		"kill_all":
			return _handle_kill_all_command()
		"enemies_to_player":
			return _handle_enemies_to_player_command()
		"enemies_to":
			return _handle_enemies_to_command(args)
		"damage_all":
			return _handle_damage_all_command(args)
		"ammo":
			return _handle_ammo_command(args)
		"god_mode":
			return _handle_god_mode_command(args)
		"health":
			return _handle_health_command(args)
		"heal":
			return _handle_heal_command(args)
		"teleport":
			return _handle_teleport_command(args)
		"respawn":
			return _handle_respawn_command(args)
		_:
			return {"success": false, "error": "Unknown command: " + cmd}


func _handle_wave_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": "wave subcommand required (next/jump/pause/resume/info)"}
	var subcmd = args[0]
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	match subcmd:
		"next":
			dev_mode.cmd_next_wave()
			return {"success": true, "message": "Starting next wave"}
		"jump":
			if args.size() < 2:
				return {"success": false, "error": "wave jump <number> requires a wave number"}
			var wave_num_text := str(args[1]).strip_edges()
			if not wave_num_text.is_valid_int():
				return {"success": false, "error": "Invalid wave number: " + wave_num_text}
			var wave_num := int(wave_num_text)
			dev_mode.cmd_jump_to_wave(wave_num)
			return {"success": true, "message": "Jumped to wave " + str(wave_num)}
		"pause":
			dev_mode.cmd_pause_waves()
			return {"success": true, "message": "Waves paused"}
		"resume":
			dev_mode.cmd_resume_waves()
			return {"success": true, "message": "Waves resumed"}
		"info":
			var info = dev_mode.cmd_get_wave_info()
			return {"success": true, "wave_info": info}
		_:
			return {"success": false, "error": "Unknown wave subcommand: " + subcmd}


func _handle_ammo_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": "ammo subcommand required (infinite/refill/set)"}
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	var subcmd = args[0]
	match subcmd:
		"infinite":
			if args.size() < 2:
				return {"success": false, "error": "Usage: ammo infinite [on|off]"}
			var state = args[1]
			var enabled = true
			if state == "off":
				enabled = false
			elif state != "on":
				return {"success": false, "error": "Usage: ammo infinite [on|off]"}
			dev_mode.cmd_infinite_ammo(enabled)
			return {"success": true, "message": "Infinite ammo: " + ("enabled" if enabled else "disabled")}
		"refill":
			dev_mode.cmd_refill_ammo()
			return {"success": true, "message": "Ammo refilled"}
		"set":
			if args.size() < 3:
				return {"success": false, "error": "Usage: ammo set <current> <reserve>"}
			var current_text := str(args[1]).strip_edges()
			var reserve_text := str(args[2]).strip_edges()
			if not current_text.is_valid_int() or not reserve_text.is_valid_int():
				return {"success": false, "error": "Invalid ammo values"}
			var current := int(current_text)
			var reserve := int(reserve_text)
			dev_mode.cmd_set_ammo(current, reserve)
			return {"success": true, "message": "Ammo set to: current=" + str(current) + ", reserve=" + str(reserve)}
		_:
			return {"success": false, "error": "Unknown ammo subcommand: " + subcmd}


func _handle_reload_command(args: Array) -> Dictionary:
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	var config_name = "all" if args.is_empty() else args[0]
	var result = dev_mode.cmd_reload_config(config_name)
	return result


func _handle_config_command(args: Array) -> Dictionary:
	if args.is_empty() or args[0] != "get":
		return {"success": false, "error": "Usage: config get <config_name>"}
	if args.size() < 2:
		return {"success": false, "error": "Usage: config get <config_name>"}
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	return dev_mode.cmd_get_config(args[1])


## Player control command handlers
func _get_developer_mode():
	return DeveloperMode


func _handle_spawn_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": _get_spawn_usage_text()}

	var random_spawn_count := _parse_spawn_batch_count(args)
	if random_spawn_count > 0:
		var random_position_result := _parse_spawn_position(args, 2)
		if not bool(random_position_result.get("valid", false)):
			return {"success": false, "error": _get_spawn_usage_text()}
		var dev_mode_random = _get_developer_mode()
		if not dev_mode_random:
			return {"success": false, "error": "DeveloperMode not available"}
		var spawned_enemies: Array[Node] = dev_mode_random.cmd_spawn_random_enemies(
			random_spawn_count,
			float(random_position_result.get("x", 0.0)),
			float(random_position_result.get("y", 0.0))
		)
		if spawned_enemies.is_empty():
			return {"success": false, "error": "Failed to spawn random enemies x%d" % random_spawn_count}
		return {
			"success": true,
			"message": "Spawned %d random enemies" % spawned_enemies.size(),
			"spawn_count": spawned_enemies.size()
		}

	var enemy_key = args[0]
	var position_result := _parse_spawn_position(args, 1)
	if not bool(position_result.get("valid", false)):
		return {"success": false, "error": _get_spawn_usage_text()}
	var x = float(position_result.get("x", 0.0))
	var y = float(position_result.get("y", 0.0))
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	var enemy = dev_mode.cmd_spawn_enemy(enemy_key, x, y)
	if enemy:
		var node_path := ""
		if enemy is Node:
			node_path = str((enemy as Node).get_path())
		return {
			"success": true,
			"message": "Spawned enemy: " + enemy_key,
			"enemy_path": node_path,
			"enemy_id": enemy.get_instance_id()
		}
	else:
		return {"success": false, "error": "Failed to spawn enemy: " + enemy_key}


func _get_spawn_usage_text() -> String:
	return "Usage: spawn <enemy_key> [x] [y] | spawn enemy x<count> [x] [y]"


func _parse_spawn_batch_count(args: Array) -> int:
	if args.size() < 2:
		return -1
	if str(args[0]).to_lower() != "enemy":
		return -1
	var count_token := str(args[1]).strip_edges().to_lower()
	if count_token.length() < 2 or not count_token.begins_with("x"):
		return -1
	var count_text := count_token.substr(1)
	if not count_text.is_valid_int():
		return -1
	var count := int(count_text)
	if count <= 0:
		return -1
	return count


func _parse_spawn_position(args: Array, start_index: int) -> Dictionary:
	var remaining_args := args.size() - start_index
	if remaining_args <= 0:
		return {"valid": true, "x": 0.0, "y": 0.0}
	if remaining_args != 2:
		return {"valid": false, "x": 0.0, "y": 0.0}
	var x_text := str(args[start_index]).strip_edges()
	var y_text := str(args[start_index + 1]).strip_edges()
	if not x_text.is_valid_float() or not y_text.is_valid_float():
		return {"valid": false, "x": 0.0, "y": 0.0}
	return {"valid": true, "x": float(x_text), "y": float(y_text)}


func _handle_kill_all_command() -> Dictionary:
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	dev_mode.cmd_kill_all_enemies()
	return {"success": true, "message": "Killed all enemies"}


func _handle_enemies_to_player_command() -> Dictionary:
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	dev_mode.cmd_teleport_enemies_to_player()
	return {"success": true, "message": "Teleported enemies to player"}


func _handle_enemies_to_command(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "error": "Usage: enemies_to <x> <y>"}

	var x_text := str(args[0]).strip_edges()
	var y_text := str(args[1]).strip_edges()
	if not x_text.is_valid_float() or not y_text.is_valid_float():
		return {"success": false, "error": "Usage: enemies_to <x> <y>"}

	var x = float(x_text)
	var y = float(y_text)
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	dev_mode.cmd_teleport_enemies_to(x, y)
	return {"success": true, "message": "Teleported enemies to (%s, %s)" % [x, y]}


func _handle_damage_all_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": "Usage: damage_all <amount>"}

	var amount_text := str(args[0]).strip_edges()
	if not amount_text.is_valid_int():
		return {"success": false, "error": "Usage: damage_all <amount>"}

	var amount = int(amount_text)
	if amount <= 0:
		return {"success": false, "error": "Damage amount must be positive"}
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}
	dev_mode.cmd_damage_all_enemies(amount)
	return {"success": true, "message": "Damaged all enemies for %d HP" % amount}


func _handle_god_mode_command(args: Array) -> Dictionary:
	var enabled := true
	if not args.is_empty():
		var state := str(args[0]).to_lower()
		enabled = state in ["on", "true", "1", "yes"]

	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}

	dev_mode.cmd_god_mode(enabled)
	return {"success": true, "god_mode": enabled}


func _handle_health_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": "Usage: health <value>"}

	var value_text := str(args[0]).strip_edges()
	if not value_text.is_valid_int():
		return {"success": false, "error": "Usage: health <value>"}

	var value := int(value_text)
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}

	dev_mode.cmd_set_health(value)
	return {"success": true, "health": value}


func _handle_heal_command(args: Array) -> Dictionary:
	if args.is_empty():
		return {"success": false, "error": "Usage: heal <amount>"}

	var amount_text := str(args[0]).strip_edges()
	if not amount_text.is_valid_int():
		return {"success": false, "error": "Usage: heal <amount>"}

	var amount := int(amount_text)
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}

	dev_mode.cmd_heal(amount)
	return {"success": true, "healed": amount}


func _handle_teleport_command(args: Array) -> Dictionary:
	if args.size() < 2:
		return {"success": false, "error": "Usage: teleport <x> <y>"}

	var x_text := str(args[0]).strip_edges()
	var y_text := str(args[1]).strip_edges()
	if not x_text.is_valid_float() or not y_text.is_valid_float():
		return {"success": false, "error": "Usage: teleport <x> <y>"}

	var x := float(x_text)
	var y := float(y_text)
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}

	dev_mode.cmd_teleport_player(x, y)
	return {"success": true, "position": {"x": x, "y": y}}


func _handle_respawn_command(args: Array) -> Dictionary:
	var _unused := args
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return {"success": false, "error": "DeveloperMode not available"}

	dev_mode.cmd_respawn_player()
	return {"success": true, "message": "Player respawned"}


func is_dev_mode_enabled() -> bool:
	return _dev_mode_enabled
