# ABOUTME: Integration tests for the live brew flow: the stand overlay, the
# ABOUTME: minigame chain, and the brewed payload that reaches the live throw.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const GOLDEN_BEAN_ITEM := preload("res://resources/items/beans/golden_coast_arabica.tres")
const HOUSE_BEAN_ITEM := preload("res://resources/items/beans/house.tres")
const GEISHA_BEAN_ITEM := preload("res://resources/items/beans/geisha_vault.tres")
const BLENDER_ITEM := preload("res://resources/items/appliances/blender.tres")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")

const MAX_FRAMES_TO_WAIT := 1200
const BREW_NOT_HERE_TEXT := "BREW AT THE CAFE POT."
const BREW_HAND_FULL_TEXT := "THE HAND IS FULL. NO ROOM FOR A BREWED CUP."
const NEEDS_BLENDER_TEXT := "NEEDS: BLENDER"
const NEEDS_TURKISH_POT_TEXT := "NEEDS: TURKISH_POT"
const STEEP_START_TOAST_TEXT := "COLD BREW CONCENTRATE STEEPING. COME BACK LATER."
const PROTEIN_STEEP_START_TOAST_TEXT := "PROTEIN COLD BREW STEEPING. COME BACK LATER."
const STEEP_READY_TOAST_TEXT := "THE COLD BREW IS READY. COLLECT IT AT THE POT."
const COLLECT_TOAST_TEXT := "COLD BREW CONCENTRATE BREWED. SCORE 85."

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready. The area overlaps of a fresh
	# city report from the third physics step onward, so the cafe zone of the
	# pot rules reads warm after four.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_a_full_hand_refuses_the_brew() -> void:
	# The player starts with a full hand, so the pot stays closed until a cup
	# leaves it.
	_city._unhandled_input(_key(KEY_B))
	assert_object(_city.brew_pot.stand()).is_null()
	assert_str(_city.hud.toast_message()).is_equal(BREW_HAND_FULL_TEXT)
	(
		assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.BREW).is_available())
		. is_false()
	)

	_spend_one_cup()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.BREW).is_available()).is_true()


func test_start_brew_outside_the_pot_only_toasts() -> void:
	_spend_one_cup()
	_city.player.global_position = Vector2(3000.0, 360.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_city._unhandled_input(_key(KEY_B))
	assert_object(_city.brew_pot.stand()).is_null()
	assert_str(_city.hud.toast_message()).is_equal(BREW_NOT_HERE_TEXT)


func test_the_stand_gates_the_player_for_its_whole_run() -> void:
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	assert_object(stand).is_not_null()
	assert_bool(_city.player.is_input_locked()).is_true()

	# The stop_grind key shares Space with throw_coffee: the locked player
	# throws nothing while the dial runs.
	var children_before := _city.get_child_count()
	_city.player._unhandled_input(_key(KEY_SPACE))
	assert_int(_city.get_child_count()).is_equal(children_before)
	assert_int(_city.player.coffee_supply.cups).is_equal(_full_limit() - 1)

	stand.close()
	await get_tree().process_frame
	assert_object(_city.brew_pot.stand()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.player.is_inside_tree()).is_true()


func test_the_stand_holds_the_interact_key_at_the_masters() -> void:
	# The lift and stop actions share the E key with interact, so a press
	# mid-brew must not also take a master lesson at the cafe pot.
	var master := _city.master_school.masters()[0]
	_city.player.global_position = master.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spend_one_cup()
	await get_tree().physics_frame

	_city._unhandled_input(_key(KEY_B))
	assert_object(_city.brew_pot.stand()).is_not_null()
	_city._unhandled_input(_key(KEY_E))
	assert_int(_city.master_lessons.lessons_taken(master.master.master_id)).is_equal(0)

	_city.brew_pot.stand().close()
	# The pot eats the press that ends the brew, so the lesson press waits
	# for the next frame.
	await get_tree().physics_frame
	await get_tree().process_frame
	_city._unhandled_input(_key(KEY_E))
	assert_int(_city.master_lessons.lessons_taken(master.master.master_id)).is_equal(1)


func test_the_menu_lists_the_recipe_lore_and_marks_master_recipes() -> void:
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	var ids: Array[String] = []
	for recipe: Recipe in stand.brewable_recipes():
		ids.append(recipe.recipe_id)
	assert_bool(ids.has("frappuccino")).is_true()
	assert_bool(ids.has("triple_shot")).is_true()
	assert_bool(ids.has("geisha_vault_cup")).is_true()
	assert_bool(ids.has("turkish_cup")).is_true()
	# The cold brew recipes ride the fridge flow now, section 8.
	assert_bool(ids.has("cold_brew_concentrate")).is_true()
	assert_bool(ids.has("protein_cold_brew")).is_true()
	# No steep runs, so the fridge panel stays hidden.
	assert_bool(stand.steep_panel.visible).is_false()

	# The school marks the recipes its lessons taught.
	assert_str(_row_text(stand, "SINGLE-ORIGIN V60")).is_equal("SINGLE-ORIGIN V60")
	_city.master_lessons.take_lesson("offmug")
	stand.begin(_city.player, _city.master_lessons, _city.cold_fridge)
	assert_str(_row_text(stand, "SINGLE-ORIGIN V60")).is_equal("SINGLE-ORIGIN V60 (MASTER)")
	stand.close()
	await get_tree().process_frame


func test_a_cold_brew_recipe_starts_the_steep_and_closes_the_stand() -> void:
	# The acceptance of T117: the stand lists the cold brew recipes, and the
	# START begins the steep instead of a minigame chain. The player walks out
	# at once and comes back later.
	_spend_one_cup()
	_city.player.inventory.add(GOLDEN_BEAN_ITEM, 1)
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("cold_brew_concentrate"))
	assert_bool(stand.start_button.disabled).is_false()
	assert_str(stand.plan_label.text).contains("THE FRIDGE STEEPS IT: 5:00")

	stand.begin_selected_brew()
	assert_object(stand.grind_dial()).is_null()
	await get_tree().process_frame
	assert_object(_city.brew_pot.stand()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.cold_fridge.is_steeping()).is_true()
	assert_str(_city.cold_fridge.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")
	assert_str(_city.cold_fridge.steeped_bean().bean_id).is_equal("golden_coast_arabica")
	assert_str(_city.hud.toast_message()).is_equal(STEEP_START_TOAST_TEXT)
	# The steep start spent the chosen bean, section 7: the fridge took it
	# out of the bag.
	assert_int(_city.player.inventory.count("golden_coast_arabica")).is_equal(0)
	# No cup and no skill before the player comes back: the steep alone brews
	# nothing yet, section 8.
	assert_int(_city.player.coffee_supply.cups).is_equal(_full_limit() - 1)
	assert_int(_city.player.brewing_skills.skill("cold_brew")).is_equal(0)


func test_the_pot_ticks_the_steep_while_the_player_plays() -> void:
	# Come back later: the steep runs on the play clock, not on the stand.
	_spend_one_cup()
	_city.cold_fridge.start(
		LIBRARY.find_recipe("protein_cold_brew"),
		LIBRARY.find_bean("house"),
		LIBRARY.find_method("cold_brew")
	)
	assert_str(_city.hud.toast_message()).is_equal(PROTEIN_STEEP_START_TOAST_TEXT)
	var before := _city.cold_fridge.remaining_seconds()
	for _i: int in range(10):
		await get_tree().physics_frame
	assert_float(_city.cold_fridge.remaining_seconds()).is_less(before)
	assert_bool(_city.cold_fridge.is_steeping()).is_true()


func test_the_ready_steep_collects_into_the_hand() -> void:
	# Come back later, part two: the ready fridge shows its countdown turn
	# into a COLLECT, and the ceiling cup lands in the hand like any brew.
	_spend_one_cup()
	_city.player.inventory.add(GOLDEN_BEAN_ITEM, 1)
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("cold_brew_concentrate"))
	# Section 8 for the cold cup: the roast the player picks at the stand
	# rides the steep into the collected cup, like any minigame brew.
	stand.select_roast(LIBRARY.find_roast("light"))
	stand.begin_selected_brew()
	await get_tree().process_frame
	await get_tree().process_frame
	for _i: int in range(30):
		_city.cold_fridge.tick(10.0)
	assert_bool(_city.cold_fridge.is_ready()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(STEEP_READY_TOAST_TEXT)

	_city._unhandled_input(_key(KEY_B))
	var reopened := _city.brew_pot.stand()
	await get_tree().process_frame
	assert_bool(reopened.steep_panel.visible).is_true()
	assert_str(reopened.steep_label.text).is_equal("COLD BREW: READY")
	assert_bool(reopened.collect_button.visible).is_true()

	var cups_before := _city.player.coffee_supply.cups
	reopened.collect_steep()
	await get_tree().process_frame
	assert_object(_city.brew_pot.stand()).is_null()
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("cold_brew")
	assert_str(payload.bean.bean_id).is_equal("golden_coast_arabica")
	assert_str(payload.roast.roast_id).is_equal("light")
	assert_float(payload.score).is_equal(85.0)
	assert_int(payload.tier(_city.player.brewing_balance)).is_equal(CupTier.Tier.GOOD)
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before + 1)
	# A good ceiling brew trains +1 skill, section 14.
	assert_int(_city.player.brewing_skills.skill("cold_brew")).is_equal(1)
	assert_str(_city.hud.toast_message()).is_equal(COLLECT_TOAST_TEXT)
	assert_bool(_city.cold_fridge.is_empty()).is_true()


func test_a_recipe_with_an_unowned_appliance_refuses_to_brew() -> void:
	# The acceptance of T082, part two: the Frappuccino needs the blender,
	# section 15. Without it the plan names the appliance, START stays dead,
	# and no minigame opens.
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	assert_bool(stand.start_button.disabled).is_true()
	assert_str(stand.plan_label.text).contains(NEEDS_BLENDER_TEXT)

	stand.begin_selected_brew()
	assert_object(stand.grind_dial()).is_null()
	assert_int(stand.phase()).is_equal(BrewStandView.Phase.MENU)
	assert_bool(_city.player.is_input_locked()).is_true()

	# The scavenged blender opens the brew, and the toast gate lifts.
	_city.player.inventory.add(BLENDER_ITEM, 1)
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	assert_bool(stand.start_button.disabled).is_false()
	assert_bool(stand.plan_label.text.contains(NEEDS_BLENDER_TEXT)).is_false()
	stand.close()
	await get_tree().process_frame


func test_each_stand_brew_spends_the_chosen_bean_from_the_bag() -> void:
	# The acceptance of T082, part one: a brew of a bag bean takes one unit
	# out of the bag, section 7. Two house beans in, one brew, one bean left.
	_spend_one_cup()
	_city.player.inventory.add(HOUSE_BEAN_ITEM, 2)
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("super_tall_american"))
	assert_int(stand.bean_options(LIBRARY.find_recipe("super_tall_american")).size()).is_equal(1)
	stand.begin_selected_brew()
	_stop_the_dial_on_target(stand)
	await _finish_the_pour(stand)

	assert_object(_city.brew_pot.stand()).is_null()
	assert_int(_city.player.inventory.count("house")).is_equal(1)
	assert_str(_city.player.brew_hand.active_payload().bean.bean_id).is_equal("house")
	# The second brew of the same stack spends the next unit.
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var second := _city.brew_pot.stand()
	second.select_recipe(LIBRARY.find_recipe("super_tall_american"))
	second.begin_selected_brew()
	_stop_the_dial_on_target(second)
	await _finish_the_pour(second)
	assert_int(_city.player.inventory.count("house")).is_equal(0)


func test_the_cafe_stock_brew_stays_free_on_an_empty_bag() -> void:
	# The stand keeps its own jar of the common bean, T066: an empty bag
	# still brews the house stock, and no bean is spent.
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("super_tall_american"))
	stand.begin_selected_brew()
	_stop_the_dial_on_target(stand)
	await _finish_the_pour(stand)
	assert_int(_city.player.inventory.count("house")).is_equal(0)
	assert_str(_city.player.brew_hand.active_payload().bean.bean_id).is_equal("house")


func test_the_roast_choice_rides_the_brewed_cup() -> void:
	# Section 8: different roast levels give different coffees. The open
	# roast of the frappuccino takes the choice of the player.
	_spend_one_cup()
	_city.player.inventory.add(BLENDER_ITEM, 1)
	_city.player.brewing_skills.load_state({"filter": 10})
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	assert_int(stand.roast_options(LIBRARY.find_recipe("frappuccino")).size()).is_equal(3)
	stand.select_roast(LIBRARY.find_roast("dark"))
	assert_str(stand.selected_roast().roast_id).is_equal("dark")

	stand.begin_auto_brew()
	await get_tree().process_frame
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.roast.roast_id).is_equal("dark")
	assert_str(payload.matched_recipe(LIBRARY).recipe_id).is_equal("frappuccino")


func test_the_roast_picker_names_the_wake_power() -> void:
	# The acceptance of T111: the point of choice teaches section 15. Every
	# roast button names its wake power, and the board hint states the fact
	# and the roasts strong enough for the sleeper the recipe cures.
	_spend_one_cup()
	_city.player.inventory.add(BLENDER_ITEM, 1)
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	var labels: Array[String] = []
	for child: Node in stand.roast_row.get_children():
		var button := child as Button
		if button != null:
			labels.append(button.text)
	assert_int(labels.size()).is_equal(3)
	assert_str(labels[0]).is_equal("LIGHT ROAST - WAKE 100")
	assert_str(labels[1]).is_equal("MEDIUM ROAST - WAKE 80")
	assert_str(labels[2]).is_equal("DARK ROAST - WAKE 60")
	assert_str(stand.hint_label.text).starts_with(BrewFlow.ROAST_FACT_TEXT)
	assert_str(stand.hint_label.text).contains("WAKES THE TOURIST: LIGHT OR MEDIUM ROAST.")

	# A pinned roast offers no choice, so the roast row stays empty and the
	# board hint falls back to the generic instruction.
	stand.select_recipe(LIBRARY.find_recipe("super_tall_american"))
	assert_int(stand.roast_row.get_child_count()).is_equal(0)
	assert_str(stand.hint_label.text).is_equal(BrewStandView.HINT_TEXT)

	# BACK returns the board to the generic hint of the menu.
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	stand.back_button.pressed.emit()
	assert_str(stand.hint_label.text).is_equal(BrewStandView.HINT_TEXT)
	stand.close()
	await get_tree().process_frame


func test_a_geisha_brew_pays_the_sleep_jam_cure_bean() -> void:
	# The T082 headline: the Geisha Vault beans from the T074 locked rooms
	# now turn into BrewedCup payloads one bean at a time, and the payload
	# is the T031 Sleep Jam boss cure.
	_spend_one_cup()
	_city.player.inventory.add(GEISHA_BEAN_ITEM, 3)
	_city.player.brewing_skills.load_state({"filter": 10})
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("geisha_vault_cup"))
	assert_bool(stand.start_button.disabled).is_false()

	stand.begin_auto_brew()
	await get_tree().process_frame
	assert_int(_city.player.inventory.count("geisha_vault")).is_equal(2)
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.bean.bean_id).is_equal("geisha_vault")
	(
		assert_bool(
			BossCure.accepted(
				payload, LIBRARY.find_recipe("geisha_vault_cup"), _city.player.brewing_balance
			)
		)
		. is_true()
	)


func test_a_frappuccino_brew_reaches_the_live_throw_and_wakes_a_tourist() -> void:
	# The acceptance of T066: the minigames brew a real payload, the live
	# throw carries it, and a special sleeper wakes from it in normal play.
	# The brew rides the scavenged blender, section 15.
	_spend_one_cup()
	_city.player.inventory.add(BLENDER_ITEM, 1)
	var tourist := _park_a_frozen_tourist()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("frappuccino"))
	stand.begin_selected_brew()
	_stop_the_dial_on_target(stand)
	assert_object(stand.pour_view()).is_not_null()

	await _finish_the_pour(stand)
	assert_object(_city.brew_pot.stand()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()

	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("filter")
	assert_str(payload.roast.roast_id).is_equal("medium")
	assert_str(payload.extra_id).is_equal("whipped_cream")
	assert_float(payload.score).is_equal(100.0)
	assert_str(_city.hud.toast_message()).is_equal("FRAPPUCCINO BREWED. SCORE 100.")
	# A perfect brew trains +2 skill, section 14.
	assert_int(_city.player.brewing_skills.skill("filter")).is_equal(2)

	var cup := _city.player.throw_cup(Vector2.RIGHT)
	assert_object(cup).is_not_null()
	assert_str(cup.brewed.extra_id).is_equal("whipped_cream")
	var frames := 0
	while tourist.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(tourist.state).is_equal(Sleepwalker.State.AWAKE)

	# The brewed cup spent itself: the next throw pours the plain pot again.
	assert_int(_city.player.brew_hand.cups_left()).is_equal(0)
	var plain_cup := _city.player.throw_cup(Vector2.RIGHT)
	assert_str(plain_cup.brewed.extra_id).is_equal("")
	assert_float(plain_cup.brewed.score).is_equal(_city.player.brewing_balance.standard_cup_score)


func test_a_ristretto_brew_runs_the_press_after_the_dial() -> void:
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("ristretto"))
	stand.begin_selected_brew()
	_stop_the_dial_on_target(stand)
	var view := stand.press_view()
	assert_object(view).is_not_null()

	# Chase the hold like a player: pump the needle under the creeping zone
	# until the pull opens, then ride the pressure up to the mark and lift.
	var shot := view.model
	var frames := 0
	while shot.step == PressShot.Step.HOLD and frames < MAX_FRAMES_TO_WAIT:
		view.held = shot.pressure < shot.zone_center
		await get_tree().process_frame
		frames += 1
	frames = 0
	while (
		shot.is_running()
		and shot.pressure < view.balance.release_mark_pressure - 0.03
		and frames < MAX_FRAMES_TO_WAIT
	):
		view.held = true
		await get_tree().process_frame
		frames += 1
	view.held = false
	while shot.is_running() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame

	assert_object(_city.brew_pot.stand()).is_null()
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("espresso")
	assert_str(payload.roast.roast_id).is_equal("light")
	assert_str(payload.extra_id).is_equal("short_pull")
	assert_int(shot.result.outcome).is_equal(PressResult.Outcome.PRESSED)
	assert_float(payload.score).is_equal(shot.result.score)


func test_a_turkish_brew_runs_the_foam_watch_after_the_dial() -> void:
	# The Turkish cure needs the scavenged Turkish pot, section 15: the plan
	# names it until the bag holds it.
	_spend_one_cup()
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("turkish_cup"))
	assert_bool(stand.start_button.disabled).is_true()
	assert_str(stand.plan_label.text).contains(NEEDS_TURKISH_POT_TEXT)

	_city.player.inventory.add(TURKISH_POT_ITEM, 1)
	stand.select_recipe(LIBRARY.find_recipe("turkish_cup"))
	assert_bool(stand.start_button.disabled).is_false()
	stand.begin_selected_brew()
	_stop_the_dial_on_target(stand)
	assert_object(stand.foam_view()).is_not_null()

	stand.foam_view().request_lift()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_object(_city.brew_pot.stand()).is_null()
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("turkish")
	assert_str(payload.roast.roast_id).is_equal("medium")
	assert_str(payload.bean.bean_id).is_equal("house")
	assert_float(payload.score).is_less(_city.player.brewing_balance.good_tier_min_score)


func test_auto_brew_skips_the_minigames_at_skill_ten() -> void:
	_spend_one_cup()
	_city.player.brewing_skills.load_state({"filter": 10})
	_city._unhandled_input(_key(KEY_B))
	var stand := _city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("super_tall_american"))
	assert_bool(stand.get_node(^"Board/PlanPanel/ButtonsRow/AutoButton").visible).is_true()

	stand.begin_auto_brew()
	await get_tree().process_frame
	assert_object(_city.brew_pot.stand()).is_null()
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("filter")
	assert_str(payload.extra_id).is_equal("tall_size")
	assert_float(payload.score).is_equal(_city.player.brewing_balance.auto_brew_score)
	assert_int(_city.player.brewing_skills.skill("filter")).is_equal(10)
	assert_int(_city.player.brew_hand.active_payload().tier(_city.player.brewing_balance)).is_equal(
		CupTier.Tier.GOOD
	)
	# An auto-brew off the empty bag rides the free cafe stock jar.
	assert_int(_city.player.inventory.count("house")).is_equal(0)


func test_the_tutorial_owns_the_brew_key_while_it_runs() -> void:
	var intro := INTRO_SCENE.instantiate() as CityRun
	add_child(auto_free(intro))
	await get_tree().physics_frame
	await get_tree().physics_frame

	intro._unhandled_input(_key(KEY_B))
	assert_object(intro.brew_pot.stand()).is_null()


func _spend_one_cup() -> void:
	# The player starts with a full hand; one throw into the west empties a
	# cup and leaves room for the brewed one.
	_park_the_crowd_west()
	_city.player.throw_cup(Vector2.LEFT)


func _park_the_crowd_west() -> void:
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)


func _park_a_frozen_tourist() -> Sleepwalker:
	# One frozen Tourist straight east of the player: the aim cone cannot
	# miss it and nothing else stands in the lane.
	_park_the_crowd_west()
	for i: int in range(_city.crowd_count()):
		var walker := _city.crowd_enemy(i)
		if walker.enemy_type.type_id == "tourist":
			walker.set_physics_process(false)
			walker.velocity = Vector2.ZERO
			walker.global_position = _city.player.global_position + Vector2(150.0, 0.0)
			return walker
	return null


func _stop_the_dial_on_target(stand: BrewStandView) -> void:
	# Stop the marker in the middle of the method zone: a clean grind.
	var dial := stand.grind_dial()
	dial.model.position = (dial.model.zone_start() + dial.model.zone_end()) * 0.5
	dial.request_stop()


func _finish_the_pour(stand: BrewStandView) -> void:
	# Runs The Pour to its end like a player: a steady pour rate, then the
	# wait for the bloom to finish. The helper contains an await, so every
	# caller awaits it.
	stand.pour_view().pour_rate = 0.7
	# The model is a RefCounted: the local keeps it alive past the view's
	# teardown, so the wait never touches a freed node.
	var bloom := stand.pour_view().model
	var frames := 0
	while bloom.is_running() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame


func _row_text(stand: BrewStandView, row_start: String) -> String:
	for column: VBoxContainer in [
		stand.get_node(^"Board/Columns/LeftColumn"), stand.get_node(^"Board/Columns/RightColumn")
	]:
		for child: Node in column.get_children():
			var row := child as Button
			if row != null and row.text.begins_with(row_start):
				return row.text
	return ""


func _full_limit() -> int:
	return _city.player.coffee_supply.carry_limit()


func _key(code: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key
