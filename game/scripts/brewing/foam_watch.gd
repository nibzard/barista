# ABOUTME: FoamWatch is the pure model of The Foam Watch minigame, GAME_DESIGN section 8.
# ABOUTME: Turkish coffee: the pot heats up, the foam rises, greed boils over.
# ABOUTME: No nodes here: callers tick the clock and lift the pot, the score comes out.
class_name FoamWatch
extends RefCounted

enum Step {
	HEAT,
	RISE,
}

# The pot rim. The foam caps here, and past it only the grace window holds.
const RIM_FOAM := 1.0

var balance: FoamWatchBalance
# The current step: the pot heats first, then the foam rises.
var step: Step = Step.HEAT
# The pot heat from 0.0 (cold) to 1.0 (the boil starts).
var heat := 0.0
# The foam from 0.0 (none) to RIM_FOAM (the foam sits at the rim).
var foam := 0.0
# Seconds the foam has sat at the rim with no lift.
var at_rim_seconds := 0.0
# Seconds of the whole run so far.
var elapsed := 0.0
# The frozen result, set once a lift grades or the pot boils over.
var result: FoamResult = null


func _init(p_balance: FoamWatchBalance) -> void:
	balance = p_balance


func tick(delta: float) -> void:
	# Advance the watch by delta seconds. The clock runs on its own: the pot
	# heats, the foam rises, and the pot boils over when greed outlasts the
	# grace window.
	if not is_running():
		return
	elapsed += delta
	if step == Step.HEAT:
		_tick_heat(delta)
	else:
		_tick_rise(delta)


func lift() -> FoamResult:
	# Lift the pot where it stands: the one move of the minigame. Safe to call
	# twice and safe after the end; the answer never changes.
	if result != null:
		return result
	if step == Step.HEAT:
		result = _grade_cold()
	else:
		result = _grade_lifted()
	return result


func is_running() -> bool:
	return result == null


func is_at_rim() -> bool:
	return foam >= RIM_FOAM


func is_rushing() -> bool:
	# Above the rush line the foam climbs at the rush rate.
	return step == Step.RISE and foam >= balance.rush_start_foam


func _tick_heat(delta: float) -> void:
	heat = minf(heat + balance.heat_rate_per_second * delta, 1.0)
	if heat >= 1.0:
		step = Step.RISE


func _tick_rise(delta: float) -> void:
	# The foam grows, faster above the rush line. At the rim the grace window
	# runs: the last safe moment. The tick that reaches the rim costs no grace;
	# every tick that starts at the rim spends its full delta.
	if is_at_rim():
		at_rim_seconds += delta
		if at_rim_seconds >= balance.boil_over_grace_seconds:
			result = _grade_boil_over()
		return
	foam = minf(foam + _foam_rate_per_second() * delta, RIM_FOAM)


func _foam_rate_per_second() -> float:
	# The rate is picked at the start of each tick, so a tick that crosses the
	# rush line runs at one speed for its whole length.
	var rate := balance.foam_rate_per_second
	if foam >= balance.rush_start_foam:
		rate *= balance.rush_multiplier
	return rate


func _grade_lifted() -> FoamResult:
	# More foam gives a better cup: the score is the foam share of the rim.
	var score := balance.lifted_score * foam / RIM_FOAM
	return FoamResult.new(
		FoamResult.Outcome.LIFTED,
		heat,
		foam,
		at_rim_seconds,
		elapsed,
		score,
		_quality_factor(score)
	)


func _grade_boil_over() -> FoamResult:
	# Greed costs the cup: the pot boiled over and nothing stays.
	return FoamResult.new(
		FoamResult.Outcome.BOILED_OVER,
		heat,
		foam,
		at_rim_seconds,
		elapsed,
		balance.boil_over_score,
		_quality_factor(balance.boil_over_score)
	)


func _grade_cold() -> FoamResult:
	# A lift before the boil lifts a cold pot: no foam, no cup.
	return FoamResult.new(
		FoamResult.Outcome.COLD,
		heat,
		foam,
		at_rim_seconds,
		elapsed,
		balance.cold_score,
		_quality_factor(balance.cold_score)
	)


func _quality_factor(score: float) -> float:
	return clampf(score / balance.lifted_score, 0.0, 1.0)
