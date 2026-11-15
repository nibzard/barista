# ABOUTME: Unit tests for the Fish Throwers cure, section 6 and T029.
# ABOUTME: Only a tall cup of the market dark roast reaches the head apron.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const CURE := preload("res://resources/brewing/recipes/market_dark_roast_tall.tres")


func test_the_cure_recipe_pins_the_market_dark_roast() -> void:
	# The data rule behind the fight: the beans of the Steamtle region, the
	# dark roast of the market, and the tall cup. Any brew method pours it.
	assert_int(CURE.bean_match).is_equal(Recipe.Match.EXACT)
	assert_str(CURE.bean_id).is_equal("golden_coast_arabica")
	assert_int(CURE.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(CURE.roast).is_equal(RoastProfile.Kind.DARK)
	assert_int(CURE.method_match).is_equal(Recipe.Match.ANY)
	assert_str(CURE.extra_id).is_equal("tall_size")


func test_a_good_market_dark_roast_tall_cup_is_accepted() -> void:
	# The acceptance case for the cure: a good tall cup of the market dark
	# roast, poured by any method, wakes the head fishmonger.
	for brew: Array in [
		["golden_coast_arabica", "dark", "filter", "tall_size"],
		["golden_coast_arabica", "dark", "espresso", "tall_size"],
		["golden_coast_arabica", "dark", "french_press", "tall_size"],
	]:
		var cup := _brew(brew[0], brew[1], brew[2], brew[3], 85.0)
		assert_bool(_accepted(cup)).is_true()


func test_a_weak_cure_cup_is_refused() -> void:
	# Section 15: a weak cup wakes basic types only, so the market sleeps on.
	var weak := _brew("golden_coast_arabica", "dark", "filter", "tall_size", 42.0)
	assert_bool(_accepted(weak)).is_false()


func test_a_perfect_house_cup_is_accepted() -> void:
	# Section 15: a perfect cup wakes all types, the head fishmonger included.
	var perfect := _brew("house", "medium", "filter", "", 99.0)
	assert_bool(_accepted(perfect)).is_true()


func test_good_cups_of_the_wrong_roast_are_refused() -> void:
	# The dark roast is the cure, not the bean alone: a light or medium tall
	# cup from the same beans splashes off the apron.
	for roast_id: String in ["light", "medium"]:
		var cup := _brew("golden_coast_arabica", roast_id, "filter", "tall_size", 85.0)
		assert_bool(_accepted(cup)).is_false()


func test_good_dark_tall_cups_of_the_wrong_beans_are_refused() -> void:
	# The market roast comes from the beans of the Steamtle region: house and
	# Moss Hollow dark tall cups are not the market dark roast.
	for bean_id: String in ["house", "moss_hollow_organic"]:
		var cup := _brew(bean_id, "dark", "filter", "tall_size", 85.0)
		assert_bool(_accepted(cup)).is_false()


func test_a_short_cup_of_the_market_roast_is_refused() -> void:
	# The tall size belongs to other cures when it is missing: a plain serve of
	# the market dark roast, or the triple-shot serve, wakes nobody here.
	var plain := _brew("golden_coast_arabica", "dark", "filter", "", 85.0)
	assert_bool(_accepted(plain)).is_false()
	var triple := _brew("golden_coast_arabica", "dark", "aeropress", "three_shots", 85.0)
	assert_bool(_accepted(triple)).is_false()


func test_a_missing_cup_or_cure_wakes_nobody() -> void:
	var cup := _brew("golden_coast_arabica", "dark", "filter", "tall_size", 85.0)
	assert_bool(FishThrowers.cure_accepted(cup, null, BALANCE)).is_false()
	assert_bool(FishThrowers.cure_accepted(null, CURE, BALANCE)).is_false()


func _accepted(cup: BrewedCup) -> bool:
	return FishThrowers.cure_accepted(cup, CURE, BALANCE)


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
