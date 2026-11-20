# ABOUTME: Unit tests for The Press minigame scoring, per GAME_DESIGN section 8.
# ABOUTME: Pure grading logic: a stream of held-state samples in, a score out.
# ABOUTME: An early release makes a sour cup and a late one a bitter cup.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/press.tres")

const CHASE_STEP := 0.05


func test_a_new_press_starts_empty_and_running() -> void:
	var press := PressShot.new(BALANCE)
	assert_float(press.pressure).is_equal(0.0)
	assert_float(press.fill).is_equal(0.0)
	assert_float(press.drift_seconds).is_equal(0.0)
	assert_float(press.elapsed).is_equal(0.0)
	assert_float(press.pull_elapsed).is_equal(0.0)
	assert_int(press.step).is_equal(PressShot.Step.HOLD)
	assert_bool(press.is_running()).is_true()
	assert_object(press.result).is_null()
	assert_float(press.zone_start()).is_equal_approx(0.26, 0.0001)
	assert_float(press.zone_end()).is_equal_approx(0.44, 0.0001)


func test_holding_builds_pressure() -> void:
	var press := PressShot.new(BALANCE)
	press.tick(1.0, true)
	assert_float(press.pressure).is_equal_approx(0.55, 0.0001)


func test_lifting_off_bleeds_pressure_back_down() -> void:
	var press := PressShot.new(BALANCE)
	press.tick(1.0, true)
	press.tick(0.5, false)
	assert_float(press.pressure).is_equal_approx(0.175, 0.0001)


func test_pressure_clamps_at_empty_and_at_the_overload_cap() -> void:
	var idle := PressShot.new(BALANCE)
	idle.tick(1.0, false)
	assert_float(idle.pressure).is_equal(0.0)
	var pinned := PressShot.new(BALANCE)
	for _i: int in range(10):
		pinned.tick(1.0, true)
	assert_float(pinned.pressure).is_equal(BALANCE.pressure_max)
	assert_bool(pinned.is_running()).is_true()


func test_the_green_zone_creeps_upward() -> void:
	var press := PressShot.new(BALANCE)
	press.tick(1.0, false)
	assert_float(press.zone_center).is_equal_approx(0.395, 0.0001)
	assert_float(press.zone_start()).is_equal_approx(0.305, 0.0001)
	assert_float(press.zone_end()).is_equal_approx(0.485, 0.0001)


func test_both_zone_edges_count_as_inside() -> void:
	var press := PressShot.new(BALANCE)
	assert_bool(press.is_in_zone(press.zone_start())).is_true()
	assert_bool(press.is_in_zone(press.zone_end())).is_true()
	assert_bool(press.is_in_zone(press.zone_start() - 0.001)).is_false()
	assert_bool(press.is_in_zone(press.zone_end() + 0.001)).is_false()


func test_a_chased_hold_fills_the_cup_inside_the_zone() -> void:
	# Pump the hold to chase the creeping zone. The fill grows while the needle
	# stays inside, and the initial climb into the zone does not count as drift.
	var press := PressShot.new(BALANCE)
	_chase_zone(press, 2.0)
	assert_bool(press.is_running()).is_true()
	assert_int(press.step).is_equal(PressShot.Step.HOLD)
	assert_float(press.fill).is_between(0.35, 0.5)
	assert_float(press.drift_seconds).is_equal(0.0)


func test_a_steady_hold_drifts_out_of_the_creeping_zone() -> void:
	# Holding without pumping overshoots the zone on the way up: the needle
	# passes through it, and time above it counts as drift.
	var press := PressShot.new(BALANCE)
	for _i: int in range(20):
		press.tick(CHASE_STEP, true)
	assert_float(press.drift_seconds).is_between(0.1, 0.3)
	assert_float(press.fill).is_less(0.15)


func test_a_clean_press_reaches_perfect_tier() -> void:
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	_lift_at(press, BALANCE.release_mark_pressure)
	assert_int(press.result.outcome).is_equal(PressResult.Outcome.PRESSED)
	assert_float(press.result.score).is_greater_equal(95.0)


func test_finishing_step_one_on_a_lift_does_not_instant_fail_step_two() -> void:
	var press := PressShot.new(BALANCE)
	while press.is_running() and press.fill < 0.90:
		press.tick(CHASE_STEP, press.pressure < press.zone_center)
	# Push to upper half of the zone, then finish step 1 on a bleed (held=false).
	while press.is_running() and press.pressure < press.zone_center + 0.06:
		press.tick(0.01, true)
	assert_int(press.step).is_equal(PressShot.Step.HOLD)
	while press.is_running() and press.step == PressShot.Step.HOLD:
		press.tick(0.01, false)
	assert_int(press.step).is_equal(PressShot.Step.RELEASE)
	# Continuing to lift for a few frames waits for the player to hold again.
	press.tick(0.02, false)
	assert_bool(press.is_running()).is_true()
	assert_object(press.result).is_null()
	_lift_at(press, BALANCE.release_mark_pressure)
	assert_int(press.result.outcome).is_equal(PressResult.Outcome.PRESSED)


func test_a_full_hold_moves_the_press_to_the_pull_step() -> void:
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	assert_bool(press.is_running()).is_true()
	assert_int(press.step).is_equal(PressShot.Step.RELEASE)
	assert_float(press.fill).is_equal(1.0)
	assert_float(press.pull_elapsed).is_equal(0.0)


func test_lifting_during_the_hold_is_not_the_release() -> void:
	# The release only counts in the pull step. A lift during step one just
	# bleeds pressure, so the player can pump the hold.
	var press := PressShot.new(BALANCE)
	_chase_zone(press, 1.0)
	var needle := press.pressure
	press.tick(0.2, false)
	assert_bool(press.is_running()).is_true()
	assert_int(press.step).is_equal(PressShot.Step.HOLD)
	assert_float(press.pressure).is_less(needle)
	assert_object(press.result).is_null()


func test_a_release_on_the_mark_scores_the_press() -> void:
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	_lift_at(press, BALANCE.release_mark_pressure - 0.02)
	var result := press.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.PRESSED)
	assert_bool(result.is_pressed()).is_true()
	assert_float(result.pressure).is_between(
		BALANCE.release_mark_pressure - BALANCE.perfect_tolerance,
		BALANCE.release_mark_pressure + BALANCE.perfect_tolerance
	)
	assert_float(result.score).is_between(85.0, 100.0)
	assert_float(result.quality_factor).is_equal_approx(result.score / 100.0, 0.0001)


func test_an_early_release_makes_a_sour_cup() -> void:
	# The hold is full, then the player pulls briefly and lifts far below the
	# mark: the cup is sour and the score falls with the distance.
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	press.tick(0.05, true)
	press.tick(0.05, false)
	var result := press.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.SOUR)
	assert_float(result.pressure).is_less(BALANCE.release_mark_pressure - BALANCE.perfect_tolerance)
	assert_float(result.score).is_between(BALANCE.off_mark_floor_score, 50.0)
	assert_float(result.quality_factor).is_less(0.8)


func test_a_late_release_makes_a_bitter_cup() -> void:
	# The lift comes past the mark: the cup is bitter.
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	_lift_at(press, BALANCE.release_mark_pressure + 0.1)
	var result := press.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.BITTER)
	assert_float(result.pressure).is_greater(
		BALANCE.release_mark_pressure + BALANCE.perfect_tolerance
	)
	assert_float(result.score).is_between(70.0, 90.0)
	assert_float(result.quality_factor).is_between(0.7, 0.9)


func test_a_pull_that_never_releases_runs_bitter_to_the_floor() -> void:
	# The pull window closes on a needle pinned in the overload band: the
	# press grades itself as maximally late and the floor saves some coffee.
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	var ticks := 0
	while press.is_running() and ticks < 100:
		press.tick(0.1, true)
		ticks += 1
	assert_bool(press.is_running()).is_false()
	var result := press.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.BITTER)
	assert_float(result.pressure).is_equal(BALANCE.pressure_max)
	assert_float(result.score).is_equal(BALANCE.off_mark_floor_score)
	assert_float(press.pull_elapsed).is_equal_approx(BALANCE.pull_window_seconds, 0.0001)


func test_a_press_that_never_holds_runs_out_of_shot() -> void:
	var press := PressShot.new(BALANCE)
	var ticks := 0
	while press.is_running() and ticks < 20:
		press.tick(1.0, false)
		ticks += 1
	var result := press.result
	assert_int(ticks).is_equal(12)
	assert_int(result.outcome).is_equal(PressResult.Outcome.NO_SHOT)
	assert_float(result.fill).is_equal(0.0)
	assert_float(result.score).is_equal(0.0)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.elapsed_seconds).is_equal_approx(BALANCE.press_window_seconds, 0.0001)


func test_a_partial_hold_scores_its_fill_when_the_window_closes() -> void:
	# Pour enough hold into the cup to matter, then let the window close: the
	# fill scales the weak no-shot score.
	var press := PressShot.new(BALANCE)
	_chase_zone(press, 1.5)
	assert_float(press.fill).is_equal_approx(0.3, 0.001)
	while press.is_running():
		press.tick(1.0, false)
	var result := press.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.NO_SHOT)
	assert_float(result.score).is_equal_approx(result.fill * BALANCE.no_shot_score_max, 0.001)
	assert_float(result.score).is_between(0.0, BALANCE.no_shot_score_max)


func test_the_result_freezes_after_the_press_ends() -> void:
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	_lift_at(press, BALANCE.release_mark_pressure - 0.02)
	var result := press.result
	press.tick(0.5, true)
	press.tick(0.5, false)
	assert_object(press.result).is_same(result)
	assert_float(press.pressure).is_equal(result.pressure)
	assert_float(press.elapsed).is_equal_approx(result.elapsed_seconds, 0.0001)


func test_the_quality_factor_orders_the_outcomes() -> void:
	# A release on the mark keeps the cup, a sour or bitter release loses
	# quality with distance, and a press that never completes stays under
	# them all.
	var pressed := _completed_press(BALANCE.release_mark_pressure - 0.02)
	var sour := _completed_press(BALANCE.release_mark_pressure - 0.3)
	var bitter := PressShot.new(BALANCE)
	_chase_until_pull(bitter)
	while bitter.is_running():
		bitter.tick(0.1, true)
	var idle := PressShot.new(BALANCE)
	while idle.is_running():
		idle.tick(1.0, false)
	assert_float(pressed.quality_factor).is_greater_equal(0.85)
	assert_float(pressed.quality_factor).is_greater(sour.quality_factor)
	assert_float(sour.quality_factor).is_greater(bitter.result.quality_factor)
	assert_float(bitter.result.quality_factor).is_greater(idle.result.quality_factor)
	assert_float(idle.result.quality_factor).is_equal(0.0)


func _chase_zone(press: PressShot, seconds: float) -> void:
	# Pump the hold to chase the creeping green zone: hold below the center,
	# lift above it. Fixed steps keep the run deterministic.
	var remaining := seconds
	while remaining > 0.0:
		var delta: float = minf(CHASE_STEP, remaining)
		press.tick(delta, press.pressure < press.zone_center)
		remaining -= delta


func _chase_until_pull(press: PressShot) -> void:
	# Chase the zone for as long as the hold step runs.
	var guard := 0
	while press.is_running() and press.step == PressShot.Step.HOLD and guard < 500:
		press.tick(CHASE_STEP, press.pressure < press.zone_center)
		guard += 1
	assert_int(press.step).is_equal(PressShot.Step.RELEASE)


func _lift_at(press: PressShot, target_pressure: float) -> void:
	# Hold the pull until the needle reaches the target, then lift. The lift
	# grades at the pressure the run last saw.
	while press.is_running() and press.pressure < target_pressure:
		press.tick(0.02, true)
	press.tick(0.02, false)


func _completed_press(target_pressure: float) -> PressResult:
	var press := PressShot.new(BALANCE)
	_chase_until_pull(press)
	_lift_at(press, target_pressure)
	return press.result
