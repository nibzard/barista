# ABOUTME: PourBloom is the pure model of The Pour minigame, GAME_DESIGN section 8.
# ABOUTME: V60 pour-over, filter coffee, Aeropress: pour in a slow circle.
# ABOUTME: No nodes here: callers stream pour-rate samples in, the score comes out.
class_name PourBloom
extends RefCounted

var balance: PourBalance

# The bloom fill from 0.0 (dry bed) to 1.0 (full ring, the goal).
var fill := 0.0
# Pooled water from pouring too fast, from 0.0 up to the flood level.
var excess := 0.0
# Seconds of the brew window spent so far.
var elapsed := 0.0
# The frozen result, set once the ring fills, floods, or stalls.
var result: PourResult = null

var _wet := false


func _init(p_balance: PourBalance) -> void:
	balance = p_balance


func tick(delta: float, pour_rate: float) -> void:
	# Advance the bloom by one sample of the input stream: delta seconds at
	# pour_rate. The rate runs from 0.0 (no pour) to 1.0 (full throttle).
	if not is_running():
		return
	pour_rate = clampf(pour_rate, 0.0, 1.0)
	elapsed += delta
	if pour_rate > balance.sweet_spot_end:
		# Too fast: the bed still drinks at its top speed, but the water
		# beyond the sweet spot pools and pushes the bed toward a flood.
		fill = minf(fill + balance.fill_rate_per_second * delta, 1.0)
		excess += ((pour_rate - balance.sweet_spot_end) * balance.flood_build_multiplier * delta)
	else:
		# At or below the sweet-spot end the bed settles. Inside the band the
		# bloom grows. Below it the bloom dries out and stalls.
		excess = maxf(excess - balance.drain_rate_per_second * delta, 0.0)
		if pour_rate >= balance.sweet_spot_start:
			fill = minf(fill + balance.fill_rate_per_second * delta, 1.0)
		else:
			fill = maxf(fill - balance.dry_rate_per_second * delta, 0.0)
	if fill > 0.0:
		_wet = true
	# A full ring ends the brew the moment it fills; the flood damage already
	# taxes the score. A wet bloom that dries to nothing stalls at once, and a
	# ring that never fills before the window closes stalls as well.
	if fill >= 1.0:
		result = _grade(PourResult.Outcome.BLOOMED)
	elif excess >= balance.flood_excess:
		result = _grade(PourResult.Outcome.FLOODED)
	elif _wet and fill <= 0.0:
		result = _grade(PourResult.Outcome.STALLED)
	elif elapsed >= balance.brew_window_seconds:
		result = _grade(PourResult.Outcome.STALLED)


func is_running() -> bool:
	return result == null


func _grade(outcome: PourResult.Outcome) -> PourResult:
	var score := 0.0
	match outcome:
		PourResult.Outcome.BLOOMED:
			score = clampf(
				balance.bloomed_score - excess * balance.excess_penalty_per_unit,
				0.0,
				balance.bloomed_score
			)
		PourResult.Outcome.FLOODED:
			score = balance.flood_score
		PourResult.Outcome.STALLED:
			score = fill * balance.stalled_score_max
	return PourResult.new(outcome, fill, excess, elapsed, score, _quality_factor(score))


func _quality_factor(score: float) -> float:
	return clampf(score / balance.bloomed_score, 0.0, 1.0)
