# tests/unit/test_enemy_indicator.gd
extends GutTest

## EnemyIndicatorArrow 单元测试 (TDD GREEN 阶段)
## 测试敌人指示器箭头的核心行为

var _indicator: EnemyIndicator
var _arrow: EnemyArrow


# ============================================
# Mock Enemy class with died signal
# ============================================

class MockEnemy extends Node:
	signal died


# ============================================
# 阈值检测测试
# ============================================

func test_threshold_detection() -> void:
	# Create EnemyIndicator node
	_indicator = EnemyIndicator.new()
	add_child(_indicator)
	_indicator.max_enemies_for_display = 3

	# Watch signals
	watch_signals(_indicator)

	# Test: indicator_disabled when count exceeds threshold (crosses UP)
	# Start with 4 enemies (above threshold)
	_indicator._active_arrows[1] = null  # placeholder
	_indicator._active_arrows[2] = null
	_indicator._active_arrows[3] = null
	_indicator._active_arrows[4] = null
	_indicator._threshold_armed = true  # Simulate armed state
	_indicator._check_threshold()
	assert_signal_emitted(_indicator, "indicator_disabled", "Should emit indicator_disabled when crossing above threshold")
	assert_false(_indicator._threshold_armed, "Threshold should be disarmed after indicator_disabled")

	# Reset
	_indicator._active_arrows.clear()
	_indicator._threshold_armed = false

	# Test: indicator_enabled when count drops to threshold (crosses DOWN)
	_indicator._active_arrows[1] = null
	_indicator._active_arrows[2] = null
	_indicator._active_arrows[3] = null
	_indicator._check_threshold()
	assert_signal_emitted(_indicator, "indicator_enabled", "Should emit indicator_enabled when crossing below threshold")
	assert_true(_indicator._threshold_armed, "Threshold should be armed after indicator_enabled")

	_indicator.queue_free()


# ============================================
# 箭头位置边缘测试
# ============================================

func test_arrow_position_edge() -> void:
	# Create EnemyIndicator node
	_indicator = EnemyIndicator.new()
	add_child(_indicator)

	# Set viewport bounds to 1280x720
	_indicator._viewport_bounds = Rect2(0, 0, 1280, 720)
	_indicator._ui_margin = 50.0

	# Test off-screen point to the right
	var off_screen_right := Vector2(2000, 360)
	var edge_pos := _indicator._get_edge_position(off_screen_right)

	# Verify edge position is within bounds (accounting for margin)
	assert_true(edge_pos.x <= 1280 - 50, "Edge X should be within screen bounds")
	assert_true(edge_pos.x >= 50, "Edge X should be >= margin")
	assert_true(edge_pos.y >= 50, "Edge Y should be >= margin")
	assert_true(edge_pos.y <= 720 - 50, "Edge Y should be <= screen height - margin")

	# Verify direction from center matches input direction
	var viewport_center := Vector2(640, 360)
	var expected_dir := (off_screen_right - viewport_center).normalized()
	var actual_dir := (edge_pos - viewport_center).normalized()
	assert_true(
		expected_dir.distance_to(actual_dir) < 0.01,
		"Edge position direction should match input direction"
	)

	# Test off-screen point to the top-right
	var off_screen_top_right := Vector2(1600, -100)
	edge_pos = _indicator._get_edge_position(off_screen_top_right)
	assert_true(edge_pos.y >= 50, "Top edge Y should be >= margin")
	assert_true(edge_pos.x <= 1280 - 50, "Right edge X should be within bounds")

	_indicator.queue_free()


# ============================================
# 箭头位置头顶测试
# ============================================

func test_arrow_position_overhead() -> void:
	# Create EnemyIndicator node
	_indicator = EnemyIndicator.new()
	add_child(_indicator)

	# Set viewport bounds
	_indicator._viewport_bounds = Rect2(0, 0, 1280, 720)

	# Set up a mock camera that returns known screen positions
	# Since we can't easily mock Camera2D in unit tests, test the _world_to_screen fallback
	# when no camera is set - it should return world_pos as-is
	var world_pos := Vector2(100, 200)
	var screen_pos := _indicator._world_to_screen(world_pos)

	# Without a camera, _world_to_screen returns world_pos unchanged
	assert_eq(screen_pos, world_pos, "Without camera, should return world_pos unchanged")

	# Test _is_on_screen for a point within expanded bounds
	var inside_point := Vector2(640, 360)
	var is_on_screen := _indicator._is_on_screen(inside_point)
	assert_true(is_on_screen, "Center point should be on screen")

	# Test _is_on_screen for a point outside
	var outside_point := Vector2(-100, -100)
	is_on_screen = _indicator._is_on_screen(outside_point)
	assert_false(is_on_screen, "Point outside expanded bounds should not be on screen")

	_indicator.queue_free()


# ============================================
# 状态转换测试
# ============================================

func test_state_transition() -> void:
	# Create EnemyArrow node
	_arrow = EnemyArrow.new()
	add_child(_arrow)

	# Set initial state to EDGE
	_arrow.set_state(EnemyArrow.ArrowState.EDGE)
	assert_eq(_arrow._state, EnemyArrow.ArrowState.EDGE, "State should be EDGE after first set_state")

	# Transition to OVERHEAD - should detect the transition
	_arrow.set_state(EnemyArrow.ArrowState.OVERHEAD)
	assert_eq(_arrow._state, EnemyArrow.ArrowState.OVERHEAD, "State should be OVERHEAD after set_state")

	# Call set_target_position to apply OVERHEAD rotation (downward art keeps 0 rad)
	# The _pending_transition flag triggers a tween
	_arrow.set_target_position(Vector2(500, 300))

	# Wait for the transition tween to complete (TRANSITION_DURATION = 0.15s)
	await get_tree().create_timer(0.2).timeout

	# Verify OVERHEAD rotation stays 0 for downward arrow art
	assert_true(
		abs(_arrow.rotation) < 0.01,
		"OVERHEAD state rotation should be 0 (downward texture baseline)"
	)

	# Transition back to EDGE
	_arrow.set_state(EnemyArrow.ArrowState.EDGE)
	assert_eq(_arrow._state, EnemyArrow.ArrowState.EDGE, "State should be EDGE after transition back")

	# Set a different target to see EDGE rotation change
	_arrow.set_target_position(Vector2(100, 100))

	# Wait for transition tween to complete
	await get_tree().create_timer(0.2).timeout

	# Verify rotation changed (EDGE rotation is direction-based, not fixed overhead 0)
	assert_true(
		abs(_arrow.rotation) > 0.1,
		"EDGE state rotation should not be fixed overhead orientation"
	)

	_arrow.queue_free()


# ============================================
# 信号连接测试
# ============================================

func test_signal_connections() -> void:
	# Create EnemyIndicator node
	_indicator = EnemyIndicator.new()
	add_child(_indicator)

	# Create a mock enemy using our MockEnemy class (has died signal)
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)

	# Test: _connect_enemy_signals with valid enemy should not crash
	_indicator._connect_enemy_signals(mock_enemy)
	# _connect_enemy_signals returns void, check it doesn't error

	# Test: _connect_enemy_signals with invalid enemy should be guarded
	var invalid_enemy: Node = null
	_indicator._connect_enemy_signals(invalid_enemy)  # Should not crash due to is_instance_valid check

	# Test: _on_enemy_died removes enemy from _active_arrows
	var enemy_id := mock_enemy.get_instance_id()
	_indicator._active_arrows[enemy_id] = mock_enemy
	_indicator._arrow_indicators[enemy_id] = EnemyArrow.new()  # Add mock arrow
	add_child(_indicator._arrow_indicators[enemy_id])

	_indicator._on_enemy_died(enemy_id)

	assert_false(
		_indicator._active_arrows.has(enemy_id),
		"Enemy should be removed from _active_arrows after _on_enemy_died"
	)

	mock_enemy.queue_free()
	_indicator.queue_free()
