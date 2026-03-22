# src/autoload/boot_sequence.gd
# 注意：不使用 class_name 以避免与 autoload 单例名称冲突
extends Node

## 启动序列编排器
## 负责按正确顺序初始化所有游戏系统

## 预加载 LoadingScreen
const LoadingScreenClass = preload("res://src/ui/loading_screen.gd")

## 初始化阶段定义
## 每个阶段内的系统并行初始化，阶段之间串行执行
const INIT_PHASES: Array[Array] = [
	# Phase 1: 基础设施（无依赖，可并行）
	["CSharpSaveManager", "AudioManager", "EffectManager", "ProjectileSpawner"],
	# Phase 2: 输入系统（依赖 GUIDE）
	["EnhancedInput"],
	# Phase 3: 存档系统（依赖 CSharpSaveManager）
	["SaveManager"],
	# Phase 4: 关卡管理（依赖 SaveManager）
	["LevelManager"],
	# Phase 5: 游戏核心（依赖 SaveManager, LevelManager）
	["GameManager"],
]

## 系统路径映射（autoload 名称 -> /root/路径）
const SYSTEM_PATHS: Dictionary = {
	"CSharpSaveManager": "/root/CSharpSaveManager",
	"AudioManager": "/root/AudioManager",
	"EffectManager": "/root/EffectManager",
	"ProjectileSpawner": "/root/ProjectileSpawner",
	"EnhancedInput": "/root/EnhancedInput",
	"SaveManager": "/root/SaveManager",
	"LevelManager": "/root/LevelManager",
	"GameManager": "/root/GameManager",
}

## 初始化超时（秒）
const INIT_TIMEOUT: float = 30.0

## 信号
signal boot_completed
signal boot_failed(system_name: String, error: String)
signal phase_started(phase_index: int, phase_name: String)
signal system_initialized(system_name: String)

## 状态
var current_phase: int = -1
var current_system: String = ""
var initialized_count: int = 0
var total_systems: int = 0
var _boot_started: bool = false
var _boot_completed: bool = false

## 引用
var loading_screen: Control = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_calculate_total_systems()
	
	# 获取 LoadingScreen 子节点
	var ls_node = get_node_or_null("LoadingScreen")
	if ls_node:
		loading_screen = ls_node
	
	# 延迟启动，确保所有 autoload 已加载
	call_deferred("_run_boot_sequence")


func _calculate_total_systems() -> void:
	for phase in INIT_PHASES:
		total_systems += phase.size()


## 运行启动序列
func _run_boot_sequence() -> void:
	if _boot_started:
		return
	
	_boot_started = true
	print("=== 游戏启动序列开始 ===")
	
	# 显示加载画面
	if loading_screen:
		loading_screen.show_loading()
	
	var start_time: float = Time.get_ticks_msec() / 1000.0
	
	for phase_idx in INIT_PHASES.size():
		current_phase = phase_idx
		var phase_systems: Array = INIT_PHASES[phase_idx]
		
		phase_started.emit(phase_idx, "Phase %d" % (phase_idx + 1))
		print("[Boot] 开始阶段 %d: %s" % [phase_idx + 1, phase_systems])
		
		# 并行初始化本阶段所有系统
		var pending: Array = []
		for system_name in phase_systems:
			var system = _get_system(system_name)
			if system:
				current_system = system_name
				_update_loading_screen()
				
				# 调用初始化方法
				if system.has_method("initialize"):
					system.initialize()
					pending.append({"name": system_name, "node": system})
				elif system.has_method("Initialize"):  # C# 方法
					system.Initialize()
					pending.append({"name": system_name, "node": system})
				else:
					# 没有 initialize 方法，假设已就绪
					initialized_count += 1
					system_initialized.emit(system_name)
			else:
				push_warning("[Boot] 系统节点不存在: %s" % system_name)
		
		# 等待本阶段所有系统完成
		for item in pending:
			await _wait_for_system(item.node, item.name)
		
		# 更新进度
		_update_loading_screen()
	
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - start_time
	print("=== 启动序列完成 (耗时 %.2fs) ===" % elapsed)
	
	_boot_completed = true
	
	# 隐藏加载画面
	if loading_screen:
		await loading_screen.fade_out()
	
	boot_completed.emit()
	
	# 加载主场景
	_load_main_scene()


## 获取系统节点
func _get_system(system_name: String) -> Node:
	var path: String = SYSTEM_PATHS.get(system_name, "")
	if path.is_empty():
		push_error("[Boot] 未知系统: %s" % system_name)
		return null
	return get_node_or_null(path)


## 等待系统初始化完成
func _wait_for_system(system: Node, system_name: String) -> void:
	# 检查是否已初始化
	var is_init = _check_initialized(system)
	
	if is_init:
		initialized_count += 1
		system_initialized.emit(system_name)
		return
	
	# 等待初始化信号
	var signal_name = "system_ready"
	if system.has_signal("SystemReady"):
		signal_name = "SystemReady"
	elif system.has_signal("system_ready"):
		signal_name = "system_ready"
	else:
		# 没有初始化信号，轮询等待
		var polling_timer := get_tree().create_timer(INIT_TIMEOUT)
		while not _check_initialized(system):
			await get_tree().process_frame
			if polling_timer.time_left <= 0:
				_on_system_timeout(system_name)
				return
		initialized_count += 1
		system_initialized.emit(system_name)
		return
	
	# 连接信号等待 - 使用数组包装器解决 lambda 捕获问题
	var init_completed := [false]
	var timeout_timer := get_tree().create_timer(INIT_TIMEOUT)
	
	system.connect(signal_name, func(_name): init_completed[0] = true, CONNECT_ONE_SHOT)
	
	while not init_completed[0]:
		await get_tree().process_frame
		if timeout_timer.time_left <= 0:
			_on_system_timeout(system_name)
			return
	
	initialized_count += 1
	system_initialized.emit(system_name)


## 检查系统是否已初始化
func _check_initialized(system: Node) -> bool:
	# GDScript 属性
	if "is_initialized" in system:
		return system.is_initialized
	# C# 属性 (首字母大写)
	if "IsInitialized" in system:
		return system.IsInitialized
	return true


## 系统初始化超时
func _on_system_timeout(system_name: String) -> void:
	push_error("[Boot] 系统初始化超时: %s" % system_name)
	boot_failed.emit(system_name, "初始化超时")
	
	if loading_screen:
		loading_screen.show_error("系统初始化失败: %s" % system_name)


## 更新加载画面
func _update_loading_screen() -> void:
	if not loading_screen:
		return
	
	var progress: float = float(initialized_count) / float(total_systems)
	var status: String = "正在加载: %s" % current_system if current_system else "初始化中..."
	
	loading_screen.set_progress(progress, status)


## 加载主场景
func _load_main_scene() -> void:
	# 应用已保存的设置
	_apply_saved_settings()
	
	# 获取主场景路径
	var main_scene := ProjectSettings.get_setting("application/run/main_scene") as String
	
	if main_scene.is_empty():
		push_error("[Boot] 未配置主场景")
		return
	
	# 如果当前场景就是主场景，不需要切换
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == main_scene:
		print("[Boot] 已在主场景，无需切换")
		return
	
	# 切换到主场景
	print("[Boot] 加载主场景: %s" % main_scene)
	get_tree().change_scene_to_file(main_scene)


## 应用已保存的设置
func _apply_saved_settings() -> void:
	print("[Boot] 应用保存的设置...")
	
	var settings = SaveManager.load_settings()
	if settings.is_empty():
		print("[Boot] 未找到保存的设置，使用默认值")
		return
	
	# 应用音量 (AudioManager 使用 BusType 枚举)
	var master_volume = settings.get("master_volume", 0.8)
	var music_volume = settings.get("music_volume", 0.7)
	var sfx_volume = settings.get("sfx_volume", 1.0)
	
	if AudioManager:
		AudioManager.set_bus_volume(AudioManager.BusType.MASTER, master_volume)
		AudioManager.set_bus_volume(AudioManager.BusType.MUSIC, music_volume)
		AudioManager.set_bus_volume(AudioManager.BusType.SFX, sfx_volume)
	
	# 应用窗口模式
	var window_mode = settings.get("window_mode", 0)
	match window_mode:
		0:  # Windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:  # Fullscreen
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:  # Borderless
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	
	# 应用 VSync
	var vsync_enabled = settings.get("vsync", true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	
	# 应用鼠标灵敏度
	var sensitivity = settings.get("mouse_sensitivity", 1.0)
	# 存储到 ProjectSettings 或全局变量供游戏使用
	ProjectSettings.set_setting("game/input/mouse_sensitivity", sensitivity)
	
	print("[Boot] 设置已应用")


## 检查启动是否完成
func is_boot_completed() -> bool:
	return _boot_completed


## 获取当前进度 (0.0 - 1.0)
func get_progress() -> float:
	if total_systems == 0:
		return 0.0
	return float(initialized_count) / float(total_systems)


## 获取当前状态描述
func get_status() -> String:
	if _boot_completed:
		return "启动完成"
	if current_system:
		return "正在加载: %s" % current_system
	return "初始化中..."
