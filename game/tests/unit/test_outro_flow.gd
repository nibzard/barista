# ABOUTME: Unit tests for the pure outro step machine of section 16, T048.
# ABOUTME: Proves the beat order, the mid-sentence catch, and the no-replay rule.
extends GdUnitTestSuite

const KAREN_TYPE := preload("res://resources/enemies/karen.tres")

# The full demand of the Karen, section 6, and where the credits cut it,
# inside the last word: mid-sentence by construction.
const DEMAND_LINE := "Manager! I want to see the manager!"
const CAUGHT_LINE := "Manager! I want to see the ma—"

var _transitions: Array[OutroFlow.Step] = []
var _finished_count := 0


func before_test() -> void:
	_transitions.clear()
	_finished_count = 0


func test_the_outro_starts_waiting() -> void:
	var flow := OutroFlow.new()
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.WAITING)
	assert_bool(flow.has_played()).is_false()
	assert_bool(flow.is_post_game()).is_false()


func test_the_step_order_pin() -> void:
	# One value per beat of section 16, in play order.
	assert_int(OutroFlow.Step.WAITING).is_equal(0)
	assert_int(OutroFlow.Step.ARRIVAL).is_equal(1)
	assert_int(OutroFlow.Step.DEMAND).is_equal(2)
	assert_int(OutroFlow.Step.CREDITS).is_equal(3)
	assert_int(OutroFlow.Step.POST_GAME).is_equal(4)


func test_every_event_is_refused_before_the_outro_begins() -> void:
	var flow := OutroFlow.new()
	assert_bool(flow.notify_karen_blocked()).is_false()
	assert_bool(flow.notify_credits_started()).is_false()
	assert_bool(flow.notify_credits_ended()).is_false()
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.WAITING)


func test_events_are_refused_out_of_order() -> void:
	var flow := OutroFlow.new()
	assert_bool(flow.begin()).is_true()
	# The credits cannot start before she blocks the road and demands.
	assert_bool(flow.notify_credits_started()).is_false()
	assert_bool(flow.notify_credits_ended()).is_false()
	assert_bool(flow.notify_karen_blocked()).is_true()
	# The roll cannot end before it started.
	assert_bool(flow.notify_credits_ended()).is_false()
	assert_bool(flow.notify_credits_started()).is_true()
	# The beats do not run backwards after the version ended.
	assert_bool(flow.notify_credits_started()).is_false()
	assert_bool(flow.notify_karen_blocked()).is_false()


func test_the_full_sequence_reaches_the_post_game() -> void:
	var flow := OutroFlow.new()
	flow.begin()
	flow.notify_karen_blocked()
	flow.notify_credits_started()
	assert_bool(flow.notify_credits_ended()).is_true()
	assert_bool(flow.is_post_game()).is_true()
	assert_bool(flow.has_played()).is_true()


func test_step_changed_fires_once_per_real_move() -> void:
	var flow := OutroFlow.new()
	flow.step_changed.connect(
		func(from_step: OutroFlow.Step, to_step: OutroFlow.Step) -> void:
			_transitions.append(from_step)
			_transitions.append(to_step)
	)
	flow.begin()
	flow.notify_karen_blocked()
	flow.notify_credits_started()
	flow.notify_credits_ended()
	# A refused move fires nothing.
	flow.notify_credits_ended()
	assert_int(_transitions.size()).is_equal(8)
	var expected: Array[OutroFlow.Step] = [
		OutroFlow.Step.WAITING,
		OutroFlow.Step.ARRIVAL,
		OutroFlow.Step.ARRIVAL,
		OutroFlow.Step.DEMAND,
		OutroFlow.Step.DEMAND,
		OutroFlow.Step.CREDITS,
		OutroFlow.Step.CREDITS,
		OutroFlow.Step.POST_GAME,
	]
	assert_array(_transitions).is_equal(expected)


func test_finished_fires_exactly_once() -> void:
	var flow := OutroFlow.new()
	flow.finished.connect(func() -> void: _finished_count += 1)
	flow.begin()
	flow.notify_karen_blocked()
	flow.notify_credits_started()
	assert_int(_finished_count).is_equal(0)
	flow.notify_credits_ended()
	assert_int(_finished_count).is_equal(1)
	flow.notify_credits_ended()
	assert_int(_finished_count).is_equal(1)


func test_a_played_outro_never_begins_again() -> void:
	var flow := OutroFlow.new()
	flow.begin()
	assert_bool(flow.begin()).is_false()
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.ARRIVAL)
	flow.notify_karen_blocked()
	flow.notify_credits_started()
	flow.notify_credits_ended()
	assert_bool(flow.begin()).is_false()
	assert_bool(flow.is_post_game()).is_true()


func test_the_demand_line_is_the_karen_wake_line() -> void:
	# Section 6: when she shows up, she asks for the manager. The outro speaks
	# the same line as the enemy type.
	var flow := OutroFlow.new()
	assert_str(flow.demand_line()).is_equal(KAREN_TYPE.wake_line)
	assert_str(flow.demand_line()).is_equal(DEMAND_LINE)


func test_the_credits_catch_her_mid_sentence() -> void:
	# Section 16: the credits catch her mid-sentence. The frozen line is a
	# strict prefix of the demand, cut inside the last word, on the cut mark.
	var flow := OutroFlow.new()
	var caught := flow.caught_line()
	assert_str(caught).is_equal(CAUGHT_LINE)
	assert_str(caught.right(1)).is_equal("—")
	assert_bool(DEMAND_LINE.begins_with(caught.trim_suffix("—"))).is_true()
	assert_int(caught.length()).is_less(DEMAND_LINE.length())
	# The cut lands inside the last word, not at a word edge.
	assert_str(DEMAND_LINE.substr(caught.length() - 1, 1)).is_not_equal(" ")


func test_save_round_trip_mid_demand() -> void:
	var flow := OutroFlow.new()
	flow.begin()
	flow.notify_karen_blocked()
	var saved := flow.save_state()
	var loaded := OutroFlow.new()
	loaded.load_state(saved)
	assert_int(loaded.current_step()).is_equal(OutroFlow.Step.DEMAND)
	# A loaded outro never replays: begin is refused on any played step.
	assert_bool(loaded.begin()).is_false()
	assert_bool(loaded.notify_credits_started()).is_true()


func test_load_post_game_stays_played_and_silent() -> void:
	var flow := OutroFlow.new()
	flow.begin()
	flow.notify_karen_blocked()
	flow.notify_credits_started()
	flow.notify_credits_ended()
	var saved := flow.save_state()
	var loaded := OutroFlow.new()
	loaded.step_changed.connect(
		func(_from_step: OutroFlow.Step, _to_step: OutroFlow.Step) -> void:
			_transitions.append(_to_step)
	)
	loaded.finished.connect(func() -> void: _finished_count += 1)
	loaded.load_state(saved)
	assert_bool(loaded.is_post_game()).is_true()
	assert_bool(loaded.begin()).is_false()
	assert_int(_transitions.size()).is_equal(0)
	assert_int(_finished_count).is_equal(0)


func test_load_unknown_step_falls_back_to_waiting() -> void:
	var flow := OutroFlow.new()
	flow.load_state({"step": 99})
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.WAITING)
	flow.load_state({"step": -3})
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.WAITING)


func test_load_empty_state_starts_waiting() -> void:
	var flow := OutroFlow.new()
	flow.load_state({})
	assert_int(flow.current_step()).is_equal(OutroFlow.Step.WAITING)
	assert_bool(flow.has_played()).is_false()
