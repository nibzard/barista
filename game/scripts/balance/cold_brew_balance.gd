# ABOUTME: ColdBrewBalance holds the cold brew tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/cold_brew.tres, never in scripts.
class_name ColdBrewBalance
extends Resource

# Seconds of steeping before the cold brew cup is ready. The player starts
# the brew and comes back later, so the timer spans play, not one screen.
@export var steep_seconds: float
