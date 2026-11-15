# ABOUTME: Integration tests for the Grind Dial scene: input, timing, and the result.
# ABOUTME: The view only presents; every grade comes from the pure GrindDial model.
extends GdUnitTestSuite

const DIAL_SCENE := preload("res://scenes/minigames/grind_dial.tscn")
const ESPRESSO_METHOD := preload("res://resources/brewing/methods/espresso.tres")

const FRAME_GUARD := 400

var _view: GrindDialView
var _finished_results: Array[GrindResult] = []


func before_test() -> void:
	_view = DIAL_SCENE.instantiate() as GrindDialView
	add_child(auto_free(_view))
	_finished_results = []
	_view.finished.connect(_on_finished)
	await get_tree().process_frame


func test_scene_wires_the_balance_the_method_and_a_running_model() -> void:
	assert_object(_view.balance).is_not_null()
	assert_float(_view.balance.marker_speed_units_per_second).is_equal(0.7)
	assert_str(_view.method.method_id).is_equal("filter")
	assert_object(_view.model).is_not_null()
	assert_object(_view.model.method).is_same(_view.method)
	assert_bool(_view.model.is_running()).is_true()
	assert_str(_view.method_label.text).is_equal("GRIND: FILTER COFFEE")


func test_the_marker_runs_in_the_scene_tree() -> void:
	var start := _view.model.position
	var frames := 0
	while _view.model.position < start + 0.05 and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_float(_view.model.position).is_greater(start + 0.05)


func test_a_stop_inside_the_zone_emits_a_graded_hit() -> void:
	# Filter zone is 0.55 to 0.75. Wait for the marker to enter it, then stop.
	var frames := 0
	while _view.model.position < _view.model.zone_start() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	var result := _view.request_stop()
	assert_object(result).is_not_null()
	assert_int(result.outcome).is_equal(GrindResult.Outcome.HIT)
	assert_int(_finished_results.size()).is_equal(1)
	assert_object(_finished_results[0]).is_same(result)
	assert_str(_view.result_label.text).is_equal("Right grind. Score 100.")
	assert_bool(_view.result_label.visible).is_true()


func test_the_dial_misses_when_nobody_stops_it() -> void:
	# The marker runs fine to coarse in about 1.4 seconds, then the dial
	# grades a miss on its own.
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(GrindResult.Outcome.MISS)
	assert_int(_finished_results.size()).is_equal(1)
	assert_float(_finished_results[0].score).is_equal(0.0)
	assert_str(_view.result_label.text).is_equal("No grind. The dial ran away. Score 0.")


func test_the_dial_finishes_only_once() -> void:
	var first := _view.request_stop()
	assert_int(first.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	var second := _view.request_stop()
	assert_object(second).is_same(first)
	assert_int(_finished_results.size()).is_equal(1)


func test_the_keyboard_action_stops_the_dial() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	_view._unhandled_input(key)
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(GrindResult.Outcome.WRONG_ZONE)
	assert_int(_finished_results.size()).is_equal(1)


func test_any_screen_tap_stops_the_dial() -> void:
	# Touch first: the tap needs no keyboard, no mouse, and no action map.
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.pressed = true
	tap.position = Vector2(200, 360)
	_view._unhandled_input(tap)
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_finished_results.size()).is_equal(1)


func test_begin_restarts_the_dial_for_another_method() -> void:
	_view.request_stop()
	_view.begin(ESPRESSO_METHOD)
	assert_bool(_view.model.is_running()).is_true()
	assert_object(_view.model.method).is_same(ESPRESSO_METHOD)
	assert_str(_view.method_label.text).is_equal("GRIND: ESPRESSO")
	assert_bool(_view.result_label.visible).is_false()
	assert_float(_view.model.zone_start()).is_equal_approx(0.12, 0.0001)
	assert_int(_finished_results.size()).is_equal(1)


func _on_finished(grind_result: GrindResult) -> void:
	_finished_results.append(grind_result)
