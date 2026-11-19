# ABOUTME: RobotaxiDepotBalance holds the Robotaxi Depot quest tuning values
# ABOUTME: as a typed resource. The numbers live in the .tres beside it.
class_name RobotaxiDepotBalance
extends Resource

# The robotaxi drives at this speed, in pixels per second.
@export var cab_speed: float
# The cab takes a sleeper aboard when it comes this close, in pixels.
@export var pickup_radius: float
# The cab drops the sleeper beside the player at this distance, in pixels.
@export var delivery_radius: float
# One ride ends; the next haul starts after this many seconds.
@export var delivery_cooldown: float
# The first haul of a run waits this many seconds after the player takes the
# quest, so the fleet never surprises a player who just walked in.
@export var first_ride_delay: float
# The cab serves only sleepers at least this far from the player, in pixels,
# so a haul always fetches its passenger from somewhere else in the city.
@export var pickup_min_player_distance: float
# The interact key hails a ride at a taxi stand inside this radius, in pixels.
@export var stand_notice_radius: float
# The quest accepts when the player comes this close to the sleeping engineer,
# in pixels.
@export var depot_notice_radius: float
