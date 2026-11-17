# ABOUTME: Pins the V2+ cure data rows of GAME_DESIGN section 6.
# ABOUTME: Data only: no V2 enemy type ships yet, so no row touches live play.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/brewing/brewing_balance.tres")


func test_double_espresso_pins_the_night_nurse_cure() -> void:
	# Section 6: the Night Nurse wakes from a double espresso. Two shots of
	# any bean and any roast from the espresso method mark the doppio.
	var recipe := LIBRARY.find_recipe("double_espresso")
	assert_object(recipe).is_not_null()
	assert_str(recipe.display_name).is_equal("Double Espresso")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("espresso")
	assert_str(recipe.extra_id).is_equal("double_shot")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.ANY)


func test_protein_cold_brew_pins_the_crossfitter_cure() -> void:
	# Section 6: the Crossfitter wakes from a protein cold brew. The protein
	# scoop marks the cup; the beans and the roast stay free.
	var recipe := LIBRARY.find_recipe("protein_cold_brew")
	assert_object(recipe).is_not_null()
	assert_str(recipe.display_name).is_equal("Protein Cold Brew")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("cold_brew")
	assert_str(recipe.extra_id).is_equal("protein_powder")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.ANY)


func test_executive_wakes_from_the_offmug_recipe() -> void:
	# Section 6: the Executive wakes from a 12-dollar single-origin V60.
	# Section 9: some types wake only from a master recipe. The Offmug
	# recipe of T036 is that cup, so the cure names it and adds no copy.
	var cure := LIBRARY.find_cure("executive")
	assert_object(cure).is_not_null()
	assert_str(cure.display_name).is_equal("The Executive")
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("single_origin_v60")
	assert_object(LIBRARY.find_recipe(cure.cure_recipe_id)).is_not_null()


func test_designer_dripper_cup_pins_the_sam_oatman_cure() -> void:
	# Section 6: Sam Oatman wakes from one cup off his own 700-dollar
	# dripper. Section 15 lists the dripper as scavenge gear, so the recipe
	# asks the appliance, like the Turkish cup asks the Turkish pot.
	var recipe := LIBRARY.find_recipe("designer_dripper_cup")
	assert_object(recipe).is_not_null()
	assert_str(recipe.display_name).is_equal("Designer Dripper Cup")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.method_id).is_equal("v60")
	assert_str(recipe.extra_id).is_equal("")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.ANY)
	assert_str(recipe.required_appliance).is_equal("designer_dripper")


func test_competition_cup_pins_the_ceo_cure() -> void:
	# Section 6: the CEO wakes from one cup with all eight brewing methods
	# inside. Section 8: the Champion teaches this "competition cup", so one
	# row serves both names. The eight-method build is the extra step.
	var recipe := LIBRARY.find_recipe("competition_cup")
	assert_object(recipe).is_not_null()
	assert_str(recipe.display_name).is_equal("Competition Cup")
	assert_int(recipe.method_match).is_equal(Recipe.Match.ANY)
	assert_str(recipe.extra_id).is_equal("all_eight_methods")
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.ANY)


func test_v2_cures_pin_their_recipe_links() -> void:
	# Every special cure names a recipe the library resolves, like the V1
	# rows in test_brewing_data.gd.
	var night_nurse := LIBRARY.find_cure("night_nurse")
	assert_object(night_nurse).is_not_null()
	assert_str(night_nurse.display_name).is_equal("The Night Nurse")
	assert_bool(night_nurse.is_basic).is_false()
	assert_str(night_nurse.cure_recipe_id).is_equal("double_espresso")

	var crossfitter := LIBRARY.find_cure("crossfitter")
	assert_object(crossfitter).is_not_null()
	assert_str(crossfitter.display_name).is_equal("The Crossfitter")
	assert_bool(crossfitter.is_basic).is_false()
	assert_str(crossfitter.cure_recipe_id).is_equal("protein_cold_brew")


func test_withdrawer_wakes_from_any_cup_but_needs_the_second() -> void:
	# Section 6: one cup wakes the Withdrawer, but the wake does not hold.
	# A second cup inside one minute keeps him up. Any cup wakes him, so
	# the cure stays basic and pins the window. Every other cure holds.
	var cure := LIBRARY.find_cure("withdrawer")
	assert_object(cure).is_not_null()
	assert_str(cure.display_name).is_equal("The Withdrawer")
	assert_bool(cure.is_basic).is_true()
	assert_str(cure.cure_recipe_id).is_equal("")
	assert_float(cure.second_cup_window_seconds).is_equal(60.0)
	for other: SleepwalkerCure in LIBRARY.cures:
		if other.sleeper_type_id != "withdrawer":
			assert_float(other.second_cup_window_seconds).is_equal(0.0)


func test_new_extras_resolve() -> void:
	# The three V2 add-on steps: the doppio pull, the protein scoop, and
	# the eight-method build of the competition cup.
	assert_str(LIBRARY.find_extra("double_shot").display_name).is_equal("Double Shot")
	assert_str(LIBRARY.find_extra("protein_powder").display_name).is_equal("Protein Powder")
	assert_str(LIBRARY.find_extra("all_eight_methods").display_name).is_equal("All Eight Methods")


func test_double_espresso_needs_the_double_shot_extra() -> void:
	var doppio := _brew("house", "medium", "espresso", "double_shot", 85.0)
	var recipe := doppio.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("double_espresso")
	var single := _brew("house", "medium", "espresso", "", 85.0)
	assert_object(single.matched_recipe(LIBRARY)).is_null()


func test_protein_cold_brew_needs_the_protein_extra() -> void:
	var protein := _brew("house", "dark", "cold_brew", "protein_powder", 85.0)
	var recipe := protein.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("protein_cold_brew")
	var plain := _brew("house", "dark", "cold_brew", "", 85.0)
	assert_object(plain.matched_recipe(LIBRARY)).is_null()


func test_designer_cup_leaves_the_offmug_recipe_first() -> void:
	# The library keeps the earlier Offmug row first, so his exact brew
	# still names itself. A plain V60 pour of other beans falls through to
	# the designer cup until the appliance gate of T082 lands.
	var offmug := _brew("golden_coast_arabica", "light", "v60", "", 85.0)
	assert_str(offmug.matched_recipe(LIBRARY).recipe_id).is_equal("single_origin_v60")
	var plain := _brew("house", "medium", "v60", "", 85.0)
	assert_str(plain.matched_recipe(LIBRARY).recipe_id).is_equal("designer_dripper_cup")


func test_competition_cup_needs_the_eight_methods_extra() -> void:
	var built := _brew("house", "medium", "filter", "all_eight_methods", 85.0)
	var recipe := built.matched_recipe(LIBRARY)
	assert_object(recipe).is_not_null()
	assert_str(recipe.recipe_id).is_equal("competition_cup")
	var plain := _brew("house", "medium", "filter", "", 85.0)
	assert_object(plain.matched_recipe(LIBRARY)).is_null()


func test_v2_special_cures_follow_the_tier_rules() -> void:
	# The section 15 tiers lead every cure: weak wakes basic types only,
	# good wakes the type that needs the drink, perfect wakes all.
	var weak_doppio := _brew("house", "medium", "espresso", "double_shot", 42.0)
	assert_bool(_wakes(weak_doppio, "night_nurse")).is_false()
	var good_doppio := _brew("house", "medium", "espresso", "double_shot", 85.0)
	assert_bool(_wakes(good_doppio, "night_nurse")).is_true()
	var plain_espresso := _brew("house", "medium", "espresso", "", 85.0)
	assert_bool(_wakes(plain_espresso, "night_nurse")).is_false()

	var protein := _brew("house", "medium", "cold_brew", "protein_powder", 85.0)
	assert_bool(_wakes(protein, "crossfitter")).is_true()
	var dark_protein := _brew("house", "dark", "cold_brew", "protein_powder", 85.0)
	assert_bool(_wakes(dark_protein, "crossfitter")).is_false()
	var plain_cold := _brew("house", "medium", "cold_brew", "", 85.0)
	assert_bool(_wakes(plain_cold, "crossfitter")).is_false()

	var offmug := _brew("golden_coast_arabica", "light", "v60", "", 85.0)
	assert_bool(_wakes(offmug, "executive")).is_true()
	var wrong_v60 := _brew("house", "light", "v60", "", 85.0)
	assert_bool(_wakes(wrong_v60, "executive")).is_false()

	var any_weak := _brew("house", "medium", "filter", "", 10.0)
	assert_bool(_wakes(any_weak, "withdrawer")).is_true()

	var perfect_plain := _brew("house", "medium", "filter", "", 99.0)
	for type_id: String in ["night_nurse", "crossfitter", "executive", "withdrawer"]:
		assert_bool(_wakes(perfect_plain, type_id)).is_true()


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
