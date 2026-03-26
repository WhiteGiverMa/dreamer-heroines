extends EditorPlugin


func _enter_tree() -> void:
	print("DeveloperCommands: Plugin initialized")


func _exit_tree() -> void:
	print("DeveloperCommands: Plugin cleaned up")
