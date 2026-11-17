# ABOUTME: Unit tests for the cold brew method, per GAME_DESIGN section 8.
# ABOUTME: Pure timer logic: tick the clock, come back later, read the cup.
# ABOUTME: Low ceiling, zero stress: the finished cup is always good, never perfect.
extends GdUnitTestSuite

const METHOD := preload("res://resources/brewing/methods/cold_brew.tres")
const BALANCE := preload("res://resources/balance/cold_brew.tres")
const BREWING_BALANCE := preload("res://resources/brewing/brewing_balance.tres")


func test_a_new_brew_starts_steeping() -> void:
	# The tuned steep: five minutes of play, so the player starts the brew
	# and comes back later, section 8.
	assert_float(BALANCE.steep_seconds).is_equal(300.0)
	assert_float(BALANCE.steep_seconds).is_greater(0.0)
	var brew := ColdBrew.new(METHOD, BALANCE)
	assert_float(brew.elapsed).is_equal(0.0)
	assert_bool(brew.is_ready()).is_false()
	assert_object(brew.result).is_null()
	assert_object(brew.collect()).is_null()
	assert_float(brew.progress()).is_equal(0.0)
	assert_float(brew.remaining_seconds()).is_equal(BALANCE.steep_seconds)


func test_no_cup_before_the_steep_ends() -> void:
	# Coming back too early finds no cup, and the steep keeps running.
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(BALANCE.steep_seconds - 0.5)
	assert_bool(brew.is_ready()).is_false()
	assert_object(brew.collect()).is_null()
	brew.tick(1.0)
	assert_bool(brew.is_ready()).is_true()


func test_the_steep_finishes_on_its_own() -> void:
	# The exact boundary tick lands the cup: timer-based completion.
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(BALANCE.steep_seconds - 0.5)
	assert_bool(brew.is_ready()).is_false()
	brew.tick(0.5)
	assert_bool(brew.is_ready()).is_true()
	assert_float(brew.elapsed).is_equal(BALANCE.steep_seconds)
	assert_float(brew.progress()).is_equal(1.0)
	assert_float(brew.remaining_seconds()).is_equal(0.0)


func test_many_small_ticks_match_one_big_tick() -> void:
	var patient := ColdBrew.new(METHOD, BALANCE)
	for _i: int in range(300):
		patient.tick(1.0)
	var hurried := ColdBrew.new(METHOD, BALANCE)
	hurried.tick(BALANCE.steep_seconds)
	assert_bool(patient.is_ready()).is_true()
	assert_bool(hurried.is_ready()).is_true()
	assert_float(patient.elapsed).is_equal(hurried.elapsed)
	assert_float(patient.collect().score).is_equal(hurried.collect().score)


func test_coming_back_much_later_changes_nothing() -> void:
	# Zero stress: a huge absence lands the same cup as a punctual return,
	# and ticks after the end never change the frozen answer.
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(3600.0)
	assert_bool(brew.is_ready()).is_true()
	assert_float(brew.elapsed).is_equal(BALANCE.steep_seconds)
	var first := brew.collect()
	brew.tick(3600.0)
	assert_float(brew.elapsed).is_equal(BALANCE.steep_seconds)
	assert_object(brew.collect()).is_same(first)
	assert_float(first.score).is_equal(brew.collect().score)


func test_collect_returns_the_same_frozen_cup() -> void:
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(BALANCE.steep_seconds)
	var first := brew.collect()
	assert_object(brew.collect()).is_same(first)
	assert_object(brew.result).is_same(first)


func test_the_finished_cup_scores_the_method_ceiling() -> void:
	var brew := _finished_brew()
	assert_float(brew.collect().score).is_equal(METHOD.score_ceiling)
	assert_float(brew.collect().score).is_equal(85.0)
	assert_float(brew.collect().elapsed).is_equal(BALANCE.steep_seconds)


func test_the_ceiling_never_reaches_the_perfect_tier() -> void:
	# Section 8: low ceiling. The cup lands inside the good band, so it never
	# wakes the perfect-only crowd and never gains the perfect wake radius.
	var cup := _finished_brew().collect()
	assert_float(METHOD.score_ceiling).is_greater_equal(BREWING_BALANCE.good_tier_min_score)
	assert_float(METHOD.score_ceiling).is_less(BREWING_BALANCE.perfect_tier_min_score)
	assert_int(CupTier.from_score(cup.score, BREWING_BALANCE)).is_equal(CupTier.Tier.GOOD)


func test_quality_factor_carries_the_ceiling() -> void:
	# The low ceiling travels into the cup payload: 85 of the full 100.
	var cup := _finished_brew().collect()
	assert_float(cup.quality_factor).is_equal_approx(0.85, 0.0001)
	assert_float(cup.quality_factor).is_less(1.0)


func test_a_duplicated_balance_steeps_at_its_own_rate() -> void:
	# The rules read the resource, so a retuned steep changes only the data.
	var tuned := BALANCE.duplicate() as ColdBrewBalance
	tuned.steep_seconds = 10.0
	var brew := ColdBrew.new(METHOD, tuned)
	brew.tick(9.5)
	assert_bool(brew.is_ready()).is_false()
	brew.tick(0.5)
	assert_bool(brew.is_ready()).is_true()
	assert_float(brew.elapsed).is_equal(10.0)


func test_a_duplicated_method_grades_at_its_own_ceiling() -> void:
	# The ceiling is method data, not a constant: retune it and the tier
	# follows, both up into the perfect band and down into the weak band.
	var perfect := METHOD.duplicate() as BrewingMethod
	perfect.score_ceiling = 100.0
	var strong := ColdBrew.new(perfect, BALANCE)
	strong.tick(BALANCE.steep_seconds)
	assert_float(strong.collect().score).is_equal(100.0)
	assert_int(CupTier.from_score(strong.collect().score, BREWING_BALANCE)).is_equal(
		CupTier.Tier.PERFECT
	)
	var weak := METHOD.duplicate() as BrewingMethod
	weak.score_ceiling = 75.0
	var flat := ColdBrew.new(weak, BALANCE)
	flat.tick(BALANCE.steep_seconds)
	assert_float(flat.collect().score).is_equal(75.0)
	assert_int(CupTier.from_score(flat.collect().score, BREWING_BALANCE)).is_equal(
		CupTier.Tier.WEAK
	)


func test_progress_and_remaining_drive_a_countdown() -> void:
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(75.0)
	assert_float(brew.progress()).is_equal_approx(0.25, 0.0001)
	assert_float(brew.remaining_seconds()).is_equal(225.0)
	brew.tick(75.0)
	assert_float(brew.progress()).is_equal_approx(0.5, 0.0001)
	assert_float(brew.progress()).is_greater_equal(0.25)
	brew.tick(300.0)
	assert_float(brew.progress()).is_equal(1.0)
	assert_float(brew.remaining_seconds()).is_equal(0.0)


func test_save_state_round_trips_a_running_brew() -> void:
	# Come back later within one save: the steep stands where it stood.
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(120.0)
	var saved := brew.save_state()
	var loaded := ColdBrew.new(METHOD, BALANCE)
	loaded.load_state(saved)
	assert_float(loaded.elapsed).is_equal(120.0)
	assert_bool(loaded.is_ready()).is_false()
	loaded.tick(BALANCE.steep_seconds - 120.0)
	assert_bool(loaded.is_ready()).is_true()
	assert_float(loaded.collect().score).is_equal(METHOD.score_ceiling)


func test_load_state_completes_an_overdue_brew() -> void:
	# Come back later across a closed app: a steep that ran out away from
	# the game is ready at once.
	var loaded := ColdBrew.new(METHOD, BALANCE)
	loaded.load_state({"elapsed": 9999.0})
	assert_bool(loaded.is_ready()).is_true()
	assert_float(loaded.elapsed).is_equal(BALANCE.steep_seconds)
	assert_float(loaded.collect().score).is_equal(METHOD.score_ceiling)


func test_load_state_clamps_impossible_values() -> void:
	var loaded := ColdBrew.new(METHOD, BALANCE)
	loaded.load_state({"elapsed": -50.0})
	assert_float(loaded.elapsed).is_equal(0.0)
	assert_bool(loaded.is_ready()).is_false()
	loaded.load_state({"elapsed": 999999.0})
	assert_float(loaded.elapsed).is_equal(BALANCE.steep_seconds)
	assert_bool(loaded.is_ready()).is_true()
	loaded.load_state({})
	assert_float(loaded.elapsed).is_equal(0.0)
	assert_bool(loaded.is_ready()).is_false()
	var fresh := ColdBrew.new(METHOD, BALANCE)
	assert_float(float(fresh.save_state().get("elapsed", -1.0))).is_equal(0.0)


func _finished_brew() -> ColdBrew:
	var brew := ColdBrew.new(METHOD, BALANCE)
	brew.tick(BALANCE.steep_seconds)
	return brew
