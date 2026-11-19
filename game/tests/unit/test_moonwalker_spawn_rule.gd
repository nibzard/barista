# ABOUTME: Unit tests for the MoonwalkerSpawnRule, section 24.
# ABOUTME: Dawn, a silent zone, and a dead tower, all at once, one figure.
extends GdUnitTestSuite


func test_every_condition_must_hold() -> void:
	assert_bool(MoonwalkerSpawnRule.should_spawn(true, true, true, false)).is_true()
	assert_bool(MoonwalkerSpawnRule.should_spawn(false, true, true, false)).is_false()
	assert_bool(MoonwalkerSpawnRule.should_spawn(true, false, true, false)).is_false()
	assert_bool(MoonwalkerSpawnRule.should_spawn(true, true, false, false)).is_false()


func test_a_live_figure_blocks_the_next_spawn() -> void:
	assert_bool(MoonwalkerSpawnRule.should_spawn(true, true, true, true)).is_false()
