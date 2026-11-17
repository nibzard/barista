# ABOUTME: Pins the live wake-power rule of section 15: the roast decides.
# ABOUTME: The roast gates which sleepers a good cup wakes and scales the splash.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")


func test_wake_power_reads_the_roast_factor() -> void:
	assert_float(CureMatcher.wake_power(_brew("light"))).is_equal(1.0)
	assert_float(CureMatcher.wake_power(_brew("medium"))).is_equal(0.8)
	assert_float(CureMatcher.wake_power(_brew("dark"))).is_equal(0.6)


func test_dark_roast_right_recipe_does_not_wake_a_special() -> void:
	# The core live rule: a dark roast cup matches the free-roast cure
	# recipes, but its lower wake power sits below the strength of every
	# special sleeper, so it wakes none of them.
	var dark_bulletproof := _brew("dark", "espresso", "butter", 85.0)
	assert_bool(_wakes(dark_bulletproof, "tech_bro")).is_false()
	var dark_frappuccino := _brew("dark", "filter", "whipped_cream", 85.0)
	assert_bool(_wakes(dark_frappuccino, "tourist")).is_false()
	var dark_doppio := _brew("dark", "espresso", "double_shot", 85.0)
	assert_bool(_wakes(dark_doppio, "night_nurse")).is_false()
	var dark_protein := _brew("dark", "cold_brew", "protein_powder", 85.0)
	assert_bool(_wakes(dark_protein, "crossfitter")).is_false()


func test_light_and_medium_roast_wake_the_free_roast_specials() -> void:
	for roast_id: String in ["light", "medium"]:
		var bulletproof := _brew(roast_id, "espresso", "butter", 85.0)
		assert_bool(_wakes(bulletproof, "tech_bro")).is_true()
		var frappuccino := _brew(roast_id, "filter", "whipped_cream", 85.0)
		assert_bool(_wakes(frappuccino, "tourist")).is_true()


func test_perfect_cup_wakes_every_type_from_any_roast() -> void:
	# The tier promise of section 15 stays whole: a perfect cup wakes all
	# types, dark roast included. The roast scales the splash, not the
	# promise.
	var perfect_dark := _brew("dark", "filter", "", 99.0)
	for cure: SleepwalkerCure in LIBRARY.cures:
		assert_bool(_wakes(perfect_dark, cure.sleeper_type_id)).is_true()


func test_weak_dark_cup_still_wakes_the_basic_types() -> void:
	# Basic sleepers have zero strength, so the weakest dark cup wakes them.
	var weak_dark := _brew("dark", "filter", "", 10.0)
	assert_bool(_wakes(weak_dark, "neighbor")).is_true()
	assert_bool(_wakes(weak_dark, "withdrawer")).is_true()


func test_cure_strength_follows_the_canonical_roast() -> void:
	# The strength of a sleeper equals the wake power of the roast its cure
	# pins. A free-roast recipe takes the balanced middle, the medium roast.
	# Basic types stay at zero, so any cup wakes them.
	var medium_power := LIBRARY.find_roast("medium").wake_power_factor
	for cure: SleepwalkerCure in LIBRARY.cures:
		if cure.is_basic:
			assert_float(cure.wake_resistance).is_equal(0.0)
			continue
		var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
		assert_object(recipe).is_not_null()
		if recipe.roast_match == Recipe.Match.EXACT:
			var pinned := LIBRARY.find_roast_by_kind(recipe.roast)
			assert_object(pinned).is_not_null()
			assert_float(cure.wake_resistance).is_equal(pinned.wake_power_factor)
		else:
			assert_float(cure.wake_resistance).is_equal(medium_power)


func test_perfect_wake_radius_scales_with_the_roast_power() -> void:
	var light := _brew("light", "filter", "", 99.0)
	assert_float(CureMatcher.wake_radius(light, BALANCE)).is_equal(BALANCE.perfect_wake_radius)
	var medium := _brew("medium", "filter", "", 99.0)
	assert_float(CureMatcher.wake_radius(medium, BALANCE)).is_equal_approx(80.0, 0.01)
	var dark := _brew("dark", "filter", "", 99.0)
	assert_float(CureMatcher.wake_radius(dark, BALANCE)).is_equal_approx(60.0, 0.01)
	var good_light := _brew("light", "filter", "", 85.0)
	assert_float(CureMatcher.wake_radius(good_light, BALANCE)).is_equal(0.0)


func test_roast_ids_with_enough_power_list_the_wakeable_roasts() -> void:
	var tourist := LIBRARY.find_cure("tourist")
	var tourist_ids := CureMatcher.roast_ids_with_enough_power(tourist, LIBRARY)
	assert_int(tourist_ids.size()).is_equal(2)
	assert_str(tourist_ids[0]).is_equal("light")
	assert_str(tourist_ids[1]).is_equal("medium")
	var gamer_ids := CureMatcher.roast_ids_with_enough_power(LIBRARY.find_cure("gamer"), LIBRARY)
	assert_int(gamer_ids.size()).is_equal(1)
	assert_str(gamer_ids[0]).is_equal("light")
	var neighbor_ids := CureMatcher.roast_ids_with_enough_power(
		LIBRARY.find_cure("neighbor"), LIBRARY
	)
	assert_int(neighbor_ids.size()).is_equal(3)


func _brew(
	roast_id: String, method_id: String = "filter", extra_id: String = "", score: float = 85.0
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)


func _wakes(cup: BrewedCup, sleeper_type_id: String) -> bool:
	var cure := LIBRARY.find_cure(sleeper_type_id)
	return CureMatcher.can_wake(cup, cure, LIBRARY, BALANCE)
