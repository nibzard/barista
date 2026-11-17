# ABOUTME: ColdBrewResult is the frozen answer of one cold brew steep.
# ABOUTME: Pure value object: the timer grades it, the caller and tests read it.
# ABOUTME: No outcome enum: a finished cold brew cannot fail, section 8.
class_name ColdBrewResult
extends RefCounted

# Seconds of steeping behind the cup. Always the full tuned duration.
var elapsed: float
# The 0 to 100 cup score. The method ceiling caps it below the perfect tier.
var score: float
# How much cup quality the brew keeps: 1 keeps it all, 0 ruins the cup.
var quality_factor: float


func _init(p_elapsed: float, p_score: float, p_quality_factor: float) -> void:
	elapsed = p_elapsed
	score = p_score
	quality_factor = p_quality_factor
