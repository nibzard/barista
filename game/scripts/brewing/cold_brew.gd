# ABOUTME: ColdBrew is the pure model of the cold brew method, section 8.
# ABOUTME: No minigame: the player starts it and comes back later.
# ABOUTME: No nodes here: callers tick the timer, the finished cup comes out.
class_name ColdBrew
extends RefCounted

# The top of the cup score scale. The method ceiling grades below it.
const SCORE_TOP := 100.0

var method: BrewingMethod
var balance: ColdBrewBalance
# Seconds the brew has steeped, clamped to the steep duration.
var elapsed := 0.0
# The frozen result, set once the steep finishes.
var result: ColdBrewResult = null


func _init(p_method: BrewingMethod, p_balance: ColdBrewBalance) -> void:
	method = p_method
	balance = p_balance


func tick(delta: float) -> void:
	# Advance the steep by delta seconds. The brew asks for no player input,
	# so the cup finishes on its own: zero stress. Coming back much later
	# changes nothing; the timer stops when the cup is ready.
	if is_ready():
		return
	elapsed = minf(elapsed + delta, balance.steep_seconds)
	if elapsed >= balance.steep_seconds:
		_finish()


func collect() -> ColdBrewResult:
	# Take the finished cup out of the fridge. Before the steep ends there is
	# no cup to take. Safe to call twice: the answer never changes.
	return result


func is_ready() -> bool:
	return result != null


func progress() -> float:
	# The steeped fraction from 0.0 to 1.0, for a countdown display.
	return clampf(elapsed / balance.steep_seconds, 0.0, 1.0)


func remaining_seconds() -> float:
	return maxf(balance.steep_seconds - elapsed, 0.0)


func save_state() -> Dictionary:
	# The save system stores the steep, so the player can close the app and
	# come back later, section 18.
	return {"elapsed": elapsed}


func load_state(saved: Dictionary) -> void:
	# A loaded brew stands where it stood, and a steep that ran out while the
	# game was closed is ready at once.
	elapsed = clampf(float(saved.get("elapsed", 0.0)), 0.0, balance.steep_seconds)
	result = null
	if elapsed >= balance.steep_seconds:
		_finish()


func _finish() -> void:
	# The cup grades at the method ceiling: a low ceiling, never a perfect
	# cup. The timer stops at the full steep.
	elapsed = balance.steep_seconds
	var score := method.score_ceiling
	result = ColdBrewResult.new(elapsed, score, _quality_factor(score))


func _quality_factor(score: float) -> float:
	return clampf(score / SCORE_TOP, 0.0, 1.0)
