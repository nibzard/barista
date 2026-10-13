# ABOUTME: Unit tests for SleepMeter accumulation, clamping, and recovery.
# ABOUTME: Pure logic tests, no scene tree needed.
extends GdUnitTestSuite

var _meter: SleepMeter


func before_test() -> void:
	_meter = auto_free(SleepMeter.new())


func test_add_accumulates() -> void:
	_meter.add(0.25)
	_meter.add(0.5)
	assert_float(_meter.value).is_equal_approx(0.75, 0.0001)


func test_add_clamps_at_max() -> void:
	_meter.add(2.0)
	assert_float(_meter.value).is_equal(1.0)
	assert_bool(_meter.is_asleep()).is_true()


func test_recover_reduces_and_clamps_at_zero() -> void:
	_meter.add(0.5)
	_meter.recover(0.2)
	assert_float(_meter.value).is_equal_approx(0.3, 0.0001)
	_meter.recover(5.0)
	assert_float(_meter.value).is_equal(0.0)
	assert_bool(_meter.is_asleep()).is_false()
