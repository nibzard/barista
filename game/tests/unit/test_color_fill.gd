# ABOUTME: Unit tests for ColorFill, the sketch-to-color wake front of the art direction.
# ABOUTME: The fill runs without a scene tree; the tests push time with advance().
extends GdUnitTestSuite

const HAND_DRAWN := preload("res://shaders/hand_drawn.gdshader")

var _owner: Node2D
var _fill: ColorFill


func before_test() -> void:
	_owner = auto_free(Node2D.new())
	var material := ShaderMaterial.new()
	material.shader = HAND_DRAWN
	_owner.material = material
	_fill = ColorFill.new()
	_fill.duration = 2.0
	_fill.radius = 300.0
	_owner.add_child(_fill)


func test_a_new_fill_is_a_sketch() -> void:
	assert_float(_fill.progress()).is_equal(0.0)
	assert_bool(_fill.is_filled()).is_false()
	assert_bool(_fill.is_running()).is_false()


func test_time_does_nothing_before_the_start() -> void:
	_fill.advance(5.0)
	assert_float(_fill.progress()).is_equal(0.0)


func test_the_fill_grows_with_time_after_the_start() -> void:
	_fill.start(Vector2(10, 20))
	_fill.advance(1.0)
	assert_float(_fill.progress()).is_equal_approx(0.5, 0.0001)
	assert_bool(_fill.is_running()).is_true()


func test_the_fill_stops_at_full_color_and_signals_once() -> void:
	var signals: Array[int] = [0]
	_fill.filled.connect(func() -> void: signals[0] += 1)
	_fill.start(Vector2.ZERO)
	_fill.advance(1.5)
	_fill.advance(1.5)
	_fill.advance(1.5)
	assert_float(_fill.progress()).is_equal(1.0)
	assert_bool(_fill.is_filled()).is_true()
	assert_bool(_fill.is_running()).is_false()
	assert_int(signals[0]).is_equal(1)


func test_a_full_fill_ignores_a_second_start() -> void:
	_fill.start(Vector2.ZERO)
	_fill.advance(2.0)
	_fill.start(Vector2(500, 500))
	assert_bool(_fill.is_running()).is_false()
	assert_float(_fill.progress()).is_equal(1.0)


func test_fill_now_jumps_to_full_color_without_the_signal() -> void:
	var signals: Array[int] = [0]
	_fill.filled.connect(func() -> void: signals[0] += 1)
	_fill.fill_now()
	assert_bool(_fill.is_filled()).is_true()
	assert_int(signals[0]).is_equal(0)


func test_reset_goes_back_to_the_sketch() -> void:
	_fill.start(Vector2.ZERO)
	_fill.advance(1.0)
	_fill.reset()
	assert_float(_fill.progress()).is_equal(0.0)
	assert_bool(_fill.is_running()).is_false()


func test_the_owner_material_gets_the_wake_front() -> void:
	var material := _owner.material as ShaderMaterial
	_fill.start(Vector2(40, 60))
	_fill.advance(1.0)
	assert_vector(material.get_shader_parameter("fill_origin") as Vector2).is_equal(Vector2(40, 60))
	assert_float(material.get_shader_parameter("fill_radius") as float).is_equal(300.0)
	# The shader value eases out: the front moves fast first, then settles.
	assert_float(material.get_shader_parameter("fill") as float).is_equal_approx(0.75, 0.0001)


func test_a_zero_duration_fills_on_the_first_step() -> void:
	_fill.duration = 0.0
	_fill.start(Vector2.ZERO)
	_fill.advance(0.016)
	assert_bool(_fill.is_filled()).is_true()
