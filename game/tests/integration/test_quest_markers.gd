# ABOUTME: Integration tests that prove quest signals drive the UI markers.
# ABOUTME: The marker layer binds once; only QuestLog signals move its targets.
extends GdUnitTestSuite

const MAIN_ROUTE := preload("res://resources/quests/main_route.tres")
const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BALANCE := preload("res://resources/balance/city.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")


func _build_map(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = BALANCE
	add_child(auto_free(map))
	return map


func _build_log(city: CityDefinition) -> QuestLog:
	var log := QuestLog.new()
	assert_bool(log.setup(MAIN_ROUTE, city.city_id)).is_true()
	return log


func _bind(log: QuestLog, map: CityMap) -> QuestMarkers:
	var markers := QuestMarkers.new()
	add_child(auto_free(markers))
	markers.bind(log, map)
	return markers


func _block_center(view: CityBlockView) -> Vector2:
	return view.global_position + view.size * 0.5


func test_the_first_marker_sits_on_the_tower() -> void:
	# Section 19 step 7: the survivor speaks, the marker appears on the tower.
	var map := _build_map(SAN_COFFESCO)
	var markers := _bind(_build_log(SAN_COFFESCO), map)

	assert_bool(markers.has_objective_marker()).is_true()
	assert_vector(markers.objective_marker_position()).is_equal(
		map.broadcast_tower().global_position
	)
	assert_str(markers.objective_marker_label()).is_equal("THE TOWER")


func test_the_marker_follows_the_chain_through_its_signals() -> void:
	# The layer binds once. Every move below comes from a quest signal alone.
	var map := _build_map(SAN_COFFESCO)
	var log := _build_log(SAN_COFFESCO)
	var markers := _bind(log, map)
	var arena := _block_center(map.find_block_of_kind(CityBlock.Kind.BOSS_ARENA))

	log.mark_tower_off()
	assert_vector(markers.objective_marker_position()).is_equal(arena)
	assert_str(markers.objective_marker_label()).is_equal("SAM OATMAN")

	log.mark_boss_cured()
	assert_bool(markers.has_objective_marker()).is_true()
	assert_str(markers.objective_marker_label()).is_equal("THE ROAD EAST")
	var bounds := map.city_size()
	assert_vector(markers.objective_marker_position()).is_equal(
		Vector2(bounds.x, bounds.y * 0.5) + QuestMarkers.ROAD_EAST_OFFSET
	)


func test_the_boss_beat_alone_keeps_the_tower_marker() -> void:
	var map := _build_map(SAN_COFFESCO)
	var log := _build_log(SAN_COFFESCO)
	var markers := _bind(log, map)

	log.mark_boss_cured()
	assert_vector(markers.objective_marker_position()).is_equal(
		map.broadcast_tower().global_position
	)
	assert_str(markers.objective_marker_label()).is_equal("THE TOWER")


func test_the_last_city_shows_no_road_east_marker() -> void:
	# Pourtland is the last city of the version: the road east ends here.
	var map := _build_map(POURTLAND)
	var log := _build_log(POURTLAND)
	var markers := _bind(log, map)

	log.mark_tower_off()
	log.mark_boss_cured()

	assert_int(log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	assert_bool(markers.has_objective_marker()).is_false()
	assert_int(markers.side_marker_positions().size()).is_equal(0)


func test_an_active_side_quest_marks_the_signature_landmark() -> void:
	# The Robotaxi Depot names no site: its marker sits on the quest landmark.
	var map := _build_map(SAN_COFFESCO)
	var log := _build_log(SAN_COFFESCO)
	var markers := _bind(log, map)
	var landmark := _block_center(map.find_block_of_kind(CityBlock.Kind.QUEST))

	assert_int(markers.side_marker_positions().size()).is_equal(0)
	log.accept("robotaxi_depot")
	assert_int(markers.side_marker_positions().size()).is_equal(1)
	assert_vector(markers.side_marker_positions()[0]).is_equal(landmark)

	log.complete("robotaxi_depot")
	assert_int(markers.side_marker_positions().size()).is_equal(0)


func test_an_active_side_quest_marks_its_named_site() -> void:
	# Sleepvana marks The Garage, the place where the frontman sleeps.
	var map := _build_map(STEAMTLE)
	var log := _build_log(STEAMTLE)
	var markers := _bind(log, map)
	var garage := map.find_quest_site("The Garage").quest_site_marker()

	log.accept("sleepvana")
	assert_int(markers.side_marker_positions().size()).is_equal(1)
	assert_vector(markers.side_marker_positions()[0]).is_equal(garage.global_position)


func test_a_quest_of_another_city_gets_no_marker_here() -> void:
	var map := _build_map(STEAMTLE)
	var log := _build_log(STEAMTLE)
	var markers := _bind(log, map)

	log.accept("robotaxi_depot")
	assert_int(markers.side_marker_positions().size()).is_equal(0)


func test_a_named_site_that_the_map_lacks_gets_no_marker() -> void:
	var map := _build_map(SAN_COFFESCO)
	var log := _build_log(SAN_COFFESCO)
	var markers := _bind(log, map)

	assert_bool(log.accept("sleepvana")).is_true()
	assert_int(markers.side_marker_positions().size()).is_equal(0)
