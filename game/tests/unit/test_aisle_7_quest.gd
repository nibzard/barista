# ABOUTME: Unit tests for the Aisle 7 quest machine, section 13: the photo
# ABOUTME: gate, the Turkish cup rule, the sweet hug, and the master unlock.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const TURKISH_CURE := preload("res://resources/brewing/recipes/turkish_cup.tres")
const TURKISH_HUSBAND := preload("res://resources/masters/turkish_husband.tres")
const RAOAST := preload("res://resources/masters/raoast.tres")

var _photo_count := 0
var _woke_count := 0
var _hug_count := 0


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declaration.
	_photo_count = 0
	_woke_count = 0
	_hug_count = 0


func test_the_quest_waits_for_the_photo_first() -> void:
	var quest := _make_quest()
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.PHOTO_WAIT)
	assert_bool(quest.is_husband_awake()).is_false()
	assert_bool(quest.is_master_unlocked()).is_false()

	quest.photo_taken.connect(func() -> void: _photo_count += 1)
	assert_bool(quest.take_photo()).is_true()
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.HUSBAND_ASLEEP)
	assert_int(_photo_count).is_equal(1)
	# The photo leaves her hand exactly once.
	assert_bool(quest.take_photo()).is_false()
	assert_int(_photo_count).is_equal(1)


func test_no_cup_reaches_the_husband_before_the_photo() -> void:
	# The wife speaks first, section 13: a Turkish cup that arrives before the
	# photo wakes nobody.
	var quest := _make_quest()
	assert_bool(quest.receive_cup(_turkish_cup(85.0))).is_false()
	assert_bool(quest.is_husband_awake()).is_false()
	assert_bool(quest.take_photo()).is_true()
	assert_bool(quest.receive_cup(_turkish_cup(85.0))).is_true()


func test_one_turkish_cup_wakes_the_husband() -> void:
	var quest := _make_quest()
	quest.take_photo()
	quest.husband_woke.connect(func() -> void: _woke_count += 1)

	assert_bool(quest.receive_cup(_turkish_cup(85.0))).is_true()
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.SWEET_HUG)
	assert_bool(quest.is_husband_awake()).is_true()
	assert_int(_woke_count).is_equal(1)
	# He wakes once: a second cup changes nothing.
	assert_bool(quest.receive_cup(_turkish_cup(95.0))).is_false()
	assert_int(_woke_count).is_equal(1)


func test_the_wrong_cups_wake_no_husband() -> void:
	# The Turkish rule, section 15: any bean, a medium roast, the Turkish pot.
	# The cafe-standard filter cup, a light or dark roast, and the wrong method
	# all bounce off him.
	var quest := _make_quest()
	quest.take_photo()
	assert_bool(quest.receive_cup(_brew("house", "medium", "filter", 85.0))).is_false()
	assert_bool(quest.receive_cup(_brew("house", "light", "turkish", 85.0))).is_false()
	assert_bool(quest.receive_cup(_brew("house", "dark", "turkish", 85.0))).is_false()
	assert_bool(quest.receive_cup(_brew("house", "medium", "espresso", 85.0))).is_false()
	assert_bool(quest.is_husband_awake()).is_false()
	# Any bean satisfies the recipe, so the Moss Hollow organic beans of the
	# Pourtland region brew his cup too.
	(
		assert_bool(quest.receive_cup(_brew("moss_hollow_organic", "medium", "turkish", 85.0)))
		. is_true()
	)


func test_a_weak_turkish_cup_wakes_nobody() -> void:
	# The tiers lead: below the good threshold the cup wakes nobody, even with
	# the right recipe, section 15.
	var quest := _make_quest()
	quest.take_photo()
	assert_bool(quest.receive_cup(_turkish_cup(79.0))).is_false()
	assert_bool(quest.receive_cup(_turkish_cup(80.0))).is_true()


func test_a_perfect_cup_wakes_him_from_any_brew() -> void:
	# A perfect cup wakes every type, section 15, so even a light-roast filter
	# brew reaches the husband at score 95.
	var quest := _make_quest()
	quest.take_photo()
	assert_bool(quest.receive_cup(_brew("house", "light", "filter", 94.0))).is_false()
	assert_bool(quest.receive_cup(_brew("house", "light", "filter", 95.0))).is_true()


func test_the_hug_completes_once_and_opens_the_master() -> void:
	var quest := _make_quest()
	quest.take_photo()
	quest.receive_cup(_turkish_cup(85.0))
	quest.sweet_hug.connect(func() -> void: _hug_count += 1)

	assert_bool(quest.is_master_unlocked()).is_false()
	assert_bool(quest.hug_completed()).is_true()
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.MASTER_OPEN)
	assert_bool(quest.is_master_unlocked()).is_true()
	assert_int(_hug_count).is_equal(1)
	assert_bool(quest.hug_completed()).is_false()
	assert_int(_hug_count).is_equal(1)


func test_the_hug_needs_the_wake_first() -> void:
	var quest := _make_quest()
	quest.take_photo()
	assert_bool(quest.hug_completed()).is_false()
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.HUSBAND_ASLEEP)


func test_the_cure_recipe_pins_the_turkish_data() -> void:
	# Section 15: the Turkish recipe is any bean, a medium roast, the Turkish
	# pot, and it wakes the Tinfoil Man and one husband.
	assert_str(TURKISH_CURE.recipe_id).is_equal("turkish_cup")
	assert_int(TURKISH_CURE.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(TURKISH_CURE.method_id).is_equal("turkish")
	assert_int(TURKISH_CURE.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(TURKISH_CURE.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(TURKISH_CURE.roast).is_equal(RoastProfile.Kind.MEDIUM)
	assert_object(LIBRARY.find_recipe("turkish_cup")).is_equal(TURKISH_CURE)


func test_save_and_load_round_trip_every_phase() -> void:
	for phase: int in [
		Aisle7Quest.Phase.PHOTO_WAIT,
		Aisle7Quest.Phase.HUSBAND_ASLEEP,
		Aisle7Quest.Phase.SWEET_HUG,
		Aisle7Quest.Phase.MASTER_OPEN,
	]:
		var quest := _make_quest()
		quest.load_state({"phase": phase})
		assert_int(quest.phase()).is_equal(phase)
		var saved := quest.save_state()
		assert_int(int(saved["phase"])).is_equal(phase)


func test_a_loaded_quest_never_replays_a_beat() -> void:
	var quest := _make_quest()
	quest.take_photo()
	quest.receive_cup(_turkish_cup(85.0))
	quest.hug_completed()
	quest.photo_taken.connect(func() -> void: _photo_count += 1)
	quest.husband_woke.connect(func() -> void: _woke_count += 1)
	quest.sweet_hug.connect(func() -> void: _hug_count += 1)

	var loaded := _make_quest()
	loaded.load_state(quest.save_state())
	assert_int(loaded.phase()).is_equal(Aisle7Quest.Phase.MASTER_OPEN)
	assert_bool(loaded.is_master_unlocked()).is_true()
	assert_bool(loaded.take_photo()).is_false()
	assert_bool(loaded.receive_cup(_turkish_cup(85.0))).is_false()
	assert_bool(loaded.hug_completed()).is_false()
	assert_int(_photo_count + _woke_count + _hug_count).is_equal(0)


func test_an_unknown_saved_phase_keeps_the_photo_wait() -> void:
	var quest := _make_quest()
	quest.load_state({"phase": 99})
	assert_int(quest.phase()).is_equal(Aisle7Quest.Phase.PHOTO_WAIT)
	var empty := _make_quest()
	empty.load_state({})
	assert_int(empty.phase()).is_equal(Aisle7Quest.Phase.PHOTO_WAIT)


func test_the_aisle_7_husband_is_the_turkish_master() -> void:
	# Section 13: the sleeper becomes the teacher. The husband of aisle 7
	# teaches the Turkish method and grants the Turkish recipe.
	assert_str(TURKISH_HUSBAND.master_id).is_equal("husband")
	assert_str(TURKISH_HUSBAND.display_name).is_equal("The Turkish Husband")
	assert_str(TURKISH_HUSBAND.city_id).is_equal("pourtland")
	assert_array(TURKISH_HUSBAND.taught_methods).is_equal(["turkish"])
	assert_array(TURKISH_HUSBAND.lesson_recipes).is_equal(["turkish_cup"])
	assert_str(TURKISH_HUSBAND.role_line).is_equal("He teaches the Turkish coffee.")
	assert_bool(TURKISH_HUSBAND.catchphrase.is_empty()).is_false()
	assert_bool(TURKISH_HUSBAND.lesson_line.is_empty()).is_false()


func test_the_quest_unlocks_the_turkish_master_mid_run() -> void:
	# Section 13: the sleeper becomes the teacher. The husband joins the school
	# only when the Aisle 7 quest hands him over, and then he teaches the full
	# three lessons like every master.
	var skills := BrewingSkills.new(BALANCE)
	var school := MasterLessons.new([RAOAST], skills)
	assert_bool(school.can_take_lesson("husband")).is_false()
	assert_array(school.take_lesson("husband")).is_empty()

	assert_bool(school.register_master(TURKISH_HUSBAND)).is_true()
	assert_bool(school.register_master(TURKISH_HUSBAND)).is_false()
	assert_bool(school.register_master(null)).is_false()
	assert_bool(school.can_take_lesson("husband")).is_true()

	assert_array(school.take_lesson("husband")).is_equal(["turkish_cup"])
	assert_int(skills.skill("turkish")).is_equal(BALANCE.master_lesson_skill_gain)
	assert_bool(school.is_recipe_known("turkish_cup")).is_true()
	school.take_lesson("husband")
	school.take_lesson("husband")
	assert_bool(school.is_school_complete("husband")).is_true()
	assert_int(school.lessons_taken("husband")).is_equal(BALANCE.lessons_per_master)
	assert_int(skills.skill("turkish")).is_equal(
		BALANCE.master_lesson_skill_gain * BALANCE.lessons_per_master
	)


func test_the_husband_shares_pourtland_with_raoast_by_design() -> void:
	# Section 8 puts one resident cafe master in each city; section 13 adds the
	# Turkish husband to Pourtland as the quest reward, so the husband is no
	# city resident: the city definitions keep exactly one master each.
	assert_str(TURKISH_HUSBAND.city_id).is_equal(RAOAST.city_id)
	var school := MasterLessons.new([RAOAST, TURKISH_HUSBAND], BrewingSkills.new(BALANCE))
	assert_int(school.masters().size()).is_equal(2)
	assert_object(school.master_for_city("pourtland")).is_equal(RAOAST)


func _make_quest() -> Aisle7Quest:
	return Aisle7Quest.new(TURKISH_CURE, BALANCE)


func _turkish_cup(score: float) -> BrewedCup:
	return _brew("house", "medium", "turkish", score)


func _brew(bean_id: String, roast_id: String, method_id: String, score: float) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		"",
		score
	)
