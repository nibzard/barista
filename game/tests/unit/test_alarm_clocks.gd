# ABOUTME: Unit tests of the alarm clock row, ART_DIRECTION section 11.
# ABOUTME: Wake-ups are small alarm clocks; a used one rings and falls over.
extends GdUnitTestSuite


func _clocks(remaining: int, maximum: int, hardcore := false) -> AlarmClocks:
	var clocks: AlarmClocks = auto_free(AlarmClocks.new())
	clocks.read(remaining, maximum, hardcore)
	return clocks


func test_a_full_row_stands_five_clocks() -> void:
	var clocks := _clocks(5, 5)
	assert_int(clocks.clock_count()).is_equal(5)
	assert_int(clocks.standing_count()).is_equal(5)
	assert_int(clocks.fallen_count()).is_equal(0)


func test_a_used_clock_falls_over() -> void:
	var clocks := _clocks(4, 5)
	assert_int(clocks.standing_count()).is_equal(4)
	assert_int(clocks.fallen_count()).is_equal(1)
	assert_float(clocks.clock_angle(4)).is_equal_approx(70.0, 0.01)
	for index: int in range(4):
		assert_float(clocks.clock_angle(index)).is_equal_approx(0.0, 0.01)


func test_the_fallen_clocks_sit_at_the_end_of_the_row() -> void:
	# The row stands its clocks first and tips the used ones over, so the
	# wake-ups left read before the wake-ups spent.
	var clocks := _clocks(2, 5)
	for index: int in range(5):
		if index >= 2:
			assert_bool(clocks.is_fallen(index)).is_true()
		else:
			assert_bool(clocks.is_fallen(index)).is_false()


func test_the_last_wake_up_fells_the_final_clock() -> void:
	var clocks := _clocks(0, 5)
	assert_int(clocks.standing_count()).is_equal(0)
	assert_int(clocks.fallen_count()).is_equal(5)
	assert_bool(clocks.is_fallen(4)).is_true()


func test_hardcore_shows_no_clocks_at_all() -> void:
	# Section 9: a hardcore run holds no wake-ups, so the row counts no
	# lives the mode never grants, whatever the numbers say.
	var clocks := _clocks(0, 5, true)
	assert_int(clocks.clock_count()).is_equal(0)
	assert_int(clocks.standing_count()).is_equal(0)
	assert_int(clocks.fallen_count()).is_equal(0)
	clocks.read(3, 5, true)
	assert_int(clocks.clock_count()).is_equal(0)


func test_clock_centers_pack_at_a_fixed_pitch() -> void:
	var clocks := _clocks(5, 5)
	for index: int in range(1, 5):
		var step := clocks.clock_center(index) - clocks.clock_center(index - 1)
		assert_float(step.x).is_equal_approx(20.0, 0.01)
		assert_float(step.y).is_equal_approx(0.0, 0.01)


func test_reading_keeps_the_minimum_size_stable() -> void:
	# The HUD polls every frame; a repeat read changes nothing.
	var clocks := _clocks(5, 5)
	clocks.read(5, 5, false)
	assert_vector(clocks.custom_minimum_size).is_equal(Vector2(100.0, 22.0))
	clocks.read(1, 5, false)
	assert_vector(clocks.custom_minimum_size).is_equal(Vector2(100.0, 22.0))
