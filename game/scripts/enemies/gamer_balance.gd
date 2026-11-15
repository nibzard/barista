# ABOUTME: GamerBalance holds the dash tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/gamer.tres, never in scripts.
class_name GamerBalance
extends Resource

@export var dash_speed: float
@export var dash_duration_seconds: float
@export var windup_seconds: float
@export var rest_seconds: float
