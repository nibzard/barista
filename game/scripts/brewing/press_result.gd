# ABOUTME: PressResult is the frozen answer of one The Press run.
# ABOUTME: Pure value object: the press grades it, the view and tests read it.
class_name PressResult
extends RefCounted

enum Outcome {
	PRESSED,
	SOUR,
	BITTER,
	NO_SHOT,
}

var outcome: Outcome
# The gauge pressure at the release. A no-shot reports the window-close pressure.
var pressure: float
# The hold fill at the end, from an empty cup 0.0 to a full hold 1.0.
var fill: float
# Seconds the hold spent outside the green zone.
var drift_seconds: float
# Seconds of the whole run when the press ended.
var elapsed_seconds: float
# The 0 to 100 press score.
var score: float
# How much cup quality the press keeps: 1 keeps it all, 0 ruins the cup.
var quality_factor: float


func _init(
	p_outcome: Outcome,
	p_pressure: float,
	p_fill: float,
	p_drift_seconds: float,
	p_elapsed_seconds: float,
	p_score: float,
	p_quality_factor: float
) -> void:
	outcome = p_outcome
	pressure = p_pressure
	fill = p_fill
	drift_seconds = p_drift_seconds
	elapsed_seconds = p_elapsed_seconds
	score = p_score
	quality_factor = p_quality_factor


func is_pressed() -> bool:
	return outcome == Outcome.PRESSED
