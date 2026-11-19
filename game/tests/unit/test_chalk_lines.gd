# ABOUTME: Unit tests of the chalk stroke geometry behind the icon readouts.
# ABOUTME: Dashed marks, arc sampling, and curve points are pure math.
extends GdUnitTestSuite


func test_a_dashed_line_breaks_into_pairs_of_points() -> void:
	var segments := ChalkLines.dash_segments(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(10.0, 0.0)]), 2.0, 1.0
	)
	# Ten units at mark two, gap one: three marks and a start of a fourth.
	assert_int(segments.size()).is_equal(8)
	assert_vector(segments[0]).is_equal(Vector2(0.0, 0.0))
	assert_vector(segments[1]).is_equal(Vector2(2.0, 0.0))
	assert_vector(segments[2]).is_equal(Vector2(3.0, 0.0))
	assert_vector(segments[3]).is_equal(Vector2(5.0, 0.0))


func test_every_mark_stays_within_its_dash_length() -> void:
	var segments := ChalkLines.dash_segments(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(7.0, 4.0)]), 2.2, 1.8
	)
	assert_int(segments.size() % 2).is_equal(0)
	for i: int in range(0, segments.size(), 2):
		var length := segments[i].distance_to(segments[i + 1])
		assert_float(length).is_less_equal(2.21)
		assert_float(length).is_greater(0.0)


func test_marks_and_gaps_survive_a_corner() -> void:
	# The pen keeps its budget across a corner, so a mark never resets mid
	# stroke: the pieces of a bent line still cover it without overlap.
	var points := PackedVector2Array([Vector2(0.0, 0.0), Vector2(3.0, 0.0), Vector2(3.0, 3.0)])
	var segments := ChalkLines.dash_segments(points, 2.0, 1.0)
	assert_int(segments.size() % 2).is_equal(0)
	assert_vector(segments[0]).is_equal(Vector2(0.0, 0.0))
	assert_vector(segments[1]).is_equal(Vector2(2.0, 0.0))
	# The first mark spent two of its units, so the next picks up the rest.
	assert_vector(segments[2]).is_equal(Vector2(3.0, 0.0))


func test_a_short_line_draws_one_full_mark() -> void:
	var segments := ChalkLines.dash_segments(
		PackedVector2Array([Vector2(0.0, 0.0), Vector2(1.0, 0.0)]), 2.0, 1.0
	)
	assert_int(segments.size()).is_equal(2)
	assert_vector(segments[1]).is_equal(Vector2(1.0, 0.0))


func test_an_empty_path_has_no_segments() -> void:
	assert_int(ChalkLines.dash_segments(PackedVector2Array(), 2.0, 1.0).size()).is_equal(0)
	(
		assert_int(
			ChalkLines.dash_segments(PackedVector2Array([Vector2(4.0, 4.0)]), 2.0, 1.0).size()
		)
		. is_equal(0)
	)


func test_arc_points_walk_the_radius() -> void:
	var points := ChalkLines.arc_points(Vector2.ZERO, 10.0, 0.0, PI * 0.5, 4)
	assert_int(points.size()).is_equal(5)
	assert_vector(points[0]).is_equal_approx(Vector2(10.0, 0.0), Vector2(0.01, 0.01))
	assert_vector(points[4]).is_equal_approx(Vector2(0.0, 10.0), Vector2(0.01, 0.01))
	for point: Vector2 in points:
		assert_float(point.length()).is_equal_approx(10.0, 0.01)


func test_curve_points_touch_both_ends() -> void:
	var from := Vector2(-2.0, -9.0)
	var control := Vector2(-5.0, -12.0)
	var to := Vector2(-1.0, -15.0)
	var points := ChalkLines.curve_points(from, control, to, 10)
	assert_int(points.size()).is_equal(11)
	assert_vector(points[0]).is_equal(from)
	assert_vector(points[10]).is_equal(to)
	# The curve bows toward its control point, away from the straight line.
	var straight := (to - from).normalized()
	var bow := (points[5] - from).cross(straight)
	assert_float(absf(bow)).is_greater(0.5)
