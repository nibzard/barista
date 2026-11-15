# ABOUTME: TouchControlsBalance holds the virtual stick tuning as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/touch_controls.tres, never in scripts.
class_name TouchControlsBalance
extends Resource

# How far the thumb rests before a drag counts as a move, in pixels from the
# stick center.
@export var stick_dead_zone_pixels: float
# How far the thumb fully tilts the stick, in pixels from the stick center.
@export var stick_max_distance_pixels: float
