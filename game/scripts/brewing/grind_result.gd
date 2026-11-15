# ABOUTME: GrindResult is the frozen answer of one Grind Dial run.
# ABOUTME: Pure value object: the dial grades it, the view and tests read it.
class_name GrindResult
extends RefCounted

enum Outcome {
	HIT,
	WRONG_ZONE,
	MISS,
}

# Where the marker stopped. A miss always reports the coarse end.
var outcome: Outcome
var position: float
var distance_from_target: float
# The 0 to 100 grind score.
var score: float
# How much cup quality the grind keeps: 1 keeps it all, 0 ruins the cup.
var quality_factor: float


func _init(
	p_outcome: Outcome,
	p_position: float,
	p_distance_from_target: float,
	p_score: float,
	p_quality_factor: float
) -> void:
	outcome = p_outcome
	position = p_position
	distance_from_target = p_distance_from_target
	score = p_score
	quality_factor = p_quality_factor


func is_hit() -> bool:
	return outcome == Outcome.HIT
