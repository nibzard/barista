# ABOUTME: Unit tests for the section 21 tolerance rule.
# ABOUTME: Past 30 minutes a sound filters deeper or it goes silent.
extends GdUnitTestSuite

const ADDRESS_BALANCE := preload("res://resources/balance/address_audio.tres")

var _tolerance: SoundTolerance


func before_test() -> void:
	_tolerance = SoundTolerance.new(ADDRESS_BALANCE)


func test_a_registered_sound_starts_tolerable() -> void:
	_tolerance.register("address_loop", true)
	assert_bool(_tolerance.is_tolerable("address_loop")).is_true()
	assert_int(_tolerance.remedy("address_loop")).is_equal(SoundTolerance.Remedy.NONE)


func test_exposure_adds_up_across_calls() -> void:
	_tolerance.register("address_loop", true)
	_tolerance.expose("address_loop", 10.0)
	_tolerance.expose("address_loop", 15.5)
	assert_float(_tolerance.exposure_minutes("address_loop")).is_equal_approx(25.5, 0.001)


func test_the_sound_stays_tolerable_at_thirty_minutes() -> void:
	_tolerance.register("address_loop", true)
	_tolerance.expose("address_loop", ADDRESS_BALANCE.tolerance_minutes)
	assert_bool(_tolerance.is_tolerable("address_loop")).is_true()
	assert_int(_tolerance.remedy("address_loop")).is_equal(SoundTolerance.Remedy.NONE)


func test_past_the_limit_an_essential_sound_filters() -> void:
	_tolerance.register("address_loop", true)
	_tolerance.expose("address_loop", ADDRESS_BALANCE.tolerance_minutes + 0.01)
	assert_bool(_tolerance.is_tolerable("address_loop")).is_false()
	assert_int(_tolerance.remedy("address_loop")).is_equal(SoundTolerance.Remedy.FILTER)
	assert_float(_tolerance.remedy_filter_hz()).is_equal(ADDRESS_BALANCE.tolerance_filter_hz)


func test_past_the_limit_a_plain_sound_goes_silent() -> void:
	_tolerance.register("vinyl_jazz", false)
	_tolerance.expose("vinyl_jazz", ADDRESS_BALANCE.tolerance_minutes + 0.01)
	assert_int(_tolerance.remedy("vinyl_jazz")).is_equal(SoundTolerance.Remedy.STOP)


func test_an_unregistered_sound_accumulates_nothing() -> void:
	_tolerance.expose("mystery", 100.0)
	assert_float(_tolerance.exposure_minutes("mystery")).is_equal(0.0)


func test_registration_holds_the_first_essential_flag() -> void:
	_tolerance.register("address_loop", true)
	_tolerance.register("address_loop", false)
	_tolerance.expose("address_loop", ADDRESS_BALANCE.tolerance_minutes + 0.01)
	assert_int(_tolerance.remedy("address_loop")).is_equal(SoundTolerance.Remedy.FILTER)
