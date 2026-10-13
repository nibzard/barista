# ABOUTME: Unit tests for recipe matching and the cure-matching rules.
# ABOUTME: Pins section 15: weak, good, and perfect cups and who they wake.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")


func test_matching_finds_super_tall_american() -> void:
	var cup := _brew("house", "medium", "filter", "tall_size", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("super_tall_american")


func test_matching_accepts_house_or_better_beans() -> void:
	var cup := _brew("geisha_vault", "medium", "filter", "tall_size", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("super_tall_american")


func test_matching_rejects_wrong_roast() -> void:
	var cup := _brew("house", "light", "filter", "tall_size", 85.0)
	assert_object(cup.matched_recipe(LIBRARY)).is_null()


func test_matching_rejects_missing_extra() -> void:
	var cup := _brew("house", "medium", "filter", "", 85.0)
	assert_object(cup.matched_recipe(LIBRARY)).is_null()


func test_matching_accepts_any_bean_for_triple_shot() -> void:
	var cup := _brew("golden_coast_arabica", "light", "aeropress", "three_shots", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("triple_shot")


func test_matching_accepts_any_roast_for_bulletproof() -> void:
	var cup := _brew("geisha_vault", "dark", "espresso", "butter", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("bulletproof")


func test_matching_ignores_method_for_frappuccino() -> void:
	var cup := _brew("house", "dark", "french_press", "whipped_cream", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("frappuccino")


func test_matching_finds_turkish_cup() -> void:
	var cup := _brew("moss_hollow_organic", "medium", "turkish", "", 85.0)
	var recipe := cup.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("turkish_cup")


func test_matching_rejects_light_turkish() -> void:
	var cup := _brew("house", "light", "turkish", "", 85.0)
	assert_object(cup.matched_recipe(LIBRARY)).is_null()


func test_big_filter_pot_needs_exact_house_beans() -> void:
	var house_cup := _brew("house", "medium", "filter", "full_pot", 85.0)
	var house_recipe := house_cup.matched_recipe(LIBRARY)
	assert_object(house_recipe).is_not_null()
	assert_str(house_recipe.recipe_id).is_equal("big_filter_pot")
	var golden_cup := _brew("golden_coast_arabica", "medium", "filter", "full_pot", 85.0)
	assert_object(golden_cup.matched_recipe(LIBRARY)).is_null()


func test_weak_cup_wakes_basic_types_only() -> void:
	var weak_plain := _brew("house", "medium", "filter", "", 10.0)
	assert_bool(_wakes(weak_plain, "neighbor")).is_true()
	var weak_karen_cure := _brew("house", "medium", "filter", "tall_size", 79.0)
	assert_bool(_wakes(weak_karen_cure, "karen")).is_false()
	assert_bool(_wakes(weak_karen_cure, "neighbor")).is_true()


func test_good_cup_wakes_only_types_that_need_the_drink() -> void:
	var super_tall := _brew("house", "medium", "filter", "tall_size", 85.0)
	assert_bool(_wakes(super_tall, "karen")).is_true()
	assert_bool(_wakes(super_tall, "gamer")).is_false()
	assert_bool(_wakes(super_tall, "neighbor")).is_true()
	var plain := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(_wakes(plain, "karen")).is_false()
	assert_bool(_wakes(plain, "neighbor")).is_true()


func test_good_cup_wakes_each_special_type() -> void:
	var bulletproof := _brew("house", "dark", "espresso", "butter", 88.0)
	assert_bool(_wakes(bulletproof, "tech_bro")).is_true()
	var triple_shot := _brew("house", "light", "aeropress", "three_shots", 88.0)
	assert_bool(_wakes(triple_shot, "gamer")).is_true()
	var turkish := _brew("house", "medium", "turkish", "", 88.0)
	assert_bool(_wakes(turkish, "tinfoil_man")).is_true()
	var frappuccino := _brew("house", "dark", "filter", "whipped_cream", 88.0)
	assert_bool(_wakes(frappuccino, "tourist")).is_true()
	var ristretto := _brew("geisha_vault", "light", "espresso", "short_pull", 88.0)
	assert_bool(_wakes(ristretto, "moonwalker")).is_true()
	var big_pot := _brew("house", "medium", "filter", "full_pot", 88.0)
	assert_bool(_wakes(big_pot, "trucker")).is_true()


func test_perfect_cup_wakes_every_type() -> void:
	var perfect_plain := _brew("house", "medium", "filter", "", 99.0)
	for cure: SleepwalkerCure in LIBRARY.cures:
		assert_bool(_wakes(perfect_plain, cure.sleeper_type_id)).is_true()


func test_perfect_cup_has_wake_radius_others_do_not() -> void:
	var perfect := _brew("house", "medium", "filter", "", 99.0)
	var good := _brew("house", "medium", "filter", "", 85.0)
	var weak := _brew("house", "medium", "filter", "", 42.0)
	assert_float(CureMatcher.wake_radius(perfect, BALANCE)).is_equal(BALANCE.perfect_wake_radius)
	assert_float(CureMatcher.wake_radius(good, BALANCE)).is_equal(0.0)
	assert_float(CureMatcher.wake_radius(weak, BALANCE)).is_equal(0.0)


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	var bean := LIBRARY.find_bean(bean_id)
	var roast := LIBRARY.find_roast(roast_id)
	var method := LIBRARY.find_method(method_id)
	return BrewedCup.new(bean, roast, method, extra_id, score)


func _wakes(cup: BrewedCup, sleeper_type_id: String) -> bool:
	var cure := LIBRARY.find_cure(sleeper_type_id)
	return CureMatcher.can_wake(cup, cure, LIBRARY, BALANCE)
