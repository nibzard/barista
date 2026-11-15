# ABOUTME: Aisle7Balance holds the Aisle 7 quest tuning values as a typed
# ABOUTME: resource. The numbers live in game/resources/balance/aisle_7.tres.
class_name Aisle7Balance
extends Resource

# The wife walks to her husband at this speed when he wakes.
@export var wife_walk_speed: float
# The player stands inside this radius of the husband to brew one Turkish cup
# in front of him.
@export var brew_stand_radius: float
# The wife stops at this distance from her husband: the two figures stand side
# by side in the hug pose.
@export var hug_arrive_radius: float
# The sweet hug holds for this many seconds before the husband opens his
# school as the Turkish master.
@export var master_unlock_delay: float
