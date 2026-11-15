# ABOUTME: Unit tests for the brewing skill progression rules, section 14.
# ABOUTME: Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")


func _make_skills() -> BrewingSkills:
	return BrewingSkills.new(BALANCE)


func _fill_to_maximum(skills: BrewingSkills, method_id: String) -> void:
	while skills.skill(method_id) < BALANCE.max_method_skill:
		var gained := skills.record_brew(method_id, 100.0)
		assert_int(gained).is_greater(0)


func test_every_method_starts_at_skill_zero() -> void:
	var skills := _make_skills()
	for method: BrewingMethod in LIBRARY.methods:
		assert_int(skills.skill(method.method_id)).is_equal(0)
		assert_bool(skills.is_auto_brew_available(method.method_id)).is_false()


func test_a_weak_brew_gains_no_skill() -> void:
	var skills := _make_skills()
	assert_int(skills.record_brew("filter", BALANCE.good_tier_min_score - 0.1)).is_equal(0)
	assert_int(skills.record_brew("filter", 0.0)).is_equal(0)
	assert_int(skills.skill("filter")).is_equal(0)


func test_a_good_brew_gains_one_skill() -> void:
	var skills := _make_skills()
	assert_int(skills.record_brew("filter", BALANCE.good_tier_min_score)).is_equal(1)
	assert_int(skills.record_brew("filter", BALANCE.perfect_tier_min_score - 0.1)).is_equal(1)
	assert_int(skills.skill("filter")).is_equal(2)


func test_a_perfect_brew_gains_two_skill() -> void:
	var skills := _make_skills()
	assert_int(skills.record_brew("v60", BALANCE.perfect_tier_min_score)).is_equal(2)
	assert_int(skills.record_brew("v60", 100.0)).is_equal(2)
	assert_int(skills.skill("v60")).is_equal(4)


func test_the_skill_caps_at_ten() -> void:
	var skills := _make_skills()
	for brew: int in range(5):
		assert_int(skills.record_brew("espresso", 100.0)).is_equal(2)
	assert_int(skills.record_brew("espresso", 100.0)).is_equal(0)
	assert_int(skills.skill("espresso")).is_equal(BALANCE.max_method_skill)
	assert_int(skills.skill("espresso")).is_equal(10)


func test_a_gain_never_passes_the_cap() -> void:
	var skills := _make_skills()
	for brew: int in range(4):
		skills.record_brew("espresso", 100.0)
	assert_int(skills.record_brew("espresso", BALANCE.good_tier_min_score)).is_equal(1)
	assert_int(skills.skill("espresso")).is_equal(9)

	assert_int(skills.record_brew("espresso", 100.0)).is_equal(1)
	assert_int(skills.skill("espresso")).is_equal(BALANCE.max_method_skill)


func test_skills_are_independent_per_method() -> void:
	var skills := _make_skills()
	skills.record_brew("filter", 100.0)
	skills.record_brew("espresso", BALANCE.good_tier_min_score)
	assert_int(skills.skill("filter")).is_equal(2)
	assert_int(skills.skill("espresso")).is_equal(1)
	assert_int(skills.skill("turkish")).is_equal(0)


func test_the_gain_rules_read_the_balance_thresholds() -> void:
	var tuned := BALANCE.duplicate() as BrewingBalance
	tuned.good_tier_min_score = 50.0
	tuned.perfect_tier_min_score = 70.0
	var skills := BrewingSkills.new(tuned)

	assert_int(skills.record_brew("filter", 49.9)).is_equal(0)
	assert_int(skills.record_brew("filter", 50.0)).is_equal(1)
	assert_int(skills.record_brew("filter", 70.0)).is_equal(2)


func test_a_master_lesson_gains_two_skill() -> void:
	var skills := _make_skills()
	assert_int(skills.record_master_lesson("aeropress")).is_equal(2)
	assert_int(skills.skill("aeropress")).is_equal(2)
	assert_bool(skills.is_auto_brew_available("aeropress")).is_false()


func test_a_master_lesson_at_the_cap_gains_nothing() -> void:
	var skills := _make_skills()
	for lesson: int in range(4):
		skills.record_master_lesson("aeropress")
	assert_int(skills.skill("aeropress")).is_equal(8)
	skills.record_brew("aeropress", 100.0)
	assert_int(skills.skill("aeropress")).is_equal(BALANCE.max_method_skill)
	assert_int(skills.record_master_lesson("aeropress")).is_equal(0)
	assert_int(skills.skill("aeropress")).is_equal(BALANCE.max_method_skill)


func test_auto_brew_opens_only_at_the_maximum_skill() -> void:
	var skills := _make_skills()
	skills.record_master_lesson("moka_pot")
	assert_bool(skills.is_auto_brew_available("moka_pot")).is_false()

	while skills.skill("moka_pot") < BALANCE.max_method_skill:
		skills.record_master_lesson("moka_pot")
	assert_int(skills.skill("moka_pot")).is_equal(10)
	assert_bool(skills.is_auto_brew_available("moka_pot")).is_true()


func test_auto_brew_always_scores_a_good_cup_never_a_perfect_one() -> void:
	var skills := _make_skills()
	for sample: int in range(100):
		var score := skills.auto_brew_score()
		assert_float(score).is_equal(BALANCE.auto_brew_score)
		assert_int(CupTier.from_score(score, BALANCE)).is_equal(CupTier.Tier.GOOD)
	assert_float(skills.auto_brew_score()).is_equal(80.0)

	assert_float(BALANCE.auto_brew_score).is_greater_equal(BALANCE.good_tier_min_score)
	assert_float(BALANCE.auto_brew_score).is_less(BALANCE.perfect_tier_min_score)


func test_skill_gained_signal_reports_the_method_and_new_skill() -> void:
	var skills := _make_skills()
	var events: Array = []
	skills.skill_gained.connect(
		func(method_id: String, new_skill: int) -> void: events.append([method_id, new_skill])
	)

	skills.record_brew("turkish", BALANCE.perfect_tier_min_score)
	skills.record_brew("turkish", 0.0)
	assert_int(events.size()).is_equal(1)
	assert_str(events[0][0]).is_equal("turkish")
	assert_int(events[0][1]).is_equal(2)


func test_auto_brew_opened_signal_fires_once_per_method() -> void:
	var skills := _make_skills()
	var opened: Array[String] = []
	skills.auto_brew_opened.connect(func(method_id: String) -> void: opened.append(method_id))

	_fill_to_maximum(skills, "french_press")
	assert_int(opened.size()).is_equal(1)
	assert_str(opened[0]).is_equal("french_press")

	skills.record_brew("french_press", 100.0)
	skills.record_master_lesson("french_press")
	_fill_to_maximum(skills, "v60")
	assert_int(opened.size()).is_equal(2)
	assert_str(opened[1]).is_equal("v60")


func test_save_state_exposes_every_skill_for_the_save_system() -> void:
	var skills := _make_skills()
	skills.record_brew("filter", BALANCE.good_tier_min_score)
	skills.record_brew("espresso", 100.0)

	var saved: Dictionary = skills.save_state()
	assert_int(saved.size()).is_equal(2)
	assert_int(saved["filter"]).is_equal(1)
	assert_int(saved["espresso"]).is_equal(2)


func test_load_state_restores_skills_without_signal_replay() -> void:
	var skills := _make_skills()
	_fill_to_maximum(skills, "filter")
	skills.record_brew("espresso", 100.0)
	var saved: Dictionary = skills.save_state()

	var loaded := _make_skills()
	var gains: Array = []
	var opened: Array = []
	loaded.skill_gained.connect(
		func(method_id: String, new_skill: int) -> void: gains.append([method_id, new_skill])
	)
	loaded.auto_brew_opened.connect(func(method_id: String) -> void: opened.append(method_id))
	loaded.load_state(saved)

	assert_int(loaded.skill("filter")).is_equal(BALANCE.max_method_skill)
	assert_bool(loaded.is_auto_brew_available("filter")).is_true()
	assert_int(loaded.skill("espresso")).is_equal(2)
	assert_bool(loaded.is_auto_brew_available("espresso")).is_false()
	assert_int(gains.size()).is_equal(0)
	assert_int(opened.size()).is_equal(0)


func test_load_state_clamps_impossible_values() -> void:
	var loaded := _make_skills()
	loaded.load_state({"filter": -3, "espresso": 15, "v60": "not a number"})

	assert_int(loaded.skill("filter")).is_equal(0)
	assert_bool(loaded.is_auto_brew_available("filter")).is_false()
	assert_int(loaded.skill("espresso")).is_equal(BALANCE.max_method_skill)
	assert_bool(loaded.is_auto_brew_available("espresso")).is_true()
	assert_int(loaded.skill("v60")).is_equal(0)
