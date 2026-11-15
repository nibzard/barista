# ABOUTME: Integration tests for The Press scene: input, timing, and the result.
# ABOUTME: The view only presents; every grade comes from the pure PressShot model.
extends GdUnitTestSuite

const PRESS_SCENE := preload("res://scenes/minigames/press_shot.tscn")
const FRENCH_PRESS_METHOD := preload("res://resources/brewing/methods/french_press.tres")

const FRAME_GUARD := 1200

var _view: PressShotView
var _finished_results: Array[PressResult] = []


func before_test() -> void:
	_view = PRESS_SCENE.instantiate() as PressShotView
	add_child(auto_free(_view))
	_finished_results = []
	_view.finished.connect(_on_finished)
	await get_tree().process_frame


func test_scene_wires_the_balance_the_method_and_a_running_model() -> void:
	assert_object(_view.balance).is_not_null()
	assert_float(_view.balance.pressure_build_per_second).is_equal(0.55)
	assert_float(_view.balance.release_mark_pressure).is_equal(0.95)
	assert_str(_view.method.method_id).is_equal("espresso")
	assert_object(_view.model).is_not_null()
	assert_bool(_view.model.is_running()).is_true()
	assert_bool(_view.held).is_false()
	assert_str(_view.method_label.text).is_equal("PRESS: ESPRESSO")
	assert_str(_view.step_label.text).is_equal("STEP 1: HOLD THE GREEN ZONE")


func test_a_chased_hold_fills_the_cup_and_opens_the_pull() -> void:
	await _await_hold_step()
	assert_int(_view.model.step).is_equal(PressShot.Step.RELEASE)
	assert_float(_view.model.fill).is_equal(1.0)
	assert_str(_view.step_label.text).is_equal("STEP 2: RELEASE AT THE MARK")
	assert_int(_finished_results.size()).is_equal(0)


func test_a_release_on_the_mark_finishes_the_press() -> void:
	# Pump the hold until the pull opens, then hold the needle up to the mark
	# and lift. The lift grades at the pressure the player last saw.
	await _await_hold_step()
	var frames := 0
	while (
		_view.model.is_running()
		and _view.model.pressure < _view.balance.release_mark_pressure - 0.03
		and frames < FRAME_GUARD
	):
		_view.held = true
		await get_tree().process_frame
		frames += 1
	_view.held = false
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_running()).is_false()
	var result := _view.model.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.PRESSED)
	assert_float(result.pressure).is_between(
		_view.balance.release_mark_pressure - _view.balance.perfect_tolerance,
		_view.balance.release_mark_pressure + _view.balance.perfect_tolerance
	)
	assert_int(_finished_results.size()).is_equal(1)
	assert_object(_finished_results[0]).is_same(result)
	assert_str(_view.result_label.text).is_equal(
		"Released on the mark. Score %d." % roundi(result.score)
	)
	assert_bool(_view.result_label.visible).is_true()


func test_an_early_lift_makes_a_sour_cup() -> void:
	await _await_hold_step()
	_view.held = false
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	var result := _view.model.result
	assert_int(result.outcome).is_equal(PressResult.Outcome.SOUR)
	assert_float(result.pressure).is_less(
		_view.balance.release_mark_pressure - _view.balance.perfect_tolerance
	)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).contains("Sour cup")
	assert_bool(_view.result_label.visible).is_true()


func test_a_held_pull_runs_bitter_to_the_end() -> void:
	# Keep the hold on past the mark and never lift: the pull window closes
	# the run on its own and the cup is bitter.
	await _await_hold_step()
	_view.held = true
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(PressResult.Outcome.BITTER)
	assert_float(_view.model.result.pressure).is_equal(_view.balance.pressure_max)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).contains("Bitter cup")


func test_the_press_finishes_only_once() -> void:
	await _await_hold_step()
	_view.held = false
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


func test_a_screen_touch_press_and_release_drive_the_hold() -> void:
	# Touch first: press and hold anywhere on the panel, lift to release.
	_view._unhandled_input(_touch(true, Vector2(200, 300)))
	assert_bool(_view.held).is_true()
	_view._unhandled_input(_touch(false, Vector2(200, 300)))
	assert_bool(_view.held).is_false()


func test_a_held_mouse_button_drives_the_same_hold() -> void:
	_view._unhandled_input(_mouse_button(true, Vector2(200, 300)))
	assert_bool(_view.held).is_true()
	_view._unhandled_input(_mouse_button(false, Vector2(200, 300)))
	assert_bool(_view.held).is_false()


func test_the_keyboard_action_holds_the_pressure() -> void:
	var press_key := InputEventKey.new()
	press_key.physical_keycode = KEY_SPACE
	press_key.pressed = true
	_view._unhandled_input(press_key)
	assert_bool(_view.held).is_true()
	var lift_key := InputEventKey.new()
	lift_key.physical_keycode = KEY_SPACE
	lift_key.pressed = false
	_view._unhandled_input(lift_key)
	assert_bool(_view.held).is_false()


func test_begin_restarts_the_press_for_another_method() -> void:
	await _await_hold_step()
	_view.held = false
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	_view.begin(FRENCH_PRESS_METHOD)
	assert_bool(_view.model.is_running()).is_true()
	assert_int(_view.model.step).is_equal(PressShot.Step.HOLD)
	assert_float(_view.model.fill).is_equal(0.0)
	assert_float(_view.model.pressure).is_equal(0.0)
	assert_bool(_view.held).is_false()
	assert_str(_view.method_label.text).is_equal("PRESS: FRENCH PRESS")
	assert_str(_view.step_label.text).is_equal("STEP 1: HOLD THE GREEN ZONE")
	assert_bool(_view.result_label.visible).is_false()
	assert_int(_finished_results.size()).is_equal(1)


func _await_hold_step() -> void:
	# Pump the hold through real frames until the pull step opens.
	var frames := 0
	while _view.model.step == PressShot.Step.HOLD and frames < FRAME_GUARD:
		_view.held = _view.model.pressure < _view.model.zone_center
		await get_tree().process_frame
		frames += 1
	assert_int(_view.model.step).is_equal(PressShot.Step.RELEASE)


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = pressed
	touch.position = position
	return touch


func _mouse_button(pressed: bool, position: Vector2) -> InputEventMouseButton:
	var button := InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = position
	return button


func _on_finished(press_result: PressResult) -> void:
	_finished_results.append(press_result)
