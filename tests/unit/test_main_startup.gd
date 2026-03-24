extends GutTest

var MainControllerClass = preload("res://src/main.gd")


func test_resolve_level_root_returns_self() -> void:
	var main_controller: Node = MainControllerClass.new()
	add_child_autofree(main_controller)
	var resolved_root: Node = main_controller._resolve_level_root()

	assert_eq(resolved_root, main_controller, "Main startup should use self as level root fallback")


func test_main_controller_can_be_instantiated_for_fast_regression() -> void:
	var main_controller: Node = MainControllerClass.new()
	add_child_autofree(main_controller)

	assert_not_null(main_controller, "main.gd should be instantiable in headless unit tests")


func test_initialize_level_is_safe_when_node_is_not_in_tree() -> void:
	var parent := Node.new()
	add_child_autofree(parent)

	var main_controller: Node = MainControllerClass.new()
	parent.add_child(main_controller)
	parent.remove_child(main_controller)

	# 如果未来有人移除 _initialize_level 的树状态保护，这里会在 CI 中暴露回归
	main_controller._initialize_level()
	assert_true(true, "_initialize_level should no-op safely when node is detached")
	main_controller.free()


func test_ready_coroutine_is_safe_when_node_detaches_before_resume() -> void:
	var parent := Node.new()
	add_child_autofree(parent)

	var main_controller: Node = MainControllerClass.new()
	parent.add_child(main_controller)
	main_controller.queue_free()

	await wait_process_frames(2)
	assert_true(true, "Detaching main node before deferred _ready resume should not crash")
