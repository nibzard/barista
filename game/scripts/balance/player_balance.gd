# ABOUTME: PlayerBalance holds the player tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/player.tres, never in scripts.
class_name PlayerBalance
extends Resource

@export var move_speed: float
@export var drink_slow_walk_factor: float
@export var dodge_duration_seconds: float
@export var dodge_speed: float
@export var hug_mash_presses_to_break: int
@export var hug_break_grace_seconds: float
