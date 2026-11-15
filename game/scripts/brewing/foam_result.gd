# ABOUTME: FoamResult is the frozen answer of one The Foam Watch run.
# ABOUTME: Pure value object: the watch grades it, the view and tests read it.
class_name FoamResult
extends RefCounted

enum Outcome {
	LIFTED,
	BOILED_OVER,
	COLD,
}

var outcome: Outcome
# The pot heat at the end, from a cold pot 0.0 to a full boil 1.0.
var heat: float
# The foam at the end, from none 0.0 to the rim 1.0.
var foam: float
# Seconds the foam sat at the rim before the end.
var at_rim_seconds: float
# Seconds of the whole run when the watch ended.
var elapsed_seconds: float
# The 0 to 100 foam watch score.
var score: float
# How much cup quality the watch keeps: 1 keeps it all, 0 ruins the cup.
var quality_factor: float


func _init(
	p_outcome: Outcome,
	p_heat: float,
	p_foam: float,
	p_at_rim_seconds: float,
	p_elapsed_seconds: float,
	p_score: float,
	p_quality_factor: float
) -> void:
	outcome = p_outcome
	heat = p_heat
	foam = p_foam
	at_rim_seconds = p_at_rim_seconds
	elapsed_seconds = p_elapsed_seconds
	score = p_score
	quality_factor = p_quality_factor


func is_lifted() -> bool:
	return outcome == Outcome.LIFTED
