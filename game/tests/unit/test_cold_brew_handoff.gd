# ABOUTME: Unit tests for the cold brew handoff across the move east, T119.
# ABOUTME: Pure logic: the steep parks once, arrives once, then clears.
extends GdUnitTestSuite


func before_test() -> void:
	# A parked steep from an earlier case must never leak into the next one.
	ColdBrewHandoff.reset()


func after_test() -> void:
	ColdBrewHandoff.reset()


func test_a_fresh_session_arrives_with_an_empty_fridge() -> void:
	assert_dict(ColdBrewHandoff.take_arriving_state()).is_empty()


func test_the_parked_steep_arrives_in_the_next_city() -> void:
	ColdBrewHandoff.park(
		{"recipe_id": "cold_brew_concentrate", "bean_id": "golden_coast_arabica", "elapsed": 200.0}
	)
	var arriving := ColdBrewHandoff.take_arriving_state()
	assert_str(str(arriving.get("recipe_id", ""))).is_equal("cold_brew_concentrate")
	assert_str(str(arriving.get("bean_id", ""))).is_equal("golden_coast_arabica")
	assert_float(float(arriving.get("elapsed", 0.0))).is_equal(200.0)


func test_the_arrival_takes_the_steep_once() -> void:
	# The handoff holds one move: a second arrival, like a reload of the east
	# city after a death, never replays the steep.
	ColdBrewHandoff.park({"recipe_id": "cold_brew_concentrate", "elapsed": 200.0})
	ColdBrewHandoff.take_arriving_state()
	assert_dict(ColdBrewHandoff.take_arriving_state()).is_empty()


func test_a_move_without_a_steep_arrives_with_an_empty_fridge() -> void:
	# The player can walk the road east with no steep running. The arrival
	# then starts at an empty fridge, ready for the next start.
	ColdBrewHandoff.park({})
	assert_dict(ColdBrewHandoff.take_arriving_state()).is_empty()


func test_reset_clears_a_parked_steep() -> void:
	ColdBrewHandoff.park({"recipe_id": "cold_brew_concentrate", "elapsed": 5.0})
	ColdBrewHandoff.reset()
	assert_dict(ColdBrewHandoff.take_arriving_state()).is_empty()


func test_the_park_freezes_the_state() -> void:
	# The fridge hands a fresh dict per save, but the handoff must stay
	# frozen: a caller that keeps its dict cannot change the parked steep.
	var state := {"recipe_id": "cold_brew_concentrate", "elapsed": 10.0}
	ColdBrewHandoff.park(state)
	state["elapsed"] = 999.0
	assert_float(float(ColdBrewHandoff.take_arriving_state().get("elapsed", 0.0))).is_equal(10.0)
