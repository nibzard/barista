# ABOUTME: Unit tests for the move handoff across the road east, section 10.
# ABOUTME: The park, the take-once read, and the reset of the plain store.
extends GdUnitTestSuite


func before_test() -> void:
	MoveHandoff.reset()


func after_test() -> void:
	MoveHandoff.reset()


func test_a_parked_traveler_arrives_once() -> void:
	MoveHandoff.park({"bag": {"house": 3}, "unlock": true})

	var arriving := MoveHandoff.take_arriving()
	assert_int(int(arriving.get("bag", {}).get("house", 0))).is_equal(3)
	assert_bool(bool(arriving.get("unlock", false))).is_true()
	assert_bool(MoveHandoff.take_arriving().is_empty()).is_true()


func test_an_arrival_without_a_park_reads_empty() -> void:
	# A fresh run that never traveled keeps its plain start.
	assert_bool(MoveHandoff.take_arriving().is_empty()).is_true()


func test_reset_clears_a_parked_move() -> void:
	MoveHandoff.park({"bag": {"house": 3}})

	MoveHandoff.reset()

	assert_bool(MoveHandoff.take_arriving().is_empty()).is_true()


func test_the_plain_park_stores_a_copy() -> void:
	# The park stores a copy, so a caller cannot change the arrival by
	# holding the same dict after the move.
	var traveler := {"bag": {"house": 3}}
	MoveHandoff.park(traveler)
	traveler["bag"] = {"house": 9}

	assert_int(int(MoveHandoff.take_arriving()["bag"]["house"])).is_equal(3)
