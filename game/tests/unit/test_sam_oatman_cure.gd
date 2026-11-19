# ABOUTME: Unit tests for the Sam Oatman cure condition, section 6.
# ABOUTME: Only a cup off the 700-dollar designer dripper reaches the guru.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const CURE := preload("res://resources/brewing/recipes/designer_dripper_cup.tres")
const APPLIANCE_ITEM := preload("res://resources/items/gear/designer_dripper.tres")


func test_the_cure_recipe_pins_the_designer_dripper_brew() -> void:
	# The data rule behind the fight, section 6: one V60 pour off the
	# scavenge dripper, any bean, any roast, plain serve.
	assert_str(CURE.recipe_id).is_equal("designer_dripper_cup")
	assert_int(CURE.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(CURE.method_id).is_equal("v60")
	assert_int(CURE.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(CURE.roast_match).is_equal(Recipe.Match.ANY)
	assert_str(CURE.extra_id).is_empty()
	assert_str(CURE.required_appliance).is_equal("designer_dripper")


func test_the_dripper_in_the_bag_opens_the_recipe() -> void:
	# Section 15: the 700-dollar designer dripper is scavenge gear and the
	# recipe's cafe appliance, so the brew stand gates on the bag holding it.
	var bag := Inventory.new()
	assert_bool(BrewFlow.appliance_owned(CURE, bag)).is_false()
	assert_int(bag.add(APPLIANCE_ITEM, 1)).is_equal(1)
	assert_bool(BrewFlow.appliance_owned(CURE, bag)).is_true()


func test_a_good_dripper_cup_is_accepted() -> void:
	# The acceptance case for the cure: a good V60 cup from any bean and any
	# roast wakes the guru.
	for brew: Array in [
		["house", "light", "v60", ""],
		["golden_coast_arabica", "medium", "v60", ""],
		["geisha_vault", "dark", "v60", ""],
	]:
		var cup := _brew(brew[0], brew[1], brew[2], brew[3], 85.0)
		assert_bool(_accepted(cup)).is_true()


func test_a_weak_dripper_cup_is_refused() -> void:
	# Section 15: a weak cup wakes basic types only, so the guru sleeps on.
	var weak := _brew("house", "medium", "v60", "", 42.0)
	assert_bool(_accepted(weak)).is_false()


func test_a_perfect_cup_wakes_him_on_any_method() -> void:
	# Section 15: a perfect cup wakes all types, the guru included, even off
	# a method the dripper never pours.
	var perfect := _brew("house", "medium", "filter", "", 99.0)
	assert_bool(_accepted(perfect)).is_true()


func test_a_good_cup_off_the_wrong_method_is_refused() -> void:
	# The dripper defines the brew: a good filter or press cup never matches
	# the V60 cure recipe.
	for method_id: String in ["filter", "espresso", "french_press"]:
		var cup := _brew("house", "medium", method_id, "", 85.0)
		assert_bool(_accepted(cup)).is_false()


func test_an_extra_in_the_cup_is_refused() -> void:
	# The cure is a plain serve: extras belong to other recipes, section 15.
	for extra_id: String in ["tall_size", "butter", "whipped_cream"]:
		var cup := _brew("house", "medium", "v60", extra_id, 85.0)
		assert_bool(_accepted(cup)).is_false()


func test_a_missing_cup_or_cure_wakes_nobody() -> void:
	var cup := _brew("house", "medium", "v60", "", 85.0)
	assert_bool(SamOatman.cure_accepted(cup, null, BALANCE)).is_false()
	assert_bool(SamOatman.cure_accepted(null, CURE, BALANCE)).is_false()


func _accepted(cup: BrewedCup) -> bool:
	return SamOatman.cure_accepted(cup, CURE, BALANCE)


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
