# ABOUTME: Unit tests for the live cold brew fridge, per GAME_DESIGN section 8.
# ABOUTME: Start the steep, tick the play clock, come back later, collect the cup.
# ABOUTME: Pure model tests: no scene tree, no nodes.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/balance/cold_brew.tres")
const BREWING_BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const METHOD := preload("res://resources/brewing/methods/cold_brew.tres")


func test_start_steeps_the_chosen_recipe_and_bean() -> void:
	var fridge := ColdBrewFridge.new(BALANCE)
	var started: Array = []
	fridge.steep_started.connect(func(recipe_id: String) -> void: started.append(recipe_id))
	(
		assert_bool(
			fridge.start(_recipe("cold_brew_concentrate"), _bean("golden_coast_arabica"), METHOD)
		)
		. is_true()
	)
	assert_bool(fridge.is_steeping()).is_true()
	assert_bool(fridge.is_ready()).is_false()
	assert_bool(fridge.is_empty()).is_false()
	assert_str(fridge.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")
	assert_str(fridge.steeped_bean().bean_id).is_equal("golden_coast_arabica")
	assert_int(started.size()).is_equal(1)
	assert_str(started[0]).is_equal("cold_brew_concentrate")


func test_start_refuses_empty_hands() -> void:
	var fridge := ColdBrewFridge.new(BALANCE)
	assert_bool(fridge.start(null, _bean("house"), METHOD)).is_false()
	assert_bool(fridge.start(_recipe("cold_brew_concentrate"), null, METHOD)).is_false()
	assert_bool(fridge.start(_recipe("cold_brew_concentrate"), _bean("house"), null)).is_false()
	assert_bool(fridge.is_empty()).is_true()


func test_one_fridge_holds_one_steep() -> void:
	# A second start lands only after the cup leaves the fridge.
	var fridge := _steeping_fridge()
	assert_bool(fridge.start(_recipe("protein_cold_brew"), _bean("house"), METHOD)).is_false()
	_finish_the_steep(fridge)
	assert_bool(fridge.is_ready()).is_true()
	assert_bool(fridge.start(_recipe("protein_cold_brew"), _bean("house"), METHOD)).is_false()
	fridge.collect(LIBRARY)
	assert_bool(fridge.is_empty()).is_true()
	assert_bool(fridge.start(_recipe("protein_cold_brew"), _bean("house"), METHOD)).is_true()


func test_tick_advances_and_announces_ready_once() -> void:
	var fridge := _steeping_fridge()
	var ready: Array = []
	fridge.steep_ready.connect(func(recipe_id: String) -> void: ready.append(recipe_id))
	for _i: int in range(300):
		fridge.tick(1.0)
	assert_bool(fridge.is_ready()).is_true()
	assert_int(ready.size()).is_equal(1)
	assert_str(ready[0]).is_equal("cold_brew_concentrate")
	fridge.tick(60.0)
	assert_int(ready.size()).is_equal(1)


func test_the_fridge_tells_the_countdown() -> void:
	var fridge := _steeping_fridge()
	assert_float(fridge.steep_seconds()).is_equal(BALANCE.steep_seconds)
	assert_float(fridge.remaining_seconds()).is_equal(BALANCE.steep_seconds)
	fridge.tick(120.0)
	assert_float(fridge.remaining_seconds()).is_equal(BALANCE.steep_seconds - 120.0)


func test_an_empty_fridge_answers_the_status_queries() -> void:
	var fridge := ColdBrewFridge.new(BALANCE)
	assert_bool(fridge.is_empty()).is_true()
	assert_bool(fridge.is_steeping()).is_false()
	assert_bool(fridge.is_ready()).is_false()
	assert_float(fridge.remaining_seconds()).is_equal(0.0)
	assert_object(fridge.collect(LIBRARY)).is_null()
	fridge.tick(60.0)
	assert_bool(fridge.is_empty()).is_true()


func test_collect_before_ready_returns_nothing() -> void:
	var fridge := _steeping_fridge()
	fridge.tick(BALANCE.steep_seconds - 0.5)
	assert_object(fridge.collect(LIBRARY)).is_null()
	assert_bool(fridge.is_steeping()).is_true()


func test_collect_builds_the_ceiling_cup_and_empties_the_fridge() -> void:
	var fridge := _steeping_fridge()
	_finish_the_steep(fridge)
	var cup := fridge.collect(LIBRARY)
	assert_object(cup).is_not_null()
	assert_str(cup.method.method_id).is_equal("cold_brew")
	assert_float(cup.score).is_equal(METHOD.score_ceiling)
	assert_int(cup.tier(BREWING_BALANCE)).is_equal(CupTier.Tier.GOOD)
	assert_str(cup.bean.bean_id).is_equal("golden_coast_arabica")
	assert_int(cup.roast.kind).is_equal(RoastProfile.Kind.MEDIUM)
	assert_bool(fridge.is_empty()).is_true()
	assert_object(fridge.collect(LIBRARY)).is_null()


func test_collect_carries_the_recipe_extra() -> void:
	# The protein cold brew adds its extra to the cup payload.
	var fridge := ColdBrewFridge.new(BALANCE)
	fridge.start(_recipe("protein_cold_brew"), _bean("house"), METHOD)
	_finish_the_steep(fridge)
	var cup := fridge.collect(LIBRARY)
	assert_str(cup.extra_id).is_equal("protein_powder")
	assert_object(cup.matched_recipe(LIBRARY)).is_not_null()
	assert_str(cup.matched_recipe(LIBRARY).recipe_id).is_equal("protein_cold_brew")


func test_the_chosen_roast_kind_rides_the_collected_cup() -> void:
	# Section 8: the roast the player picked at the stand steeps in the
	# fridge and rides the collected cup, not the medium default. A start
	# without a choice keeps the cafe default of the open roast.
	var fridge := ColdBrewFridge.new(BALANCE)
	fridge.start(_recipe("cold_brew_concentrate"), _bean("house"), METHOD, RoastProfile.Kind.LIGHT)
	_finish_the_steep(fridge)
	var cup := fridge.collect(LIBRARY)
	assert_int(cup.roast.kind).is_equal(RoastProfile.Kind.LIGHT)
	# The next steep picks its own roast.
	fridge.start(_recipe("cold_brew_concentrate"), _bean("house"), METHOD, RoastProfile.Kind.DARK)
	_finish_the_steep(fridge)
	cup = fridge.collect(LIBRARY)
	assert_int(cup.roast.kind).is_equal(RoastProfile.Kind.DARK)


func test_the_steep_state_round_trips_the_chosen_roast_kind() -> void:
	# Section 18: the roast choice survives the closed app. A save from
	# before the picker holds no roast key, and a kind the library lost
	# tells no roast: both steeps brew the cafe default, never a broken cup.
	var fridge := ColdBrewFridge.new(BALANCE)
	fridge.start(_recipe("protein_cold_brew"), _bean("house"), METHOD, RoastProfile.Kind.LIGHT)
	fridge.tick(120.0)
	var loaded := ColdBrewFridge.new(BALANCE)
	loaded.load_state(fridge.save_state(), LIBRARY)
	_finish_the_steep(loaded)
	var cup := loaded.collect(LIBRARY)
	assert_int(cup.roast.kind).is_equal(RoastProfile.Kind.LIGHT)

	var legacy := ColdBrewFridge.new(BALANCE)
	legacy.load_state(
		{"recipe_id": "cold_brew_concentrate", "bean_id": "house", "elapsed": 9999.0}, LIBRARY
	)
	assert_int(legacy.collect(LIBRARY).roast.kind).is_equal(RoastProfile.Kind.MEDIUM)
	var changed := ColdBrewFridge.new(BALANCE)
	(
		changed
		. load_state(
			{
				"recipe_id": "cold_brew_concentrate",
				"bean_id": "house",
				"roast_kind": 9,
				"elapsed": 9999.0,
			},
			LIBRARY
		)
	)
	assert_int(changed.collect(LIBRARY).roast.kind).is_equal(RoastProfile.Kind.MEDIUM)


func test_save_state_round_trips_a_running_steep() -> void:
	var fridge := _steeping_fridge()
	fridge.tick(120.0)
	var loaded := ColdBrewFridge.new(BALANCE)
	var signals: Array = []
	loaded.steep_started.connect(func(_recipe_id: String) -> void: signals.append("started"))
	loaded.steep_ready.connect(func(_recipe_id: String) -> void: signals.append("ready"))
	loaded.load_state(fridge.save_state(), LIBRARY)
	assert_bool(loaded.is_steeping()).is_true()
	assert_str(loaded.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")
	assert_str(loaded.steeped_bean().bean_id).is_equal("golden_coast_arabica")
	assert_float(loaded.remaining_seconds()).is_equal(BALANCE.steep_seconds - 120.0)
	assert_int(signals.size()).is_equal(0)
	_finish_the_steep(loaded)
	var cup := loaded.collect(LIBRARY)
	assert_float(cup.score).is_equal(METHOD.score_ceiling)
	assert_str(cup.bean.bean_id).is_equal("golden_coast_arabica")


func test_load_state_completes_an_overdue_steep() -> void:
	# Come back later across a closed app: a steep that ran out is ready at
	# once, silent.
	var fridge := ColdBrewFridge.new(BALANCE)
	var signals: Array = []
	fridge.steep_started.connect(func(_recipe_id: String) -> void: signals.append("started"))
	fridge.steep_ready.connect(func(_recipe_id: String) -> void: signals.append("ready"))
	fridge.load_state(
		{"recipe_id": "cold_brew_concentrate", "bean_id": "house", "elapsed": 9999.0}, LIBRARY
	)
	assert_bool(fridge.is_ready()).is_true()
	assert_int(signals.size()).is_equal(0)
	var cup := fridge.collect(LIBRARY)
	assert_float(cup.score).is_equal(METHOD.score_ceiling)


func test_load_state_drops_unknown_ids_and_clears_on_empty() -> void:
	var fridge := _steeping_fridge()
	fridge.load_state(
		{"recipe_id": "no_such_recipe", "bean_id": "house", "elapsed": 100.0}, LIBRARY
	)
	assert_bool(fridge.is_empty()).is_true()
	fridge.load_state(
		{"recipe_id": "cold_brew_concentrate", "bean_id": "ghost", "elapsed": 100.0}, LIBRARY
	)
	assert_bool(fridge.is_empty()).is_true()
	fridge.load_state({}, LIBRARY)
	assert_bool(fridge.is_empty()).is_true()
	assert_dict(fridge.save_state()).is_empty()


func test_an_empty_fridge_saves_nothing() -> void:
	var fridge := ColdBrewFridge.new(BALANCE)
	assert_dict(fridge.save_state()).is_empty()


func _steeping_fridge() -> ColdBrewFridge:
	var fridge := ColdBrewFridge.new(BALANCE)
	fridge.start(_recipe("cold_brew_concentrate"), _bean("golden_coast_arabica"), METHOD)
	return fridge


func _finish_the_steep(fridge: ColdBrewFridge) -> void:
	fridge.tick(BALANCE.steep_seconds)


func _recipe(recipe_id: String) -> Recipe:
	return LIBRARY.find_recipe(recipe_id)


func _bean(bean_id: String) -> BeanType:
	return LIBRARY.find_bean(bean_id)
