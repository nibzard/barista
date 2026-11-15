# ABOUTME: FishThrowersBalance holds the Fish Throwers fight tuning as a resource.
# ABOUTME: The numbers live in game/resources/balance/fish_throwers.tres, never in scripts.
class_name FishThrowersBalance
extends Resource

# The steady rhythm of the volley: one fish per beat, in seller order.
@export var volley_interval_seconds: float
# The flight speed of one thrown fish, in pixels per second.
@export var fish_speed: float
# How far one fish flies before it drops, in pixels.
@export var fish_flight_range: float
# A fish that lands on the player staggers them for this long, in seconds.
@export var fish_stun_seconds: float
# The market plays its volley only while the player stands inside this radius.
@export var volley_trigger_radius: float
# The line the crew speaks on the wake, section 6. Empty stays silent.
@export var cheer_line: String
