# ABOUTME: Unit tests for the city completion flow: tower off plus boss cured.
# ABOUTME: Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite


func test_a_new_city_starts_incomplete() -> void:
	var progress := CityProgress.new()
	assert_bool(progress.is_tower_off()).is_false()
	assert_bool(progress.is_boss_cured()).is_false()
	assert_bool(progress.is_complete()).is_false()


func test_the_tower_switch_alone_does_not_complete_the_city() -> void:
	var progress := CityProgress.new()
	progress.mark_tower_off()
	assert_bool(progress.is_tower_off()).is_true()
	assert_bool(progress.is_complete()).is_false()


func test_the_boss_cure_alone_does_not_complete_the_city() -> void:
	var progress := CityProgress.new()
	progress.mark_boss_cured()
	assert_bool(progress.is_boss_cured()).is_true()
	assert_bool(progress.is_complete()).is_false()


func test_the_tower_and_the_boss_cure_complete_the_city_once() -> void:
	var progress := CityProgress.new()
	var completions: Array[int] = []
	progress.city_completed.connect(func() -> void: completions.append(1))

	progress.mark_tower_off()
	assert_int(completions.size()).is_equal(0)
	progress.mark_boss_cured()

	assert_bool(progress.is_complete()).is_true()
	assert_int(completions.size()).is_equal(1)


func test_the_beats_complete_the_city_in_either_order() -> void:
	var progress := CityProgress.new()
	progress.mark_boss_cured()
	progress.mark_tower_off()
	assert_bool(progress.is_complete()).is_true()


func test_repeated_marks_do_not_replay_the_completion() -> void:
	var progress := CityProgress.new()
	var completions: Array[int] = []
	progress.city_completed.connect(func() -> void: completions.append(1))

	progress.mark_tower_off()
	progress.mark_tower_off()
	progress.mark_boss_cured()
	progress.mark_boss_cured()

	assert_int(completions.size()).is_equal(1)


func test_save_round_trip_carries_both_beats() -> void:
	var progress := CityProgress.new()
	progress.mark_tower_off()
	var saved := progress.save_state()

	var loaded := CityProgress.new()
	var completions: Array[int] = []
	loaded.city_completed.connect(func() -> void: completions.append(1))
	loaded.load_state(saved)

	assert_bool(loaded.is_tower_off()).is_true()
	assert_bool(loaded.is_boss_cured()).is_false()
	assert_bool(loaded.is_complete()).is_false()
	assert_int(completions.size()).is_equal(0)

	loaded.mark_boss_cured()
	assert_bool(loaded.is_complete()).is_true()
	assert_int(completions.size()).is_equal(1)


func test_load_of_a_complete_city_never_replays_the_beat() -> void:
	var progress := CityProgress.new()
	progress.mark_tower_off()
	progress.mark_boss_cured()

	var loaded := CityProgress.new()
	var completions: Array[int] = []
	loaded.city_completed.connect(func() -> void: completions.append(1))
	loaded.load_state(progress.save_state())

	assert_bool(loaded.is_complete()).is_true()
	assert_int(completions.size()).is_equal(0)
