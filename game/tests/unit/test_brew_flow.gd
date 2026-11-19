# ABOUTME: Unit tests for the brew pipeline: recipe resolution, grind factor,
# ABOUTME: score ceiling, bean options, and the payloads that reach the cures.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const HOUSE_BEAN_ITEM := preload("res://resources/items/beans/house.tres")
const GOLDEN_BEAN_ITEM := preload("res://resources/items/beans/golden_coast_arabica.tres")
const MOSS_BEAN_ITEM := preload("res://resources/items/beans/moss_hollow_organic.tres")
const GEISHA_BEAN_ITEM := preload("res://resources/items/beans/geisha_vault.tres")
const COLD_BREW_METHOD := preload("res://resources/brewing/methods/cold_brew.tres")
const COLD_BREW_BALANCE := preload("res://resources/balance/cold_brew.tres")
const GEISHA_CURE_RECIPE := preload("res://resources/brewing/recipes/geisha_vault_cup.tres")
const MARKET_CURE_RECIPE := preload("res://resources/brewing/recipes/market_dark_roast_tall.tres")


func test_resolve_pins_the_exact_recipe_fields() -> void:
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("triple_shot"), LIBRARY.find_bean("house"), LIBRARY
	)
	assert_str(flow.method.method_id).is_equal("aeropress")
	assert_int(flow.roast.kind).is_equal(RoastProfile.Kind.LIGHT)
	assert_str(flow.extra_id).is_equal("three_shots")
	assert_str(flow.bean.bean_id).is_equal("house")
	assert_bool(flow.needs_method_minigame()).is_true()


func test_resolve_fills_open_fields_with_the_cafe_defaults() -> void:
	# The frappuccino pins no method and no roast: the stand brews it as the
	# cafe standard filter with the balanced medium roast.
	var flow := BrewFlow.resolve(
		LIBRARY.find_recipe("frappuccino"), LIBRARY.find_bean("house"), LIBRARY
	)
	assert_str(flow.method.method_id).is_equal(BrewFlow.ANY_METHOD_DEFAULT_ID)
	assert_int(flow.roast.kind).is_equal(BrewFlow.ANY_ROAST_DEFAULT_KIND)
	assert_str(flow.extra_id).is_equal("whipped_cream")


func test_compose_score_multiplies_the_grind_factor() -> void:
	# A wrong grind lowers the quality of the cup, section 8: the factor
	# keeps only the earned share of the method score.
	assert_float(BrewFlow.compose_score(100.0, 0.5, LIBRARY.find_method("filter"))).is_equal(50.0)
	assert_float(BrewFlow.compose_score(90.0, 1.0, LIBRARY.find_method("filter"))).is_equal(90.0)


func test_compose_score_clamps_to_the_method_ceiling() -> void:
	# The cold brew ceiling caps every cup below the perfect tier, section 8.
	assert_float(BrewFlow.compose_score(100.0, 1.0, COLD_BREW_METHOD)).is_equal(85.0)
	assert_float(BrewFlow.compose_score(95.0, 1.0, COLD_BREW_METHOD)).is_equal(85.0)


func test_a_full_flow_brews_a_perfect_cup() -> void:
	var flow := _flow("single_origin_v60", "golden_coast_arabica")
	flow.apply_grind(_grind(1.0))
	assert_object(flow.cup()).is_null()
	flow.apply_method_score(100.0)
	var cup := flow.cup()
	assert_object(cup).is_not_null()
	assert_float(cup.score).is_equal(100.0)
	assert_int(cup.tier(BALANCE)).is_equal(CupTier.Tier.PERFECT)


func test_a_wrong_grind_lowers_the_earned_cup() -> void:
	var flow := _flow("triple_shot", "house")
	flow.apply_grind(_grind(0.6))
	flow.apply_method_score(100.0)
	var cup := flow.cup()
	assert_float(cup.score).is_equal(60.0)
	assert_int(cup.tier(BALANCE)).is_equal(CupTier.Tier.WEAK)


func test_auto_brew_scores_the_auto_brew_score_never_perfect() -> void:
	var flow := _flow("triple_shot", "house")
	flow.apply_auto_brew(BALANCE)
	var cup := flow.cup()
	assert_float(cup.score).is_equal(BALANCE.auto_brew_score)
	assert_int(cup.tier(BALANCE)).is_equal(CupTier.Tier.GOOD)


func test_apply_cold_brew_grades_the_ceiling_cup() -> void:
	# The steep grades itself, section 8: no grind, no minigame, the frozen
	# timer score with the method ceiling above it.
	var flow := _flow("protein_cold_brew", "house")
	assert_object(flow.cup()).is_null()
	var brew := ColdBrew.new(COLD_BREW_METHOD, COLD_BREW_BALANCE)
	brew.tick(300.0)
	flow.apply_cold_brew(brew.collect())
	var cup := flow.cup()
	assert_float(cup.score).is_equal(COLD_BREW_METHOD.score_ceiling)
	assert_int(cup.tier(BALANCE)).is_equal(CupTier.Tier.GOOD)
	assert_str(cup.extra_id).is_equal("protein_powder")


func test_apply_cold_brew_without_a_result_keeps_the_flow_ungraded() -> void:
	var flow := _flow("cold_brew_concentrate", "golden_coast_arabica")
	flow.apply_cold_brew(null)
	assert_bool(flow.is_graded()).is_false()
	assert_object(flow.cup()).is_null()


func test_held_beans_list_the_bag_in_library_order() -> void:
	var bag := Inventory.new()
	bag.add(MOSS_BEAN_ITEM, 2)
	bag.add(HOUSE_BEAN_ITEM, 3)
	var held := BrewFlow.held_beans(bag, LIBRARY)
	assert_int(held.size()).is_equal(2)
	assert_str(held[0].bean_id).is_equal("house")
	assert_str(held[1].bean_id).is_equal("moss_hollow_organic")


func test_an_empty_bag_still_brews_the_cafe_stock() -> void:
	# The stand keeps its own jar of the common bean, but only for the
	# recipes that accept it.
	var options := BrewFlow.bean_options(
		LIBRARY.find_recipe("super_tall_american"), Inventory.new(), LIBRARY
	)
	assert_int(options.size()).is_equal(1)
	assert_str(options[0].bean_id).is_equal("house")


func test_a_pinned_bean_recipe_needs_that_bean_in_the_bag() -> void:
	var recipe := LIBRARY.find_recipe("market_dark_roast_tall")
	assert_int(BrewFlow.bean_options(recipe, Inventory.new(), LIBRARY).size()).is_equal(0)
	var bag := Inventory.new()
	bag.add(HOUSE_BEAN_ITEM, 1)
	assert_int(BrewFlow.bean_options(recipe, bag, LIBRARY).size()).is_equal(0)
	bag.add(GOLDEN_BEAN_ITEM, 1)
	var options := BrewFlow.bean_options(recipe, bag, LIBRARY)
	assert_int(options.size()).is_equal(1)
	assert_str(options[0].bean_id).is_equal("golden_coast_arabica")


func test_a_quality_tier_recipe_needs_a_fine_enough_bean() -> void:
	var recipe := LIBRARY.find_recipe("geisha_vault_cup")
	var bag := Inventory.new()
	bag.add(GOLDEN_BEAN_ITEM, 1)
	assert_int(BrewFlow.bean_options(recipe, bag, LIBRARY).size()).is_equal(0)
	bag.add(GEISHA_BEAN_ITEM, 1)
	var options := BrewFlow.bean_options(recipe, bag, LIBRARY)
	assert_int(options.size()).is_equal(1)
	assert_str(options[0].bean_id).is_equal("geisha_vault")


func test_brewed_flow_cups_wake_the_special_types() -> void:
	# The acceptance of T066: a brewed payload with an earned good score
	# wakes every V1 special type the standard cup cannot reach.
	var rows := [
		["triple_shot", "gamer"],
		["bulletproof", "tech_bro"],
		["frappuccino", "tourist"],
		["turkish_cup", "tinfoil_man"],
		["super_tall_american", "karen"],
	]
	for row: Array in rows:
		var cup := _brewed_cup(row[0], 90.0)
		assert_bool(_wakes(cup, row[1])).is_true()


func test_weak_brewed_flow_cups_still_wake_no_special_type() -> void:
	var cup := _brewed_cup("triple_shot", 42.0)
	assert_bool(_wakes(cup, "gamer")).is_false()
	assert_bool(_wakes(cup, "neighbor")).is_true()


func test_brewed_flow_cups_reach_the_boss_cures() -> void:
	# The thrown payload must satisfy BossCure.accepted for the Steamtle and
	# Pourtland bosses, which the cafe-standard cup never does.
	var geisha_cup := _brewed_cup("geisha_vault_cup", 90.0)
	assert_bool(BossCure.accepted(geisha_cup, GEISHA_CURE_RECIPE, BALANCE)).is_true()
	var market_cup := _brewed_cup("market_dark_roast_tall", 90.0)
	assert_bool(BossCure.accepted(market_cup, MARKET_CURE_RECIPE, BALANCE)).is_true()
	var standard := BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("filter"),
		"",
		BALANCE.standard_cup_score
	)
	assert_bool(BossCure.accepted(standard, GEISHA_CURE_RECIPE, BALANCE)).is_false()
	assert_bool(BossCure.accepted(standard, MARKET_CURE_RECIPE, BALANCE)).is_false()


func test_roast_button_labels_name_the_wake_power() -> void:
	# The acceptance of T111: the roast picker states the wake power of each
	# choice, section 15, with the light roast as the full share.
	assert_str(BrewFlow.roast_button_label(LIBRARY.find_roast("light"))).is_equal(
		"LIGHT ROAST - WAKE 100"
	)
	assert_str(BrewFlow.roast_button_label(LIBRARY.find_roast("medium"))).is_equal(
		"MEDIUM ROAST - WAKE 80"
	)
	assert_str(BrewFlow.roast_button_label(LIBRARY.find_roast("dark"))).is_equal(
		"DARK ROAST - WAKE 60"
	)
	assert_str(BrewFlow.roast_button_label(null)).is_equal("")


func test_the_wake_hint_teaches_the_fact_and_the_cure_roasts() -> void:
	# The open roast of the frappuccino teaches the section 15 fact and names
	# the roasts that can wake the Tourist from a good cup.
	var hint := BrewFlow.wake_hint_text(LIBRARY.find_recipe("frappuccino"), LIBRARY)
	assert_str(hint).starts_with(BrewFlow.ROAST_FACT_TEXT)
	assert_str(hint).contains("WAKES THE TOURIST: LIGHT OR MEDIUM ROAST.")


func test_the_wake_hint_drops_roasts_below_the_cure_strength() -> void:
	# The wake line reads the same matcher rule that gates the wake: a
	# sleeper as strong as the light roast keeps the light roast only.
	var strong_tourist := LIBRARY.find_cure("tourist").duplicate() as SleepwalkerCure
	strong_tourist.wake_resistance = LIBRARY.find_roast("light").wake_power_factor
	var strong := BrewingLibrary.new()
	strong.roasts = LIBRARY.roasts
	strong.recipes = LIBRARY.recipes
	strong.cures = [strong_tourist]
	var hint := BrewFlow.wake_hint_text(strong.find_recipe("frappuccino"), strong)
	assert_str(hint).contains("WAKES THE TOURIST: LIGHT ROAST.")
	assert_str(hint).not_contains("MEDIUM ROAST")


func test_the_wake_hint_edges_of_pinned_and_cureless_recipes() -> void:
	# A recipe that pins its roast offers no choice point, so it teaches
	# nothing: the hint stays empty for the stand to fall back on. No sleeper
	# needs the cold brew concentrate, so its hint carries the section 15 fact
	# alone.
	(
		assert_str(BrewFlow.wake_hint_text(LIBRARY.find_recipe("super_tall_american"), LIBRARY))
		. is_equal("")
	)
	var cureless := BrewFlow.wake_hint_text(LIBRARY.find_recipe("cold_brew_concentrate"), LIBRARY)
	assert_str(cureless).is_equal(BrewFlow.ROAST_FACT_TEXT)


func _flow(recipe_id: String, bean_id: String) -> BrewFlow:
	return BrewFlow.resolve(LIBRARY.find_recipe(recipe_id), LIBRARY.find_bean(bean_id), LIBRARY)


func _grind(factor: float) -> GrindResult:
	return GrindResult.new(GrindResult.Outcome.HIT, 0.5, 0.0, 100.0, factor)


func _brewed_cup(recipe_id: String, method_score: float) -> BrewedCup:
	# One stand brew: a clean grind and the given method score.
	var recipe := LIBRARY.find_recipe(recipe_id)
	var options := BrewFlow.bean_options(recipe, _full_bag(), LIBRARY)
	var flow := BrewFlow.resolve(recipe, options[0], LIBRARY)
	flow.apply_grind(_grind(1.0))
	flow.apply_method_score(method_score)
	return flow.cup()


func _full_bag() -> Inventory:
	var bag := Inventory.new()
	bag.add(HOUSE_BEAN_ITEM, 1)
	bag.add(GOLDEN_BEAN_ITEM, 1)
	bag.add(MOSS_BEAN_ITEM, 1)
	bag.add(GEISHA_BEAN_ITEM, 1)
	return bag


func _wakes(cup: BrewedCup, sleeper_type_id: String) -> bool:
	return CureMatcher.can_wake(cup, LIBRARY.find_cure(sleeper_type_id), LIBRARY, BALANCE)
