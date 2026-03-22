# src/base/game_system.gd
class_name GameSystem
extends Node

## 系统名称（用于日志和依赖检查）
@export var system_name: String = ""

## 是否已完成初始化
var is_initialized: bool = false

## 初始化完成信号
signal system_ready(system_name: String)

## 初始化方法 - 子类必须重写
func initialize() -> void:
	push_warning("GameSystem.initialize() 未在子类重写: %s" % name)
	_mark_ready()

## 异步初始化版本（用于需要 await 的场景）
func initialize_async() -> void:
	await initialize()

## 标记初始化完成
func _mark_ready() -> void:
	is_initialized = true
	system_ready.emit(system_name)
	print("[GameSystem] %s 初始化完成" % system_name)
