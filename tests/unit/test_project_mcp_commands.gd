extends GutTest


const ProjectMcpCommandsClass = preload("res://src/autoload/project_mcp_commands.gd")


class FakeDeveloperCommands:
	extends Node

	var last_wave_args: Array = []
	var last_health_args: Array = []
	var last_respawn_args: Array = []
	var dev_mode_params: Dictionary = {}
	var dev_cmd_params: Dictionary = {}

	func handle_dev_mode(params: Dictionary) -> Dictionary:
		dev_mode_params = params.duplicate(true)
		return {"success": true, "dev_mode": params.get("enabled", false)}

	func handle_dev_cmd(params: Dictionary) -> Dictionary:
		dev_cmd_params = params.duplicate(true)
		return {"success": true, "message": "ok"}

	func _handle_wave_command(args: Array) -> Dictionary:
		last_wave_args = args.duplicate(true)
		return {"success": true, "wave_args": last_wave_args}

	func _handle_health_command(args: Array) -> Dictionary:
		last_health_args = args.duplicate(true)
		return {"success": true, "health": args[0]}

	func _handle_respawn_command(args: Array) -> Dictionary:
		last_respawn_args = args.duplicate(true)
		return {"success": true, "message": "respawned"}


class FakeDeveloperMode:
	extends Node

	var is_active := true
	var god_mode := true
	var infinite_ammo := false
	var _user_enabled := true

	func is_user_enabled() -> bool:
		return _user_enabled


class TestProjectMcpCommands:
	extends ProjectMcpCommandsClass

	var fake_commands: Node = null
	var fake_mode: Node = null

	func _get_developer_commands():
		return fake_commands

	func _get_developer_mode():
		return fake_mode


func test_can_handle_command_includes_project_owned_dev_commands() -> void:
	var commands := ProjectMcpCommandsClass.new()
	add_child_autofree(commands)

	assert_true(commands.can_handle_command("dev_status"))
	assert_true(commands.can_handle_command("dev_reload_config"))
	assert_true(commands.can_handle_command("dev_respawn_player"))
	assert_false(commands.can_handle_command("not_a_real_command"))


func test_dev_status_reads_state_from_developer_mode() -> void:
	var commands := TestProjectMcpCommands.new()
	commands.fake_mode = FakeDeveloperMode.new()
	add_child_autofree(commands)
	add_child_autofree(commands.fake_mode)

	var result := commands.handle_command("dev_status", {})

	assert_eq(result.get("success"), true)
	assert_eq(result.get("dev_mode"), true)
	assert_eq(result.get("god_mode"), true)
	assert_eq(result.get("infinite_ammo"), false)
	assert_eq(result.get("user_enabled"), true)


func test_dev_wave_jump_validates_and_forwards_to_developer_commands() -> void:
	var commands := TestProjectMcpCommands.new()
	var fake_commands := FakeDeveloperCommands.new()
	commands.fake_commands = fake_commands
	add_child_autofree(commands)
	add_child_autofree(fake_commands)

	var result := commands.handle_command("dev_wave", {"action": "jump", "wave": 7})

	assert_eq(result.get("success"), true)
	assert_eq(fake_commands.last_wave_args, ["jump", 7])


func test_dev_set_health_forwards_structured_value() -> void:
	var commands := TestProjectMcpCommands.new()
	var fake_commands := FakeDeveloperCommands.new()
	commands.fake_commands = fake_commands
	add_child_autofree(commands)
	add_child_autofree(fake_commands)

	var result := commands.handle_command("dev_set_health", {"value": 88})

	assert_eq(result.get("success"), true)
	assert_eq(fake_commands.last_health_args, [88])


func test_dev_respawn_player_uses_empty_args() -> void:
	var commands := TestProjectMcpCommands.new()
	var fake_commands := FakeDeveloperCommands.new()
	commands.fake_commands = fake_commands
	add_child_autofree(commands)
	add_child_autofree(fake_commands)

	var result := commands.handle_command("dev_respawn_player", {})

	assert_eq(result.get("success"), true)
	assert_eq(fake_commands.last_respawn_args, [])


func test_dev_wave_requires_action() -> void:
	var commands := TestProjectMcpCommands.new()
	var fake_commands := FakeDeveloperCommands.new()
	commands.fake_commands = fake_commands
	add_child_autofree(commands)
	add_child_autofree(fake_commands)

	var result := commands.handle_command("dev_wave", {})

	assert_eq(result.get("success"), false)
	assert_string_contains(str(result.get("error", "")), "Missing action")
