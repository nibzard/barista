# ABOUTME: OutroBalance holds the tuning values of the version ending as a resource.
# ABOUTME: The numbers live in game/resources/balance/outro.tres, never in scripts.
class_name OutroBalance
extends Resource

# The Karen marches in from the east edge and blocks the road, in seconds.
@export var karen_march_seconds: float
# She demands the manager this long before the credits catch her, in seconds.
@export var demand_hold_seconds: float
# The credits roll this long before they end on their own, in seconds.
@export var credits_roll_seconds: float
