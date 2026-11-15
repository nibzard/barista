# ABOUTME: Unit tests for The Foam Watch minigame, per GAME_DESIGN section 8.
# ABOUTME: Pure grading logic: tick the clock, lift the pot, read the score.
# ABOUTME: More foam gives a better cup; greed past the grace window costs it.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/foam_watch.tres")


func test_a_new_watch_starts_cold_and_running() -> void:
	var watch := FoamWatch.new(BALANCE)
	assert_float(watch.heat).is_equal(0.0)
	assert_float(watch.foam).is_equal(0.0)
	assert_float(watch.at_rim_seconds).is_equal(0.0)
	assert_float(watch.elapsed).is_equal(0.0)
	assert_int(watch.step).is_equal(FoamWatch.Step.HEAT)
	assert_bool(watch.is_running()).is_true()
	assert_object(watch.result).is_null()
	assert_bool(watch.is_at_rim()).is_false()
	assert_bool(watch.is_rushing()).is_false()


func test_the_pot_heats_up_toward_the_boil() -> void:
	var watch := FoamWatch.new(BALANCE)
	watch.tick(1.0)
	assert_float(watch.heat).is_equal_approx(0.5, 0.0001)
	assert_float(watch.foam).is_equal(0.0)
	assert_int(watch.step).is_equal(FoamWatch.Step.HEAT)
	watch.tick(1.0)
	assert_float(watch.heat).is_equal(1.0)
	assert_int(watch.step).is_equal(FoamWatch.Step.RISE)
	assert_float(watch.foam).is_equal(0.0)


func test_heat_clamps_at_the_full_boil() -> void:
	var watch := FoamWatch.new(BALANCE)
	for _i: int in range(5):
		watch.tick(1.0)
	assert_float(watch.heat).is_equal(1.0)


func test_the_foam_rises_only_after_the_boil_starts() -> void:
	# No foam while the pot heats: the watch phase pays nothing.
	var watch := FoamWatch.new(BALANCE)
	watch.tick(1.0)
	assert_float(watch.foam).is_equal(0.0)
	watch.tick(1.0)
	watch.tick(1.0)
	assert_float(watch.foam).is_equal_approx(0.3, 0.0001)


func test_the_foam_rises_at_the_steady_rate() -> void:
	var watch := _at_rise()
	watch.tick(1.0)
	assert_float(watch.foam).is_equal_approx(0.3, 0.0001)
	assert_bool(watch.is_rushing()).is_false()
	assert_bool(watch.is_at_rim()).is_false()


func test_the_foam_rushes_above_the_rush_line() -> void:
	# The tick that lands exactly on the rush line still runs at the steady
	# rate; every tick after it runs at the rush rate.
	var watch := _at_rise()
	watch.tick(1.0)
	watch.tick(1.0)
	assert_float(watch.foam).is_equal_approx(BALANCE.rush_start_foam, 0.0001)
	assert_bool(watch.is_rushing()).is_true()
	watch.tick(0.5)
	assert_float(watch.foam).is_equal_approx(0.93, 0.0001)


func test_the_foam_clamps_at_the_rim() -> void:
	var watch := _at_the_rim()
	for _i: int in range(3):
		watch.tick(0.1)
	assert_float(watch.foam).is_equal(FoamWatch.RIM_FOAM)
	assert_bool(watch.is_at_rim()).is_true()


func test_the_landing_tick_costs_no_grace() -> void:
	# The tick that overshoots into the rim lands the foam and spends none of
	# the grace window; the window starts on the next tick.
	var watch := _at_the_rim()
	assert_float(watch.at_rim_seconds).is_equal(0.0)
	assert_bool(watch.is_running()).is_true()
	watch.tick(0.4)
	assert_float(watch.at_rim_seconds).is_equal_approx(0.4, 0.0001)
	assert_bool(watch.is_running()).is_true()


func test_the_pot_boils_over_after_the_grace_window() -> void:
	var watch := _at_the_rim()
	watch.tick(0.4)
	watch.tick(0.4)
	assert_bool(watch.is_running()).is_false()
	var result := watch.result
	assert_int(result.outcome).is_equal(FoamResult.Outcome.BOILED_OVER)
	assert_float(result.score).is_equal(BALANCE.boil_over_score)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.foam).is_equal(FoamWatch.RIM_FOAM)
	assert_float(result.at_rim_seconds).is_equal_approx(BALANCE.boil_over_grace_seconds, 0.0001)
	assert_float(result.elapsed_seconds).is_equal_approx(5.8, 0.001)
	assert_bool(result.is_lifted()).is_false()


func test_a_watch_left_alone_always_boils_over() -> void:
	# The clock ends the run on its own: no lift, no stall, one ending.
	var watch := FoamWatch.new(BALANCE)
	var ticks := 0
	while watch.is_running() and ticks < 20:
		watch.tick(1.0)
		ticks += 1
	assert_int(ticks).is_equal(6)
	assert_int(watch.result.outcome).is_equal(FoamResult.Outcome.BOILED_OVER)


func test_a_lift_during_the_heat_makes_a_cold_cup() -> void:
	var watch := FoamWatch.new(BALANCE)
	watch.tick(1.0)
	var result := watch.lift()
	assert_int(result.outcome).is_equal(FoamResult.Outcome.COLD)
	assert_float(result.score).is_equal(BALANCE.cold_score)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.foam).is_equal(0.0)
	assert_float(result.heat).is_equal_approx(0.5, 0.0001)
	assert_float(result.elapsed_seconds).is_equal_approx(1.0, 0.0001)


func test_an_early_lift_scores_its_foam() -> void:
	var watch := _at_rise()
	watch.tick(1.0)
	var result := watch.lift()
	assert_int(result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_bool(result.is_lifted()).is_true()
	assert_float(result.foam).is_equal_approx(0.3, 0.0001)
	assert_float(result.score).is_equal_approx(30.0, 0.001)
	assert_float(result.quality_factor).is_equal_approx(0.3, 0.001)
	assert_float(result.at_rim_seconds).is_equal(0.0)


func test_a_lift_above_the_rush_line_reaches_the_good_tier() -> void:
	var watch := _at_rise()
	watch.tick(1.0)
	watch.tick(1.0)
	watch.tick(0.5)
	var result := watch.lift()
	assert_int(result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_float(result.score).is_equal_approx(93.0, 0.001)
	assert_float(result.score).is_greater_equal(80.0)


func test_a_lift_at_the_rim_is_the_perfect_cup() -> void:
	var watch := _at_the_rim()
	watch.tick(0.4)
	var result := watch.lift()
	assert_int(result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_float(result.score).is_equal(BALANCE.lifted_score)
	assert_float(result.quality_factor).is_equal(1.0)
	assert_float(result.at_rim_seconds).is_equal_approx(0.4, 0.0001)
	assert_float(result.foam).is_equal(FoamWatch.RIM_FOAM)


func test_a_lift_inside_the_grace_window_is_still_safe() -> void:
	# The last safe moment is the whole grace window, not its first frame.
	var watch := _at_the_rim()
	watch.tick(0.7)
	assert_bool(watch.is_running()).is_true()
	var result := watch.lift()
	assert_int(result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_float(result.score).is_equal(BALANCE.lifted_score)


func test_the_result_freezes_after_the_end() -> void:
	var watch := _at_the_rim()
	watch.tick(0.4)
	watch.tick(0.4)
	var result := watch.result
	watch.tick(1.0)
	assert_object(watch.lift()).is_same(result)
	assert_float(watch.elapsed).is_equal_approx(result.elapsed_seconds, 0.0001)
	assert_float(watch.foam).is_equal(result.foam)
	assert_float(watch.at_rim_seconds).is_equal(result.at_rim_seconds)


func test_the_quality_factor_orders_the_outcomes() -> void:
	# A rim lift keeps the cup, an early lift keeps its foam share, and a boil
	# or a cold lift keeps nothing at all.
	var perfect := _lifted_at_rim()
	var good := _lifted_at_foam(0.93)
	var early := _lifted_at_foam(0.3)
	var boiled := _boiled_over_watch().result
	var cold := _cold_lift_watch().result
	assert_float(perfect.quality_factor).is_equal(1.0)
	assert_float(perfect.quality_factor).is_greater(good.quality_factor)
	assert_float(good.quality_factor).is_greater(early.quality_factor)
	assert_float(early.quality_factor).is_greater(boiled.quality_factor)
	assert_float(boiled.quality_factor).is_equal(cold.quality_factor)
	assert_float(cold.quality_factor).is_equal(0.0)


func _at_rise() -> FoamWatch:
	# Heat the pot to the boil: two seconds at heat rate 0.5.
	var watch := FoamWatch.new(BALANCE)
	watch.tick(1.0)
	watch.tick(1.0)
	assert_int(watch.step).is_equal(FoamWatch.Step.RISE)
	return watch


func _at_the_rim() -> FoamWatch:
	# Run the foam through the steady phase, the rush, and into the rim. The
	# tick that lands at the rim spends no grace.
	var watch := _at_rise()
	watch.tick(1.0)
	watch.tick(1.0)
	watch.tick(0.5)
	watch.tick(0.5)
	assert_bool(watch.is_at_rim()).is_true()
	assert_float(watch.at_rim_seconds).is_equal(0.0)
	return watch


func _lifted_at_foam(foam_level: float) -> FoamResult:
	# Lift at an exact foam level: run the steady phase first, then the rush.
	var watch := _at_rise()
	var steady := minf(foam_level, BALANCE.rush_start_foam)
	watch.tick(steady / BALANCE.foam_rate_per_second)
	if watch.foam < foam_level:
		watch.tick(
			(foam_level - watch.foam) / (BALANCE.foam_rate_per_second * BALANCE.rush_multiplier)
		)
	assert_float(watch.foam).is_equal_approx(foam_level, 0.001)
	return watch.lift()


func _lifted_at_rim() -> FoamResult:
	var watch := _at_the_rim()
	watch.tick(0.4)
	return watch.lift()


func _boiled_over_watch() -> FoamWatch:
	var watch := _at_the_rim()
	watch.tick(0.4)
	watch.tick(0.4)
	return watch


func _cold_lift_watch() -> FoamWatch:
	var watch := FoamWatch.new(BALANCE)
	watch.tick(1.0)
	watch.lift()
	return watch
