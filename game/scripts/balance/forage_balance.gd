# ABOUTME: ForageBalance holds the section 6 foraging values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/forage.tres, never in scripts.
class_name ForageBalance
extends Resource

# The V1 switch of the rule "they eat everything they find": false stands the
# whole behavior down, so the scope call needs no code change.
@export var foraging_enabled: bool = true
# How far a sleeping sleepwalker smells food, in pixels.
@export var smell_radius: float
# The walk speed of a sleepwalker that heads for food.
@export var forage_speed: float
# How close a sleepwalker must stand before the meal starts.
@export var eat_range: float
# How long one meal lasts, in seconds.
@export var eat_duration_seconds: float
