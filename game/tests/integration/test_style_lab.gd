# ABOUTME: Integration tests for the style lab, the playable prototype of ART_DIRECTION.md.
# ABOUTME: Covers the wake front on a sleepwalker, the tower sunrise, and the city switch.
extends GdUnitTestSuite

const LAB_SCENE := preload("res://scenes/prototypes/style_lab.tscn")
# The street fill takes 2.6 seconds; wait on time, not frames, so a fast
# headless frame rate cannot end the wait early.
const MAX_SECONDS_TO_WAIT := 5.0

var _lab: StyleLab


func before_test() -> void:
	_lab = LAB_SCENE.instantiate() as StyleLab
	add_child(auto_free(_lab))
	await get_tree().process_frame


func test_the_street_starts_as_a_sleeping_sketch() -> void:
	assert_int(_lab.walker_count()).is_equal(4)
	for index in _lab.walker_count():
		assert_bool(_lab.walker(index).sleepwalking).is_true()
		assert_float(_lab.walker(index).color_fill().progress()).is_equal(0.0)
	assert_float(_lab.street_fill().progress()).is_equal(0.0)
	assert_float(_lab.haze_strength()).is_equal(1.0)


func test_the_barista_is_always_in_full_color() -> void:
	assert_bool(_lab.barista().sleepwalking).is_false()
	assert_bool(_lab.barista().color_fill().is_filled()).is_true()


func test_a_thrown_cup_wakes_the_sleepwalker_and_colors_it_in() -> void:
	var target := _lab.walker(0)
	assert_bool(_lab.throw_at(0)).is_true()
	var waited := 0.0
	while not target.color_fill().is_filled() and waited < MAX_SECONDS_TO_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert_bool(target.sleepwalking).is_false()
	assert_bool(target.color_fill().is_filled()).is_true()
	# The other sleepwalkers still sleep.
	assert_bool(_lab.walker(1).sleepwalking).is_true()


func test_a_woken_walker_takes_no_second_cup() -> void:
	_lab.wake_walker(0, _lab.walker(0).body_center())
	assert_bool(_lab.throw_at(0)).is_false()


func test_the_tower_switch_floods_the_street_and_clears_the_haze() -> void:
	_lab.switch_off_tower()
	assert_bool(_lab.is_tower_off()).is_true()
	var waited := 0.0
	while not _lab.street_fill().is_filled() and waited < MAX_SECONDS_TO_WAIT:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert_bool(_lab.street_fill().is_filled()).is_true()
	assert_float(_lab.haze_strength()).is_equal_approx(0.0, 0.001)


func test_next_city_rebuilds_a_sleeping_street() -> void:
	_lab.switch_off_tower()
	_lab.next_city()
	assert_str(_lab.current_city().city_id).is_equal("steamtle")
	assert_bool(_lab.is_tower_off()).is_false()
	assert_float(_lab.street_fill().progress()).is_equal(0.0)
	_lab.next_city()
	_lab.next_city()
	assert_str(_lab.current_city().city_id).is_equal("san_coffesco")
