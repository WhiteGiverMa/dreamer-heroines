# tests/unit/test_boot_sequence.gd
extends GutTest

# 预加载类避免 headless 模式下的类型解析问题
var BootSequenceClass = preload("res://src/autoload/boot_sequence.gd")
var GameSystemClass = preload("res://src/base/game_system.gd")

var boot_sequence: Node


func before_each() -> void:
	boot_sequence = BootSequenceClass.new()
	add_child(boot_sequence)


func after_each() -> void:
	if boot_sequence:
		boot_sequence.queue_free()


func test_initial_state() -> void:
	assert_false(boot_sequence._boot_started, "初始状态 boot_started 应为 false")
	assert_false(boot_sequence._boot_completed, "初始状态 boot_completed 应为 false")
	assert_eq(boot_sequence.current_phase, -1, "初始阶段应为 -1")
	assert_eq(boot_sequence.initialized_count, 0, "初始计数应为 0")


func test_total_systems_calculated() -> void:
	# 验证系统总数计算正确
	# 5 阶段: 5 + 1 + 1 + 1 + 1 = 9
	assert_eq(boot_sequence.total_systems, 9, "总系统数应为 9")


func test_system_paths_defined() -> void:
	var paths = boot_sequence.SYSTEM_PATHS
	assert_true(paths.has("GameManager"), "应包含 GameManager 路径")
	assert_true(paths.has("AudioManager"), "应包含 AudioManager 路径")
	assert_true(paths.has("SaveManager"), "应包含 SaveManager 路径")
	assert_true(paths.has("LevelManager"), "应包含 LevelManager 路径")
	assert_true(paths.has("EnhancedInput"), "应包含 EnhancedInput 路径")


func test_init_phases_order() -> void:
	var phases = boot_sequence.INIT_PHASES
	assert_eq(phases.size(), 5, "应有 5 个初始化阶段")

	# Phase 1: 基础设施
	assert_true("CSharpSaveManager" in phases[0], "Phase 1 应包含 CSharpSaveManager")
	assert_true("AudioManager" in phases[0], "Phase 1 应包含 AudioManager")
	assert_true("EffectManager" in phases[0], "Phase 1 应包含 EffectManager")

	# Phase 3: SaveManager 在 CSharpSaveManager 之后
	assert_true("SaveManager" in phases[2], "Phase 3 应包含 SaveManager")

	# Phase 5: GameManager 最后
	assert_true("GameManager" in phases[4], "Phase 5 应包含 GameManager")


func test_get_progress() -> void:
	# 初始进度
	assert_eq(boot_sequence.get_progress(), 0.0, "初始进度应为 0.0")

	# 模拟部分初始化
	boot_sequence.initialized_count = 3
	boot_sequence.total_systems = 7
	assert_almost_eq(boot_sequence.get_progress(), 0.428, 0.01, "进度应约为 0.428")

	# 完成初始化
	boot_sequence.initialized_count = 7
	assert_eq(boot_sequence.get_progress(), 1.0, "完成进度应为 1.0")


func test_get_status() -> void:
	# 初始状态
	assert_eq(boot_sequence.get_status(), "初始化中...", "初始状态描述")

	# 正在加载某系统
	boot_sequence.current_system = "AudioManager"
	assert_eq(boot_sequence.get_status(), "正在加载: AudioManager", "正在加载状态")

	# 完成状态
	boot_sequence._boot_completed = true
	assert_eq(boot_sequence.get_status(), "启动完成", "完成状态")


func test_is_boot_completed() -> void:
	assert_false(boot_sequence.is_boot_completed(), "初始未完成")

	boot_sequence._boot_completed = true
	assert_true(boot_sequence.is_boot_completed(), "设置后已完成")


func test_signals_defined() -> void:
	watch_signals(boot_sequence)

	# 验证信号存在
	assert_true(boot_sequence.has_signal("boot_completed"), "应有 boot_completed 信号")
	assert_true(boot_sequence.has_signal("boot_failed"), "应有 boot_failed 信号")
	assert_true(boot_sequence.has_signal("phase_started"), "应有 phase_started 信号")
	assert_true(boot_sequence.has_signal("system_initialized"), "应有 system_initialized 信号")
