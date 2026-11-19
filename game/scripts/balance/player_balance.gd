# ABOUTME: PlayerBalance holds the player tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/player.tres, never in scripts.
class_name PlayerBalance
extends Resource

@export var move_speed: float
@export var drink_slow_walk_factor: float
@export var dodge_cooldown_seconds: float
@export var dodge_duration_seconds: float
@export var dodge_speed: float
@export var hug_mash_presses_to_break: int
@export var hug_break_grace_seconds: float
# The serve action, section 6: the arm's reach for handing one cup straight
# to a sleeper. The tinfoil hat stops thrown coffee only, so the Turkish
# cure of the Tinfoil Man travels this reach.
@export var serve_reach: float
