# ABOUTME: Unit tests that pin the brewing dataset to the GAME_DESIGN values.
# ABOUTME: Covers the library wiring plus methods, beans, roasts, and recipes.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")

const METHOD_GROUPS := {
	"filter": BrewingMethod.MinigameGroup.POUR,
	"turkish": BrewingMethod.MinigameGroup.FOAM_WATCH,
	"french_press": BrewingMethod.MinigameGroup.PRESS,
	"v60": BrewingMethod.MinigameGroup.POUR,
	"moka_pot": BrewingMethod.MinigameGroup.PRESS,
	"espresso": BrewingMethod.MinigameGroup.PRESS,
	"aeropress": BrewingMethod.MinigameGroup.POUR,
	"cold_brew": BrewingMethod.MinigameGroup.NONE,
}

const BEAN_QUALITIES := {
	"house": BeanType.Quality.BASIC,
	"golden_coast_arabica": BeanType.Quality.GOOD,
	"moss_hollow_organic": BeanType.Quality.GOOD,
	"geisha_vault": BeanType.Quality.EXCELLENT,
}

const CURE_RECIPES := {
	"neighbor": "",
	"tourist": "frappuccino",
	"tech_bro": "bulletproof",
	"gamer": "triple_shot",
	"tinfoil_man": "turkish_cup",
	"karen": "super_tall_american",
	"moonwalker": "ristretto",
	"trucker": "big_filter_pot",
}


func test_library_holds_the_full_dataset() -> void:
	assert_int(LIBRARY.methods.size()).is_equal(8)
	assert_int(LIBRARY.beans.size()).is_equal(4)
	assert_int(LIBRARY.roasts.size()).is_equal(3)
	assert_int(LIBRARY.extras.size()).is_equal(6)
	assert_int(LIBRARY.recipes.size()).is_equal(7)
	assert_int(LIBRARY.cures.size()).is_equal(8)


func test_methods_pin_minigame_groups_and_grind_zones() -> void:
	for method_id: String in METHOD_GROUPS:
		var method := LIBRARY.find_method(method_id)
		assert_object(method).is_not_null()
		assert_int(method.minigame_group).is_equal(METHOD_GROUPS[method_id])
		assert_float(method.grind_target).is_greater(0.0)
		assert_float(method.grind_target).is_less(1.0)
		assert_float(method.grind_tolerance).is_greater(0.0)
	var turkish := LIBRARY.find_method("turkish")
	var cold_brew := LIBRARY.find_method("cold_brew")
	for method: BrewingMethod in LIBRARY.methods:
		assert_float(method.grind_target).is_greater_equal(turkish.grind_target)
		assert_float(cold_brew.grind_target).is_greater_equal(method.grind_target)


func test_beans_pin_quality_tiers() -> void:
	for bean_id: String in BEAN_QUALITIES:
		var bean := LIBRARY.find_bean(bean_id)
		assert_object(bean).is_not_null()
		assert_int(bean.quality).is_equal(BEAN_QUALITIES[bean_id])


func test_roasts_pin_wake_power_order() -> void:
	var light := LIBRARY.find_roast("light")
	var medium := LIBRARY.find_roast("medium")
	var dark := LIBRARY.find_roast("dark")
	assert_float(light.wake_power_factor).is_equal(1.0)
	assert_float(medium.wake_power_factor).is_equal(0.8)
	assert_float(dark.wake_power_factor).is_equal(0.6)
	assert_float(light.wake_power_factor).is_greater(medium.wake_power_factor)
	assert_float(medium.wake_power_factor).is_greater(dark.wake_power_factor)


func test_brewing_balance_values() -> void:
	assert_float(BALANCE.good_tier_min_score).is_equal(80.0)
	assert_float(BALANCE.perfect_tier_min_score).is_equal(95.0)
	assert_float(BALANCE.perfect_wake_radius).is_equal(100.0)
	assert_float(BALANCE.standard_cup_score).is_equal(85.0)


func test_super_tall_american_constraints() -> void:
	var recipe := LIBRARY.find_recipe("super_tall_american")
	assert_object(recipe).is_not_null()
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("filter")
	assert_str(recipe.extra_id).is_equal("tall_size")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.QUALITY_MIN)
	assert_int(recipe.min_bean_quality).is_equal(BeanType.Quality.BASIC)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.MEDIUM)


func test_triple_shot_constraints() -> void:
	var recipe := LIBRARY.find_recipe("triple_shot")
	assert_object(recipe).is_not_null()
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("aeropress")
	assert_str(recipe.extra_id).is_equal("three_shots")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.LIGHT)


func test_frappuccino_uses_blender_and_any_method() -> void:
	var recipe := LIBRARY.find_recipe("frappuccino")
	assert_object(recipe).is_not_null()
	assert_int(recipe.method_match).is_equal(Recipe.Match.ANY)
	assert_str(recipe.extra_id).is_equal("whipped_cream")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.ANY)
	assert_str(recipe.required_appliance).is_equal("blender")


func test_turkish_cup_needs_the_turkish_pot() -> void:
	var recipe := LIBRARY.find_recipe("turkish_cup")
	assert_object(recipe).is_not_null()
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("turkish")
	assert_str(recipe.extra_id).is_equal("")
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.MEDIUM)
	assert_str(recipe.required_appliance).is_equal("turkish_pot")


func test_big_filter_pot_requires_house_beans() -> void:
	var recipe := LIBRARY.find_recipe("big_filter_pot")
	assert_object(recipe).is_not_null()
	assert_int(recipe.bean_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.bean_id).is_equal("house")
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.MEDIUM)


func test_cures_pin_recipes() -> void:
	for sleeper_type_id: String in CURE_RECIPES:
		var cure := LIBRARY.find_cure(sleeper_type_id)
		assert_object(cure).is_not_null()
		assert_str(cure.cure_recipe_id).is_equal(CURE_RECIPES[sleeper_type_id])
	assert_bool(LIBRARY.find_cure("neighbor").is_basic).is_true()
	for cure: SleepwalkerCure in LIBRARY.cures:
		if cure.sleeper_type_id != "neighbor":
			assert_bool(cure.is_basic).is_false()


func test_every_cure_recipe_id_resolves() -> void:
	for cure: SleepwalkerCure in LIBRARY.cures:
		if cure.cure_recipe_id != "":
			assert_object(LIBRARY.find_recipe(cure.cure_recipe_id)).is_not_null()


func test_recipe_method_ids_resolve() -> void:
	for recipe: Recipe in LIBRARY.recipes:
		if recipe.method_match == Recipe.Match.EXACT:
			assert_object(LIBRARY.find_method(recipe.method_id)).is_not_null()


func test_extra_ids_resolve() -> void:
	for recipe: Recipe in LIBRARY.recipes:
		if recipe.extra_id != "":
			assert_object(LIBRARY.find_extra(recipe.extra_id)).is_not_null()
