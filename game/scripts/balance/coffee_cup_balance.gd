# ABOUTME: CoffeeCupBalance holds the thrown-cup tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/coffee_cup.tres, never in scripts.
class_name CoffeeCupBalance
extends Resource

@export var flight_time_seconds: float
@export var throw_range: float
@export var arc_peak_height: float
@export var aim_cone_half_angle_degrees: float
