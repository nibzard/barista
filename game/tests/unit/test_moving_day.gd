# ABOUTME: Unit tests for the moving-day state between two city cafes.
# ABOUTME: Pure logic: the unload beat fires once and never replays.
extends GdUnitTestSuite


func test_fresh_move_still_waits_for_the_van() -> void:
	var move := MovingDay.new()
	assert_bool(move.is_done()).is_false()


func test_unload_completes_the_move_once() -> void:
	var move := MovingDay.new()
	assert_bool(move.unload()).is_true()
	assert_bool(move.is_done()).is_true()


func test_unload_never_replays() -> void:
	var move := MovingDay.new()
	move.unload()
	assert_bool(move.unload()).is_false()
	assert_bool(move.is_done()).is_true()


func test_finished_signal_fires_once() -> void:
	# A lambda copies plain locals, so the collector counts through an array.
	var move := MovingDay.new()
	var fires: Array[int] = []
	move.finished.connect(func() -> void: fires.append(1))
	move.unload()
	move.unload()
	assert_int(fires.size()).is_equal(1)


func test_save_and_load_round_trip() -> void:
	var move := MovingDay.new()
	move.unload()
	assert_bool(move.save_state()).is_true()

	var loaded := MovingDay.new()
	assert_bool(loaded.save_state()).is_false()
	loaded.load_state(move.save_state())
	assert_bool(loaded.is_done()).is_true()
	# A loaded move never replays the beat.
	assert_bool(loaded.unload()).is_false()


func test_load_can_restore_an_open_move() -> void:
	var move := MovingDay.new()
	move.load_state(false)
	assert_bool(move.is_done()).is_false()
	assert_bool(move.unload()).is_true()
