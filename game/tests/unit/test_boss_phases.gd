# ABOUTME: Unit tests for the shared boss phase clock of the boss framework.
# ABOUTME: Pins the boundary rule: each phase runs its time, the last holds.
extends GdUnitTestSuite


func test_the_first_phase_holds_until_its_time_runs_out() -> void:
	var phases := BossPhases.new([5.0, 5.0])
	assert_int(phases.phase_count()).is_equal(3)
	assert_int(phases.current()).is_equal(0)
	for _step: int in range(4):
		assert_int(phases.tick(1.0)).is_equal(-1)
	assert_int(phases.current()).is_equal(0)
	assert_float(phases.elapsed_in_phase()).is_equal(4.0)


func test_the_full_time_of_a_phase_crosses_its_boundary() -> void:
	# The fifth second of a five second phase ends it: the boundary reports
	# the new index, and the step after it runs inside the new phase.
	var phases := BossPhases.new([5.0, 5.0])
	for _step: int in range(5):
		phases.tick(1.0)
	assert_int(phases.current()).is_equal(1)
	assert_float(phases.elapsed_in_phase()).is_equal(0.0)


func test_the_last_phase_holds_forever() -> void:
	# The show never ends on its own: after the last boundary, any time the
	# clock eats changes nothing, because only the cure ends the fight.
	var phases := BossPhases.new([1.0, 1.0])
	for _step: int in range(2):
		phases.tick(1.0)
	assert_int(phases.current()).is_equal(2)
	assert_bool(phases.is_holding()).is_true()
	for _step: int in range(600):
		assert_int(phases.tick(1.0)).is_equal(-1)
	assert_int(phases.current()).is_equal(2)


func test_one_large_step_skips_to_the_phase_it_lands_in() -> void:
	# A hitching frame or a loaded machine can hand the clock one big step:
	# it crosses every boundary it passed and reports the last one.
	var phases := BossPhases.new([5.0, 5.0])
	assert_int(phases.tick(100.0)).is_equal(2)
	assert_int(phases.current()).is_equal(2)
	assert_bool(phases.is_holding()).is_true()


func test_the_leftover_time_carries_into_the_next_phase() -> void:
	# Three seconds of a two second phase leave one second inside the next.
	var phases := BossPhases.new([2.0, 2.0])
	assert_int(phases.tick(3.0)).is_equal(1)
	assert_float(phases.elapsed_in_phase()).is_equal(1.0)
	assert_int(phases.tick(1.0)).is_equal(2)


func test_no_phases_make_a_clock_that_only_holds() -> void:
	var phases := BossPhases.new()
	assert_int(phases.phase_count()).is_equal(1)
	assert_int(phases.current()).is_equal(0)
	assert_bool(phases.is_holding()).is_true()
	assert_int(phases.tick(10.0)).is_equal(-1)


func test_a_standing_step_never_advances_the_clock() -> void:
	# A zero or negative delta asks nothing, so it moves nothing, even in the
	# middle of a phase with its time already full.
	var phases := BossPhases.new([2.0])
	phases.tick(2.0)
	assert_int(phases.current()).is_equal(1)
	assert_int(phases.tick(0.0)).is_equal(-1)
	assert_int(phases.tick(-1.0)).is_equal(-1)
	assert_int(phases.current()).is_equal(1)
