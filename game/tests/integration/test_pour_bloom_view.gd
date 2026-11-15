# ABOUTME: Integration tests for The Pour scene: input, timing, and the result.
# ABOUTME: The view only presents; every grade comes from the pure PourBloom model.
extends GdUnitTestSuite

const POUR_SCENE := preload("res://scenes/minigames/pour_bloom.tscn")
const FILTER_METHOD := preload("res://resources/brewing/methods/filter.tres")

const FRAME_GUARD := 1200

var _view: PourBloomView
var _finished_results: Array[PourResult] = []


func before_test() -> void:
	_view = POUR_SCENE.instantiate() as PourBloomView
	add_child(auto_free(_view))
	_finished_results = []
	_view.finished.connect(_on_finished)
	await get_tree().process_frame


func test_scene_wires_the_balance_the_method_and_a_running_model() -> void:
	assert_object(_view.balance).is_not_null()
	assert_float(_view.balance.sweet_spot_start).is_equal(0.55)
	assert_float(_view.balance.sweet_spot_end).is_equal(0.85)
	assert_str(_view.method.method_id).is_equal("v60")
	assert_object(_view.model).is_not_null()
	assert_bool(_view.model.is_running()).is_true()
	assert_str(_view.method_label.text).is_equal("POUR: V60 POUR-OVER")


func test_a_steady_pour_in_the_sweet_spot_fills_the_ring() -> void:
	# Hold the pour at 0.7, inside the 0.55 to 0.85 band. The ring fills in
	# about four seconds and the view announces the graded result once.
	_view.pour_rate = 0.7
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_running()).is_false()
	var result := _view.model.result
	assert_int(result.outcome).is_equal(PourResult.Outcome.BLOOMED)
	assert_float(result.score).is_equal(100.0)
	assert_int(_finished_results.size()).is_equal(1)
	assert_object(_finished_results[0]).is_same(result)
	assert_str(_view.result_label.text).is_equal("Full bloom. Score 100.")
	assert_bool(_view.result_label.visible).is_true()


func test_pouring_full_throttle_floods_the_bed() -> void:
	_view.pour_rate = 1.0
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_int(_view.model.result.outcome).is_equal(PourResult.Outcome.FLOODED)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).is_equal("Flooded bed. Score 0.")


func test_a_stopped_pour_stalls_the_bloom() -> void:
	# Pour until the ring is part full, then stop: the wet bloom dries out
	# and stalls.
	_view.pour_rate = 0.7
	var frames := 0
	while _view.model.fill < 0.3 and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	_view.pour_rate = 0.0
	frames = 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_int(_view.model.result.outcome).is_equal(PourResult.Outcome.STALLED)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).is_equal("The bloom stalled. Score 0.")


func test_the_pour_finishes_only_once() -> void:
	_view.pour_rate = 1.0
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_int(_finished_results.size()).is_equal(1)
	var first := _view.model.result
	for _i: int in range(30):
		await get_tree().process_frame
	assert_object(_view.model.result).is_same(first)
	assert_int(_finished_results.size()).is_equal(1)


func test_a_touch_circle_around_the_ring_pours() -> void:
	# Touch first: press on the ring, drag around it, and the pour rate
	# follows the angular speed. Lifting the finger stops the pour.
	var center := _ring_center_global()
	_view._unhandled_input(_touch(true, center + Vector2(120.0, 0.0)))
	await get_tree().process_frame
	assert_float(_view.pour_rate).is_equal(0.0)
	for i: int in range(6):
		var angle := (i + 1) * (TAU / 12.0)
		_view._unhandled_input(_drag(center + Vector2.from_angle(angle) * 120.0))
		await get_tree().process_frame
	assert_float(_view.pour_rate).is_greater(0.05)
	_view._unhandled_input(_touch(false, center + Vector2.from_angle(TAU / 2.0) * 120.0))
	await get_tree().process_frame
	assert_float(_view.pour_rate).is_equal(0.0)


func test_a_held_mouse_circle_pours_the_same_way() -> void:
	# Desktop development convenience: a held left button moved in a circle
	# drives the same pour path as touch.
	var center := _ring_center_global()
	_view._unhandled_input(_mouse_button(true, center + Vector2(120.0, 0.0)))
	await get_tree().process_frame
	for i: int in range(6):
		var angle := (i + 1) * (TAU / 12.0)
		_view._unhandled_input(_mouse_motion(center + Vector2.from_angle(angle) * 120.0))
		await get_tree().process_frame
	assert_float(_view.pour_rate).is_greater(0.05)
	_view._unhandled_input(_mouse_button(false, center + Vector2.from_angle(TAU / 2.0) * 120.0))
	await get_tree().process_frame
	assert_float(_view.pour_rate).is_equal(0.0)


func test_begin_restarts_the_pour_for_another_method() -> void:
	_view.pour_rate = 1.0
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	_view.begin(FILTER_METHOD)
	assert_bool(_view.model.is_running()).is_true()
	assert_float(_view.model.fill).is_equal(0.0)
	assert_float(_view.pour_rate).is_equal(0.0)
	assert_str(_view.method_label.text).is_equal("POUR: FILTER COFFEE")
	assert_bool(_view.result_label.visible).is_false()
	assert_int(_finished_results.size()).is_equal(1)


func _ring_center_global() -> Vector2:
	return _view.get_global_rect().position + PourBloomView.RING_CENTER


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = pressed
	touch.position = position
	return touch


func _drag(position: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = position
	return drag


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = position
	return button


func _mouse_motion(position: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = position
	return motion


func _on_finished(pour_result: PourResult) -> void:
	_finished_results.append(pour_result)
