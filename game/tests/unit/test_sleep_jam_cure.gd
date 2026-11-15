# ABOUTME: Unit tests for the Sleep Jam cure condition, section 6.
# ABOUTME: Only a Geisha Vault tier cup reaches the band; the tiers still lead.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const CURE := preload("res://resources/brewing/recipes/geisha_vault_cup.tres")


func test_the_cure_recipe_asks_for_the_excellent_bean_tier() -> void:
	# The data rule behind the fight: any brew method and any roast work, but
	# only the most obscure beans in the world pass the recipe.
	assert_int(CURE.bean_match).is_equal(Recipe.Match.QUALITY_MIN)
	assert_int(CURE.min_bean_quality).is_equal(BeanType.Quality.EXCELLENT)
	assert_int(CURE.method_match).is_equal(Recipe.Match.ANY)
	assert_int(CURE.roast_match).is_equal(Recipe.Match.ANY)


func test_a_good_geisha_vault_cup_is_accepted() -> void:
	# The acceptance case for the cure: a good cup brewed from the Geisha
	# Vault beans wakes the band, on any method and roast.
	for brew: Array in [
		["geisha_vault", "light", "v60", ""],
		["geisha_vault", "medium", "filter", ""],
		["geisha_vault", "dark", "french_press", ""],
	]:
		var cup := _brew(brew[0], brew[1], brew[2], brew[3], 85.0)
		assert_bool(_accepted(cup)).is_true()


func test_a_weak_geisha_vault_cup_is_refused() -> void:
	# Section 15: a weak cup wakes basic types only, so the band sleeps on.
	var weak := _brew("geisha_vault", "medium", "filter", "", 42.0)
	assert_bool(_accepted(weak)).is_false()


func test_a_perfect_house_cup_is_accepted() -> void:
	# Section 15: a perfect cup wakes all types, the band included.
	var perfect := _brew("house", "medium", "filter", "", 99.0)
	assert_bool(_accepted(perfect)).is_true()


func test_good_cups_from_lesser_beans_are_refused() -> void:
	# Only the obscure beans work: house, Golden Coast, and Moss Hollow are
	# basic or good tier, one step below the cure.
	for bean_id: String in ["house", "golden_coast_arabica", "moss_hollow_organic"]:
		var cup := _brew(bean_id, "medium", "filter", "", 85.0)
		assert_bool(_accepted(cup)).is_false()


func test_the_plain_serve_is_the_cure() -> void:
	# The recipe extras belong to other cures, section 15: the tall size makes
	# a super tall American, not the obscure single-origin cup.
	var tall_geisha := _brew("geisha_vault", "medium", "filter", "tall_size", 85.0)
	assert_bool(_accepted(tall_geisha)).is_false()


func test_a_missing_cup_or_cure_wakes_nobody() -> void:
	var cup := _brew("geisha_vault", "medium", "filter", "", 85.0)
	assert_bool(SleepJamBand.cure_accepted(cup, null, BALANCE)).is_false()
	assert_bool(SleepJamBand.cure_accepted(null, CURE, BALANCE)).is_false()


func _accepted(cup: BrewedCup) -> bool:
	return SleepJamBand.cure_accepted(cup, CURE, BALANCE)


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
