# ABOUTME: FoamWatchBalance holds The Foam Watch tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/foam_watch.tres, never in scripts.
class_name FoamWatchBalance
extends Resource

# Heat gained per second. At heat 1.0 the boil starts and the foam rises.
@export var heat_rate_per_second: float
# Foam gained per second below the rush line.
@export var foam_rate_per_second: float
# The foam level where the rise turns into a rush.
@export var rush_start_foam: float
# The foam rate multiplier above the rush line. The last stretch comes fast.
@export var rush_multiplier: float
# Seconds the foam may sit at the rim before the pot boils over. This window
# is the last safe moment.
@export var boil_over_grace_seconds: float
# The score for a lift at the rim, before any damage.
@export var lifted_score: float
# The score for a pot that boiled over. Greed costs the cup.
@export var boil_over_score: float
# The score for a lift before the boil. A cold pot holds no foam.
@export var cold_score: float
