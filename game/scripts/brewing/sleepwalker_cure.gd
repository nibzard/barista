# ABOUTME: SleepwalkerCure maps one sleepwalker type to the recipe that wakes it.
# ABOUTME: Basic types wake from any coffee, so their cure recipe id stays empty.
class_name SleepwalkerCure
extends Resource

@export var sleeper_type_id: String
@export var display_name: String
@export var is_basic: bool
@export var cure_recipe_id: String
# Section 6, the Withdrawer: zero holds the wake forever. A value above zero
# means the sleeper needs a second cup inside that many seconds.
@export var second_cup_window_seconds: float = 0.0
# Section 15: the roast sets the wake power of a cup. This strength says
# which roasts can wake the sleeper: a good cup whose roast factor sits
# below the strength cannot wake it. Basic types stay at zero, so any cup
# wakes them.
@export var wake_resistance: float = 0.0
