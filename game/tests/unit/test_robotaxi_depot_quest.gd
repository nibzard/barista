# ABOUTME: Unit tests for the pure RobotaxiDepotQuest state machine, T033.
# ABOUTME: Pins the order match, the tier-led wake rule, and the fast travel
# ABOUTME: unlock of section 13, plus the save round trip.
extends GdUnitTestSuite

const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BREWING_BALANCE := preload("res://resources/brewing/brewing_balance.tres")
const ORDER := preload("res://resources/brewing/recipes/robotaxi_engineer_order.tres")

var _woke_count: Array[int] = []


func before_test() -> void:
	# GdUnit reuses one suite instance, so the counter resets per case.
	_woke_count.clear()


func test_the_depot_starts_asleep_and_the_fleet_hauls() -> void:
	var quest := _quest()
	assert_int(quest.phase()).is_equal(RobotaxiDepotQuest.Phase.DEPOT_ASLEEP)
	assert_bool(quest.fleet_delivers_sleepwalkers()).is_true()
	assert_bool(quest.is_fast_travel_unlocked()).is_false()


func test_the_order_match_wakes_the_engineer_and_unlocks_fast_travel() -> void:
	# The acceptance rule of the task: the order match wakes him, the fleet
	# re-routes, and the taxis turn into fast travel.
	var quest := _quest()
	quest.engineer_woke.connect(func() -> void: _woke_count.append(1))
	var order_cup := _cup("house", "medium", "espresso", "oat_cortado_31", 85.0)
	assert_bool(quest.receive_cup(order_cup)).is_true()
	assert_int(quest.phase()).is_equal(RobotaxiDepotQuest.Phase.FLEET_ROUTED)
	assert_bool(quest.fleet_delivers_sleepwalkers()).is_false()
	assert_bool(quest.is_fast_travel_unlocked()).is_true()
	assert_int(_woke_count.size()).is_equal(1)


func test_a_perfect_cup_wakes_him_from_any_brew() -> void:
	# The shared tier rule of the bosses, section 15: a perfect cup wakes
	# anyone, even far off the order.
	var quest := _quest()
	var perfect := _cup("house", "dark", "filter", "", 96.0)
	assert_bool(quest.receive_cup(perfect)).is_true()
	assert_bool(quest.is_fast_travel_unlocked()).is_true()


func test_weak_and_wrong_cups_never_wake_him() -> void:
	# A weak cup wakes nobody, and between the tiers only the order itself
	# works: the cafe standard, a plain espresso, and the right build at the
	# wrong milk all bounce off.
	var quest := _quest()
	quest.engineer_woke.connect(func() -> void: _woke_count.append(1))
	assert_bool(quest.receive_cup(_cup("house", "medium", "filter", "", 85.0))).is_false()
	assert_bool(quest.receive_cup(_cup("house", "medium", "espresso", "", 85.0))).is_false()
	(
		assert_bool(quest.receive_cup(_cup("house", "medium", "espresso", "three_shots", 85.0)))
		. is_false()
	)
	(
		assert_bool(quest.receive_cup(_cup("house", "light", "espresso", "oat_cortado_31", 79.0)))
		. is_false()
	)
	assert_int(quest.phase()).is_equal(RobotaxiDepotQuest.Phase.DEPOT_ASLEEP)
	assert_int(_woke_count.size()).is_equal(0)


func test_a_second_cup_after_the_wake_changes_nothing() -> void:
	var quest := _quest()
	quest.engineer_woke.connect(func() -> void: _woke_count.append(1))
	(
		assert_bool(quest.receive_cup(_cup("house", "medium", "espresso", "oat_cortado_31", 85.0)))
		. is_true()
	)
	(
		assert_bool(quest.receive_cup(_cup("house", "medium", "espresso", "oat_cortado_31", 85.0)))
		. is_false()
	)
	assert_int(_woke_count.size()).is_equal(1)
	assert_bool(quest.is_fast_travel_unlocked()).is_true()


func test_save_and_load_round_trip_without_a_replay() -> void:
	# The save holds the phase as one plain number, and a loaded quest never
	# replays the wake beat.
	var quest := _quest()
	quest.engineer_woke.connect(func() -> void: _woke_count.append(1))
	var asleep_save := quest.save_state()
	assert_int(int(asleep_save["phase"])).is_equal(RobotaxiDepotQuest.Phase.DEPOT_ASLEEP)
	(
		assert_bool(quest.receive_cup(_cup("house", "medium", "espresso", "oat_cortado_31", 85.0)))
		. is_true()
	)

	quest.load_state(asleep_save)
	assert_int(quest.phase()).is_equal(RobotaxiDepotQuest.Phase.DEPOT_ASLEEP)
	assert_int(_woke_count.size()).is_equal(1)

	var fresh := _quest()
	fresh.engineer_woke.connect(func() -> void: _woke_count.append(1))
	fresh.load_state({"phase": RobotaxiDepotQuest.Phase.FLEET_ROUTED})
	assert_bool(fresh.is_fast_travel_unlocked()).is_true()
	assert_int(_woke_count.size()).is_equal(1)

	fresh.load_state({"phase": 99})
	assert_int(fresh.phase()).is_equal(RobotaxiDepotQuest.Phase.DEPOT_ASLEEP)


func test_the_order_recipe_pins_the_code_like_request() -> void:
	# Section 13: the order is a triple shot oat cortado with milk at exactly
	# 31 degrees. The recipe pins the espresso base and the oat-cortado extra
	# and leaves bean and roast open, because the code names neither.
	assert_str(ORDER.recipe_id).is_equal("robotaxi_engineer_order")
	assert_str(ORDER.display_name).is_equal("The Engineer's Order")
	assert_int(ORDER.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(ORDER.method_id).is_equal("espresso")
	assert_str(ORDER.extra_id).is_equal("oat_cortado_31")
	assert_int(ORDER.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(ORDER.roast_match).is_equal(Recipe.Match.ANY)
	assert_str(ORDER.required_appliance).is_equal("")
	assert_object(LIBRARY.find_extra("oat_cortado_31")).is_not_null()
	assert_object(LIBRARY.find_recipe("robotaxi_engineer_order")).is_not_null()


func _quest() -> RobotaxiDepotQuest:
	return RobotaxiDepotQuest.new(ORDER, BREWING_BALANCE)


func _cup(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
