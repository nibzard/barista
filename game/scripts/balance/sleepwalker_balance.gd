# ABOUTME: SleepwalkerBalance holds the sleepwalker tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/sleepwalker.tres, never in scripts.
class_name SleepwalkerBalance
extends Resource

@export var walk_speed: float
@export var chase_speed: float
@export var wander_change_min_seconds: float
@export var wander_change_max_seconds: float
@export var idle_chance: float
