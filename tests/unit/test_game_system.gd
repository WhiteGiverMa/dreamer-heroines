# tests/unit/test_game_system.gd
extends GutTest

const GameSystemClass = preload("res://src/base/game_system.gd")

var game_system

func before_each() -> void:
	game_system = GameSystemClass.new()
	game_system.system_name = "test_system"
	add_child(game_system)

func after_each() -> void:
	if game_system:
		game_system.queue_free()

func test_initial_state_not_initialized() -> void:
	assert_false(game_system.is_initialized, "初始状态 should not be initialized")

func test_mark_ready_sets_initialized() -> void:
	game_system._mark_ready()
	assert_true(game_system.is_initialized, "_mark_ready() should set is_initialized")

func test_system_ready_signal_emitted() -> void:
	watch_signals(game_system)
	game_system._mark_ready()
	assert_signal_emitted(game_system, "system_ready", "system_ready signal should be emitted")
	assert_signal_emitted_with_parameters(game_system, "system_ready", ["test_system"])

func test_initialize_override_warning() -> void:
	# 基类 initialize 应该打印警告并调用 _mark_ready
	watch_signals(game_system)
	game_system.initialize()
	assert_signal_emitted(game_system, "system_ready")
