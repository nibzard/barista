# ABOUTME: TutorialBalance holds the tuning values of the first ten minutes as a resource.
# ABOUTME: The numbers live in game/resources/balance/tutorial.tres, never in scripts.
class_name TutorialBalance
extends Resource

# The Dr. Morgen video plays this long before it ends on its own, section 19.
@export var video_seconds: float
# The player wakes groggy from the video: the meter starts here so the first
# drink visibly fills it, section 19 step 3.
@export var wake_meter_value: float
# How far the player must walk before the move prompt lands, in pixels.
@export var move_min_distance: float
# The speaker pole of the safe-zone lesson covers this radius around the door.
@export var pole_zone_radius: float
# The pole lesson needs this many seconds of drain before the step can end.
@export var pole_min_seconds: float
# The survivor speaks when the player comes this close, in pixels.
@export var survivor_notice_radius: float
# The survivor stands this far outside the cafe safe zone, at the door.
@export var survivor_door_gap: float
# Where the scripted Neighbor spawns on the cafe block, as a size fraction.
@export var window_neighbor_fraction: Vector2
# How long spoken lines hold above the world, in seconds.
@export var line_hold_seconds: float
# The finale camera pan across the whole city, in seconds.
@export var finale_pan_seconds: float
# The three-city map holds alone before the title card shows, in seconds.
@export var finale_map_hold_seconds: float
# The title card holds before the game returns, in seconds.
@export var title_hold_seconds: float
# The fade buffer after the title card, in seconds.
@export var finale_fade_seconds: float
# The camera zoom margin: 0.95 leaves a small border around the city.
@export var finale_zoom_margin: float
