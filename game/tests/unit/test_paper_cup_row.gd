# ABOUTME: Unit tests of the paper cup row, ART_DIRECTION section 11.
# ABOUTME: Cups in hand are small paper cup icons in a row; the room stays dashed.
extends GdUnitTestSuite


func _row(cups: int, limit: int) -> PaperCupRow:
	var row: PaperCupRow = auto_free(PaperCupRow.new())
	row.read(cups, limit)
	return row


func test_one_icon_per_slot_of_the_carry_limit() -> void:
	assert_int(_row(12, 12).icon_count()).is_equal(12)
	assert_int(_row(3, 15).icon_count()).is_equal(15)
	assert_int(_row(0, 0).icon_count()).is_equal(0)


func test_the_held_cups_fill_the_row_from_the_left() -> void:
	# The brewed cups stand first; the dashed room follows them, so a glance
	# reads the cups in hand before the room.
	var row := _row(8, 12)
	assert_int(row.filled_count()).is_equal(8)
	assert_int(row.empty_count()).is_equal(4)
	for index: int in range(8):
		assert_bool(row.is_filled(index)).is_true()
	for index: int in range(8, 12):
		assert_bool(row.is_filled(index)).is_false()


func test_cups_above_the_limit_show_no_extra_icons() -> void:
	# The supply clamps its own cups, and the row clamps again: only the
	# carry limit ever draws.
	var row := _row(20, 12)
	assert_int(row.filled_count()).is_equal(12)
	assert_int(row.empty_count()).is_equal(0)
	assert_int(row.icon_count()).is_equal(12)


func test_an_empty_hand_shows_only_the_room() -> void:
	var row := _row(0, 12)
	assert_int(row.filled_count()).is_equal(0)
	assert_int(row.empty_count()).is_equal(12)
	assert_bool(row.is_filled(0)).is_false()


func test_the_row_packs_tighter_at_a_big_carry_limit() -> void:
	# A limit above the row width shrinks the pitch, never the row: the van
	# kitchen with a thermos belt fits its twenty-three slots.
	var calm := _row(12, 12)
	assert_float(calm.cup_pitch()).is_equal_approx(13.0, 0.01)
	var packed := _row(20, 23)
	assert_float(packed.cup_pitch()).is_less(13.0)
	assert_float(packed.cup_pitch()).is_greater_equal(6.0)
	assert_float(float(packed.icon_count()) * packed.cup_pitch()).is_less_equal(190.01)


func test_cup_rects_tile_the_row_without_overlap() -> void:
	var row := _row(5, 12)
	var cup := row.cup_size()
	for index: int in range(12):
		var rect := row.cup_rect(index)
		assert_vector(rect.size).is_equal(cup)
		assert_float(rect.position.y).is_greater_equal(0.0)
		assert_float(rect.end.y).is_less_equal(18.01)
		if index > 0:
			var left := row.cup_rect(index - 1)
			assert_float(rect.position.x).is_greater_equal(left.end.x - 0.01)


func test_reading_keeps_the_minimum_size_stable() -> void:
	# The HUD polls every frame; a repeat read changes nothing.
	var row := _row(12, 12)
	row.read(12, 12)
	assert_vector(row.custom_minimum_size).is_equal(Vector2(156.0, 18.0))
	row.read(20, 23)
	assert_vector(row.custom_minimum_size).is_equal(Vector2(190.0, 18.0))


func test_the_cup_keeps_the_interface_kit_proportions() -> void:
	# The kit cup is 18 wide over 28 tall: a touch taller than wide.
	var row := _row(12, 12)
	var cup := row.cup_size()
	assert_float(cup.x).is_less(cup.y)
	assert_float(cup.x / cup.y).is_equal_approx(18.0 / 28.0, 0.01)
