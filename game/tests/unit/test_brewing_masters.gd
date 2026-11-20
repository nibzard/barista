# ABOUTME: Unit tests for the brewing masters of section 8: the data pins and
# ABOUTME: the lesson flow of the school, one fixed lesson taught three times.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const OFFMUG := preload("res://resources/masters/offmug.tres")
const HEDRIP := preload("res://resources/masters/hedrip.tres")
const RAOAST := preload("res://resources/masters/raoast.tres")
const TURKISH_HUSBAND := preload("res://resources/masters/turkish_husband.tres")


func _make_skills() -> BrewingSkills:
	return BrewingSkills.new(BALANCE)


func test_the_three_v1_masters_pin_their_identities() -> void:
	assert_str(OFFMUG.master_id).is_equal("offmug")
	assert_str(OFFMUG.display_name).is_equal("James Offmug")
	assert_str(OFFMUG.city_id).is_equal("san_coffesco")
	assert_array(OFFMUG.taught_methods).is_equal(["v60"])
	assert_str(OFFMUG.role_line).is_equal("He teaches the V60 pour-over.")

	assert_str(HEDRIP.master_id).is_equal("hedrip")
	assert_str(HEDRIP.display_name).is_equal("Lance Hedrip")
	assert_str(HEDRIP.city_id).is_equal("steamtle")
	assert_array(HEDRIP.taught_methods).is_equal(["aeropress", "cold_brew"])
	assert_str(HEDRIP.role_line).is_equal("He teaches the Aeropress and the cold brew.")

	assert_str(RAOAST.master_id).is_equal("raoast")
	assert_str(RAOAST.display_name).is_equal("Scott Raoast")
	assert_str(RAOAST.city_id).is_equal("pourtland")
	assert_array(RAOAST.taught_methods).is_equal(["espresso", "filter"])
	assert_str(RAOAST.role_line).is_equal("He teaches the espresso and the filter coffee.")


func test_every_master_carries_one_role_one_lesson_and_a_catchphrase() -> void:
	# Section 8: James Offmug says "Ultimately..." in every sentence, so the
	# spoken lesson of a master starts with the catchphrase.
	assert_str(OFFMUG.catchphrase).is_equal("Ultimately...")
	for master: BrewingMaster in [OFFMUG, HEDRIP, RAOAST]:
		(
			assert_bool(master.catchphrase.is_empty())
			. override_failure_message(master.master_id)
			. is_false()
		)
		(
			assert_bool(master.lesson_line.is_empty())
			. override_failure_message(master.master_id)
			. is_false()
		)
		(
			assert_bool(master.taught_methods.is_empty())
			. override_failure_message(master.master_id)
			. is_false()
		)


func test_each_master_lives_in_a_different_city() -> void:
	var cities: Array[String] = [OFFMUG.city_id, HEDRIP.city_id, RAOAST.city_id]
	assert_int(cities.size()).is_equal(3)
	for city_id: String in cities:
		assert_int(cities.count(city_id)).is_equal(1)


func test_every_taught_method_and_lesson_recipe_resolves() -> void:
	for master: BrewingMaster in [OFFMUG, HEDRIP, RAOAST, TURKISH_HUSBAND]:
		for method_id: String in master.taught_methods:
			(
				assert_object(LIBRARY.find_method(method_id))
				. override_failure_message("%s: %s" % [master.master_id, method_id])
				. is_not_null()
			)
		assert_int(master.lesson_recipes.size()).is_less_equal(BALANCE.lessons_per_master)
		for recipe_id: String in master.lesson_recipes:
			(
				assert_object(LIBRARY.find_recipe(recipe_id))
				. override_failure_message("%s: %s" % [master.master_id, recipe_id])
				. is_not_null()
			)


func test_moka_pot_and_french_press_stay_self_taught() -> void:
	# Section 16: moka pot and French press have no master in version 1. The
	# cafe masters of the three cities teach five methods, and the Turkish
	# method belongs to the Aisle 7 husband alone, section 13.
	var taught: Array[String] = []
	for master: BrewingMaster in [OFFMUG, HEDRIP, RAOAST, TURKISH_HUSBAND]:
		for method_id: String in master.taught_methods:
			taught.append(method_id)
	for self_taught_id: String in ["moka_pot", "french_press"]:
		assert_bool(taught.has(self_taught_id)).is_false()
	assert_array(taught).is_equal(
		["v60", "aeropress", "cold_brew", "espresso", "filter", "turkish"]
	)


func test_one_lesson_grants_two_skill_per_taught_method() -> void:
	var offmug_skills := _make_skills()
	MasterLessons.new([OFFMUG], offmug_skills).take_lesson("offmug")
	assert_int(offmug_skills.skill("v60")).is_equal(2)
	assert_bool(offmug_skills.is_auto_brew_available("v60")).is_false()

	var hedrip_skills := _make_skills()
	MasterLessons.new([HEDRIP], hedrip_skills).take_lesson("hedrip")
	assert_int(hedrip_skills.skill("aeropress")).is_equal(2)
	assert_int(hedrip_skills.skill("cold_brew")).is_equal(2)

	var raoast_skills := _make_skills()
	MasterLessons.new([RAOAST], raoast_skills).take_lesson("raoast")
	assert_int(raoast_skills.skill("espresso")).is_equal(2)
	assert_int(raoast_skills.skill("filter")).is_equal(2)


func test_a_lesson_trains_faster_than_solo_practice() -> void:
	# Section 8: a master increases the brewing skill faster than solo
	# practice. One lesson trains more than one good solo brew.
	var skills := _make_skills()
	var solo_gain := skills.record_brew("v60", BALANCE.good_tier_min_score)
	var skill_before := skills.skill("v60")

	MasterLessons.new([OFFMUG], skills).take_lesson("offmug")
	var lesson_gain := skills.skill("v60") - skill_before

	assert_int(solo_gain).is_equal(BALANCE.good_brew_skill_gain)
	assert_int(lesson_gain).is_greater(solo_gain)
	assert_int(BALANCE.master_lesson_skill_gain).is_greater(BALANCE.good_brew_skill_gain)


func test_every_master_teaches_three_lessons_for_six_skill() -> void:
	for master: BrewingMaster in [OFFMUG, HEDRIP, RAOAST]:
		var skills := _make_skills()
		var school := MasterLessons.new([master], skills)
		assert_int(school.lessons_per_master()).is_equal(3)
		for lesson: int in range(3):
			assert_bool(school.can_take_lesson(master.master_id)).is_true()
			school.take_lesson(master.master_id)
		assert_bool(school.can_take_lesson(master.master_id)).is_false()
		assert_bool(school.is_school_complete(master.master_id)).is_true()
		assert_array(school.take_lesson(master.master_id)).is_empty()
		assert_int(school.lessons_taken(master.master_id)).is_equal(3)
		for method_id: String in master.taught_methods:
			assert_int(skills.skill(method_id)).is_equal(6)


func test_a_lesson_respects_the_skill_cap() -> void:
	# A master cannot push a method past the section 14 cap. The lesson still
	# counts, and auto-brew opens at the cap.
	var skills := _make_skills()
	while skills.skill("v60") < BALANCE.max_method_skill - 2:
		skills.record_brew("v60", 100.0)
	skills.record_brew("v60", BALANCE.good_tier_min_score)

	var school := MasterLessons.new([OFFMUG], skills)
	school.take_lesson("offmug")
	assert_int(skills.skill("v60")).is_equal(BALANCE.max_method_skill)
	assert_bool(skills.is_auto_brew_available("v60")).is_true()
	assert_int(school.lessons_taken("offmug")).is_equal(1)


func test_lessons_grant_the_master_recipes_in_order() -> void:
	var offmug_school := MasterLessons.new([OFFMUG], _make_skills())
	assert_array(offmug_school.take_lesson("offmug")).is_equal(["single_origin_v60"])
	assert_array(offmug_school.take_lesson("offmug")).is_empty()
	assert_array(offmug_school.take_lesson("offmug")).is_empty()

	var hedrip_school := MasterLessons.new([HEDRIP], _make_skills())
	assert_array(hedrip_school.take_lesson("hedrip")).is_equal(["triple_shot"])
	assert_array(hedrip_school.take_lesson("hedrip")).is_equal(["cold_brew_concentrate"])
	assert_array(hedrip_school.take_lesson("hedrip")).is_empty()

	var raoast_school := MasterLessons.new([RAOAST], _make_skills())
	assert_array(raoast_school.take_lesson("raoast")).is_equal(["super_tall_american"])
	assert_array(raoast_school.take_lesson("raoast")).is_equal(["ristretto"])
	assert_array(raoast_school.take_lesson("raoast")).is_equal(["bulletproof"])
	assert_array(raoast_school.known_recipes()).is_equal(
		["super_tall_american", "ristretto", "bulletproof"]
	)


func test_recipes_stay_unknown_until_their_lesson() -> void:
	var school := MasterLessons.new([RAOAST], _make_skills())
	assert_bool(school.is_recipe_known("super_tall_american")).is_false()
	school.take_lesson("raoast")
	assert_bool(school.is_recipe_known("super_tall_american")).is_true()
	assert_bool(school.is_recipe_known("ristretto")).is_false()
	assert_bool(school.is_recipe_known("turkish_cup")).is_false()


func test_lesson_taken_signal_reports_master_and_lesson_number() -> void:
	var school := MasterLessons.new([OFFMUG], _make_skills())
	var events: Array = []
	school.lesson_taken.connect(
		func(master_id: String, lesson_number: int) -> void:
			events.append([master_id, lesson_number])
	)

	school.take_lesson("offmug")
	school.take_lesson("offmug")
	assert_int(events.size()).is_equal(2)
	assert_str(events[0][0]).is_equal("offmug")
	assert_int(events[0][1]).is_equal(1)
	assert_int(events[1][1]).is_equal(2)


func test_recipe_and_school_signals_fire_once_each() -> void:
	var school := MasterLessons.new([RAOAST], _make_skills())
	var recipes: Array[String] = []
	var schools: Array[String] = []
	school.recipe_granted.connect(func(recipe_id: String) -> void: recipes.append(recipe_id))
	school.school_complete.connect(func(master_id: String) -> void: schools.append(master_id))

	for lesson: int in range(3):
		school.take_lesson("raoast")
	assert_array(recipes).is_equal(["super_tall_american", "ristretto", "bulletproof"])
	assert_array(schools).is_equal(["raoast"])


func test_unknown_masters_are_refused_and_cities_find_their_master() -> void:
	var school := MasterLessons.new([OFFMUG, HEDRIP, RAOAST], _make_skills())
	assert_bool(school.can_take_lesson("morgan_espressoth")).is_false()
	assert_array(school.take_lesson("morgan_espressoth")).is_empty()
	assert_int(school.lessons_taken("morgan_espressoth")).is_equal(0)
	assert_object(school.find_master("morgan_espressoth")).is_null()

	assert_str(school.master_for_city("san_coffesco").master_id).is_equal("offmug")
	assert_str(school.master_for_city("steamtle").master_id).is_equal("hedrip")
	assert_str(school.master_for_city("pourtland").master_id).is_equal("raoast")
	assert_object(school.master_for_city("decaf_city")).is_null()


func test_the_school_size_reads_the_balance() -> void:
	# The framework keeps no lesson count of its own: the balance decides how
	# many lessons one master teaches.
	var tuned := BALANCE.duplicate() as BrewingBalance
	tuned.lessons_per_master = 1
	var school := MasterLessons.new([OFFMUG], BrewingSkills.new(tuned))

	assert_int(school.lessons_per_master()).is_equal(1)
	school.take_lesson("offmug")
	assert_bool(school.is_school_complete("offmug")).is_true()
	assert_array(school.take_lesson("offmug")).is_empty()


func test_a_school_without_skills_teaches_nothing() -> void:
	var school := MasterLessons.new([OFFMUG], null)
	assert_int(school.lessons_per_master()).is_equal(0)
	assert_bool(school.can_take_lesson("offmug")).is_false()
	assert_array(school.take_lesson("offmug")).is_empty()


func test_save_state_holds_the_lesson_table() -> void:
	var school := MasterLessons.new([HEDRIP], _make_skills())
	school.take_lesson("hedrip")
	school.take_lesson("hedrip")

	var saved: Dictionary = school.save_state()
	var lessons: Dictionary = saved["lessons"]
	assert_int(lessons.size()).is_equal(1)
	assert_int(lessons["hedrip"]).is_equal(2)


func test_load_state_restores_without_signal_replay() -> void:
	var school := MasterLessons.new([RAOAST], _make_skills())
	school.take_lesson("raoast")
	school.take_lesson("raoast")
	var saved := school.save_state()

	var loaded := MasterLessons.new([RAOAST], _make_skills())
	var lessons: Array = []
	var recipes: Array[String] = []
	var schools: Array[String] = []
	loaded.lesson_taken.connect(func(_master_id: String, _number: int) -> void: lessons.append(1))
	loaded.recipe_granted.connect(func(recipe_id: String) -> void: recipes.append(recipe_id))
	loaded.school_complete.connect(func(master_id: String) -> void: schools.append(master_id))
	loaded.load_state(saved)

	assert_int(loaded.lessons_taken("raoast")).is_equal(2)
	assert_bool(loaded.is_recipe_known("super_tall_american")).is_true()
	assert_bool(loaded.is_recipe_known("ristretto")).is_true()
	assert_bool(loaded.is_recipe_known("bulletproof")).is_false()
	assert_array(loaded.known_recipes()).is_equal(["super_tall_american", "ristretto"])
	assert_int(lessons.size()).is_equal(0)
	assert_int(recipes.size()).is_equal(0)
	assert_int(schools.size()).is_equal(0)

	# The school continues after the load: the last lesson still works.
	assert_array(loaded.take_lesson("raoast")).is_equal(["bulletproof"])
	assert_bool(loaded.is_school_complete("raoast")).is_true()


func test_load_state_clamps_impossible_counts_and_drops_unknown_masters() -> void:
	var school := MasterLessons.new([OFFMUG, HEDRIP], _make_skills())
	school.load_state({"lessons": {"offmug": 9, "ghost": 2, "hedrip": -1}})

	assert_int(school.lessons_taken("offmug")).is_equal(3)
	assert_bool(school.is_school_complete("offmug")).is_true()
	assert_int(school.lessons_taken("hedrip")).is_equal(0)
	assert_int(school.lessons_taken("ghost")).is_equal(0)
	assert_bool(school.is_recipe_known("single_origin_v60")).is_true()


func test_late_registered_master_restores_saved_lessons_and_recipes() -> void:
	# Mid-run quest masters like the Aisle 7 husband register after load_state;
	# saved lessons and granted recipes must restore when they register.
	var school := MasterLessons.new([RAOAST], _make_skills())
	assert_bool(school.register_master(TURKISH_HUSBAND)).is_true()
	school.take_lesson("husband")
	var saved := school.save_state()

	var reloaded := MasterLessons.new([RAOAST], _make_skills())
	reloaded.load_state(saved)
	assert_bool(reloaded.is_recipe_known("turkish_cup")).is_true()
	assert_bool(reloaded.register_master(TURKISH_HUSBAND)).is_true()
	assert_int(reloaded.lessons_taken("husband")).is_equal(1)
	assert_bool(reloaded.is_recipe_known("turkish_cup")).is_true()
