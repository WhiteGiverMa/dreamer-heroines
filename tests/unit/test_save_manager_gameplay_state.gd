extends GutTest

class GameplaySaveStateStub:
	extends Node

	var gameplay_active := false
	var pending_playtime_seconds := 0
	var consume_call_count := 0

	func is_gameplay_active() -> bool:
		return gameplay_active

	func consume_pending_playtime_seconds() -> int:
		consume_call_count += 1
		var pending := pending_playtime_seconds
		pending_playtime_seconds = 0
		return pending

var _manager
var _provider
var _save_wrapper


func before_each() -> void:
	_manager = get_node("/root/CSharpSaveManager")
	_save_wrapper = get_node("/root/SaveManager")
	_manager.AutoSaveInterval = 10.0
	_save_wrapper.set_gameplay_save_state_provider(null)
	if _manager.SaveCompleted.is_connected(_save_wrapper._on_csharp_save_completed):
		_manager.SaveCompleted.disconnect(_save_wrapper._on_csharp_save_completed)

	_provider = GameplaySaveStateStub.new()
	add_child_autofree(_provider)


func after_each() -> void:
	if _manager:
		_save_wrapper.set_gameplay_save_state_provider(null)
		if _save_wrapper and not _manager.SaveCompleted.is_connected(_save_wrapper._on_csharp_save_completed):
			_manager.SaveCompleted.connect(_save_wrapper._on_csharp_save_completed)

	for slot in [7, 8, 9]:
		if _manager and is_instance_valid(_manager) and _manager.HasSaveInSlot(slot):
			_manager.DeleteSave(slot)


func test_unavailable_gameplay_state_keeps_autosave_gate_closed_and_persists_zero_pending_time() -> void:
	_manager.call("CreateNewSaveForTesting", 9, "UnavailableState")
	await get_tree().process_frame

	_manager._process(5.0)

	assert_eq(_manager.TimeUntilAutoSave, 10.0, "Unavailable gameplay state should keep autosave timer closed")

	_manager.call("SetCurrentPlayerTotalPlayTimeForTesting", 12)

	_manager.SaveToSlot(9, false)
	await get_tree().process_frame

	assert_eq(_manager.call("GetCurrentPlayerTotalPlayTimeForTesting"), 12, "Unavailable gameplay state should contribute zero playtime")


func test_autosave_timer_advances_only_while_gameplay_is_active() -> void:
	_save_wrapper.set_gameplay_save_state_provider(_provider)
	_manager.call("CreateNewSaveForTesting", 8, "AutosaveGate")
	await get_tree().process_frame

	_provider.gameplay_active = true
	_manager._process(4.0)
	assert_eq(_manager.TimeUntilAutoSave, 6.0, "Active gameplay should advance autosave timer")

	_provider.gameplay_active = false
	_manager._process(3.0)
	assert_eq(_manager.TimeUntilAutoSave, 6.0, "Inactive gameplay should stop autosave timer advancement")


func test_save_consumes_pending_playtime_delta_and_keeps_cache_in_sync() -> void:
	_save_wrapper.set_gameplay_save_state_provider(_provider)
	_manager.call("CreateNewSaveForTesting", 7, "PlaytimeDelta")
	await get_tree().process_frame

	_manager.call("SetCurrentPlayerTotalPlayTimeForTesting", 10)
	_provider.consume_call_count = 0

	_provider.pending_playtime_seconds = 5
	_manager.SaveToSlot(7, false)
	await get_tree().process_frame

	assert_eq(_manager.call("GetCurrentPlayerTotalPlayTimeForTesting"), 15, "First save should persist the pending playtime delta")
	assert_eq(_provider.pending_playtime_seconds, 0, "Pending playtime should be consumed atomically")

	_provider.pending_playtime_seconds = 3
	_manager.SaveToSlot(7, false)
	await get_tree().process_frame

	assert_eq(_manager.call("GetCurrentPlayerTotalPlayTimeForTesting"), 18, "Subsequent saves should build on the persisted total playtime")
	assert_eq(_provider.consume_call_count, 2, "Save path should consume pending playtime once per save")
