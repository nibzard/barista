# ABOUTME: Unit tests for the pure virtual stick model behind the touch controls.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/touch_controls.tres")
const TOUCH_CONTROLS_SCENE := preload("res://scenes/touch/touch_controls.tscn")

const DEAD_ZONE := 20.0
const MAX_DISTANCE := 88.0

var _stick: TouchStick


func before_test() -> void:
	_stick = TouchStick.new()
	_stick.balance = BALANCE


func test_a_new_stick_rests_centered() -> void:
	assert_bool(_stick.is_held()).is_false()
	assert_vector(_stick.direction()).is_equal(Vector2.ZERO)
	assert_vector(_stick.offset()).is_equal(Vector2.ZERO)


func test_press_wakes_the_stick_without_a_tilt() -> void:
	_stick.press()
	assert_bool(_stick.is_held()).is_true()
	assert_vector(_stick.direction()).is_equal(Vector2.ZERO)


func test_a_tilt_inside_the_dead_zone_reads_as_rest() -> void:
	_stick.press()
	_stick.drag(Vector2(DEAD_ZONE, 0.0))
	assert_vector(_stick.direction()).is_equal(Vector2.ZERO)
	assert_vector(_stick.offset()).is_equal(Vector2(DEAD_ZONE, 0.0))


func test_a_tilt_just_beyond_the_dead_zone_starts_small() -> void:
	_stick.press()
	_stick.drag(Vector2(DEAD_ZONE + 1.0, 0.0))
	var direction := _stick.direction()
	assert_float(direction.x).is_equal_approx(1.0 / (MAX_DISTANCE - DEAD_ZONE), 0.0001)
	assert_float(direction.y).is_equal(0.0)


func test_a_full_tilt_reaches_the_unit_direction() -> void:
	_stick.press()
	_stick.drag(Vector2(MAX_DISTANCE, 0.0))
	assert_vector(_stick.direction()).is_equal(Vector2.RIGHT)


func test_a_drag_beyond_the_rim_clamps_to_full_tilt() -> void:
	_stick.press()
	_stick.drag(Vector2(500.0, 0.0))
	assert_vector(_stick.direction()).is_equal(Vector2.RIGHT)
	assert_vector(_stick.offset()).is_equal(Vector2(MAX_DISTANCE, 0.0))


func test_a_diagonal_tilt_stays_normalized() -> void:
	_stick.press()
	_stick.drag(Vector2.ONE.normalized() * MAX_DISTANCE)
	var direction := _stick.direction()
	assert_float(direction.length()).is_equal_approx(1.0, 0.0001)
	assert_float(direction.x).is_equal_approx(direction.y, 0.0001)


func test_release_centers_the_stick() -> void:
	_stick.press()
	_stick.drag(Vector2(MAX_DISTANCE, 0.0))
	_stick.release()
	assert_bool(_stick.is_held()).is_false()
	assert_vector(_stick.direction()).is_equal(Vector2.ZERO)


func test_a_stick_without_a_balance_stays_at_rest() -> void:
	var bare := TouchStick.new()
	bare.press()
	bare.drag(Vector2(500.0, 0.0))
	assert_vector(bare.direction()).is_equal(Vector2.ZERO)


func test_the_tilt_rules_come_from_the_balance() -> void:
	var tuned := TouchControlsBalance.new()
	tuned.stick_dead_zone_pixels = 10.0
	tuned.stick_max_distance_pixels = 50.0
	var tuned_stick := TouchStick.new()
	tuned_stick.balance = tuned
	tuned_stick.press()
	# Halfway between the dead zone and the rim reads as half tilt.
	tuned_stick.drag(Vector2(30.0, 0.0))
	assert_float(tuned_stick.direction().x).is_equal_approx(0.5, 0.0001)


func test_the_balance_pins_and_scene_wiring() -> void:
	# The tuned stick values live in the .tres and the scene carries it.
	assert_float(BALANCE.stick_dead_zone_pixels).is_equal(20.0)
	assert_float(BALANCE.stick_max_distance_pixels).is_equal(88.0)
	assert_float(BALANCE.stick_dead_zone_pixels).is_less(BALANCE.stick_max_distance_pixels)
	var controls := auto_free(TOUCH_CONTROLS_SCENE.instantiate()) as TouchControls
	assert_object(controls.balance).is_same(BALANCE)
