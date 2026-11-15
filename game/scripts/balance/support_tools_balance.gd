# ABOUTME: SupportToolsBalance holds the support tool tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/support_tools.tres, never in scripts.
class_name SupportToolsBalance
extends Resource

# The Tamper, section 11: one melee push, one stagger, one sleepwalker.
@export var tamper_reach: float
@export var tamper_half_angle_degrees: float
@export var tamper_stagger_seconds: float
@export var tamper_push_speed: float
@export var tamper_push_seconds: float
@export var tamper_cooldown_seconds: float

# The Steam Wand, section 11: a melee cone of steam. The swing opens the
# parry window of section 14; a parried hug staggers for the parry time.
@export var steam_wand_reach: float
@export var steam_wand_half_angle_degrees: float
@export var steam_wand_stagger_seconds: float
@export var steam_wand_cooldown_seconds: float
@export var parry_window_seconds: float
@export var parry_stagger_seconds: float

# The Portafilter, section 11: a raised shield that blocks hugs, plus a bash.
@export var portafilter_block_stagger_seconds: float
@export var portafilter_block_push_speed: float
@export var portafilter_block_push_seconds: float
@export var portafilter_bash_reach: float
@export var portafilter_bash_half_angle_degrees: float
@export var portafilter_bash_stagger_seconds: float
@export var portafilter_bash_push_speed: float
@export var portafilter_bash_push_seconds: float
@export var portafilter_bash_cooldown_seconds: float

# The Iced Sprayer, section 11: iced coffee wakes nobody, but brain freeze
# slows every sleepwalker it touches.
@export var sprayer_reach: float
@export var sprayer_half_angle_degrees: float
@export var brain_freeze_seconds: float
@export var brain_freeze_speed_factor: float
@export var sprayer_cooldown_seconds: float

# The Bean Slick, section 11: dropped beans on the floor. A sleepwalker that
# steps on them slips, slides, and stays down for a beat.
@export var bean_slick_radius: float
@export var bean_slick_lifetime_seconds: float
@export var bean_slick_cooldown_seconds: float
@export var slip_slide_speed: float
@export var slip_slide_seconds: float
@export var slip_down_seconds: float
