# ABOUTME: Unit tests for the Grind Dial pre-step scoring, per GAME_DESIGN section 8.
# ABOUTME: Pure grading logic: hit, miss, and wrong zone, with no scene tree.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/balance/grind_dial.tres")


func test_marker_starts_fine_and_advances_at_the_tuned_speed() -> void:
	var dial := GrindDial.new(_method("filter"), BALANCE)
	assert_float(dial.position).is_equal(GrindDial.FINE)
	dial.tick(0.5)
	assert_float(dial.position).is_equal_approx(0.35, 0.0001)
	assert_bool(dial.is_running()).is_true()
	assert_object(dial.result).is_null()


func test_stop_on_the_target_is_a_hit() -> void:
	var dial := GrindDial.new(_method("filter"), BALANCE)
	dial.tick(_seconds_to_reach(0.65))
	var result := dial.stop()
	assert_int(result.outcome).is_equal(GrindResult.Outcome.HIT)
	assert_bool(result.is_hit()).is_true()
	assert_float(result.score).is_equal(BALANCE.hit_score)
	assert_float(result.quality_factor).is_equal(1.0)
	assert_float(result.distance_from_target).is_less(0.001)


func test_both_zone_edges_count_as_a_hit() -> void:
	var method := _method("filter")
	var dial := GrindDial.new(method, BALANCE)
	dial.position = method.grind_target - method.grind_tolerance
	assert_int(dial.stop().outcome).is_equal(GrindResult.Outcome.HIT)
	var edge_dial := GrindDial.new(method, BALANCE)
	edge_dial.position = method.grind_target + method.grind_tolerance
	assert_int(edge_dial.stop().outcome).is_equal(GrindResult.Outcome.HIT)


func test_stop_just_outside_the_zone_is_a_wrong_zone() -> void:
	var method := _method("filter")
	var dial := GrindDial.new(method, BALANCE)
	dial.position = method.grind_target + method.grind_tolerance + 0.05
	var result := dial.stop()
	assert_int(result.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	assert_bool(result.is_hit()).is_false()
	# Five hundredths beyond the zone edge cost five points at a penalty of
	# one hundred points per dial unit.
	assert_float(result.score).is_equal_approx(95.0, 0.001)
	assert_float(result.quality_factor).is_equal_approx(0.95, 0.0001)


func test_wrong_zone_score_falls_with_distance_from_the_zone() -> void:
	# Filter zone is 0.55 to 0.75. A stop at the fine end sits 0.55 beyond it
	# and costs 55 points; a stop at 0.85 sits 0.1 beyond it and costs 10.
	var near_miss := GrindDial.new(_method("filter"), BALANCE)
	near_miss.position = 0.85
	var near_result := near_miss.stop()
	assert_int(near_result.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	assert_float(near_result.score).is_equal_approx(90.0, 0.001)
	var far_miss := GrindDial.new(_method("filter"), BALANCE)
	far_miss.position = GrindDial.FINE
	var far_result := far_miss.stop()
	assert_float(far_result.score).is_equal_approx(45.0, 0.001)
	assert_float(far_result.score).is_less(near_result.score)
	# The same stop grades against the zone of the method: espresso grinds
	# fine, so its zone starts near the fine end and the stop costs less.
	var espresso := GrindDial.new(_method("espresso"), BALANCE)
	espresso.position = GrindDial.FINE
	var espresso_result := espresso.stop()
	assert_int(espresso_result.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	assert_float(espresso_result.score).is_equal_approx(88.0, 0.001)
	assert_float(espresso_result.score).is_greater(far_result.score)


func test_wrong_zone_score_never_falls_below_the_floor() -> void:
	# Turkish zone is 0.0 to 0.1. A stop at the coarse end is as wrong as a
	# stop can be, so the floor holds the score up.
	var dial := GrindDial.new(_method("turkish"), BALANCE)
	dial.position = GrindDial.COARSE
	var result := dial.stop()
	assert_int(result.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	assert_float(result.score).is_equal(BALANCE.wrong_zone_floor_score)


func test_a_marker_that_reaches_the_coarse_end_is_a_miss() -> void:
	var dial := GrindDial.new(_method("filter"), BALANCE)
	var ticks := 0
	while dial.is_running() and ticks < 20:
		dial.tick(0.25)
		ticks += 1
	assert_bool(dial.is_running()).is_false()
	assert_float(dial.position).is_equal(GrindDial.COARSE)
	var result := dial.result
	assert_int(result.outcome).is_equal(GrindResult.Outcome.MISS)
	assert_float(result.score).is_equal(BALANCE.miss_score)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.position).is_equal(GrindDial.COARSE)


func test_stop_after_a_miss_returns_the_miss_result() -> void:
	var dial := GrindDial.new(_method("filter"), BALANCE)
	while dial.is_running():
		dial.tick(0.5)
	var result := dial.stop()
	assert_int(result.outcome).is_equal(GrindResult.Outcome.MISS)
	assert_object(result).is_same(dial.result)


func test_stop_is_idempotent_and_freezes_the_marker() -> void:
	var dial := GrindDial.new(_method("v60"), BALANCE)
	dial.tick(0.3)
	var first := dial.stop()
	dial.tick(0.5)
	var second := dial.stop()
	assert_object(second).is_same(first)
	assert_float(dial.position).is_equal_approx(0.21, 0.001)


func test_a_wrong_grind_lowers_the_cup_quality() -> void:
	# Section 8: a wrong grind lowers the quality of the cup. The quality
	# factor is the lever: a hit keeps it all, a wrong zone loses some, and a
	# miss loses everything.
	var method := _method("filter")
	var hit := _stopped_result(method, method.grind_target)
	var wrong := _stopped_result(method, GrindDial.FINE)
	var miss := _missed_result(method)
	assert_float(hit.quality_factor).is_equal(1.0)
	assert_float(wrong.quality_factor).is_equal_approx(0.45, 0.001)
	assert_float(miss.quality_factor).is_equal(0.0)


func test_every_method_zone_lies_inside_the_dial() -> void:
	for method: BrewingMethod in LIBRARY.methods:
		assert_float(method.grind_target).is_between(GrindDial.FINE, GrindDial.COARSE)
		var dial := GrindDial.new(method, BALANCE)
		assert_float(dial.zone_start()).is_greater_equal(GrindDial.FINE)
		assert_float(dial.zone_end()).is_less_equal(GrindDial.COARSE)
		assert_float(dial.zone_start()).is_less(dial.zone_end())


func test_zones_clamp_to_the_dial_ends() -> void:
	# Turkish sits at the fine end and cold brew at the coarse end, so their
	# zones clamp instead of running off the dial.
	var turkish := GrindDial.new(_method("turkish"), BALANCE)
	assert_float(turkish.zone_start()).is_equal(GrindDial.FINE)
	var cold_brew := GrindDial.new(_method("cold_brew"), BALANCE)
	assert_float(cold_brew.zone_end()).is_equal(GrindDial.COARSE)


func test_each_method_has_its_own_zone() -> void:
	# Espresso wants a fine grind and french press a coarse one, so no two
	# zones in the library fully overlap.
	var espresso := GrindDial.new(_method("espresso"), BALANCE)
	var french_press := GrindDial.new(_method("french_press"), BALANCE)
	assert_float(espresso.zone_end()).is_less(french_press.zone_start())


func _method(method_id: String) -> BrewingMethod:
	return LIBRARY.find_method(method_id)


func _seconds_to_reach(dial_position: float) -> float:
	return dial_position / BALANCE.marker_speed_units_per_second


func _stopped_result(method: BrewingMethod, stop_position: float) -> GrindResult:
	var dial := GrindDial.new(method, BALANCE)
	dial.position = stop_position
	return dial.stop()


func _missed_result(method: BrewingMethod) -> GrindResult:
	var dial := GrindDial.new(method, BALANCE)
	while dial.is_running():
		dial.tick(0.5)
	return dial.result
