# ABOUTME: CureWeaponsBalance holds the cure weapon tuning of section 11: the
# ABOUTME: areas, the arcs, and the clocks. The cup costs live in coffee_supply.tres.
class_name CureWeaponsBalance
extends Resource

# The Travel Mug: a sealed steel mug. The lid keeps the coffee inside, so the
# flight spends no cups. The mug ricochets to a second sleeper and rolls back.
@export var travel_mug_throw_range: float
@export var travel_mug_flight_time_seconds: float
# The seek radius for the second sleeper of the bounce. The bounce needs no
# line of sight: the mug curves around corners, section 11.
@export var travel_mug_bounce_seek_radius: float
@export var travel_mug_bounce_flight_time_seconds: float
@export var travel_mug_return_speed: float

# The Thermos: a thrown flask that breaks and splashes a wide area.
@export var thermos_throw_range: float
@export var thermos_flight_time_seconds: float
@export var thermos_arc_peak_height: float
@export var thermos_splash_radius: float

# The French Press: a pump-action cone for close range. One pump loads, the
# next pump fires.
@export var french_press_reach: float
@export var french_press_half_angle_degrees: float

# The Moka Launcher: pressurized pots on a high arc. The coffee brews during
# the flight and bursts in a large area.
@export var moka_throw_range: float
@export var moka_flight_time_seconds: float
@export var moka_arc_peak_height: float
@export var moka_splash_radius: float

# The Coffee Minigun: a continuous stream in a narrow cone.
@export var minigun_range: float
@export var minigun_half_angle_degrees: float

# The Auto-Drip Turret: a deployable drip tower. It drips on every
# sleepwalker below it and works alone until the tank runs dry.
@export var turret_drip_radius: float
@export var turret_drip_interval_seconds: float
@export var turret_tank_seconds: float
