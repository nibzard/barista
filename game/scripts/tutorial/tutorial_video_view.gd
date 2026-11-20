# ABOUTME: TutorialVideoView draws the produced Dr. Morgen video of section 22:
# ABOUTME: the night lab through the leaning phone, 2D stills with small motions.
class_name TutorialVideoView
extends Control

# The night lab of section 22, INT. LAB, NIGHT. The phone leans against the
# beaker and records, so the camera never sees the phone itself: it sees its
# own sway, its recording light, and the hand that comes for it at the end.
const BG_COLOR := Color(0.02, 0.02, 0.045, 1.0)
const WALL_COLOR := Color(0.055, 0.05, 0.07, 1.0)
const TABLE_COLOR := Color(0.16, 0.13, 0.1, 1.0)
const TABLE_FACE_COLOR := Color(0.1, 0.08, 0.07, 1.0)
const SHELF_COLOR := Color(0.12, 0.1, 0.09, 1.0)
const JAR_COLOR := Color(0.14, 0.18, 0.17, 0.9)
const COAT_COLOR := Color(0.86, 0.86, 0.82, 1.0)
const SKIN_COLOR := Color(0.9, 0.72, 0.58, 1.0)
const HAIR_COLOR := Color(0.25, 0.18, 0.12, 1.0)
const BEAKER_COLOR := Color(0.55, 0.75, 0.8, 0.5)
const LIQUID_COLOR := Color(0.35, 0.5, 0.3, 0.9)
const BUBBLE_COLOR := Color(0.5, 0.68, 0.42, 0.8)
const STEAM_COLOR := Color(0.8, 0.85, 0.85, 1.0)
const SCREEN_FRAME_COLOR := Color(0.05, 0.05, 0.06, 1.0)
const SCREEN_DARK_COLOR := Color(0.03, 0.04, 0.05, 1.0)
const WAVE_COLOR := Color(0.9, 0.2, 0.15, 1.0)
const CUP_GLYPH_COLOR := Color(0.95, 0.9, 0.85, 1.0)
const REC_COLOR := Color(0.85, 0.15, 0.12, 1.0)
const BAND_COLOR := Color(0.0, 0.0, 0.0, 0.88)
const VIGNETTE_COLOR := Color(0.0, 0.0, 0.0, 0.28)
const OVERLAY_TEXT_COLOR := Color(0.75, 0.78, 0.75, 0.9)
const STATIC_COLOR := Color(0.7, 0.72, 0.7, 0.35)
# The lab set, in one local frame: the wall, the table, the beaker left, the
# rehearsal monitor right, and Morgen in lab clothes behind the table.
const WALL_RECT := Rect2(-420.0, -260.0, 840.0, 300.0)
const TABLE_RECT := Rect2(-420.0, 40.0, 840.0, 36.0)
const TABLE_FACE_RECT := Rect2(-420.0, 76.0, 840.0, 220.0)
const SHELF_RECT := Rect2(-420.0, -170.0, 300.0, 8.0)
const JAR_RECTS: Array[Rect2] = [
	Rect2(-390.0, -196.0, 22.0, 26.0),
	Rect2(-350.0, -192.0, 18.0, 22.0),
	Rect2(-300.0, -198.0, 26.0, 28.0),
]
const BEAKER_BASE := Vector2(-150.0, 40.0)
const BEAKER_RECT := Rect2(-166.0, -24.0, 32.0, 64.0)
const MONITOR_RECT := Rect2(170.0, -112.0, 112.0, 80.0)
const MONITOR_SCREEN_RECT := Rect2(178.0, -104.0, 96.0, 56.0)
const MONITOR_STAND_RECT := Rect2(216.0, -32.0, 20.0, 72.0)
# Morgen stands center, tired, hair down, in lab clothes.
const HAIR_RECT := Rect2(-32.0, -138.0, 64.0, 82.0)
const COAT_RECT := Rect2(-46.0, -80.0, 92.0, 150.0)
const HEAD_CENTER := Vector2(0.0, -104.0)
const HEAD_RADIUS := 26.0
const EYE_OFFSETS: Array[Vector2] = [Vector2(-10.0, -108.0), Vector2(10.0, -108.0)]
const MOUTH_SPAN := Vector2(-6.0, -88.0)
const MOUTH_WIDTH := Vector2(12.0, 0.0)
const BREATH_PIXELS := 2.0
const GAZE_PIXELS := 5.0
# The storyboard framing: one zoom and focus per shot of the director track.
const WIDE_ZOOM := 1.0
const MEDIUM_ZOOM := 1.6
const CLOSE_ZOOM := 2.2
const REHEARSAL_ZOOM := 1.35
const REACH_ZOOM := 1.75
const WIDE_FOCUS := Vector2(0.0, -10.0)
const MEDIUM_FOCUS := Vector2(0.0, -70.0)
const CLOSE_FOCUS := Vector2(0.0, -104.0)
const REHEARSAL_FOCUS := Vector2(110.0, -40.0)
const REACH_FOCUS := Vector2(0.0, -70.0)
# The hand comes for the phone, so the framing lurches as it arrives.
const REACH_LURCH_ANGLE := 0.05
const REACH_ZOOM_PUNCH := 0.12
const HAND_START_FRACTION := Vector2(0.12, 1.08)
const HAND_TARGET_FRACTION := Vector2(0.5, 0.42)
const HAND_ARM_WIDTH := 26.0
const HAND_RADIUS := 16.0
# The phone overlay: recording light, timestamp, and a soft phone-camera
# letterbox. The lab clock starts at 23:58, the night of the address.
const REC_CENTER := Vector2(34.0, 34.0)
const REC_RADIUS := 6.0
const REC_TEXT := "REC"
const REC_TEXT_SIZE := 16
const TIMESTAMP_TEXT_SIZE := 16
const TIMESTAMP_START_MINUTE := 58
const BAND_HEIGHTS := Vector2(46.0, 64.0)
const VIGNETTE_WIDTH := 40.0
# The cut: the video stops, and a burst of static fills the last frames.
const STATIC_DOTS := 30
const STATIC_JITTER_HZ := 60.0
const PANEL_PATHS: Array[String] = [
	"res://assets/art/intro/morgen_panel_1.jpg",
	"res://assets/art/intro/morgen_panel_2.jpg",
	"res://assets/art/intro/morgen_panel_3.jpg",
	"res://assets/art/intro/morgen_panel_4.jpg",
]

var _model := MorgenVideo.new()
var _elapsed := 0.0
var _panels: Array[Texture2D] = []

@onready var subtitle_label: Label = $SubtitleLabel
@onready var voice_player: AudioStreamPlayer = $VoicePlayer


func setup(video_seconds: float) -> void:
	# The pinned length rides the tutorial balance, section 19 step 1.
	_model = MorgenVideo.new(video_seconds)


func reset() -> void:
	_elapsed = 0.0
	subtitle_label.text = current_line()
	queue_redraw()


func start() -> void:
	# The produced video rolls: the track resets and the placeholder voice
	# speaks under the subtitles. The real voice lands with T054; a headless
	# run stays silent so its input pipeline never sees audio activity.
	reset()
	var voice_live := DisplayServer.get_name() != "headless"
	if voice_live:
		voice_player.stream = PlaceholderTones.morgen_voice_track(_model.video_seconds())
		voice_player.play()


func stop() -> void:
	# A skip or the end stops the voice with the picture.
	voice_player.stop()


func set_progress(fraction: float) -> void:
	# The director reports the played share of the video; the view plays the
	# track from it.
	_elapsed = clampf(fraction, 0.0, 1.0) * _model.video_seconds()
	subtitle_label.text = current_line()
	queue_redraw()


func current_line() -> String:
	return _model.subtitle_at(_elapsed)


func shot() -> MorgenVideo.Shot:
	return _model.shot_at(_elapsed)


func is_cut() -> bool:
	return _model.is_cut(_elapsed)


func _draw() -> void:
	if _model.is_cut(_elapsed):
		_draw_cut()
		return
	var flicker := _model.light_flicker(_elapsed)
	draw_rect(Rect2(Vector2.ZERO, size), _dim(BG_COLOR, flicker))
	if not _draw_illustrated_panel(flicker):
		_draw_scene(flicker)
		_draw_reach_hand()
	_draw_overlay()
	_draw_caption_card()


func _ensure_panels() -> void:
	if not _panels.is_empty():
		return
	for path: String in PANEL_PATHS:
		if ResourceLoader.exists(path):
			_panels.append(load(path) as Texture2D)


func _panel_for_shot(current_shot: MorgenVideo.Shot) -> Texture2D:
	_ensure_panels()
	if _panels.size() < 4:
		return null
	match current_shot:
		MorgenVideo.Shot.WIDE:
			return _panels[0]
		MorgenVideo.Shot.MEDIUM, MorgenVideo.Shot.CLOSE:
			return _panels[1]
		MorgenVideo.Shot.REHEARSAL:
			return _panels[2]
		_:
			return _panels[3]


func _draw_illustrated_panel(flicker: float) -> bool:
	var current_shot := _model.shot_at(_elapsed)
	var tex := _panel_for_shot(current_shot)
	if tex == null:
		return false
	var zoom := 1.04
	if current_shot == MorgenVideo.Shot.CLOSE:
		zoom = 1.14
	elif current_shot == MorgenVideo.Shot.REACH:
		zoom = 1.06 + _model.reach_progress(_elapsed) * 0.12
	var beat_len := maxf(_model.beat_duration(), 0.1)
	var beat_share := fmod(_elapsed, beat_len) / beat_len
	zoom += beat_share * 0.04
	var draw_size := size * zoom
	var sway := _model.sway_offset(_elapsed) * 1.5
	var top_left := (size - draw_size) * 0.5 + sway
	draw_texture_rect(tex, Rect2(top_left, draw_size), false, Color(flicker, flicker, flicker, 1.0))
	return true


func _draw_caption_card() -> void:
	var card := Rect2(Vector2(88.0, size.y - 166.0), Vector2(size.x - 176.0, 114.0))
	draw_rect(card, Color(0.11, 0.1, 0.12, 0.86))
	draw_rect(card, Color(0.42, 0.29, 0.19, 0.95), false, 3.0)
	var active_beat := _model.beat_at(_elapsed)
	var total := MorgenVideo.SCRIPT_LINES.size()
	var dot_start_x := size.x * 0.5 - float(total - 1) * 11.0
	var dot_y := size.y - 34.0
	for i: int in total:
		var c := Color(0.95, 0.78, 0.4, 0.95) if i == active_beat else Color(0.8, 0.78, 0.72, 0.35)
		var r := 5.0 if i == active_beat else 3.5
		draw_circle(Vector2(dot_start_x + float(i) * 22.0, dot_y), r, c)


func _draw_scene(flicker: float) -> void:
	# The phone camera: the whole set rides the handheld sway around the
	# shot focus, with a lurch as the hand comes for the phone.
	var shot := _model.shot_at(_elapsed)
	var reach := _model.reach_progress(_elapsed)
	var zoom := _shot_zoom(shot) + reach * REACH_ZOOM_PUNCH
	var scale_vector := Vector2(zoom, zoom)
	var angle := _model.sway_angle(_elapsed) + reach * REACH_LURCH_ANGLE
	var rotation_only := Transform2D(angle, scale_vector, 0.0, Vector2.ZERO)
	var camera := size * 0.5 + _model.sway_offset(_elapsed) - rotation_only * _shot_focus(shot)
	draw_set_transform_matrix(Transform2D(angle, scale_vector, 0.0, camera))
	_draw_lab(flicker)
	_draw_beaker(flicker)
	_draw_monitor(flicker)
	_draw_morgen(flicker)
	draw_set_transform_matrix(Transform2D())


func _draw_lab(flicker: float) -> void:
	draw_rect(WALL_RECT, _dim(WALL_COLOR, flicker))
	draw_rect(SHELF_RECT, _dim(SHELF_COLOR, flicker))
	for jar: Rect2 in JAR_RECTS:
		draw_rect(jar, _dim(JAR_COLOR, flicker))
	draw_rect(TABLE_RECT, _dim(TABLE_COLOR, flicker))
	draw_rect(TABLE_FACE_RECT, _dim(TABLE_FACE_COLOR, flicker))


func _draw_beaker(flicker: float) -> void:
	# The beaker the phone leans on: green liquid, rising bubbles, and steam.
	var bob := sin(TAU * 0.7 * _elapsed) * 1.5
	var liquid := Rect2(BEAKER_BASE + Vector2(-12.0, -2.0 + bob), Vector2(24.0, 38.0 - bob))
	draw_rect(liquid, _dim(LIQUID_COLOR, flicker))
	for i: int in 3:
		var phase := fmod(_elapsed * 0.25 + float(i) / 3.0, 1.0)
		var bubble_y: float = lerpf(liquid.end.y - 3.0, liquid.position.y + 3.0, phase)
		var bubble_x: float = BEAKER_BASE.x - 8.0 + float(i) * 8.0 + sin(_elapsed + float(i)) * 2.0
		draw_circle(Vector2(bubble_x, bubble_y), 2.0, _dim(BUBBLE_COLOR, flicker))
	draw_rect(BEAKER_RECT, _dim(BEAKER_COLOR, flicker), false, 3.0)
	for wisp: int in 2:
		var rise := fmod(_elapsed * 0.18 + float(wisp) * 0.5, 1.0)
		var steam_position := Vector2(
			BEAKER_BASE.x - 8.0 + float(wisp) * 16.0 + sin(_elapsed * 1.3 + float(wisp)) * 3.0,
			lerpf(-30.0, -75.0, rise)
		)
		var steam := STEAM_COLOR
		steam.a = (1.0 - rise) * 0.18
		draw_circle(steam_position, 3.0 + rise * 2.0, steam)


func _draw_monitor(flicker: float) -> void:
	# The screen that plays the address rehearsal, section 22. It stands dark
	# until she looks at it, then the waveform flickers.
	var glow := _model.rehearsal_glow(_elapsed)
	draw_rect(MONITOR_STAND_RECT, _dim(SCREEN_FRAME_COLOR, flicker))
	draw_rect(MONITOR_RECT, _dim(SCREEN_FRAME_COLOR, flicker))
	draw_rect(MONITOR_SCREEN_RECT, SCREEN_DARK_COLOR)
	if glow <= 0.0:
		return
	var halo := WAVE_COLOR
	halo.a = glow * 0.1
	draw_circle(MONITOR_SCREEN_RECT.get_center(), 70.0, halo)
	var wave := PackedVector2Array()
	for i: int in 16:
		var share := float(i) / 15.0
		var point := MONITOR_SCREEN_RECT.position + MONITOR_SCREEN_RECT.size * Vector2(share, 0.5)
		point.y += sin(TAU * 3.0 * share + _elapsed * 9.0) * 8.0 * glow
		wave.append(point)
	var wave_color := WAVE_COLOR
	wave_color.a = glow
	draw_polyline(wave, wave_color, 2.0)
	var glyph_rect := Rect2(MONITOR_SCREEN_RECT.position + Vector2(8.0, 10.0), Vector2(10.0, 12.0))
	var glyph := CUP_GLYPH_COLOR
	glyph.a = glow * 0.8
	draw_rect(glyph_rect, glyph)


func _draw_morgen(flicker: float) -> void:
	# Dr. Morgen in lab clothes, tired, hair down. She breathes, she blinks,
	# and she looks where the track points her.
	var breath := _model.breath(_elapsed) * BREATH_PIXELS
	var gaze := _model.gaze(_elapsed) * GAZE_PIXELS
	var face := gaze + Vector2(0.0, breath * 1.3)
	var breath_offset := Vector2(0.0, breath)
	draw_rect(_moved(HAIR_RECT, breath_offset), _dim(HAIR_COLOR, flicker))
	draw_rect(_moved(COAT_RECT, breath_offset), _dim(COAT_COLOR, flicker))
	draw_circle(HEAD_CENTER + face, HEAD_RADIUS, _dim(SKIN_COLOR, flicker))
	_draw_eyes(face, flicker)
	var mouth_from := MOUTH_SPAN + gaze + Vector2(0.0, breath)
	draw_line(mouth_from, mouth_from + MOUTH_WIDTH, _dim(HAIR_COLOR, flicker), 2.0)


func _draw_eyes(face: Vector2, flicker: float) -> void:
	# Tired eyes: the lids hang half closed and close fully on a blink.
	var openness := _model.lid_openness(_elapsed)
	var lid_height := lerpf(6.0, 1.5, openness)
	for offset: Vector2 in EYE_OFFSETS:
		var eye_center := HEAD_CENTER + face + offset
		draw_rect(
			Rect2(eye_center - Vector2(4.5, lid_height * 0.5), Vector2(9.0, lid_height)),
			_dim(HAIR_COLOR, flicker)
		)


func _draw_reach_hand() -> void:
	# The last beat: she reaches for the phone, so her hand fills the frame.
	var reach := _model.reach_progress(_elapsed)
	if reach <= 0.0:
		return
	var from := size * HAND_START_FRACTION
	var to := size * HAND_TARGET_FRACTION
	var tip := from.lerp(to, reach)
	draw_line(from, tip, COAT_COLOR, HAND_ARM_WIDTH)
	draw_circle(tip, HAND_RADIUS, SKIN_COLOR)


func _draw_overlay() -> void:
	# The phone-camera overlay: letterbox bands, soft edges, the blinking
	# recording light, and the lab clock at night.
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, BAND_HEIGHTS.x)), BAND_COLOR)
	draw_rect(
		Rect2(Vector2(0.0, size.y - BAND_HEIGHTS.y), Vector2(size.x, BAND_HEIGHTS.y)), BAND_COLOR
	)
	draw_rect(Rect2(Vector2.ZERO, Vector2(VIGNETTE_WIDTH, size.y)), VIGNETTE_COLOR)
	draw_rect(
		Rect2(Vector2(size.x - VIGNETTE_WIDTH, 0.0), Vector2(VIGNETTE_WIDTH, size.y)),
		VIGNETTE_COLOR
	)
	if _model.is_rec_on(_elapsed):
		draw_circle(REC_CENTER, REC_RADIUS, REC_COLOR)
		draw_string(
			ThemeDB.fallback_font,
			REC_CENTER + Vector2(14.0, 6.0),
			REC_TEXT,
			HORIZONTAL_ALIGNMENT_LEFT,
			60.0,
			REC_TEXT_SIZE,
			OVERLAY_TEXT_COLOR
		)
	var total_seconds := int(_elapsed)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(size.x - 150.0, 40.0),
		"23:%02d:%02d" % [TIMESTAMP_START_MINUTE + total_seconds / 60, total_seconds % 60],
		HORIZONTAL_ALIGNMENT_LEFT,
		120.0,
		TIMESTAMP_TEXT_SIZE,
		OVERLAY_TEXT_COLOR
	)


func _draw_cut() -> void:
	# The video stops: black, with one burst of static under it.
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var step := int(_elapsed * STATIC_JITTER_HZ)
	for i: int in STATIC_DOTS:
		var x := fmod(float(i) * 97.0, size.x)
		var y := fmod(float(i) * 53.0 + float(step) * 7.0, size.y)
		draw_circle(Vector2(x, y), 1.5, STATIC_COLOR)


func _shot_zoom(shot: MorgenVideo.Shot) -> float:
	match shot:
		MorgenVideo.Shot.MEDIUM:
			return MEDIUM_ZOOM
		MorgenVideo.Shot.CLOSE, MorgenVideo.Shot.LOOK_BACK:
			return CLOSE_ZOOM
		MorgenVideo.Shot.REHEARSAL:
			return REHEARSAL_ZOOM
		MorgenVideo.Shot.REACH:
			return REACH_ZOOM
		_:
			return WIDE_ZOOM


func _shot_focus(shot: MorgenVideo.Shot) -> Vector2:
	match shot:
		MorgenVideo.Shot.MEDIUM:
			return MEDIUM_FOCUS
		MorgenVideo.Shot.CLOSE, MorgenVideo.Shot.LOOK_BACK:
			return CLOSE_FOCUS
		MorgenVideo.Shot.REHEARSAL:
			return REHEARSAL_FOCUS
		MorgenVideo.Shot.REACH:
			return REACH_FOCUS
		_:
			return WIDE_FOCUS


func _moved(rect: Rect2, offset: Vector2) -> Rect2:
	# Rect2 carries no + operator, so the breath slides the body by hand.
	return Rect2(rect.position + offset, rect.size)


func _dim(color: Color, flicker: float) -> Color:
	# The lab light at night breathes; every surface rides it.
	return Color(color.r * flicker, color.g * flicker, color.b * flicker, color.a)
