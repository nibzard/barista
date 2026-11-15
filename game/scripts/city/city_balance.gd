# ABOUTME: CityBalance holds the section 17 level design rules as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/city.tres, never in scripts.
class_name CityBalance
extends Resource

@export var min_blocks: int
@export var max_blocks: int
@export var density_min: int
@export var density_max: int
@export var speaker_pole_count: int
@export var blocks_per_screen: float
# Section 10: the cafe safe zone grows with the cafe tier of the city. Index 0
# serves tier 1, and the last entry serves every tier above it.
@export var cafe_zone_radius_per_tier: Array[float] = [180.0, 240.0, 300.0]
