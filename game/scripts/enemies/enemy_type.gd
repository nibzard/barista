# ABOUTME: EnemyType is the data-driven definition of one sleepwalker type.
# ABOUTME: Each type carries one special behavior and one required cure.
class_name EnemyType
extends Resource

enum SpecialBehavior {
	SIMPLE_HUG,
	PHOTO_FLASH,
	DRONE_ATTACK,
	DASH_CHARGE,
	TINFOIL_HAT,
	KAREN_SURPRISE,
}

@export var type_id: String
@export var display_name: String
@export var special_behavior: SpecialBehavior = SpecialBehavior.SIMPLE_HUG
@export var pajama_color: Color
@export var cure: SleepwalkerCure
# The line the sleeper speaks on the wake, section 6. Empty stays silent.
@export var wake_line: String
