# ABOUTME: Integration tests for the Robotaxi Depot side quest of San
# ABOUTME: Coffesco, T033. Proves the order match and the wake of the routing
# ABOUTME: engineer, the sleepwalker hauls of the sleeping fleet, and the fast
# ABOUTME: travel reward of section 13.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")

const MAX_FRAMES_TO_WAIT := 600

var _city: CityRun
var _stage: RobotaxiDepotStage
var _deliveries: Array[int] = []


func before_test() -> void:
	# GdUnit reuses one suite instance, so the counters reset here.
	_deliveries.clear()
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_stage = _city.signature_quest as RobotaxiDepotStage
	_stage.cab().passenger_delivered.connect(
		func(_passenger: Sleepwalker) -> void: _deliveries.append(1)
	)


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak a pressed key.
	Input.action_release(&"move_right")


func test_the_depot_builds_its_control_room_engineer_and_stands() -> void:
	# Section 13: the routing engineer sleeps in the depot control room, his
	# order written like code, and the robotaxi stands wait at the cafe, the
	# depot, and the tower.
	assert_object(_stage).is_not_null()
	var quest_block := _city.city_map().find_block_of_kind(CityBlock.Kind.QUEST)
	var expected_depot := (
		quest_block.global_position + quest_block.size * RobotaxiDepotStage.CONTROL_ROOM_FRACTION
	)
	assert_vector(_stage.depot_position()).is_equal(expected_depot)
	var engineer := _stage.engineer()
	assert_object(engineer).is_not_null()
	assert_bool(engineer.is_awake()).is_false()
	assert_vector(engineer.global_position).is_equal(expected_depot)
	assert_str(engineer.get_node(^"LineLabel").text).is_equal(
		(
			"THE ROUTING ENGINEER\nwhile (asleep) { serve(order); }\n"
			+ 'order = {shots: 3, style: "cortado", milk: "oat", temp_c: 31}'
		)
	)
	var cab := _stage.cab()
	assert_object(cab).is_not_null()
	assert_bool(cab.is_retired()).is_false()
	assert_int(cab.state()).is_equal(RobotaxiCab.CabState.PARKED)
	var stands := _stage.stands()
	assert_int(stands.size()).is_equal(3)
	for i: int in range(stands.size()):
		assert_str(stands[i].stand_name).is_equal(RobotaxiDepotStage.STAND_NAMES[i])
		var block := _city.city_map().find_block_of_kind(RobotaxiDepotStage.STAND_KINDS[i])
		assert_vector(stands[i].global_position).is_equal(
			block.global_position + block.size * Vector2(0.14, 0.62)
		)
	# The quest balance pins its .tres values, like every tuned quest.
	assert_float(_stage.balance.cab_speed).is_equal(260.0)
	assert_float(_stage.balance.pickup_radius).is_equal(42.0)
	assert_float(_stage.balance.delivery_radius).is_equal(130.0)
	assert_float(_stage.balance.delivery_cooldown).is_equal(6.0)
	assert_float(_stage.balance.first_ride_delay).is_equal(3.0)
	assert_float(_stage.balance.pickup_min_player_distance).is_equal(200.0)
	assert_float(_stage.balance.stand_notice_radius).is_equal(120.0)
	assert_float(_stage.balance.depot_notice_radius).is_equal(160.0)


func test_walking_into_the_depot_accepts_the_quest() -> void:
	# The player reads the order on the wall: the side quest turns active and
	# its marker dot lands on the depot landmark.
	var quest := _city.quest_log.quest("robotaxi_depot")
	assert_bool(quest.is_offered()).is_true()
	var quest_block := _city.city_map().find_block_of_kind(CityBlock.Kind.QUEST)
	_city.player.global_position = _stage.engineer().global_position
	await _await_frames(4)
	assert_bool(quest.is_active()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(RobotaxiDepotStage.ACCEPT_TOAST)
	# The marker dot of the active quest anchors on the depot landmark,
	# because the quest data names no site of its own.
	var markers := _city.quest_markers().side_marker_positions()
	assert_int(markers.size()).is_equal(1)
	assert_vector(markers[0]).is_equal(quest_block.global_position + quest_block.size * 0.5)


func test_wrong_cups_bounce_and_the_order_wakes_the_engineer() -> void:
	# The acceptance path: the cafe standard, a plain espresso, and a weak
	# order cup all bounce off; the brewed order wakes him, the fleet
	# re-routes, and the side quest completes into fast travel.
	await _accept_the_quest()
	var engineer := _stage.engineer()
	assert_bool(engineer.try_wake(_cup("house", "medium", "filter", "", 85.0))).is_false()
	assert_bool(engineer.try_wake(_cup("house", "medium", "espresso", "", 85.0))).is_false()
	(
		assert_bool(engineer.try_wake(_cup("house", "medium", "espresso", "three_shots", 85.0)))
		. is_false()
	)
	(
		assert_bool(engineer.try_wake(_cup("house", "medium", "espresso", "oat_cortado_31", 79.0)))
		. is_false()
	)
	assert_bool(engineer.is_awake()).is_false()

	assert_bool(engineer.try_wake(_order_cup())).is_true()
	assert_bool(engineer.is_awake()).is_true()
	assert_bool(_stage.quest.is_fast_travel_unlocked()).is_true()
	assert_bool(_stage.cab().is_retired()).is_true()
	assert_bool(_city.quest_log.quest("robotaxi_depot").is_complete()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(RobotaxiDepotStage.WAKE_TOAST)
	assert_str(engineer.get_node(^"LineLabel").text).is_equal(RobotaxiDepotStage.WAKE_LINE)


func test_a_thrown_order_cup_wakes_the_engineer() -> void:
	# The throw works too: a brewed order cup from the hand lands on him
	# through the same quest rule.
	await _accept_the_quest()
	var engineer := _stage.engineer()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = engineer.global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _order_cup()
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(engineer.is_awake()).is_true()
	assert_bool(_stage.quest.is_fast_travel_unlocked()).is_true()


func test_the_fleet_hauls_a_sleepwalker_to_the_player() -> void:
	# The premise of the quest, section 13: while the engineer sleeps, the
	# taxis pick up sleepwalkers and deliver them to the player, asleep and
	# ready for the cup.
	await _accept_the_quest()
	var passenger := _sole_sleeping_walker()
	passenger.global_position = _stage.depot_position() + Vector2(400.0, 0.0)
	await _await_frames(2)

	var frames := 0
	while _deliveries.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(_stage.cab().state()).is_equal(RobotaxiCab.CabState.PARKED)
	assert_object(_stage.cab().passenger()).is_null()
	assert_bool(passenger.is_awake()).is_false()
	assert_float(passenger.global_position.distance_to(_city.player.global_position)).is_less(170.0)


func test_the_fleet_holds_back_while_the_player_stays_at_the_cafe() -> void:
	# The cafe street stays off the hauling route: with the player at the
	# cafe, no ride starts, awake quest or not.
	var passenger := _sole_sleeping_walker()
	passenger.global_position = _stage.depot_position() + Vector2(400.0, 0.0)
	await _await_frames(2)
	_city.player.global_position = _stage.engineer().global_position
	await _await_frames(4)
	assert_bool(_city.quest_log.quest("robotaxi_depot").is_active()).is_true()
	_city.player.global_position = _city.city_map().cafe_spawn().global_position
	await _await_frames(120)

	assert_int(_deliveries.size()).is_equal(0)
	assert_int(_stage.cab().state()).is_equal(RobotaxiCab.CabState.PARKED)
	assert_float(passenger.global_position.distance_to(_city.player.global_position)).is_greater(
		500.0
	)


func test_the_stands_stay_locked_until_the_engineer_wakes() -> void:
	# Before the reward, a locked stand keeps the key free: the press
	# declines, opens no board, and leaves the key to the van or the field
	# base, because the van can park beside any stand.
	await _accept_the_quest()
	_city.player.global_position = _stage.stands()[1].global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_false()
	assert_object(_stage.ride_board()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_str(_city.hud.toast_message()).is_equal(RobotaxiDepotStage.ACCEPT_TOAST)


func test_the_ride_board_routes_the_player_between_stands() -> void:
	# The reward, section 13: the fleet re-routes and the taxis work as fast
	# travel inside the city. The board lists every stand but the one under
	# the player, and the choice teleports him to the chosen curb.
	await _wake_the_engineer()
	_city.player.global_position = _stage.stands()[1].global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_true()

	var board := _stage.ride_board()
	assert_object(board).is_not_null()
	assert_array(board.destination_indexes()).is_equal([0, 2])
	assert_bool(_stage.holds_interact()).is_true()
	assert_bool(_city.player.is_input_locked()).is_true()

	board.press_destination(2)
	assert_object(_stage.ride_board()).is_null()
	assert_bool(_stage.holds_interact()).is_false()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_vector(_city.player.global_position).is_equal(_stage.stands()[2].drop_position())
	assert_str(_city.hud.toast_message()).is_equal("THE TAXI ROUTES YOU TO THE TOWER.")


func test_the_stay_button_closes_the_board_without_a_ride() -> void:
	await _wake_the_engineer()
	_city.player.global_position = _stage.stands()[0].global_position
	await _await_frames(4)
	assert_bool(_stage.try_interact()).is_true()
	var board := _stage.ride_board()
	assert_object(board).is_not_null()

	board.press_stay()
	assert_object(_stage.ride_board()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_vector(_city.player.global_position).is_equal(_stage.stands()[0].global_position)


func test_a_completed_quest_resumes_routed_after_a_reload() -> void:
	# Section 18: the saved log holds the finished quest, so a reload resumes
	# the routed fleet: the engineer stands awake, the cab retired, and the
	# fast travel unlocked, with no wake beat replayed.
	var reloaded := CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(reloaded))
	reloaded.quest_log.accept("robotaxi_depot")
	reloaded.quest_log.complete("robotaxi_depot")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var stage := reloaded.signature_quest as RobotaxiDepotStage
	assert_bool(stage.quest.is_fast_travel_unlocked()).is_true()
	assert_bool(stage.engineer().is_awake()).is_true()
	assert_bool(stage.cab().is_retired()).is_true()
	assert_bool(reloaded.quest_log.quest("robotaxi_depot").is_complete()).is_true()
	assert_str(reloaded.hud.toast_message()).is_equal("")


func _await_frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().physics_frame


func _accept_the_quest() -> void:
	# The player walks into the depot and the quest accepts, like live play.
	_city.player.global_position = _stage.engineer().global_position
	await _await_frames(4)
	assert_bool(_city.quest_log.quest("robotaxi_depot").is_active()).is_true()


func _wake_the_engineer() -> void:
	# Drives the quest to its reward with a served order cup, the same state
	# the brewed hand reaches in live play. The quest accepts first, like
	# live play.
	await _accept_the_quest()
	assert_bool(_stage.engineer().try_wake(_order_cup())).is_true()


func _sole_sleeping_walker() -> Sleepwalker:
	# Wakes every sleeper but one Neighbor of the first street block, so the
	# haul has exactly one eligible passenger and the suite stays steady.
	var chosen := _city.crowd_enemy(3)
	for i: int in range(_city.crowd_count()):
		if i != 3:
			_city.crowd_enemy(i).wake_up()
	assert_bool(chosen.is_awake()).is_false()
	assert_int(chosen.state).is_equal(Sleepwalker.State.WANDER)
	return chosen


func _order_cup() -> BrewedCup:
	return _cup("house", "medium", "espresso", "oat_cortado_31", 85.0)


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
