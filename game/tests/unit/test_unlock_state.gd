# ABOUTME: Unit tests for the paywall unlock state behind the bridge gate.
# ABOUTME: The stub purchase hook stands in for the store flow, see backlog T053.
extends GdUnitTestSuite


func test_the_game_starts_with_the_road_east_locked() -> void:
	var state := UnlockState.new()
	assert_bool(state.is_unlocked()).is_false()


func test_one_unlock_opens_the_road_once() -> void:
	var state := UnlockState.new()
	var unlock_signals: Array[int] = []
	state.unlocked.connect(func() -> void: unlock_signals.append(1))

	assert_bool(state.unlock()).is_true()
	assert_bool(state.is_unlocked()).is_true()
	assert_int(unlock_signals.size()).is_equal(1)


func test_repeated_unlock_calls_stay_silent() -> void:
	var state := UnlockState.new()
	state.unlock()
	var unlock_signals: Array[int] = []
	state.unlocked.connect(func() -> void: unlock_signals.append(1))

	assert_bool(state.unlock()).is_false()
	assert_int(unlock_signals.size()).is_equal(0)


func test_save_round_trip_carries_the_purchase() -> void:
	var locked := UnlockState.new()
	var loaded_locked := UnlockState.new()
	loaded_locked.load_state(locked.save_state())
	assert_bool(loaded_locked.is_unlocked()).is_false()

	var paid := UnlockState.new()
	paid.unlock()
	var loaded_paid := UnlockState.new()
	var unlock_signals: Array[int] = []
	loaded_paid.unlocked.connect(func() -> void: unlock_signals.append(1))
	loaded_paid.load_state(paid.save_state())

	assert_bool(loaded_paid.is_unlocked()).is_true()
	assert_int(unlock_signals.size()).is_equal(0)
