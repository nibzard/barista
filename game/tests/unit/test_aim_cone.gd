# ABOUTME: Unit tests for the wide aim cone: where a thrown cup lands.
# ABOUTME: Pure vector logic, no scene tree needed.
extends GdUnitTestSuite

const HALF_ANGLE := 30.0
const RANGE := 500.0


func test_target_inside_the_cone_is_snapped() -> void:
	var candidates: Array[Vector2] = [Vector2(400, 100)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(400, 100))


func test_target_outside_the_cone_is_ignored() -> void:
	var candidates: Array[Vector2] = [Vector2(300, 300)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_target_beyond_the_range_is_ignored() -> void:
	var candidates: Array[Vector2] = [Vector2(600, 0)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_target_behind_the_player_is_ignored() -> void:
	var candidates: Array[Vector2] = [Vector2(-300, 0)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_the_most_centered_target_wins() -> void:
	var candidates: Array[Vector2] = [Vector2(300, 100), Vector2(400, -100)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(400, -100))


func test_at_equal_angles_the_nearer_target_wins() -> void:
	var candidates: Array[Vector2] = [Vector2(450, 0), Vector2(300, 0)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(300, 0))


func test_no_candidates_lands_at_full_range() -> void:
	var candidates: Array[Vector2] = []
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_the_cone_opens_around_any_aim_direction() -> void:
	var candidates: Array[Vector2] = [Vector2(100, -400)]
	var landing := AimCone.landing_point(Vector2.ZERO, Vector2.UP, candidates, HALF_ANGLE, RANGE)
	assert_vector(landing).is_equal(Vector2(100, -400))
