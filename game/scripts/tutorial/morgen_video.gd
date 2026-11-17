# ABOUTME: MorgenVideo is the pure director track of the Dr. Morgen video of
# ABOUTME: section 22: subtitle beats, camera shots, and the small motions.
class_name MorgenVideo
extends RefCounted

# One camera setup per script beat. The last beat holds two: she looks back
# at the camera, then reaches for the phone, and the video stops.
enum Shot { WIDE, MEDIUM, CLOSE, REHEARSAL, LOOK_BACK, REACH }

# The section 22 script, split into subtitle beats across the video length.
# "Brew it strong" is the thesis line, so it closes the video.
const SCRIPT_LINES: Array[String] = [
	"If you see this, you drink real coffee. Good. Listen.",
	(
		"The extraction works. We removed the caffeine, and the body..."
		+ " the body keeps the count. Every missed hour."
	),
	"We did not know. They did not listen.",
	"It plays tonight. All channels. Do not watch it sleepy.",
	"I did a very bad thing. I leave it to you to correct it. Brew it strong.",
]

# The look back takes this share of the last beat; the reach fills the rest.
const LOOK_BACK_SHARE := 0.55
# The video stops on the cut inside the reach, this share before the end.
const CUT_SHARE := 0.1
# The phone leans against the beaker, so the framing never holds still.
const SWAY_PIXELS := Vector2(4.0, 3.0)
const SWAY_HZ := Vector2(0.6, 0.83)
const SWAY_ANGLE := 0.012
# She is tired: slow breathing, half-open lids, one blink about every three
# seconds.
const BREATH_PERIOD := 3.4
const BLINK_PERIOD := 3.1
const BLINK_SECONDS := 0.14
const TIRED_LID_OPENNESS := 0.45
# The rehearsal screen stands off-camera right; she watches it in one beat.
const GAZE_AT_SCREEN := Vector2(1.0, -0.1)
# The recording light of the phone blinks once per second.
const REC_PERIOD := 1.0
const REC_ON_SHARE := 0.6

var _video_seconds := 20.0


func _init(video_seconds: float = 20.0) -> void:
	# The pinned length rides the tutorial balance; the track scales every
	# beat to whatever length it receives.
	_video_seconds = maxf(video_seconds, 1.0)


func video_seconds() -> float:
	return _video_seconds


func beat_duration() -> float:
	return _video_seconds / float(SCRIPT_LINES.size())


func beat_at(elapsed: float) -> int:
	# The subtitle beat that owns the clock, clamped to the script.
	return clampi(int(elapsed / beat_duration()), 0, SCRIPT_LINES.size() - 1)


func subtitle_at(elapsed: float) -> String:
	return SCRIPT_LINES[beat_at(elapsed)]


func shot_at(elapsed: float) -> Shot:
	# The storyboard: the camera cuts with the script, one setup per beat.
	match beat_at(elapsed):
		0:
			return Shot.WIDE
		1:
			return Shot.MEDIUM
		2:
			return Shot.CLOSE
		3:
			return Shot.REHEARSAL
		_:
			# The last beat: she looks back, then reaches for the phone.
			var in_beat := _share_of_last_beat(elapsed)
			return Shot.REACH if in_beat >= LOOK_BACK_SHARE else Shot.LOOK_BACK


func is_over(elapsed: float) -> bool:
	return elapsed >= _video_seconds


func is_cut(elapsed: float) -> bool:
	# She reaches for the phone and the video stops: the cut owns the final
	# slice of the last beat.
	return elapsed >= _cut_start()


func reach_progress(elapsed: float) -> float:
	# Zero until the reach, then one smooth move of the hand that lands full
	# at the cut.
	var reach_start := _reach_start()
	if elapsed <= reach_start:
		return 0.0
	if elapsed >= _cut_start():
		return 1.0
	var share := (elapsed - reach_start) / (_cut_start() - reach_start)
	return share * share * (3.0 - 2.0 * share)


func gaze(elapsed: float) -> Vector2:
	# Where Morgen looks: at the camera, or off-camera at the rehearsal
	# screen for one beat.
	if shot_at(elapsed) == Shot.REHEARSAL:
		return GAZE_AT_SCREEN
	return Vector2.ZERO


func sway_offset(elapsed: float) -> Vector2:
	# The handheld drift of the leaning phone, in pixels.
	return (
		Vector2(sin(TAU * SWAY_HZ.x * elapsed), sin(TAU * SWAY_HZ.y * elapsed + 1.7)) * SWAY_PIXELS
	)


func sway_angle(elapsed: float) -> float:
	return sin(TAU * 0.47 * elapsed) * SWAY_ANGLE


func breath(elapsed: float) -> float:
	# One slow breath cycle, as a -1 to 1 offset for the body.
	return sin(TAU * elapsed / BREATH_PERIOD)


func lid_openness(elapsed: float) -> float:
	# Tired half-open lids that close fully for one blink.
	if fmod(maxf(elapsed, 0.0), BLINK_PERIOD) < BLINK_SECONDS:
		return 0.0
	return TIRED_LID_OPENNESS


func is_rec_on(elapsed: float) -> bool:
	# The recording light of the phone, on for the first share of each
	# second.
	return fmod(maxf(elapsed, 0.0), REC_PERIOD) < REC_PERIOD * REC_ON_SHARE


func rehearsal_glow(elapsed: float) -> float:
	# The rehearsal screen plays the address only while she watches it. The
	# picture flickers, so the glow never holds one value.
	if shot_at(elapsed) != Shot.REHEARSAL:
		return 0.0
	return 0.55 + 0.45 * (0.5 + 0.5 * sin(TAU * 6.5 * elapsed))


func light_flicker(elapsed: float) -> float:
	# The lab light at night breathes a little around one brightness.
	return 0.92 + 0.08 * (0.5 + 0.5 * sin(TAU * 1.3 * elapsed + 0.9))


func _share_of_last_beat(elapsed: float) -> float:
	var beat := beat_duration()
	return (elapsed - _last_beat_start()) / beat


func _last_beat_start() -> float:
	return beat_duration() * float(SCRIPT_LINES.size() - 1)


func _reach_start() -> float:
	return _last_beat_start() + beat_duration() * LOOK_BACK_SHARE


func _cut_start() -> float:
	return _video_seconds - beat_duration() * CUT_SHARE
