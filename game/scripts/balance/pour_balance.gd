# ABOUTME: PourBalance holds The Pour minigame tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/pour.tres, never in scripts.
class_name PourBalance
extends Resource

# The slow edge of the sweet spot, in pour-rate units from 0.0 to 1.0.
@export var sweet_spot_start: float
# The fast edge of the sweet spot.
@export var sweet_spot_end: float
# Bloom fill gained per second while the pour stays inside the sweet spot.
@export var fill_rate_per_second: float
# Bloom fill lost per second while the pour runs below the sweet spot.
@export var dry_rate_per_second: float
# Excess water pooled per second, per unit of rate beyond the sweet-spot end.
@export var flood_build_multiplier: float
# Excess water drained per second while the pour stays at or below the end.
@export var drain_rate_per_second: float
# Excess water at which the bed floods and the brew fails.
@export var flood_excess: float
# Total pour window in seconds. A ring that is not full when it closes stalls.
@export var brew_window_seconds: float
# The score for a full bloom before flood damage.
@export var bloomed_score: float
# Score lost per unit of excess water still pooled when the ring fills.
@export var excess_penalty_per_unit: float
# The score for a flooded bed.
@export var flood_score: float
# The highest score a stalled bloom can reach. The fill scales it down.
@export var stalled_score_max: float
# Seconds one full circle around the ring takes at pour rate 1.0.
@export var full_turn_seconds: float
