# ABOUTME: SamOatmanBalance holds the Sam Oatman fight tuning as a resource.
# ABOUTME: The numbers live in game/resources/balance/sam_oatman.tres.
class_name SamOatmanBalance
extends Resource

# The 700-dollar designer dripper of the guru, section 15: the scavenge gear
# the cure brews through, waiting beside the demo table.
@export var dripper_item: ItemType
# The length of the opening slides phase, in seconds: the boring show.
@export var slides_seconds: float
# The length of the live demo phase, in seconds: the drones fly.
@export var demo_seconds: float
# The reach of the boring slides, section 6: inside the radius, the show
# drains the player meter at the boring-attack rate of section 14.
@export var slides_radius: float
# The drones the live demo phase sends at the player.
@export var demo_drones: int
# The drones the endless finale phase sends at the player.
@export var finale_drones: int
# The line every fight phase starts with, section 6. Empty stays silent.
@export var phase_line: String
# The line the guru speaks on the wake, section 6. Empty stays silent.
@export var wake_line: String
