# ABOUTME: AddressAudioBalance holds the section 21 sound rules as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/address_audio.tres, never in scripts.
class_name AddressAudioBalance
extends Resource

# The loop every speaker pole plays, section 21: 5 seconds of the address.
@export var loop_seconds: float
# The pole zone radius marks the near layer; the mid reach holds recognizable
# words; everything beyond is the low muffled rumble.
@export var near_radius: float
@export var mid_radius: float
# The address never plays at full volume: every layer stays below 0 dB.
@export var far_volume_db: float
@export var mid_volume_db: float
@export var near_volume_db: float
# The address always arrives filtered: the low-pass cutoff per layer rises
# with clarity but never opens fully.
@export var far_low_pass_hz: float
@export var mid_low_pass_hz: float
@export var near_low_pass_hz: float
# Two pole offsets stay at least this far apart on the loop circle, so the
# loops never sync.
@export var sync_guard_seconds: float
# A hug swells the address for the grabbed player by this much.
@export var hug_swell_db: float
# The antagonist track gets loud inside this radius of a sleeping enemy.
@export var antagonist_radius: float
@export var antagonist_far_volume_db: float
@export var antagonist_close_volume_db: float
# The morning birdsong after the tower cut plays at this volume.
@export var birdsong_volume_db: float
# The tower owns the cut clock: the address stops mid-word, this much silence
# passes, then the birdsong plays.
@export var silence_seconds: float
# The tolerance rule: every sound must stay tolerable after this many minutes.
@export var tolerance_minutes: float
# Past the tolerance limit, the deeper filter the address drops to.
@export var tolerance_filter_hz: float
