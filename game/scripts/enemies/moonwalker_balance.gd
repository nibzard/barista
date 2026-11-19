# ABOUTME: MoonwalkerBalance tunes the Moonwalker mystery of section 24.
# ABOUTME: The numbers live in game/resources/balance/moonwalker.tres.
class_name MoonwalkerBalance
extends Resource

# The dawn window, section 24: the figure shows only at dawn. One in-city day
# runs this long, and dawn holds this many seconds of it.
@export var day_cycle_seconds: float
@export var dawn_length_seconds: float
# The fight, section 6: he never walks forward, he slides backwards, fast.
@export var slide_speed: float
@export var slide_duration_seconds: float
# The telegraph runs in reverse: the signal lands after the slide, so a
# player who answers it answers a move that already happened.
@export var telegraph_seconds: float
@export var rest_seconds: float
# He does not hug. He leans far back and slides under the guard, and the
# graze brushes the meter for this much, at most once per cooldown.
@export var graze_meter_cost: float
@export var graze_cooldown_seconds: float
# The spawn: he slides backwards across the plaza, so he enters at this
# distance from the silent zone center.
@export var appear_distance: float
# The finale of the wake, section 24: one spin, one toe stand, one small
# "hee-hee", each one beat long.
@export var finale_beat_seconds: float
# The dance-off: this many beats, the first after this delay, then one every
# interval. Taps inside the windows score; the win needs this many hits.
@export var dance_beat_count: int
@export var dance_first_beat_delay_seconds: float
@export var dance_beat_interval_seconds: float
@export var dance_perfect_window_seconds: float
@export var dance_good_window_seconds: float
@export var dance_win_hits: int
