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
# Section 15: the stock one scavenge crate of the shared kit holds. The house
# beans refill the bag; the scrap parts pay for the van upgrades, so the crate
# stock moves with the van costs in mobile_cafe.tres.
@export var scavenge_house_beans: int
@export var scavenge_scrap_parts: int
# Section 15: the region bean stock one scavenge crate of a region city holds
# on top of the house beans. Stays at or under the house bean stock, so the
# good bean of the region is never the common one.
@export var scavenge_region_beans: int
# Section 6, T109: the coffee seedling stock one scavenge crate holds, so the
# plantable bait of the foraging rule waits along the whole three-city route.
# Stays at or under the seedling stack limit, so one crate hands its whole
# stock to an empty bag in one visit.
@export var scavenge_seedlings: int
# Section 10: the cafe safe zone grows with the cafe tier of the city. Index 0
# serves tier 1, and the last entry serves every tier above it.
@export var cafe_zone_radius_per_tier: Array[float] = [180.0, 240.0, 300.0]
