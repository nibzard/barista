# ABOUTME: RoastProfile defines one roast level and its wake power as data.
# ABOUTME: Light roast keeps the most caffeine, so it gives the best wake power.
class_name RoastProfile
extends Resource

enum Kind {
	LIGHT,
	MEDIUM,
	DARK,
}

@export var roast_id: String
@export var display_name: String
@export var kind: Kind
@export var wake_power_factor: float
