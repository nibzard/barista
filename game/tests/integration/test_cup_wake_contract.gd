# ABOUTME: Pins the duck-typed wake contract of the thrown cup: any body
# ABOUTME: that answers try_wake takes the payload, whatever script it runs.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 120
# Negative asserts read state after the cup freed, with margin frames so a
# late splash frame cannot flip the result after the check.
const SETTLE_MARGIN_FRAMES := 5
# Every throw flies east along y = 200 from x = 100 into the stub at x = 400.
const START_X := 100.0
const LANE_Y := 200.0
const STUB_X := 400.0
const LANDING_X := 500.0

# GdUnit reuses one suite instance for every test case, so the flag resets
# on each throw, not in the declaration.
var _cup_in_flight := false


# A stand-in sleeper outside every known class: the cup must hand it the
# payload on contact without knowing its type (T112 decoupling). The hat
# flag plays the Tinfoil Man rule of section 6.
class StubSleeper:
	extends StaticBody2D

	var wake_calls := 0
	var last_cup: BrewedCup = null
	var hat_stops := false

	func try_wake(cup: BrewedCup) -> bool:
		wake_calls += 1
		last_cup = cup
		return true

	func hat_stops_thrown_coffee() -> bool:
		return hat_stops


func test_cup_hands_the_payload_to_any_body_that_answers_try_wake() -> void:
	var stub := _stub_at(Vector2(STUB_X, LANE_Y))
	var payload := _standard_cup()
	var cup := _throw_cup(payload)

	await _await_cup_settled()

	assert_int(stub.wake_calls).is_equal(1)
	assert_object(stub.last_cup).is_same(payload)
	assert_bool(is_instance_valid(cup)).is_false()


func test_cup_splashes_on_a_hat_without_handing_over_the_payload() -> void:
	var stub := _stub_at(Vector2(STUB_X, LANE_Y))
	stub.hat_stops = true
	var cup := _throw_cup(_standard_cup())

	await _await_cup_settled()

	assert_int(stub.wake_calls).is_equal(0)
	assert_bool(is_instance_valid(cup)).is_false()


func _stub_at(at: Vector2) -> StubSleeper:
	# A body built like the environment walls: a StaticBody2D with a
	# rectangle on the default environment layer 1, so the cup mask sees it.
	var stub := StubSleeper.new()
	stub.position = at
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 90.0)
	shape_node.shape = shape
	stub.add_child(shape_node)
	add_child(auto_free(stub))
	return stub


func _throw_cup(payload: BrewedCup) -> CoffeeCup:
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(START_X, LANE_Y)
	cup.direction = Vector2.RIGHT
	cup.brewed = payload
	add_child(auto_free(cup))
	_cup_in_flight = true
	cup.tree_exited.connect(_on_cup_left_tree)
	cup.launch(Vector2(LANDING_X, LANE_Y))
	return cup


func _on_cup_left_tree() -> void:
	# queue_free() pulls the cup from the tree at the frame end, so the flag
	# marks the death without holding the freed object.
	_cup_in_flight = false


func _standard_cup() -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("filter"),
		"",
		85.0
	)


func _await_cup_settled() -> void:
	var frames := 0
	while _cup_in_flight and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame
