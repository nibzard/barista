# ABOUTME: Unit tests for SleepMeter rates from GAME_DESIGN section 14.
# ABOUTME: Pure logic tests, no scene tree needed. Full meter means awake.
extends GdUnitTestSuite

const METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")

var _meter: SleepMeter


func before_test() -> void:
	_meter = SleepMeter.new(METER_BALANCE)


func test_starts_full_awake() -> void:
	assert_float(_meter.value).is_equal(100.0)
	assert_bool(_meter.is_asleep()).is_false()


func test_passive_drain_rate() -> void:
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(99.5, 0.0001)


func test_sleep_zone_drain_rate() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(98.5, 0.0001)


func test_boring_attack_drain_rate() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.BORING_ATTACK)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(95.0, 0.0001)


func test_hug_drain_rate() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.HUG)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(85.0, 0.0001)


func test_strongest_escalation_wins() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)
	_meter.escalate_drain(SleepMeter.DrainTier.HUG)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(85.0, 0.0001)


func test_escalation_lasts_one_tick() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.HUG)
	_meter.tick(1.0)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(84.5, 0.0001)


func test_safe_zone_suppresses_passive_drain() -> void:
	_meter.suppress_environmental_drain()
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal(100.0)


func test_safe_zone_suppresses_sleep_zone_drain() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)
	_meter.suppress_environmental_drain()
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal(100.0)


func test_safe_zone_does_not_stop_boring_attacks() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.BORING_ATTACK)
	_meter.suppress_environmental_drain()
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(95.0, 0.0001)


func test_safe_zone_does_not_stop_hugs() -> void:
	_meter.escalate_drain(SleepMeter.DrainTier.HUG)
	_meter.suppress_environmental_drain()
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(85.0, 0.0001)


func test_suppression_lasts_one_tick() -> void:
	_meter.suppress_environmental_drain()
	_meter.tick(1.0)
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(99.5, 0.0001)


func test_drinking_gain_works_in_a_safe_zone() -> void:
	_meter.drain(80.0)
	_meter.suppress_environmental_drain()
	_meter.begin_drinking()
	_meter.tick(1.5)
	# Start 20, cup gain 40, safe zone drains nothing.
	assert_float(_meter.value).is_equal_approx(60.0, 0.0001)


func test_drain_clamps_at_zero_and_sleeps() -> void:
	_meter.drain(200.0)
	assert_float(_meter.value).is_equal(0.0)
	assert_bool(_meter.is_asleep()).is_true()


func test_gain_clamps_at_max() -> void:
	_meter.drain(30.0)
	_meter.gain(1000.0)
	assert_float(_meter.value).is_equal(100.0)
	assert_bool(_meter.is_asleep()).is_false()


func test_drinking_adds_cup_gain_over_drink_duration() -> void:
	_meter.drain(80.0)
	_meter.begin_drinking()
	assert_bool(_meter.is_drinking()).is_true()
	_meter.tick(1.5)
	assert_bool(_meter.is_drinking()).is_false()
	# Start 20, cup gain 40, passive drain 0.75 over 1.5 s.
	assert_float(_meter.value).is_equal_approx(59.25, 0.0001)


func test_drinking_gain_stops_after_duration() -> void:
	_meter.drain(90.0)
	_meter.begin_drinking()
	_meter.tick(3.0)
	# Start 10, cup gain 40 ends at 1.5 s, passive drain runs the full 3 s.
	assert_float(_meter.value).is_equal_approx(48.5, 0.0001)


func test_reset_starts_a_clean_new_day() -> void:
	_meter.drain(80.0)
	_meter.begin_drinking()
	_meter.reset()
	assert_float(_meter.value).is_equal(100.0)
	assert_bool(_meter.is_asleep()).is_false()
	assert_bool(_meter.is_drinking()).is_false()
	_meter.tick(1.5)
	# A fresh day keeps no cup gain: only the passive drain of 1.5 s remains.
	assert_float(_meter.value).is_equal_approx(99.25, 0.0001)


func test_second_drink_call_while_drinking_changes_nothing() -> void:
	_meter.drain(80.0)
	_meter.begin_drinking()
	_meter.tick(0.5)
	_meter.begin_drinking()
	_meter.tick(1.0)
	assert_float(_meter.value).is_equal_approx(59.25, 0.0001)
