# ABOUTME: PourResult is the frozen answer of one The Pour run.
# ABOUTME: Pure value object: the bloom grades it, the view and tests read it.
class_name PourResult
extends RefCounted

enum Outcome {
	BLOOMED,
	FLOODED,
	STALLED,
}

var outcome: Outcome
# The bloom fill at the end, from a dry bed 0.0 to a full ring 1.0.
var fill: float
# Excess water still pooled at the end.
var excess: float
# Seconds of brew window spent when the brew ended.
var elapsed_seconds: float
# The 0 to 100 pour score.
var score: float
# How much cup quality the pour keeps: 1 keeps it all, 0 ruins the cup.
var quality_factor: float


func _init(
	p_outcome: Outcome,
	p_fill: float,
	p_excess: float,
	p_elapsed_seconds: float,
	p_score: float,
	p_quality_factor: float
) -> void:
	outcome = p_outcome
	fill = p_fill
	excess = p_excess
	elapsed_seconds = p_elapsed_seconds
	score = p_score
	quality_factor = p_quality_factor


func is_bloomed() -> bool:
	return outcome == Outcome.BLOOMED
