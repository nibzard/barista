# ABOUTME: Unit tests for the DanceOff rhythm judge, section 24.
# ABOUTME: Pure logic: beat windows, tap verdicts, and the win threshold.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/moonwalker.tres")


func test_a_tap_inside_the_perfect_window_lands_perfect() -> void:
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	dance.tick(BALANCE.dance_first_beat_delay_seconds)
	var verdict := dance.tap()
	assert_int(verdict).is_equal(DanceOff.Verdict.PERFECT)
	assert_int(dance.hits()).is_equal(1)


func test_a_tap_inside_the_good_window_lands_good() -> void:
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	dance.tick(BALANCE.dance_first_beat_delay_seconds + BALANCE.dance_perfect_window_seconds)
	assert_int(dance.tap()).is_equal(DanceOff.Verdict.GOOD)


func test_an_off_beat_tap_misses_without_spending_the_beat() -> void:
	# An early tap earns the miss, and the waiting beat stays tappable: the
	# dance-off stays fair for a player who rushes the first beat.
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	dance.tick(BALANCE.dance_first_beat_delay_seconds - BALANCE.dance_good_window_seconds - 0.05)
	assert_int(dance.tap()).is_equal(DanceOff.Verdict.MISS)
	assert_int(dance.hits()).is_equal(0)
	dance.tick(BALANCE.dance_good_window_seconds + 0.05)
	assert_int(dance.tap()).is_equal(DanceOff.Verdict.PERFECT)


func test_an_untapped_beat_misses_itself() -> void:
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	dance.tick(BALANCE.dance_first_beat_delay_seconds + BALANCE.dance_good_window_seconds + 0.01)
	assert_int(dance.next_beat()).is_equal(1)
	assert_int(dance.hits()).is_equal(0)


func test_enough_hits_win_the_dance() -> void:
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	for i: int in range(dance.beats_total()):
		dance.tick(dance.beat_time(i) - dance.elapsed())
		dance.tap()
	assert_bool(dance.is_running()).is_true()
	dance.tick(BALANCE.dance_good_window_seconds + 0.02)
	assert_bool(dance.is_over()).is_true()
	assert_int(dance.hits()).is_equal(dance.beats_total())
	assert_bool(dance.won()).is_true()


func test_no_taps_lose_the_dance() -> void:
	var dance := DanceOff.new(BALANCE)
	dance.begin()
	dance.tick(dance.beat_time(dance.beats_total() - 1) + BALANCE.dance_good_window_seconds + 0.02)
	assert_bool(dance.is_over()).is_true()
	assert_bool(dance.won()).is_false()


func test_the_beat_schedule_spreads_evenly_from_the_first_delay() -> void:
	var dance := DanceOff.new(BALANCE)
	assert_float(dance.beat_time(0)).is_equal(BALANCE.dance_first_beat_delay_seconds)
	assert_float(dance.beat_time(3) - dance.beat_time(2)).is_equal(
		BALANCE.dance_beat_interval_seconds
	)
