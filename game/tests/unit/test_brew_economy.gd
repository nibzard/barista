# ABOUTME: Unit tests for the brew input economy of T082: one brew spends
# ABOUTME: the chosen bean from the bag, recipes gate on their cafe appliance,
# ABOUTME: and an open roast takes the choice of the player. Sections 7 and 15.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const ITEM_CATALOG := preload("res://resources/items/catalog.tres")
const HOUSE_BEAN_ITEM := preload("res://resources/items/beans/house.tres")
const GOLDEN_BEAN_ITEM := preload("res://resources/items/beans/golden_coast_arabica.tres")
const MOSS_BEAN_ITEM := preload("res://resources/items/beans/moss_hollow_organic.tres")
const BLENDER_ITEM := preload("res://resources/items/appliances/blender.tres")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")
const DESIGNER_DRIPPER_ITEM := preload("res://resources/items/gear/designer_dripper.tres")


func test_one_brew_spends_one_unit_of_the_chosen_bean() -> void:
	# Section 7: the player collects beans, then brews. The chosen bean pays
	# with one unit, and only with that unit.
	var bag := Inventory.new()
	bag.add(HOUSE_BEAN_ITEM, 2)
	bag.add(MOSS_BEAN_ITEM, 1)
	assert_bool(BrewFlow.spend_bean(LIBRARY.find_bean("moss_hollow_organic"), bag)).is_true()
	assert_int(bag.count("moss_hollow_organic")).is_equal(0)
	assert_int(bag.count("house")).is_equal(2)


func test_the_last_bean_of_a_stack_still_pays_the_brew() -> void:
	var bag := Inventory.new()
	bag.add(HOUSE_BEAN_ITEM, 1)
	assert_bool(BrewFlow.spend_bean(LIBRARY.find_bean("house"), bag)).is_true()
	assert_bool(bag.has_item("house")).is_false()


func test_the_cafe_stock_jar_brews_free_from_an_empty_bag() -> void:
	# The stand keeps its own jar of the common bean, so an empty bag still
	# brews the house stock and pays nothing.
	var bag := Inventory.new()
	assert_bool(BrewFlow.spend_bean(LIBRARY.find_bean("house"), bag)).is_true()
	assert_int(bag.count("house")).is_equal(0)


func test_a_fine_bean_with_none_in_the_bag_refuses_the_brew() -> void:
	# Only the common bean has its own jar. A finer bean the bag does not
	# hold blocks the brew, and no bean pays.
	var bag := Inventory.new()
	bag.add(HOUSE_BEAN_ITEM, 1)
	assert_bool(BrewFlow.spend_bean(LIBRARY.find_bean("golden_coast_arabica"), bag)).is_false()
	assert_int(bag.count("house")).is_equal(1)


func test_no_bean_refuses_the_brew() -> void:
	assert_bool(BrewFlow.spend_bean(null, Inventory.new())).is_false()


func test_a_recipe_without_an_appliance_needs_none() -> void:
	assert_bool(BrewFlow.appliance_owned(LIBRARY.find_recipe("triple_shot"), null)).is_true()
	(
		assert_bool(BrewFlow.appliance_owned(LIBRARY.find_recipe("triple_shot"), Inventory.new()))
		. is_true()
	)


func test_the_frappuccino_brews_only_over_an_owned_blender() -> void:
	# Section 15: the blender is a cafe appliance. The player scavenges it.
	var recipe := LIBRARY.find_recipe("frappuccino")
	var bag := Inventory.new()
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_false()
	bag.add(BLENDER_ITEM, 1)
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_true()


func test_the_turkish_cup_brews_only_over_an_owned_turkish_pot() -> void:
	var recipe := LIBRARY.find_recipe("turkish_cup")
	var bag := Inventory.new()
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_false()
	bag.add(TURKISH_POT_ITEM, 1)
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_true()


func test_the_designer_dripper_cup_brews_only_over_the_owned_gear() -> void:
	# The Sam Oatman cure pins the designer dripper, scavenge gear that works
	# like the appliances at the stand.
	var recipe := LIBRARY.find_recipe("designer_dripper_cup")
	var bag := Inventory.new()
	bag.add(BLENDER_ITEM, 1)
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_false()
	bag.add(DESIGNER_DRIPPER_ITEM, 1)
	assert_bool(BrewFlow.appliance_owned(recipe, bag)).is_true()


func test_every_appliance_pin_names_a_catalog_item() -> void:
	# The gate reads the bag by item id, so every appliance pin must name an
	# item the player can truly scavenge.
	var gated := 0
	for recipe: Recipe in LIBRARY.recipes:
		if recipe.required_appliance.is_empty():
			continue
		gated += 1
		assert_object(ITEM_CATALOG.find_item(recipe.required_appliance)).is_not_null()
	assert_int(gated).is_greater_equal(3)


func test_an_open_roast_recipe_takes_the_chosen_roast() -> void:
	# Section 8: different roast levels give different coffees. The
	# frappuccino pins no roast, so the choice of the player wins.
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("frappuccino"),
		LIBRARY.find_bean("house"),
		LIBRARY,
		RoastProfile.Kind.DARK
	)
	assert_int(flow.roast.kind).is_equal(RoastProfile.Kind.DARK)


func test_a_pinned_roast_recipe_keeps_its_pin_over_the_choice() -> void:
	# The Turkish recipe pins the medium roast, section 15: a recipe is a
	# fixed combination, so the choice never overrides a pin.
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("turkish_cup"),
		LIBRARY.find_bean("house"),
		LIBRARY,
		RoastProfile.Kind.DARK
	)
	assert_int(flow.roast.kind).is_equal(RoastProfile.Kind.MEDIUM)


func test_an_open_roast_recipe_defaults_to_medium_without_a_choice() -> void:
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("frappuccino"), LIBRARY.find_bean("house"), LIBRARY
	)
	assert_int(flow.roast.kind).is_equal(BrewFlow.ANY_ROAST_DEFAULT_KIND)


func test_roast_options_open_the_choice_only_for_open_roast_recipes() -> void:
	assert_int(BrewFlow.roast_options(LIBRARY.find_recipe("frappuccino"), LIBRARY).size()).is_equal(
		LIBRARY.roasts.size()
	)
	assert_int(BrewFlow.roast_options(LIBRARY.find_recipe("turkish_cup"), LIBRARY).size()).is_equal(
		0
	)


func test_the_chosen_roast_keeps_the_recipe_match() -> void:
	# A light-roast frappuccino stays the frappuccino the Tourist needs, and
	# light roast keeps the most caffeine, section 15.
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("frappuccino"),
		LIBRARY.find_bean("house"),
		LIBRARY,
		RoastProfile.Kind.LIGHT
	)
	flow.apply_grind(GrindResult.new(GrindResult.Outcome.HIT, 0.5, 0.0, 100.0, 1.0))
	flow.apply_method_score(90.0)
	var cup := flow.cup()
	assert_str(cup.matched_recipe(LIBRARY).recipe_id).is_equal("frappuccino")
	assert_float(cup.roast.wake_power_factor).is_equal(1.0)
