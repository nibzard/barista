# ABOUTME: SleepwalkerCure maps one sleepwalker type to the recipe that wakes it.
# ABOUTME: Basic types wake from any coffee, so their cure recipe id stays empty.
class_name SleepwalkerCure
extends Resource

@export var sleeper_type_id: String
@export var display_name: String
@export var is_basic: bool
@export var cure_recipe_id: String
