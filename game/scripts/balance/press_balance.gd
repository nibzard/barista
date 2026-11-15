# ABOUTME: PressBalance holds The Press minigame tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/press.tres, never in scripts.
class_name PressBalance
extends Resource

# Pressure gained per second while the player holds.
@export var pressure_build_per_second: float
# Pressure lost per second while the player is lifted off.
@export var pressure_bleed_per_second: float
# The pressure hard cap. The needle may overshoot past 1.0 into the overload band.
@export var pressure_max: float
# The center of the green zone at the start of the hold.
@export var zone_start_center: float
# The full width of the green zone, in pressure units.
@export var zone_width: float
# How far the green zone center creeps upward per second.
@export var zone_creep_per_second: float
# Hold fill gained per second while the pressure stays inside the zone.
@export var hold_fill_per_second: float
# Total seconds the hold may take. A hold that is not full when the window
# closes yields no shot.
@export var press_window_seconds: float
# The exact mark: the release pressure that makes an even cup.
@export var release_mark_pressure: float
# How far from the mark a release still counts as on the mark.
@export var perfect_tolerance: float
# Total seconds the pull may run with no release before it grades itself.
@export var pull_window_seconds: float
# The score for a clean press before drift damage.
@export var pressed_score: float
# Score lost per second the hold spent outside the green zone.
@export var drift_penalty_per_second: float
# Score lost per unit of pressure distance between the release and the mark.
@export var off_mark_penalty_per_unit: float
# The lowest score a sour or bitter cup can take. Some coffee beats none.
@export var off_mark_floor_score: float
# The highest score a no-shot press can reach. The fill scales it down.
@export var no_shot_score_max: float
