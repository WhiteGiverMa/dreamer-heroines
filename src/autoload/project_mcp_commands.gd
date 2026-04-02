extends Node


const SUPPORTED_COMMANDS := {
	"dev_mode": "_handle_dev_mode",
	"dev_cmd": "_handle_dev_cmd",
	"dev_status": "_handle_dev_status",
	"dev_wave": "_handle_dev_wave",
	"dev_god_mode": "_handle_dev_god_mode",
	"dev_infinite_ammo": "_handle_dev_infinite_ammo",
	"dev_refill_ammo": "_handle_dev_refill_ammo",
	"dev_set_ammo": "_handle_dev_set_ammo",
	"dev_reload_config": "_handle_dev_reload_config",
	"dev_get_config": "_handle_dev_get_config",
	"dev_spawn_enemy": "_handle_dev_spawn_enemy",
	"dev_spawn_random_enemies": "_handle_dev_spawn_random_enemies",
	"dev_kill_all_enemies": "_handle_dev_kill_all_enemies",
	"dev_teleport_enemies_to_player": "_handle_dev_teleport_enemies_to_player",
	"dev_teleport_enemies_to": "_handle_dev_teleport_enemies_to",
	"dev_damage_all_enemies": "_handle_dev_damage_all_enemies",
	"dev_set_health": "_handle_dev_set_health",
	"dev_heal": "_handle_dev_heal",
	"dev_teleport_player": "_handle_dev_teleport_player",
	"dev_respawn_player": "_handle_dev_respawn_player"
}


func can_handle_command(command: String) -> bool:
	return SUPPORTED_COMMANDS.has(command)


func handle_command(command: String, params: Dictionary) -> Dictionary:
	var handler_name := String(SUPPORTED_COMMANDS.get(command, ""))
	if handler_name.is_empty() or not has_method(handler_name):
		return {"success": false, "error": "Unsupported project command: %s" % command}
	return call(handler_name, params)


func _handle_dev_mode(params: Dictionary) -> Dictionary:
	return _call_developer_commands("handle_dev_mode", [params])


func _handle_dev_cmd(params: Dictionary) -> Dictionary:
	return _call_developer_commands("handle_dev_cmd", [params])


func _handle_dev_status(_params: Dictionary) -> Dictionary:
	var dev_mode = _get_developer_mode()
	if not dev_mode:
		return _missing_dependency("DeveloperMode")
	return {
		"success": true,
		"dev_mode": dev_mode.is_active,
		"god_mode": dev_mode.god_mode,
		"infinite_ammo": dev_mode.infinite_ammo,
		"user_enabled": dev_mode.is_user_enabled()
	}


func _handle_dev_wave(params: Dictionary) -> Dictionary:
	var action := str(params.get("action", "")).strip_edges().to_lower()
	if action.is_empty():
		return {"success": false, "error": "Missing action. Expected one of: next, jump, pause, resume, info"}

	match action:
		"next":
			return _call_developer_commands("_handle_wave_command", [["next"]])
		"jump":
			var wave_result := _parse_required_int_param(params, "wave")
			if not bool(wave_result.get("success", false)):
				return wave_result
			return _call_developer_commands("_handle_wave_command", [["jump", wave_result.get("value", 0)]])
		"pause":
			return _call_developer_commands("_handle_wave_command", [["pause"]])
		"resume":
			return _call_developer_commands("_handle_wave_command", [["resume"]])
		"info":
			return _call_developer_commands("_handle_wave_command", [["info"]])
		_:
			return {"success": false, "error": "Unknown wave action: " + action}


func _handle_dev_god_mode(params: Dictionary) -> Dictionary:
	var enabled_result := _parse_bool_param(params, "enabled", true)
	if not bool(enabled_result.get("success", false)):
		return enabled_result
	return _call_developer_commands("_handle_god_mode_command", [[enabled_result.get("value", true)]])


func _handle_dev_infinite_ammo(params: Dictionary) -> Dictionary:
	var enabled_result := _parse_bool_param(params, "enabled", true)
	if not bool(enabled_result.get("success", false)):
		return enabled_result
	var state := "on" if bool(enabled_result.get("value", true)) else "off"
	return _call_developer_commands("_handle_ammo_command", [["infinite", state]])


func _handle_dev_refill_ammo(_params: Dictionary) -> Dictionary:
	return _call_developer_commands("_handle_ammo_command", [["refill"]])


func _handle_dev_set_ammo(params: Dictionary) -> Dictionary:
	var current_result := _parse_required_int_param(params, "current")
	if not bool(current_result.get("success", false)):
		return current_result
	var reserve_result := _parse_required_int_param(params, "reserve")
	if not bool(reserve_result.get("success", false)):
		return reserve_result
	return _call_developer_commands("_handle_ammo_command", [["set", current_result.get("value", 0), reserve_result.get("value", 0)]])


func _handle_dev_reload_config(params: Dictionary) -> Dictionary:
	var config_name := str(params.get("config", "all")).strip_edges()
	if config_name.is_empty():
		config_name = "all"
	return _call_developer_commands("_handle_reload_command", [[config_name]])


func _handle_dev_get_config(params: Dictionary) -> Dictionary:
	var config_name := str(params.get("config", "")).strip_edges()
	if config_name.is_empty():
		return {"success": false, "error": "Missing config parameter"}
	return _call_developer_commands("_handle_config_command", [["get", config_name]])


func _handle_dev_spawn_enemy(params: Dictionary) -> Dictionary:
	var enemy_key := str(params.get("enemy_key", "")).strip_edges()
	if enemy_key.is_empty():
		return {"success": false, "error": "Missing enemy_key parameter"}
	var args: Array = [enemy_key]
	if params.has("x") or params.has("y"):
		var x_result := _parse_optional_float_param(params, "x", 0.0)
		if not bool(x_result.get("success", false)):
			return x_result
		var y_result := _parse_optional_float_param(params, "y", 0.0)
		if not bool(y_result.get("success", false)):
			return y_result
		args.append(x_result.get("value", 0.0))
		args.append(y_result.get("value", 0.0))
	return _call_developer_commands("_handle_spawn_command", [args])


func _handle_dev_spawn_random_enemies(params: Dictionary) -> Dictionary:
	var count_result := _parse_required_int_param(params, "count")
	if not bool(count_result.get("success", false)):
		return count_result
	var count := int(count_result.get("value", 0))
	if count <= 0:
		return {"success": false, "error": "count must be greater than 0"}
	var x_result := _parse_optional_float_param(params, "x", 0.0)
	if not bool(x_result.get("success", false)):
		return x_result
	var y_result := _parse_optional_float_param(params, "y", 0.0)
	if not bool(y_result.get("success", false)):
		return y_result
	return _call_developer_commands("_handle_spawn_command", [["enemy", "x%d" % count, x_result.get("value", 0.0), y_result.get("value", 0.0)]])


func _handle_dev_kill_all_enemies(_params: Dictionary) -> Dictionary:
	return _call_developer_commands("_handle_kill_all_command", [])


func _handle_dev_teleport_enemies_to_player(_params: Dictionary) -> Dictionary:
	return _call_developer_commands("_handle_enemies_to_player_command", [])


func _handle_dev_teleport_enemies_to(params: Dictionary) -> Dictionary:
	var x_result := _parse_required_float_param(params, "x")
	if not bool(x_result.get("success", false)):
		return x_result
	var y_result := _parse_required_float_param(params, "y")
	if not bool(y_result.get("success", false)):
		return y_result
	return _call_developer_commands("_handle_enemies_to_command", [[x_result.get("value", 0.0), y_result.get("value", 0.0)]])


func _handle_dev_damage_all_enemies(params: Dictionary) -> Dictionary:
	var amount_result := _parse_required_int_param(params, "amount")
	if not bool(amount_result.get("success", false)):
		return amount_result
	return _call_developer_commands("_handle_damage_all_command", [[amount_result.get("value", 0)]])


func _handle_dev_set_health(params: Dictionary) -> Dictionary:
	var value_result := _parse_required_int_param(params, "value")
	if not bool(value_result.get("success", false)):
		return value_result
	return _call_developer_commands("_handle_health_command", [[value_result.get("value", 0)]])


func _handle_dev_heal(params: Dictionary) -> Dictionary:
	var amount_result := _parse_required_int_param(params, "amount")
	if not bool(amount_result.get("success", false)):
		return amount_result
	return _call_developer_commands("_handle_heal_command", [[amount_result.get("value", 0)]])


func _handle_dev_teleport_player(params: Dictionary) -> Dictionary:
	var x_result := _parse_required_float_param(params, "x")
	if not bool(x_result.get("success", false)):
		return x_result
	var y_result := _parse_required_float_param(params, "y")
	if not bool(y_result.get("success", false)):
		return y_result
	return _call_developer_commands("_handle_teleport_command", [[x_result.get("value", 0.0), y_result.get("value", 0.0)]])


func _handle_dev_respawn_player(_params: Dictionary) -> Dictionary:
	return _call_developer_commands("_handle_respawn_command", [[]])


func _get_developer_commands():
	return get_node_or_null("/root/DeveloperCommands")


func _call_developer_commands(method_name: String, args: Array) -> Dictionary:
	var commands = _get_developer_commands()
	if not commands:
		return _missing_dependency("DeveloperCommands")
	if not commands.has_method(method_name):
		return {"success": false, "error": "DeveloperCommands missing method: %s" % method_name}
	var result: Variant = commands.callv(method_name, args)
	if result is Dictionary:
		return result
	return {"success": false, "error": "DeveloperCommands returned invalid response for %s" % method_name}


func _get_developer_mode():
	return get_node_or_null("/root/DeveloperMode")


func _missing_dependency(dependency_name: String) -> Dictionary:
	return {"success": false, "error": "%s autoload not available" % dependency_name}


func _parse_bool_param(params: Dictionary, key: String, default_value: bool) -> Dictionary:
	if not params.has(key):
		return {"success": true, "value": default_value}
	var raw_value: Variant = params.get(key)
	if raw_value is bool:
		return {"success": true, "value": raw_value}
	var normalized := str(raw_value).strip_edges().to_lower()
	if normalized in ["true", "1", "yes", "on"]:
		return {"success": true, "value": true}
	if normalized in ["false", "0", "no", "off"]:
		return {"success": true, "value": false}
	return {"success": false, "error": "Invalid boolean parameter '%s': %s" % [key, str(raw_value)]}


func _parse_required_int_param(params: Dictionary, key: String) -> Dictionary:
	if not params.has(key):
		return {"success": false, "error": "Missing %s parameter" % key}
	var raw_value: Variant = params.get(key)
	if raw_value is int:
		return {"success": true, "value": raw_value}
	if raw_value is float:
		var float_value := float(raw_value)
		if is_equal_approx(float_value, round(float_value)):
			return {"success": true, "value": int(round(float_value))}
	var value_text := str(raw_value).strip_edges()
	if not value_text.is_valid_int():
		return {"success": false, "error": "Invalid integer parameter '%s': %s" % [key, value_text]}
	return {"success": true, "value": int(value_text)}


func _parse_required_float_param(params: Dictionary, key: String) -> Dictionary:
	if not params.has(key):
		return {"success": false, "error": "Missing %s parameter" % key}
	var value_text := str(params.get(key)).strip_edges()
	if not value_text.is_valid_float() and not value_text.is_valid_int():
		return {"success": false, "error": "Invalid number parameter '%s': %s" % [key, value_text]}
	return {"success": true, "value": float(value_text)}


func _parse_optional_float_param(params: Dictionary, key: String, default_value: float) -> Dictionary:
	if not params.has(key):
		return {"success": true, "value": default_value}
	return _parse_required_float_param(params, key)
