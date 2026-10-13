# ABOUTME: Unit tests for the WakeUps rules from GAME_DESIGN sections 9, 14, and 18.
# ABOUTME: Pure logic tests, no scene tree needed. Meter sleep versus full death.
extends GdUnitTestSuite

const WAKE_UPS_BALANCE := preload("res://resources/balance/wake_ups.tres")

var _wake_ups: WakeUps


func before_test() -> void:
	_wake_ups = WakeUps.new(WAKE_UPS_BALANCE)


func test_starts_with_five_wake_ups() -> void:
	assert_int(_wake_ups.remaining).is_equal(5)
	assert_bool(_wake_ups.has_wake_ups()).is_true()


func test_maximum_is_five() -> void:
	assert_int(_wake_ups.balance.max_wake_ups).is_equal(5)


func test_meter_sleep_spends_one_wake_up_and_wakes_in_cafe() -> void:
	assert_int(_wake_ups.register_sleep()).is_equal(WakeUps.SleepOutcome.WOKE_IN_CAFE)
	assert_int(_wake_ups.remaining).is_equal(4)


func test_each_meter_sleep_spends_exactly_one_wake_up() -> void:
	for index: int in range(5):
		var outcome: int = _wake_ups.register_sleep()
		assert_int(outcome).is_equal(WakeUps.SleepOutcome.WOKE_IN_CAFE)
		assert_int(_wake_ups.remaining).is_equal(4 - index)


func test_the_fifth_sleep_uses_the_last_wake_up() -> void:
	for index: int in range(5):
		_wake_ups.register_sleep()
	assert_int(_wake_ups.remaining).is_equal(0)
	assert_bool(_wake_ups.has_wake_ups()).is_false()


func test_sleep_at_zero_wake_ups_is_full_death() -> void:
	for index: int in range(5):
		_wake_ups.register_sleep()

	assert_int(_wake_ups.register_sleep()).is_equal(WakeUps.SleepOutcome.DIED)
	assert_int(_wake_ups.remaining).is_equal(0)


func test_repeated_sleep_at_zero_keeps_reporting_death() -> void:
	for index: int in range(5):
		_wake_ups.register_sleep()

	_wake_ups.register_sleep()
	assert_int(_wake_ups.register_sleep()).is_equal(WakeUps.SleepOutcome.DIED)


func test_tower_switch_restores_one_wake_up() -> void:
	_wake_ups.register_sleep()
	_wake_ups.register_sleep()

	assert_int(_wake_ups.restore_one()).is_equal(4)
	assert_int(_wake_ups.remaining).is_equal(4)


func test_tower_switch_restores_from_zero() -> void:
	for index: int in range(5):
		_wake_ups.register_sleep()

	assert_int(_wake_ups.restore_one()).is_equal(1)
	assert_bool(_wake_ups.has_wake_ups()).is_true()


func test_tower_switch_restore_stops_at_the_maximum() -> void:
	assert_int(_wake_ups.restore_one()).is_equal(5)
	assert_int(_wake_ups.remaining).is_equal(5)


func test_tower_switch_restore_climbs_back_to_the_maximum() -> void:
	for index: int in range(5):
		_wake_ups.register_sleep()

	_wake_ups.restore_one()
	_wake_ups.restore_one()
	_wake_ups.restore_one()
	_wake_ups.restore_one()
	assert_int(_wake_ups.remaining).is_equal(4)
	assert_int(_wake_ups.restore_one()).is_equal(5)
	assert_int(_wake_ups.restore_one()).is_equal(5)
