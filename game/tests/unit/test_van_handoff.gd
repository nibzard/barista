# ABOUTME: Unit tests for the van handoff across the move east, T101.
# ABOUTME: Pure logic: the level parks once, arrives once, then clears.
extends GdUnitTestSuite


func before_test() -> void:
	# A parked level from an earlier case must never leak into the next one.
	VanHandoff.reset()


func test_a_fresh_handoff_falls_back_to_the_plain_van() -> void:
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(MobileCafe.Level.VAN)


func test_a_parked_level_arrives_in_the_next_city() -> void:
	VanHandoff.park(MobileCafe.Level.KITCHEN)
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(
		MobileCafe.Level.KITCHEN
	)


func test_a_parked_field_cafe_arrives_too() -> void:
	VanHandoff.park(MobileCafe.Level.FIELD_CAFE)
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(
		MobileCafe.Level.FIELD_CAFE
	)


func test_the_arrival_takes_the_level_once() -> void:
	# The handoff holds one move: a second arrival, like a fresh run that
	# never traveled, falls back to the plain van.
	VanHandoff.park(MobileCafe.Level.KITCHEN)
	VanHandoff.take_arriving_level(MobileCafe.Level.VAN)
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(MobileCafe.Level.VAN)


func test_a_move_without_a_van_falls_back_to_the_plain_van() -> void:
	# The player can walk the road east before the survivors hand the van
	# over. The arrival then starts at the plain van, gift and all.
	VanHandoff.park(MobileCafe.Level.NONE)
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(MobileCafe.Level.VAN)


func test_reset_clears_a_parked_level() -> void:
	VanHandoff.park(MobileCafe.Level.FIELD_CAFE)
	VanHandoff.reset()
	assert_int(VanHandoff.take_arriving_level(MobileCafe.Level.VAN)).is_equal(MobileCafe.Level.VAN)
