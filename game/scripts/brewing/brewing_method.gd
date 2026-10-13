# ABOUTME: BrewingMethod defines one of the eight brewing methods as data.
# ABOUTME: It holds the Grind Dial target zone and the minigame group it plays.
class_name BrewingMethod
extends Resource

enum MinigameGroup {
	NONE,
	POUR,
	PRESS,
	FOAM_WATCH,
}

@export var method_id: String
@export var display_name: String
@export var minigame_group: MinigameGroup
@export var grind_target: float
@export var grind_tolerance: float
