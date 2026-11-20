# ABOUTME: PressShot is the pure model of The Press minigame, GAME_DESIGN section 8.
# ABOUTME: Espresso, French press, moka pot: a two-step hold, then a release.
# ABOUTME: No nodes here: callers stream held-state samples in, the score comes out.
class_name PressShot
extends RefCounted

enum Step {
	HOLD,
	RELEASE,
}

var balance: PressBalance
# The current step of the two-step hold.
var step: Step = Step.HOLD
# The gauge pressure, from 0.0 up to the overload cap.
var pressure := 0.0
# The center of the creeping green zone.
var zone_center := 0.0
# The hold fill from 0.0 (empty cup) to 1.0 (hold complete, the pull starts).
var fill := 0.0
# Seconds of the hold spent outside the green zone.
var drift_seconds := 0.0
# Seconds of the whole run so far.
var elapsed := 0.0
# Seconds spent in the pull, the second step.
var pull_elapsed := 0.0
# The frozen result, set once the press grades a release or runs out.
var result: PressResult = null

var _entered_zone := false
var _pull_armed := false


func _init(p_balance: PressBalance) -> void:
	balance = p_balance
	zone_center = p_balance.zone_start_center


func tick(delta: float, held: bool) -> void:
	# Advance the press by one sample of the input stream: delta seconds with
	# the pressure held (true) or lifted (false).
	if not is_running():
		return
	elapsed += delta
	if step == Step.RELEASE:
		_tick_pull(delta, held)
	else:
		_tick_hold(delta, held)


func is_running() -> bool:
	return result == null


func zone_start() -> float:
	# The low edge of the green zone.
	return zone_center - balance.zone_width * 0.5


func zone_end() -> float:
	return zone_center + balance.zone_width * 0.5


func is_in_zone(pressure_value: float) -> bool:
	# Both zone edges count as inside.
	return pressure_value >= zone_start() and pressure_value <= zone_end()


func _tick_hold(delta: float, held: bool) -> void:
	# Step one: the zone creeps upward, the needle follows the player's hold,
	# and the time inside the zone fills the cup. Time outside it after first
	# entering the zone accrues as drift and taxes the score later. A full hold
	# opens the pull; a hold that is still short when the window closes yields
	# no shot.
	zone_center += balance.zone_creep_per_second * delta
	_integrate_pressure(delta, held)
	if is_in_zone(pressure):
		_entered_zone = true
		fill = minf(fill + balance.hold_fill_per_second * delta, 1.0)
	elif _entered_zone:
		drift_seconds += delta
	if fill >= 1.0:
		step = Step.RELEASE
		_pull_armed = held
	elif elapsed >= balance.press_window_seconds:
		result = _grade_no_shot()


func _tick_pull(delta: float, held: bool) -> void:
	# Step two: the first lift after holding in the pull step is the release,
	# graded at the pressure the player last saw before this tick moves the
	# needle. If step one ended on a pump lift, wait for the player to hold
	# again before grading a release.
	if not held:
		if _pull_armed:
			result = _grade_release(pressure)
			return
		pull_elapsed += delta
		_integrate_pressure(delta, false)
		if pull_elapsed >= balance.pull_window_seconds:
			result = _grade_release(pressure)
		return
	_pull_armed = true
	pull_elapsed += delta
	_integrate_pressure(delta, true)
	if pull_elapsed >= balance.pull_window_seconds:
		result = _grade_release(pressure)


func _integrate_pressure(delta: float, held: bool) -> void:
	if held:
		pressure = minf(pressure + balance.pressure_build_per_second * delta, balance.pressure_max)
	else:
		pressure = maxf(pressure - balance.pressure_bleed_per_second * delta, 0.0)


func _grade_release(release_pressure: float) -> PressResult:
	# Early means sour, late means bitter, and the mark is the line between
	# them. Sloppy holding already taxed the base score through the drift.
	var distance := absf(release_pressure - balance.release_mark_pressure)
	var base := balance.pressed_score - drift_seconds * balance.drift_penalty_per_second
	var outcome: PressResult.Outcome
	if release_pressure < balance.release_mark_pressure - balance.perfect_tolerance:
		outcome = PressResult.Outcome.SOUR
	elif release_pressure > balance.release_mark_pressure + balance.perfect_tolerance:
		outcome = PressResult.Outcome.BITTER
	else:
		outcome = PressResult.Outcome.PRESSED
	var score := clampf(
		base - distance * balance.off_mark_penalty_per_unit,
		balance.off_mark_floor_score,
		balance.pressed_score
	)
	return PressResult.new(
		outcome, release_pressure, fill, drift_seconds, elapsed, score, _quality_factor(score)
	)


func _grade_no_shot() -> PressResult:
	# The window closed on an incomplete hold: no release, no shot. The fill
	# scales the weak score.
	var score := fill * balance.no_shot_score_max
	return PressResult.new(
		PressResult.Outcome.NO_SHOT,
		pressure,
		fill,
		drift_seconds,
		elapsed,
		score,
		_quality_factor(score)
	)


func _quality_factor(score: float) -> float:
	return clampf(score / balance.pressed_score, 0.0, 1.0)
