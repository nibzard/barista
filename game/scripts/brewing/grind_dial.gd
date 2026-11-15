# ABOUTME: GrindDial is the pure pre-step of every brew, per GAME_DESIGN section 8.
# ABOUTME: A marker runs from fine to coarse; the player stops it in the zone.
# ABOUTME: No nodes here: the view ticks and draws it, tests grade it directly.
class_name GrindDial
extends RefCounted

# The dial scale runs from FINE to COARSE over the full 0 to 1 range.
const FINE := 0.0
const COARSE := 1.0

var balance: GrindDialBalance
var method: BrewingMethod
# The marker position on the dial, from FINE to COARSE.
var position := FINE
# The graded result, set once the dial stops or runs off the end.
var result: GrindResult = null


func _init(p_method: BrewingMethod, p_balance: GrindDialBalance) -> void:
	method = p_method
	balance = p_balance


func tick(delta: float) -> void:
	# Advance the marker. A marker that reaches the coarse end with no stop
	# is a miss: the grind ran away.
	if not is_running():
		return
	position = minf(position + balance.marker_speed_units_per_second * delta, COARSE)
	if position >= COARSE:
		result = _grade(COARSE, true)


func stop() -> GrindResult:
	# Stop the marker where it stands and grade it. Repeated calls return the
	# same frozen result, so both input paths can call this safely.
	if result == null:
		result = _grade(position, false)
	return result


func is_running() -> bool:
	return result == null


func zone_start() -> float:
	# The correct zone of the method, clamped to the dial ends.
	return maxf(method.grind_target - method.grind_tolerance, FINE)


func zone_end() -> float:
	return minf(method.grind_target + method.grind_tolerance, COARSE)


func _grade(stop_position: float, missed: bool) -> GrindResult:
	# Inside the zone the grind is right and the cup keeps its quality.
	# Outside it, the quality falls with the distance beyond the zone edge.
	# A miss never grinds at all.
	var distance := absf(stop_position - method.grind_target)
	if missed:
		return GrindResult.new(
			GrindResult.Outcome.MISS,
			stop_position,
			distance,
			balance.miss_score,
			_factor(balance.miss_score)
		)
	if distance <= method.grind_tolerance:
		return GrindResult.new(
			GrindResult.Outcome.HIT,
			stop_position,
			distance,
			balance.hit_score,
			_factor(balance.hit_score)
		)
	var overshoot := distance - method.grind_tolerance
	var score := clampf(
		balance.hit_score - balance.wrong_zone_penalty_per_unit * overshoot,
		balance.wrong_zone_floor_score,
		balance.hit_score
	)
	return GrindResult.new(
		GrindResult.Outcome.WRONG_ZONE, stop_position, distance, score, _factor(score)
	)


func _factor(score: float) -> float:
	return clampf(score / balance.hit_score, 0.0, 1.0)
