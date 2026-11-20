# ABOUTME: Unit tests for QuestLog: the aggregate of the main chain and the
# ABOUTME: side quests, plus the save round trip. Pins the shipped route data.
extends GdUnitTestSuite

const MAIN_ROUTE := preload("res://resources/quests/main_route.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")


func _definition(city_id: String, quest_ids: Array[String]) -> CityDefinition:
	var definition := CityDefinition.new()
	definition.city_id = city_id
	for quest_id: String in quest_ids:
		var quest := SideQuestDefinition.new()
		quest.quest_id = quest_id
		quest.title = quest_id.capitalize()
		quest.city_id = city_id
		definition.side_quests.append(quest)
	return definition


func _two_city_route() -> MainRoute:
	var route := MainRoute.new()
	route.cities = [
		_definition("san_coffesco", ["robotaxi_depot"]), _definition("steamtle", ["sleepvana"])
	]
	return route


func _log() -> QuestLog:
	var log := QuestLog.new()
	assert_bool(log.setup(_two_city_route(), "san_coffesco")).is_true()
	return log


func _side_signals(log: QuestLog) -> Array[String]:
	var seen: Array[String] = []
	log.side_quest_changed.connect(
		func(quest_id: String, new_state: int) -> void: seen.append("%s:%d" % [quest_id, new_state])
	)
	return seen


func test_setup_registers_every_side_quest_of_the_route() -> void:
	var log := _log()
	assert_int(log.quest_count()).is_equal(2)
	assert_object(log.quest("robotaxi_depot")).is_not_null()
	assert_object(log.quest("sleepvana")).is_not_null()
	assert_bool(log.quest("sleepvana").is_offered()).is_true()
	assert_bool(log.is_active("sleepvana")).is_false()


func test_a_duplicate_quest_id_registers_once() -> void:
	var log := QuestLog.new()
	var route := MainRoute.new()
	route.cities = [
		_definition("san_coffesco", ["robotaxi_depot"]), _definition("steamtle", ["robotaxi_depot"])
	]
	assert_bool(log.setup(route, "san_coffesco")).is_true()
	assert_int(log.quest_count()).is_equal(1)


func test_a_route_with_no_cities_fails_the_setup() -> void:
	var log := QuestLog.new()
	assert_bool(log.setup(MainRoute.new(), "")).is_false()
	assert_int(log.quest_count()).is_equal(0)


func test_a_null_route_fails_the_setup() -> void:
	var log := QuestLog.new()
	assert_bool(log.setup(null, "")).is_false()


func test_accept_runs_through_the_log_and_reports_the_state() -> void:
	var log := _log()
	var side_signals := _side_signals(log)

	assert_bool(log.accept("robotaxi_depot")).is_true()
	assert_bool(log.is_active("robotaxi_depot")).is_true()
	assert_int(side_signals.size()).is_equal(1)
	assert_str(side_signals[0]).is_equal("robotaxi_depot:%d" % SideQuest.State.ACTIVE)


func test_complete_runs_through_the_log() -> void:
	var log := _log()
	log.accept("sleepvana")
	var side_signals := _side_signals(log)

	assert_bool(log.complete("sleepvana")).is_true()
	assert_bool(log.quest("sleepvana").is_complete()).is_true()
	assert_int(side_signals.size()).is_equal(1)
	assert_str(side_signals[0]).is_equal("sleepvana:%d" % SideQuest.State.COMPLETE)


func test_an_unknown_quest_is_refused() -> void:
	var log := _log()
	assert_bool(log.accept("moonwalker_mystery")).is_false()
	assert_bool(log.complete("moonwalker_mystery")).is_false()
	assert_object(log.quest("moonwalker_mystery")).is_null()


func test_a_quest_definition_without_an_id_is_refused() -> void:
	var log := QuestLog.new()
	assert_bool(log.register(SideQuestDefinition.new())).is_false()
	assert_int(log.quest_count()).is_equal(0)


func test_active_side_quests_list_only_the_active_ones() -> void:
	var log := _log()
	log.accept("sleepvana")
	log.accept("robotaxi_depot")
	log.complete("robotaxi_depot")

	var active := log.active_side_quests()
	assert_int(active.size()).is_equal(1)
	assert_str(active[0].quest_id()).is_equal("sleepvana")


func test_the_log_relays_the_chain_objective() -> void:
	var log := _log()
	var objectives: Array[int] = []
	log.objective_changed.connect(func(objective: int) -> void: objectives.append(objective))

	log.mark_tower_off()

	assert_int(objectives.size()).is_equal(1)
	assert_int(objectives[0]).is_equal(MainQuest.Objective.BOSS)
	assert_int(log.current_objective()).is_equal(MainQuest.Objective.BOSS)


func test_the_log_completes_and_travels_the_chain() -> void:
	var log := _log()
	log.mark_tower_off()
	log.mark_boss_cured()

	assert_bool(log.main_quest.is_city_complete("san_coffesco")).is_true()
	assert_bool(log.travel_east()).is_true()
	assert_str(log.main_quest.current_city()).is_equal("steamtle")


func test_save_round_trip_covers_main_and_side() -> void:
	var log := _log()
	log.mark_tower_off()
	log.accept("robotaxi_depot")
	log.accept("sleepvana")
	log.complete("sleepvana")

	var loaded := _log()
	var side_signals := _side_signals(loaded)
	var objectives: Array[int] = []
	loaded.objective_changed.connect(func(objective: int) -> void: objectives.append(objective))
	loaded.load_state(log.save_state())

	assert_bool(loaded.main_quest.is_tower_off("san_coffesco")).is_true()
	assert_bool(loaded.is_active("robotaxi_depot")).is_true()
	assert_bool(loaded.quest("sleepvana").is_complete()).is_true()
	assert_int(side_signals.size()).is_equal(0)
	assert_int(objectives.size()).is_equal(0)


func test_a_loaded_log_still_plays_on() -> void:
	var log := _log()
	log.mark_tower_off()

	var loaded := _log()
	loaded.load_state(log.save_state())
	var side_signals := _side_signals(loaded)

	loaded.mark_boss_cured()
	assert_bool(loaded.main_quest.is_city_complete("san_coffesco")).is_true()
	assert_bool(loaded.accept("sleepvana")).is_true()
	assert_int(side_signals.size()).is_equal(1)


func test_late_registered_side_quest_keeps_its_saved_state() -> void:
	# Field base quests register after QuestLog.load_state() runs; their saved
	# state must survive load and apply when register() is called.
	var late_def := SideQuestDefinition.new()
	late_def.quest_id = "field_kitchen_stock"
	late_def.title = "Field Kitchen Stock"
	var log := _log()
	assert_bool(log.register(late_def)).is_true()
	assert_bool(log.accept("field_kitchen_stock")).is_true()
	assert_bool(log.complete("field_kitchen_stock")).is_true()

	var reloaded := _log()
	reloaded.load_state(log.save_state())
	assert_bool(reloaded.register(late_def)).is_true()
	assert_bool(reloaded.quest("field_kitchen_stock").is_complete()).is_true()


func test_the_shipped_route_covers_the_three_version_one_cities() -> void:
	assert_int(MAIN_ROUTE.cities.size()).is_equal(3)
	var ids := MAIN_ROUTE.city_ids()
	assert_str(ids[0]).is_equal("san_coffesco")
	assert_str(ids[1]).is_equal("steamtle")
	assert_str(ids[2]).is_equal("pourtland")
	assert_object(MAIN_ROUTE.find_city("brewcago")).is_null()


func test_every_version_one_city_carries_its_signature_side_quest() -> void:
	var expected := {
		"san_coffesco": "robotaxi_depot",
		"steamtle": "sleepvana",
		"pourtland": "aisle_7",
	}
	for city: CityDefinition in MAIN_ROUTE.cities:
		assert_int(city.side_quests.size()).override_failure_message(city.city_id).is_equal(1)
		assert_str(city.side_quests[0].quest_id).is_equal(expected[city.city_id])
		assert_str(city.side_quests[0].city_id).is_equal(city.city_id)
		assert_str(city.side_quests[0].title).is_equal(city.quest_name)


func test_the_side_quest_sites_name_real_city_blocks() -> void:
	# A marker anchor only resolves when the site name matches a block of the
	# city, or when the quest data names no site at all.
	for city: CityDefinition in MAIN_ROUTE.cities:
		for quest: SideQuestDefinition in city.side_quests:
			if quest.site_name.is_empty():
				continue
			var found := false
			for block: CityBlock in city.blocks:
				found = found or block.site_name == quest.site_name
			(
				assert_bool(found)
				. override_failure_message("%s: %s" % [city.city_id, quest.site_name])
				. is_true()
			)
