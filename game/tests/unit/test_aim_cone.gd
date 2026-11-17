# ABOUTME: Unit tests for the wide aim cone: where a thrown cup lands.
# ABOUTME: Pure vector logic, no scene tree needed.
extends GdUnitTestSuite

const HALF_ANGLE := 30.0
const RANGE := 500.0


func _candidates(points: Array[Vector2], velocity: Vector2 = Vector2.ZERO) -> Array[AimCandidate]:
	var list: Array[AimCandidate] = []
	for point: Vector2 in points:
		list.append(AimCandidate.new(point, velocity))
	return list


func test_target_inside_the_cone_is_snapped() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, _candidates([Vector2(400, 100)]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(400, 100))


func test_target_outside_the_cone_is_ignored() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, _candidates([Vector2(300, 300)]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_target_beyond_the_range_is_ignored() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, _candidates([Vector2(600, 0)]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_target_behind_the_player_is_ignored() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, _candidates([Vector2(-300, 0)]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_the_most_centered_target_wins() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO,
		Vector2.RIGHT,
		_candidates([Vector2(300, 100), Vector2(400, -100)]),
		HALF_ANGLE,
		RANGE
	)
	assert_vector(landing).is_equal(Vector2(400, -100))


func test_at_equal_angles_the_nearer_target_wins() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO,
		Vector2.RIGHT,
		_candidates([Vector2(450, 0), Vector2(300, 0)]),
		HALF_ANGLE,
		RANGE
	)
	assert_vector(landing).is_equal(Vector2(300, 0))


func test_no_candidates_lands_at_full_range() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, _candidates([]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_the_cone_opens_around_any_aim_direction() -> void:
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.UP, _candidates([Vector2(100, -400)]), HALF_ANGLE, RANGE
	)
	assert_vector(landing).is_equal(Vector2(100, -400))


func test_a_moving_target_is_led_by_its_velocity() -> void:
	# The assist leads a mover to where the cup lands: position plus the
	# velocity it carries over the flight time.
	var candidates: Array[AimCandidate] = [AimCandidate.new(Vector2(400, 0), Vector2(0, 40))]
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE, 1.0
	)
	assert_vector(landing).is_equal(Vector2(400, 40))


func test_zero_lead_time_lands_on_the_current_position() -> void:
	var candidates: Array[AimCandidate] = [AimCandidate.new(Vector2(400, 0), Vector2(0, 40))]
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE, 0.0
	)
	assert_vector(landing).is_equal(Vector2(400, 0))


func test_the_lead_never_passes_the_throw_range() -> void:
	# A chaser sprinting away from the player gets a cup that stops at the
	# range edge, like a plain throw would.
	var candidates: Array[AimCandidate] = [AimCandidate.new(Vector2(490, 0), Vector2(70, 0))]
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE, 1.0
	)
	assert_vector(landing).is_equal(Vector2(RANGE, 0))


func test_the_lead_shifts_with_the_lead_time() -> void:
	var candidates: Array[AimCandidate] = [AimCandidate.new(Vector2(400, 0), Vector2(40, 0))]
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE, 0.5
	)
	assert_vector(landing).is_equal(Vector2(420, 0))


func test_the_cone_selects_by_current_position_not_the_lead() -> void:
	# The centered walker wins even though the other mover's led landing
	# would end up closer to the aim axis: selection reads the now, the
	# lead only moves the landing.
	var candidates: Array[AimCandidate] = [
		AimCandidate.new(Vector2(400, 0), Vector2(0, 150)),
		AimCandidate.new(Vector2(380, -80), Vector2(0, -70)),
	]
	var landing := AimCone.landing_point(
		Vector2.ZERO, Vector2.RIGHT, candidates, HALF_ANGLE, RANGE, 1.0
	)
	assert_vector(landing).is_equal(Vector2(400, 150))
