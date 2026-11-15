# ABOUTME: Unit tests for the main quest chain: city, tower, boss, and the
# ABOUTME: unlock of the next city. Pure logic: no scene nodes.
extends GdUnitTestSuite


func _route() -> Array[String]:
	return ["san_coffesco", "steamtle", "pourtland"]


func _chain(start_city := "") -> MainQuest:
	var chain := MainQuest.new()
	assert_bool(chain.setup(_route(), start_city)).is_true()
	return chain


func _counts(chain: MainQuest) -> Dictionary:
	var counts := {
		"entered": 0,
		"completed": 0,
		"unlocked": 0,
		"objective": 0,
	}
	chain.city_entered.connect(func(_city_id: String) -> void: counts["entered"] += 1)
	chain.city_completed.connect(func(_city_id: String) -> void: counts["completed"] += 1)
	chain.next_city_unlocked.connect(func(_city_id: String) -> void: counts["unlocked"] += 1)
	chain.objective_changed.connect(func(_objective: int) -> void: counts["objective"] += 1)
	return counts


func test_the_chain_starts_in_the_first_city() -> void:
	var chain := _chain()
	assert_str(chain.current_city()).is_equal("san_coffesco")
	assert_int(chain.route_size()).is_equal(3)
	assert_bool(chain.is_on_route("pourtland")).is_true()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.TOWER)


func test_the_chain_can_start_in_a_later_city() -> void:
	var chain := _chain("steamtle")
	assert_str(chain.current_city()).is_equal("steamtle")
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.TOWER)


func test_an_empty_route_fails_the_setup() -> void:
	var chain := MainQuest.new()
	var empty_route: Array[String] = []
	assert_bool(chain.setup(empty_route)).is_false()
	assert_str(chain.current_city()).is_equal("")


func test_a_repeated_city_fails_the_setup() -> void:
	var chain := MainQuest.new()
	assert_bool(chain.setup(["san_coffesco", "san_coffesco"])).is_false()
	assert_str(chain.current_city()).is_equal("")


func test_an_unknown_start_city_fails_the_setup() -> void:
	var chain := MainQuest.new()
	assert_bool(chain.setup(_route(), "brewcago")).is_false()
	assert_str(chain.current_city()).is_equal("")


func test_the_tower_beat_moves_the_objective_to_the_boss() -> void:
	var chain := _chain()
	var counts := _counts(chain)
	var objectives: Array[int] = []
	chain.objective_changed.connect(func(objective: int) -> void: objectives.append(objective))

	assert_bool(chain.mark_tower_off()).is_true()
	assert_bool(chain.is_tower_off("san_coffesco")).is_true()
	assert_bool(chain.is_city_complete("san_coffesco")).is_false()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.BOSS)
	assert_int(objectives.size()).is_equal(1)
	assert_int(objectives[0]).is_equal(MainQuest.Objective.BOSS)
	assert_int(counts["completed"]).is_equal(0)
	assert_int(counts["unlocked"]).is_equal(0)


func test_the_boss_beat_alone_keeps_the_tower_objective() -> void:
	var chain := _chain()
	var counts := _counts(chain)

	assert_bool(chain.mark_boss_cured()).is_true()
	assert_bool(chain.is_boss_cured("san_coffesco")).is_true()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.TOWER)
	assert_int(counts["objective"]).is_equal(0)


func test_both_beats_complete_the_city_once() -> void:
	var chain := _chain()
	var counts := _counts(chain)
	var completed: Array[String] = []
	var unlocked: Array[String] = []
	chain.city_completed.connect(func(city_id: String) -> void: completed.append(city_id))
	chain.next_city_unlocked.connect(func(city_id: String) -> void: unlocked.append(city_id))

	chain.mark_tower_off()
	chain.mark_boss_cured()

	assert_bool(chain.is_city_complete("san_coffesco")).is_true()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	assert_int(counts["completed"]).is_equal(1)
	assert_int(completed.size()).is_equal(1)
	assert_str(completed[0]).is_equal("san_coffesco")
	assert_int(unlocked.size()).is_equal(1)
	assert_str(unlocked[0]).is_equal("steamtle")


func test_the_beats_complete_the_city_in_either_order() -> void:
	var chain := _chain()
	chain.mark_boss_cured()
	chain.mark_tower_off()
	assert_bool(chain.is_city_complete("san_coffesco")).is_true()


func test_repeated_marks_stay_silent() -> void:
	var chain := _chain()
	chain.mark_tower_off()
	chain.mark_boss_cured()
	var counts := _counts(chain)

	chain.mark_tower_off()
	chain.mark_boss_cured()

	assert_int(counts["completed"]).is_equal(0)
	assert_int(counts["unlocked"]).is_equal(0)
	assert_int(counts["objective"]).is_equal(0)


func test_marks_for_unknown_cities_are_refused() -> void:
	var chain := _chain()
	var counts := _counts(chain)

	assert_bool(chain.mark_tower_off("brewcago")).is_false()
	assert_bool(chain.mark_boss_cured("brewcago")).is_false()
	assert_bool(chain.is_tower_off("brewcago")).is_false()
	assert_int(counts["completed"]).is_equal(0)
	assert_int(counts["objective"]).is_equal(0)


func test_a_beat_can_target_a_later_city_on_the_route() -> void:
	var chain := _chain()
	var counts := _counts(chain)

	assert_bool(chain.mark_tower_off("pourtland")).is_true()
	assert_bool(chain.is_tower_off("pourtland")).is_true()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.TOWER)
	assert_int(counts["objective"]).is_equal(0)


func test_the_first_city_stands_open_and_the_rest_wait() -> void:
	var chain := _chain()
	assert_bool(chain.is_city_unlocked("san_coffesco")).is_true()
	assert_bool(chain.is_city_unlocked("steamtle")).is_false()
	assert_bool(chain.is_city_unlocked("pourtland")).is_false()
	assert_bool(chain.is_city_unlocked("brewcago")).is_false()


func test_a_completed_city_unlocks_only_the_next_one() -> void:
	var chain := _chain()
	chain.mark_tower_off()
	chain.mark_boss_cured()

	assert_bool(chain.is_city_unlocked("steamtle")).is_true()
	assert_bool(chain.is_city_unlocked("pourtland")).is_false()
	assert_str(chain.next_city()).is_equal("steamtle")


func test_travel_east_needs_the_unlock() -> void:
	var chain := _chain()
	var counts := _counts(chain)

	assert_bool(chain.travel_east()).is_false()
	assert_str(chain.current_city()).is_equal("san_coffesco")
	assert_int(counts["entered"]).is_equal(0)


func test_travel_east_locks_in_the_arrival() -> void:
	var chain := _chain()
	chain.mark_tower_off()
	chain.mark_boss_cured()
	var counts := _counts(chain)
	var entered: Array[String] = []
	chain.city_entered.connect(func(city_id: String) -> void: entered.append(city_id))

	assert_bool(chain.travel_east()).is_true()
	assert_str(chain.current_city()).is_equal("steamtle")
	assert_str(chain.next_city()).is_equal("pourtland")
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.TOWER)
	assert_int(entered.size()).is_equal(1)
	assert_str(entered[0]).is_equal("steamtle")
	# The arrival resets the objective signal path: tower first again.
	chain.mark_tower_off()
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.BOSS)


func test_travel_east_fails_at_the_route_end() -> void:
	var chain := _chain("pourtland")
	chain.mark_tower_off("pourtland")
	chain.mark_boss_cured("pourtland")
	var counts := _counts(chain)

	assert_str(chain.next_city()).is_equal("")
	assert_bool(chain.travel_east()).is_false()
	assert_str(chain.current_city()).is_equal("pourtland")
	assert_int(counts["entered"]).is_equal(0)


func test_save_round_trip_carries_the_chain_mid_route() -> void:
	var chain := _chain()
	chain.mark_tower_off("san_coffesco")
	chain.mark_boss_cured("san_coffesco")
	chain.travel_east()

	var loaded := _chain("steamtle")
	var counts := _counts(loaded)
	loaded.load_state(chain.save_state())

	assert_str(loaded.current_city()).is_equal("steamtle")
	assert_bool(loaded.is_city_complete("san_coffesco")).is_true()
	assert_bool(loaded.is_city_complete("steamtle")).is_false()
	assert_int(loaded.current_objective()).is_equal(MainQuest.Objective.TOWER)
	assert_int(counts["completed"]).is_equal(0)
	assert_int(counts["unlocked"]).is_equal(0)

	loaded.mark_tower_off()
	loaded.mark_boss_cured()
	assert_int(counts["completed"]).is_equal(1)
	assert_int(counts["unlocked"]).is_equal(1)


func test_load_of_a_completed_city_never_replays_the_beat() -> void:
	var chain := _chain()
	chain.mark_tower_off()
	chain.mark_boss_cured()

	var loaded := _chain()
	var counts := _counts(loaded)
	loaded.load_state(chain.save_state())

	assert_bool(loaded.is_city_complete("san_coffesco")).is_true()
	assert_bool(loaded.is_city_unlocked("steamtle")).is_true()
	assert_int(counts["completed"]).is_equal(0)
	assert_int(counts["unlocked"]).is_equal(0)
	assert_int(counts["objective"]).is_equal(0)


func test_load_clamps_a_broken_route_position() -> void:
	var chain := _chain()
	var saved := chain.save_state()
	saved["current"] = 99

	chain.load_state(saved)
	assert_str(chain.current_city()).is_equal("san_coffesco")
