# ABOUTME: Unit tests for the cup flight arc: a parabola over the throw.
# ABOUTME: Pure math on the static height function, no scene tree needed.
extends GdUnitTestSuite

const PEAK := 40.0


func test_arc_starts_and_ends_at_ground_level() -> void:
	assert_float(CoffeeCup.arc_height(0.0, PEAK)).is_equal_approx(0.0, 0.0001)
	assert_float(CoffeeCup.arc_height(1.0, PEAK)).is_equal_approx(0.0, 0.0001)


func test_arc_peaks_half_way_through_the_flight() -> void:
	assert_float(CoffeeCup.arc_height(0.5, PEAK)).is_equal_approx(PEAK, 0.0001)


func test_arc_is_symmetric_around_the_peak() -> void:
	assert_float(CoffeeCup.arc_height(0.2, PEAK)).is_equal_approx(
		CoffeeCup.arc_height(0.8, PEAK), 0.0001
	)


func test_arc_rises_then_falls() -> void:
	assert_float(CoffeeCup.arc_height(0.25, PEAK)).is_less(CoffeeCup.arc_height(0.5, PEAK))
	assert_float(CoffeeCup.arc_height(0.75, PEAK)).is_less(CoffeeCup.arc_height(0.5, PEAK))


func test_arc_scales_with_the_balance_peak() -> void:
	assert_float(CoffeeCup.arc_height(0.5, 10.0)).is_equal_approx(10.0, 0.0001)
