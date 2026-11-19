# ABOUTME: Unit tests for the road west of section 23, T096: the chain moves
# ABOUTME: back one completed city and keeps every beat of the route.
extends GdUnitTestSuite


func _chain(start_city := "") -> MainQuest:
	var chain := MainQuest.new()
	assert_bool(chain.setup(["san_coffesco", "steamtle", "pourtland"], start_city)).is_true()
	return chain


func _complete(chain: MainQuest, city_id: String) -> void:
	chain.mark_tower_off(city_id)
	chain.mark_boss_cured(city_id)


func test_travel_west_moves_into_the_completed_city_west() -> void:
	var chain := _chain("pourtland")
	_complete(chain, "san_coffesco")
	_complete(chain, "steamtle")
	_complete(chain, "pourtland")
	var entered: Array[String] = []
	chain.city_entered.connect(func(city_id: String) -> void: entered.append(city_id))

	assert_bool(chain.travel_west()).is_true()
	assert_str(chain.current_city()).is_equal("steamtle")
	# The returned city reads complete: the marker points at its open road east.
	assert_int(chain.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	assert_int(entered.size()).is_equal(1)
	assert_str(entered[0]).is_equal("steamtle")
	# The beats of the route stay: a completed city never uncompletes.
	assert_bool(chain.is_city_complete("san_coffesco")).is_true()
	assert_bool(chain.is_city_complete("pourtland")).is_true()
	assert_bool(chain.is_city_unlocked("pourtland")).is_true()


func test_travel_west_refuses_the_first_city_and_an_open_city() -> void:
	# The first city of the route has no city west of it.
	var first := _chain()
	_complete(first, "san_coffesco")
	assert_bool(first.travel_west()).is_false()
	assert_str(first.current_city()).is_equal("san_coffesco")

	# The city west of the chain stands open: no way back through an unfinished
	# city, the same rule the road east holds.
	var mid := _chain("steamtle")
	assert_bool(mid.travel_west()).is_false()
	assert_str(mid.current_city()).is_equal("steamtle")


func test_the_chain_walks_the_whole_route_and_back() -> void:
	# The post-game walk of section 23: east to the end of the version, then
	# west to the first city, then east again, with the save in the middle.
	var chain := _chain()
	_complete(chain, "san_coffesco")
	chain.travel_east()
	_complete(chain, "steamtle")
	chain.travel_east()
	_complete(chain, "pourtland")

	assert_bool(chain.travel_west()).is_true()
	assert_bool(chain.travel_west()).is_true()
	assert_str(chain.current_city()).is_equal("san_coffesco")
	assert_bool(chain.travel_east()).is_true()
	assert_str(chain.current_city()).is_equal("steamtle")

	var loaded := _chain("pourtland")
	loaded.load_state(chain.save_state())
	assert_str(loaded.current_city()).is_equal("steamtle")
	assert_bool(loaded.travel_west()).is_true()
	assert_str(loaded.current_city()).is_equal("san_coffesco")
