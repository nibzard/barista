# ABOUTME: Integration tests for The Foam Watch scene: timing, input, the result.
# ABOUTME: The view only presents; every grade comes from the pure FoamWatch model.
extends GdUnitTestSuite

const FOAM_WATCH_SCENE := preload("res://scenes/minigames/foam_watch.tscn")
const TURKISH_METHOD := preload("res://resources/brewing/methods/turkish.tres")

const FRAME_GUARD := 1500

var _view: FoamWatchView
var _finished_results: Array[FoamResult] = []


func before_test() -> void:
	_view = FOAM_WATCH_SCENE.instantiate() as FoamWatchView
	add_child(auto_free(_view))
	_finished_results = []
	_view.finished.connect(_on_finished)
	await get_tree().process_frame


func test_scene_wires_the_balance_the_method_and_a_running_model() -> void:
	assert_object(_view.balance).is_not_null()
	assert_float(_view.balance.heat_rate_per_second).is_equal(0.5)
	assert_float(_view.balance.boil_over_grace_seconds).is_equal(0.8)
	assert_str(_view.method.method_id).is_equal("turkish")
	assert_int(_view.method.minigame_group).is_equal(BrewingMethod.MinigameGroup.FOAM_WATCH)
	assert_object(_view.model).is_not_null()
	assert_bool(_view.model.is_running()).is_true()
	assert_int(_view.model.step).is_equal(FoamWatch.Step.HEAT)
	assert_float(_view.model.foam).is_equal(0.0)
	assert_str(_view.method_label.text).is_equal("FOAM WATCH: TURKISH COFFEE")
	assert_str(_view.step_label.text).is_equal("STEP 1: THE POT HEATS UP")
	assert_bool(_view.result_label.visible).is_false()


func test_the_pot_heats_up_and_the_foam_rises() -> void:
	# The clock runs on its own through real frames: first the heat, then the
	# foam.
	await _await_step(FoamWatch.Step.RISE)
	assert_float(_view.model.heat).is_equal(1.0)
	assert_float(_view.model.foam).is_equal(0.0)
	assert_str(_view.step_label.text).is_equal("STEP 2: LET THE FOAM RISE")
	var frames := 0
	while _view.model.foam <= 0.0 and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_float(_view.model.foam).is_greater(0.0)


func test_the_rush_line_changes_the_prompt() -> void:
	await _await_rushing()
	assert_str(_view.step_label.text).is_equal("THE FOAM RUSHES!")
	assert_bool(_view.model.is_at_rim()).is_false()


func test_the_rim_shows_the_lift_prompt_and_a_lift_finishes_the_watch() -> void:
	await _await_at_rim()
	assert_str(_view.step_label.text).is_equal("LIFT NOW!")
	assert_bool(_view.model.is_running()).is_true()
	assert_int(_finished_results.size()).is_equal(0)
	_view._unhandled_input(_touch(true, Vector2(200, 300)))
	assert_bool(_view.model.is_running()).is_false()
	var result := _view.model.result
	assert_int(result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_float(result.score).is_equal(100.0)
	assert_float(result.foam).is_equal(FoamWatch.RIM_FOAM)
	assert_int(_finished_results.size()).is_equal(1)
	assert_object(_finished_results[0]).is_same(result)
	assert_str(_view.result_label.text).is_equal("Foam lifted. Score 100.")
	assert_bool(_view.result_label.visible).is_true()


func test_greed_boils_the_cup_over() -> void:
	# Never lift and the pot ends the run on its own: greed costs the cup.
	await _await_finished()
	var result := _view.model.result
	assert_int(result.outcome).is_equal(FoamResult.Outcome.BOILED_OVER)
	assert_float(result.score).is_equal(0.0)
	assert_float(result.at_rim_seconds).is_greater_equal(_view.balance.boil_over_grace_seconds)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).is_equal("Boiled over. Greed costs the cup. Score 0.")
	assert_bool(_view.result_label.visible).is_true()


func test_a_cold_tap_costs_the_cup() -> void:
	# A tap while the pot still heats lifts a cold pot: no foam, no cup.
	_view._unhandled_input(_touch(true, Vector2(200, 300)))
	assert_bool(_view.model.is_running()).is_false()
	var result := _view.model.result
	assert_int(result.outcome).is_equal(FoamResult.Outcome.COLD)
	assert_float(result.score).is_equal(0.0)
	assert_int(_finished_results.size()).is_equal(1)
	assert_str(_view.result_label.text).is_equal("Cold pot. No foam. Score 0.")


func test_the_watch_finishes_only_once() -> void:
	await _await_finished()
	assert_int(_finished_results.size()).is_equal(1)
	var first := _view.model.result
	for _i: int in range(30):
		await get_tree().process_frame
	assert_object(_view.model.result).is_same(first)
	assert_int(_finished_results.size()).is_equal(1)


func test_a_screen_tap_lifts_the_pot() -> void:
	await _await_step(FoamWatch.Step.RISE)
	await _await_foam_above(0.0)
	_view._unhandled_input(_touch(true, Vector2(200, 300)))
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(FoamResult.Outcome.LIFTED)
	assert_float(_view.model.foam).is_greater(0.0)


func test_a_mouse_click_lifts_the_pot() -> void:
	await _await_step(FoamWatch.Step.RISE)
	_view._unhandled_input(_mouse_button(true, Vector2(200, 300)))
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(FoamResult.Outcome.LIFTED)


func test_the_keyboard_action_lifts_the_pot() -> void:
	await _await_step(FoamWatch.Step.RISE)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	_view._unhandled_input(key)
	assert_bool(_view.model.is_running()).is_false()
	assert_int(_view.model.result.outcome).is_equal(FoamResult.Outcome.LIFTED)


func test_begin_restarts_the_watch() -> void:
	await _await_finished()
	_view.begin(TURKISH_METHOD)
	assert_bool(_view.model.is_running()).is_true()
	assert_int(_view.model.step).is_equal(FoamWatch.Step.HEAT)
	assert_float(_view.model.heat).is_less(0.1)
	assert_float(_view.model.foam).is_equal(0.0)
	assert_float(_view.model.at_rim_seconds).is_equal(0.0)
	assert_str(_view.method_label.text).is_equal("FOAM WATCH: TURKISH COFFEE")
	assert_str(_view.step_label.text).is_equal("STEP 1: THE POT HEATS UP")
	assert_bool(_view.result_label.visible).is_false()
	assert_int(_finished_results.size()).is_equal(1)


func _await_step(step: FoamWatch.Step) -> void:
	# Wait through real frames until the model reaches the given step.
	var frames := 0
	while _view.model.step != step and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_int(_view.model.step).is_equal(step)


func _await_foam_above(minimum: float) -> void:
	# Wait through real frames until the foam passes the given level.
	var frames := 0
	while _view.model.foam <= minimum and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_float(_view.model.foam).is_greater(minimum)


func _await_rushing() -> void:
	var frames := 0
	while not _view.model.is_rushing() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_rushing()).is_true()


func _await_at_rim() -> void:
	var frames := 0
	while not _view.model.is_at_rim() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_at_rim()).is_true()


func _await_finished() -> void:
	var frames := 0
	while _view.model.is_running() and frames < FRAME_GUARD:
		await get_tree().process_frame
		frames += 1
	assert_bool(_view.model.is_running()).is_false()


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


func _on_finished(foam_result: FoamResult) -> void:
	_finished_results.append(foam_result)
