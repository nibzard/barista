# ABOUTME: Integration tests for the Aisle 7 side quest of Pourtland, T037.
# ABOUTME: Proves the photo beat, the Foam Watch brew in front of the husband,
# ABOUTME: the sweet hug, and the Turkish master unlock of section 13.
extends GdUnitTestSuite

const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const TURKISH_HUSBAND := preload("res://resources/masters/turkish_husband.tres")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")

const MAX_FRAMES_TO_WAIT := 600

var _city: CityRun
var _stage: Aisle7Stage
var _spoken_lines: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declaration.
	_spoken_lines.clear()
	_city = POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_stage = _city.signature_quest as Aisle7Stage
	_stage.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak a pressed key.
	Input.action_release(&"move_right")


func test_the_store_builds_wife_husband_and_shelves() -> void:
	# Section 13: the husband sleeps in aisle 7 of the hardware store, between
	# the screws and the sandpaper, and his wife waits in the aisle mouth.
	assert_object(_stage).is_not_null()
	var anchor := (
		_city.city_map().find_quest_site("The Hardware Store").quest_site_marker().global_position
	)
	assert_vector(_stage.store_position()).is_equal(anchor)
	var husband := _stage.husband()
	assert_object(husband).is_not_null()
	assert_bool(husband.is_awake()).is_false()
	assert_float(husband.global_position.distance_to(anchor)).is_less(2.0)
	assert_str(husband.get_node(^"LineLabel").text).is_equal(
		"THE HUSBAND\nHE DRANK ONLY TURKISH COFFEE, ALL HIS LIFE."
	)
	var wife := _stage.wife()
	assert_object(wife).is_not_null()
	assert_bool(wife.holds_photo()).is_true()
	assert_bool(wife.is_hugging()).is_false()
	assert_float(wife.global_position.distance_to(anchor + Vector2(-60.0, 150.0))).is_less(2.0)
	# The quest balance pins its .tres values, like every tuned quest.
	assert_float(_stage.balance.wife_walk_speed).is_equal(110.0)
	assert_float(_stage.balance.hug_arrive_radius).is_equal(30.0)
	assert_float(_stage.balance.brew_stand_radius).is_equal(120.0)
	assert_float(_stage.balance.master_unlock_delay).is_equal(2.5)


func test_the_wife_greets_and_hands_over_the_photo() -> void:
	# The woman gives the player a photo, section 13: the greeting plays on
	# approach, the interact key takes the photo, and the quest turns active.
	var quest := _city.quest_log.quest("aisle_7")
	assert_bool(quest.is_offered()).is_true()
	var wife := _stage.wife()
	_city.player.global_position = wife.global_position
	await _await_frames(4)
	assert_str(wife.spoken_line()).is_equal(Aisle7Stage.GREET_LINE)

	assert_bool(_stage.try_interact()).is_true()
	assert_bool(quest.is_active()).is_true()
	assert_int(_city.player.inventory.count("husband_photo")).is_equal(1)
	assert_bool(wife.holds_photo()).is_false()
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.PHOTO_TOAST)
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.HUSBAND_ASLEEP)
	# The photo leaves her hand exactly once.
	assert_bool(_stage.try_interact()).is_false()


func test_no_brew_at_the_husband_before_the_photo() -> void:
	# The wife speaks first: without the photo, the interact key at the
	# husband opens nothing and keeps the key for the van.
	_city.player.global_position = _stage.husband().global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_false()
	assert_object(_stage.foam_watch_view()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.PHOTO_WAIT)


func test_no_turkish_pot_in_the_bag_refuses_the_quest_brew() -> void:
	# Section 15: the Turkish pot is a cafe appliance the player scavenges.
	# Without it, the interact at the husband opens no watch and the toast
	# names the find.
	await _take_photo()
	_city.player.global_position = _stage.husband().global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_false()
	assert_object(_stage.foam_watch_view()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.NEED_POT_TOAST)


func test_the_interact_at_the_husband_opens_the_foam_watch() -> void:
	# One Turkish cup brewed in front of him, section 13: the interact key at
	# the husband opens The Foam Watch, the Turkish minigame, and the overlay
	# owns the key while it plays. The pot rides in the bag, section 15.
	await _take_photo()
	_give_turkish_pot()
	_city.player.global_position = _stage.husband().global_position
	await _await_frames(4)

	assert_bool(_stage.try_interact()).is_true()
	var view := _stage.foam_watch_view()
	assert_object(view).is_not_null()
	assert_str(view.method.method_id).is_equal("turkish")
	assert_bool(view.model.is_running()).is_true()
	assert_bool(_city.player.is_input_locked()).is_true()
	assert_bool(_stage.holds_interact()).is_true()
	# The overlay owns the key: one press while it plays opens no second watch.
	assert_bool(_stage.try_interact()).is_true()
	assert_object(_stage.foam_watch_view()).is_equal(view)


func test_the_foam_watch_cup_wakes_the_husband() -> void:
	# The acceptance path: a good foam lift becomes the served Turkish cup, it
	# wakes him, he cries, and the quest reaches the hug while the skill grows.
	await _open_watch_at_husband()
	var view := _stage.foam_watch_view()
	while view.model.step == FoamWatch.Step.HEAT:
		view.model.tick(0.1)
	while view.model.foam < 0.9 and view.model.is_running():
		view.model.tick(0.1)
	view.request_lift()

	var husband := _stage.husband()
	assert_bool(husband.is_awake()).is_true()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.SWEET_HUG)
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.WAKE_TOAST)
	assert_str(husband.get_node(^"LineLabel").text).is_equal(Aisle7Stage.CRY_LINE)
	assert_bool(_stage.wife().is_walking()).is_true()
	# The brew trained the Turkish method, section 14.
	assert_int(_city.player.brewing_skills.skill("turkish")).is_equal(1)
	# The overlay closed and gave the keys back.
	assert_object(_stage.foam_watch_view()).is_null()
	assert_bool(_stage.holds_interact()).is_false()
	assert_bool(_city.player.is_input_locked()).is_false()


func test_a_cold_pot_leaves_the_husband_asleep() -> void:
	# A cold lift ruins the cup, section 8: the husband sleeps on, the overlay
	# closes, and the next interact brews again.
	await _open_watch_at_husband()
	var view := _stage.foam_watch_view()
	view.model.tick(0.1)
	view.request_lift()

	assert_bool(_stage.husband().is_awake()).is_false()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.HUSBAND_ASLEEP)
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.COLD_CUP_TOAST)
	assert_object(_stage.foam_watch_view()).is_null()
	assert_int(_city.player.brewing_skills.skill("turkish")).is_equal(0)

	assert_bool(_stage.try_interact()).is_true()
	assert_object(_stage.foam_watch_view()).is_not_null()


func test_a_boiled_over_pot_leaves_the_husband_asleep() -> void:
	await _open_watch_at_husband()
	var view := _stage.foam_watch_view()
	while view.model.is_running():
		view.model.tick(0.1)
	assert_int(view.model.result.outcome).is_equal(FoamResult.Outcome.BOILED_OVER)
	# The watch announces its self-end on its own process beat.
	await _await_frames(2)

	assert_bool(_stage.husband().is_awake()).is_false()
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.BOILED_OVER_TOAST)
	assert_object(_stage.foam_watch_view()).is_null()


func test_wrong_cups_never_wake_the_husband() -> void:
	# The Turkish rule through the world node: the cafe-standard cup, a light
	# roast, and a weak Turkish brew all bounce off him.
	await _take_photo()
	var husband := _stage.husband()
	assert_bool(husband.try_wake(_brew("house", "medium", "filter", 85.0))).is_false()
	assert_bool(husband.try_wake(_brew("house", "light", "turkish", 85.0))).is_false()
	assert_bool(husband.try_wake(_brew("house", "medium", "turkish", 79.0))).is_false()
	assert_bool(husband.is_awake()).is_false()
	assert_bool(husband.try_wake(_brew("house", "medium", "turkish", 85.0))).is_true()
	assert_bool(husband.is_awake()).is_true()


func test_a_thrown_turkish_cup_wakes_the_husband() -> void:
	# The throw works too: he wears no tinfoil hat, so a thrown Turkish cup
	# lands on him through the same quest rule.
	await _take_photo()
	var husband := _stage.husband()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = husband.global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "turkish", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(husband.is_awake()).is_true()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.SWEET_HUG)


func test_the_wife_walks_and_the_sweet_hug_completes_the_quest() -> void:
	# The only sweet hug in the game: the wife crosses the aisle, the pair
	# stands together with the heart, and the side quest completes.
	await _wake_husband()
	var frames := 0
	while _stage.quest.phase() != Aisle7Quest.Phase.MASTER_OPEN and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	var wife := _stage.wife()
	assert_bool(wife.is_walking()).is_false()
	assert_bool(wife.is_hugging()).is_true()
	(
		assert_float(wife.global_position.distance_to(_stage.husband().global_position))
		. is_equal_approx(_stage.balance.hug_arrive_radius, 0.2)
	)
	assert_bool(_city.quest_log.quest("aisle_7").is_complete()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.HUG_TOAST)
	assert_int(_spoken_lines.size()).is_equal(1)
	assert_str(_spoken_lines[0]).is_equal(Aisle7Stage.HUG_LINE)


func test_the_sleeper_becomes_the_turkish_master() -> void:
	# The bonus of section 13: after the hug, the husband joins the school and
	# teaches the Turkish method and its recipe like every master.
	await _wake_husband()
	await _await_quest_master()
	assert_str(_city.hud.toast_message()).is_equal(Aisle7Stage.MASTER_TOAST)

	var npc := _quest_master_npc()
	assert_object(npc).is_not_null()
	assert_str(npc.master.display_name).is_equal(TURKISH_HUSBAND.display_name)
	assert_float(npc.global_position.distance_to(_stage.store_position())).is_less(120.0)

	_city.player.global_position = npc.global_position
	await _await_frames(4)
	assert_bool(_city.master_school.interact()).is_true()
	assert_int(_city.player.brewing_skills.skill("turkish")).is_equal(2)
	assert_bool(_city.master_lessons.is_recipe_known("turkish_cup")).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		"THE TURKISH HUSBAND, LESSON 1 OF 3. +2 SKILL. NEW RECIPE: TURKISH COFFEE."
	)

	for _lesson: int in range(2):
		assert_bool(_city.master_school.interact()).is_true()
	assert_bool(_city.master_lessons.is_school_complete("husband")).is_true()
	assert_int(_city.player.brewing_skills.skill("turkish")).is_equal(6)


func test_the_turkish_master_stays_locked_before_the_quest() -> void:
	# Before the quest, only Raoast teaches in Pourtland: the husband is no
	# city resident, so nothing of him exists in the run.
	assert_int(_city.master_school.masters().size()).is_equal(1)
	assert_str(_city.master_school.masters()[0].master.master_id).is_equal("raoast")
	assert_object(_city.master_lessons.find_master("husband")).is_null()
	assert_bool(_city.master_lessons.can_take_lesson("husband")).is_false()


func test_a_completed_aisle_7_resumes_silently_with_the_master() -> void:
	# Reloading a save where aisle_7 is complete restores the woken husband,
	# hugging wife, and Turkish master without replaying toasts.
	var reloaded := POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(reloaded))
	reloaded.quest_log.load_state({"side": {"aisle_7": SideQuest.State.COMPLETE}})
	var stage := reloaded.signature_quest as Aisle7Stage
	await _await_frames(3)
	assert_int(stage.quest.phase()).is_equal(Aisle7Quest.Phase.MASTER_OPEN)
	assert_bool(stage.husband().is_awake()).is_true()
	assert_bool(stage.wife().is_hugging()).is_true()
	assert_bool(reloaded.master_lessons.find_master("husband") != null).is_true()
	assert_bool(reloaded.hud.is_toast_visible()).is_false()


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _await_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().physics_frame


func _take_photo() -> void:
	# The photo beat as live play reaches it: the player stands at the wife and
	# takes the photo through the interact key. The helper awaits its frames, so
	# every caller awaits the helper.
	_city.player.global_position = _stage.wife().global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_true()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.HUSBAND_ASLEEP)


func _open_watch_at_husband() -> void:
	await _take_photo()
	_give_turkish_pot()
	_city.player.global_position = _stage.husband().global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_true()
	assert_object(_stage.foam_watch_view()).is_not_null()


func _give_turkish_pot() -> void:
	# The quest brew needs the scavenged Turkish pot in the bag, section 15.
	_city.player.inventory.add(TURKISH_POT_ITEM, 1)


func _wake_husband() -> void:
	# Drives the quest into the hug leg with a served good Turkish cup, the
	# same state the Foam Watch brew reaches in live play. The photo comes
	# first, like in live play.
	await _take_photo()
	assert_bool(_stage.husband().try_wake(_brew("house", "medium", "turkish", 85.0))).is_true()
	assert_int(_stage.quest.phase()).is_equal(Aisle7Quest.Phase.SWEET_HUG)


func _await_quest_master() -> void:
	# The hug holds for the tuned delay before the school opens.
	var frames := 0
	while _quest_master_npc() == null and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


func _quest_master_npc() -> MasterNpc:
	for npc: MasterNpc in _city.master_school.masters():
		if npc.master.master_id == "husband":
			return npc
	return null


func _brew(bean_id: String, roast_id: String, method_id: String, score: float) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		"",
		score
	)
