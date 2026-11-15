# ABOUTME: Unit tests for The Pour minigame scoring, per GAME_DESIGN section 8.
# ABOUTME: Pure grading logic: a stream of pour-rate samples in, a score out.
# ABOUTME: Flood and stall are the two failure modes; both run here headless.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/pour.tres")


func test_a_new_bloom_starts_dry_and_running() -> void:
	var bloom := PourBloom.new(BALANCE)
	assert_float(bloom.fill).is_equal(0.0)
	assert_float(bloom.excess).is_equal(0.0)
	assert_float(bloom.elapsed).is_equal(0.0)
	assert_bool(bloom.is_running()).is_true()
	assert_object(bloom.result).is_null()


func test_a_pour_inside_the_sweet_spot_fills_the_bloom() -> void:
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 0.7)
	assert_float(bloom.fill).is_equal_approx(0.25, 0.0001)
	assert_float(bloom.excess).is_equal(0.0)
	assert_float(bloom.elapsed).is_equal(1.0)
	assert_bool(bloom.is_running()).is_true()


func test_both_sweet_spot_edges_count_as_inside() -> void:
	var slow_edge := PourBloom.new(BALANCE)
	slow_edge.tick(1.0, BALANCE.sweet_spot_start)
	assert_float(slow_edge.fill).is_equal_approx(0.25, 0.0001)
	assert_float(slow_edge.excess).is_equal(0.0)
	var fast_edge := PourBloom.new(BALANCE)
	fast_edge.tick(1.0, BALANCE.sweet_spot_end)
	assert_float(fast_edge.fill).is_equal_approx(0.25, 0.0001)
	assert_float(fast_edge.excess).is_equal(0.0)


func test_a_pour_above_the_band_still_fills_but_pools_water() -> void:
	# The bed drinks at its top speed, but the water beyond the sweet-spot
	# end pools: (1.0 - 0.85) * 2.0 = 0.3 excess after one second.
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 1.0)
	assert_float(bloom.fill).is_equal_approx(0.25, 0.0001)
	assert_float(bloom.excess).is_equal_approx(0.3, 0.0001)
	assert_bool(bloom.is_running()).is_true()


func test_pooled_water_grows_with_the_rate_beyond_the_band() -> void:
	var gentle := PourBloom.new(BALANCE)
	gentle.tick(1.0, 0.9)
	assert_float(gentle.excess).is_equal_approx(0.1, 0.0001)
	var full := PourBloom.new(BALANCE)
	full.tick(1.0, 1.0)
	assert_float(full.excess).is_equal_approx(0.3, 0.0001)
	assert_float(full.excess).is_greater(gentle.excess)


func test_a_pour_below_the_band_dries_the_bloom() -> void:
	# Pouring too slow is as dry as not pouring at all.
	var too_slow := PourBloom.new(BALANCE)
	too_slow.tick(1.0, 0.7)
	too_slow.tick(1.0, 0.3)
	assert_float(too_slow.fill).is_equal_approx(0.13, 0.0001)
	var stopped := PourBloom.new(BALANCE)
	stopped.tick(1.0, 0.7)
	stopped.tick(1.0, 0.0)
	assert_float(stopped.fill).is_equal_approx(0.13, 0.0001)


func test_pooled_water_drains_while_the_pour_settles() -> void:
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 1.0)
	assert_float(bloom.excess).is_equal_approx(0.3, 0.0001)
	bloom.tick(1.0, 0.7)
	assert_float(bloom.excess).is_equal_approx(0.2, 0.0001)
	var drying := PourBloom.new(BALANCE)
	drying.tick(1.0, 1.0)
	drying.tick(1.0, 0.0)
	assert_float(drying.excess).is_equal_approx(0.2, 0.0001)


func test_a_full_ring_finishes_the_brew_with_a_perfect_score() -> void:
	var result := _stream(_seconds_at(4.0, 0.7, 1.0))
	assert_int(result.outcome).is_equal(PourResult.Outcome.BLOOMED)
	assert_bool(result.is_bloomed()).is_true()
	assert_float(result.score).is_equal(BALANCE.bloomed_score)
	assert_float(result.quality_factor).is_equal(1.0)
	assert_float(result.fill).is_equal(1.0)
	assert_float(result.elapsed_seconds).is_equal_approx(4.0, 0.0001)


func test_pooled_water_lowers_the_bloomed_score() -> void:
	# Two seconds of flood-risk pour pool 0.6 excess; the drain leaves 0.4
	# when the ring fills, and 25 points per unit cost 10 points.
	var result := _stream([Vector2(2.0, 1.0), Vector2(2.0, 0.7)])
	assert_int(result.outcome).is_equal(PourResult.Outcome.BLOOMED)
	assert_float(result.excess).is_equal_approx(0.4, 0.0001)
	assert_float(result.score).is_equal_approx(90.0, 0.001)
	assert_float(result.quality_factor).is_equal_approx(0.9, 0.0001)


func test_pouring_too_fast_floods_the_bed() -> void:
	# Full throttle pools 0.3 excess per second, so the bed floods at about
	# 3.3 seconds, well before the ring could fill.
	var bloom := PourBloom.new(BALANCE)
	var ticks := 0
	while bloom.is_running() and ticks < 10:
		bloom.tick(0.5, 1.0)
		ticks += 1
	assert_bool(bloom.is_running()).is_false()
	var result := bloom.result
	assert_int(result.outcome).is_equal(PourResult.Outcome.FLOODED)
	assert_float(result.score).is_equal(BALANCE.flood_score)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.excess).is_greater_equal(BALANCE.flood_excess)
	assert_float(result.fill).is_equal_approx(0.875, 0.001)
	assert_float(result.elapsed_seconds).is_equal_approx(3.5, 0.001)


func test_a_wet_bloom_that_dries_out_stalls() -> void:
	# Half a ring of bloom, then no pour at all: the bed dries and stalls.
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 0.7)
	bloom.tick(1.0, 0.7)
	assert_float(bloom.fill).is_equal_approx(0.5, 0.0001)
	var ticks := 0
	while bloom.is_running() and ticks < 40:
		bloom.tick(0.25, 0.0)
		ticks += 1
	var result := bloom.result
	assert_int(result.outcome).is_equal(PourResult.Outcome.STALLED)
	assert_float(result.fill).is_equal(0.0)
	assert_float(result.score).is_equal(0.0)
	assert_float(result.quality_factor).is_equal(0.0)
	assert_float(result.elapsed_seconds).is_between(6.0, 6.5)


func test_a_pour_below_the_band_stalls_the_bloom() -> void:
	# "Too slow stalls it": a wet bloom poured at 0.54, just below the band,
	# dries out and stalls instead of flooding.
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 0.7)
	var ticks := 0
	while bloom.is_running() and ticks < 40:
		bloom.tick(0.25, 0.54)
		ticks += 1
	var result := bloom.result
	assert_int(result.outcome).is_equal(PourResult.Outcome.STALLED)
	assert_float(result.excess).is_equal(0.0)
	assert_float(result.score).is_equal(0.0)
	assert_float(result.elapsed_seconds).is_between(3.0, 3.5)


func test_a_window_that_closes_on_a_dry_bed_stalls() -> void:
	# A brew that never pours anything sits dry until the window closes.
	var result := _stream([Vector2(5.5, 0.0), Vector2(5.5, 0.0)])
	assert_int(result.outcome).is_equal(PourResult.Outcome.STALLED)
	assert_float(result.fill).is_equal(0.0)
	assert_float(result.score).is_equal(0.0)
	assert_float(result.elapsed_seconds).is_equal_approx(11.0, 0.0001)


func test_a_partial_bloom_scores_its_fill_when_it_stalls() -> void:
	# Pour just enough to keep the bloom alive, never enough to fill it: the
	# window closes on a wet ring, and the fill scales the stalled score.
	var bloom := PourBloom.new(BALANCE)
	while bloom.is_running():
		bloom.tick(0.5, 0.7)
		if bloom.is_running():
			bloom.tick(1.0, 0.0)
	var result := bloom.result
	assert_int(result.outcome).is_equal(PourResult.Outcome.STALLED)
	assert_float(result.elapsed_seconds).is_greater_equal(BALANCE.brew_window_seconds)
	assert_float(result.fill).is_greater(0.0)
	assert_float(result.score).is_equal_approx(result.fill * BALANCE.stalled_score_max, 0.001)
	assert_float(result.score).is_between(0.0, BALANCE.stalled_score_max)


func test_the_pour_rate_clamps_at_full_throttle() -> void:
	var bloom := PourBloom.new(BALANCE)
	bloom.tick(1.0, 7.5)
	assert_float(bloom.fill).is_equal_approx(0.25, 0.0001)
	assert_float(bloom.excess).is_equal_approx(0.3, 0.0001)


func test_the_result_freezes_after_the_brew_ends() -> void:
	var bloom := PourBloom.new(BALANCE)
	while bloom.is_running():
		bloom.tick(1.0, 0.7)
	var result := bloom.result
	bloom.tick(1.0, 1.0)
	assert_object(bloom.result).is_same(result)
	assert_float(bloom.fill).is_equal(1.0)
	assert_float(bloom.excess).is_equal(0.0)
	assert_float(bloom.elapsed).is_equal_approx(4.0, 0.0001)


func test_the_quality_factor_orders_the_outcomes() -> void:
	# A perfect pour keeps all the cup quality, a splashy pour keeps less, a
	# stalled pour stays below the good-tier line, and a flood ruins the cup.
	var perfect := _stream(_seconds_at(4.0, 0.7, 1.0))
	var splashy := _stream([Vector2(2.0, 1.0), Vector2(2.0, 0.7)])
	var bloom := PourBloom.new(BALANCE)
	while bloom.is_running():
		bloom.tick(0.5, 0.7)
		if bloom.is_running():
			bloom.tick(1.0, 0.0)
	var stalled: PourResult = bloom.result
	var flooded := PourBloom.new(BALANCE)
	while flooded.is_running():
		flooded.tick(0.5, 1.0)
	assert_float(perfect.quality_factor).is_equal(1.0)
	assert_float(splashy.quality_factor).is_equal_approx(0.9, 0.0001)
	assert_float(stalled.quality_factor).is_less_equal(
		BALANCE.stalled_score_max / BALANCE.bloomed_score
	)
	assert_float(flooded.result.quality_factor).is_equal(0.0)
	assert_float(perfect.quality_factor).is_greater(splashy.quality_factor)
	assert_float(splashy.quality_factor).is_greater(stalled.quality_factor)
	assert_float(stalled.quality_factor).is_greater(flooded.result.quality_factor)


func _stream(samples: Array[Vector2]) -> PourResult:
	# Feed a whole input stream in one call. Each sample holds delta seconds
	# in x and the pour rate in y; the graded result comes out.
	var bloom := PourBloom.new(BALANCE)
	for sample: Vector2 in samples:
		bloom.tick(sample.x, sample.y)
	return bloom.result


func _seconds_at(seconds: float, rate: float, step: float) -> Array[Vector2]:
	var samples: Array[Vector2] = []
	var remaining := seconds
	while remaining > 0.0:
		var delta: float = minf(step, remaining)
		samples.append(Vector2(delta, rate))
		remaining -= delta
	return samples
