# ABOUTME: GrindDialBalance holds the Grind Dial tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/grind_dial.tres, never in scripts.
class_name GrindDialBalance
extends Resource

# How fast the marker runs from fine to coarse, in dial units per second.
@export var marker_speed_units_per_second: float
# The score for a stop inside the correct zone of the method.
@export var hit_score: float
# Score lost per dial unit of distance beyond the zone edge.
@export var wrong_zone_penalty_per_unit: float
# The lowest score a stopped-but-wrong grind can still reach.
@export var wrong_zone_floor_score: float
# The score for a marker that ran off the dial with no stop at all.
@export var miss_score: float
