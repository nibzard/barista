# ABOUTME: Unit tests for the DawnClock of the Moonwalker mystery, section 24.
# ABOUTME: Pure logic: the dawn window opens, holds, closes, and returns.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/moonwalker.tres")


func test_a_fresh_day_starts_just_past_dawn() -> void:
	# The figure needs the silence earned first: dawn never opens at the gate.
	var clock := DawnClock.new(BALANCE)
	assert_bool(clock.is_dawn()).is_false()


func test_dawn_opens_after_the_rest_of_the_day() -> void:
	var clock := DawnClock.new(BALANCE)
	clock.tick(BALANCE.day_cycle_seconds - BALANCE.dawn_length_seconds)
	assert_bool(clock.is_dawn()).is_true()


func test_dawn_holds_its_window_then_closes() -> void:
	var clock := DawnClock.new(BALANCE)
	clock.advance(BALANCE.day_cycle_seconds - BALANCE.dawn_length_seconds)
	assert_bool(clock.is_dawn()).is_true()
	clock.tick(BALANCE.dawn_length_seconds)
	assert_bool(clock.is_dawn()).is_false()


func test_dawn_returns_the_next_day() -> void:
	var clock := DawnClock.new(BALANCE)
	clock.tick(BALANCE.day_cycle_seconds - BALANCE.dawn_length_seconds)
	assert_bool(clock.is_dawn()).is_true()
	clock.tick(BALANCE.day_cycle_seconds)
	assert_bool(clock.is_dawn()).is_true()


func test_the_clock_wraps_instead_of_growing() -> void:
	var clock := DawnClock.new(BALANCE)
	clock.advance(BALANCE.day_cycle_seconds * 4.5)
	assert_float(clock.time_of_day()).is_less(BALANCE.day_cycle_seconds)
