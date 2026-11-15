# ABOUTME: SleepJamBalance holds the Sleep Jam fight tuning as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/sleep_jam.tres, never in scripts.
class_name SleepJamBalance
extends Resource

# The reach of the endless song, section 6: inside the radius, the lullaby
# drains the player meter at the boring-attack rate of section 14.
@export var lullaby_radius: float
# The line the band speaks on the wake, section 6. Empty stays silent.
@export var wake_line: String
