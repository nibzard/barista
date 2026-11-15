# ABOUTME: TutorialVideoView draws the placeholder stills of the Dr. Morgen video.
# ABOUTME: The produced video comes with T043; this view plays the section 22 script.
class_name TutorialVideoView
extends Control

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

# Placeholder night-lab colors until T043 brings the real stills.
const BG_COLOR := Color(0.02, 0.02, 0.045, 1.0)
const TABLE_COLOR := Color(0.16, 0.13, 0.1, 1.0)
const COAT_COLOR := Color(0.86, 0.86, 0.82, 1.0)
const SKIN_COLOR := Color(0.9, 0.72, 0.58, 1.0)
const HAIR_COLOR := Color(0.25, 0.18, 0.12, 1.0)
const BEAKER_COLOR := Color(0.55, 0.75, 0.8, 0.5)
const LIQUID_COLOR := Color(0.35, 0.5, 0.3, 0.9)
const PHONE_COLOR := Color(0.08, 0.08, 0.1, 1.0)
const PHONE_SCREEN_COLOR := Color(0.75, 0.85, 0.8, 1.0)
const REC_COLOR := Color(0.85, 0.15, 0.12, 1.0)
const REC_RADIUS := 6.0
# Morgen stands center, tired, hair down, in lab clothes.
const COAT_RECT := Rect2(-46.0, -80.0, 92.0, 150.0)
const HEAD_RADIUS := 26.0
const HEAD_OFFSET := Vector2(0.0, -104.0)
const HAIR_RECT := Rect2(-32.0, -138.0, 64.0, 76.0)
# The phone leans against the beaker, both on the table.
const BEAKER_RECT := Rect2(-26.0, -66.0, 52.0, 66.0)
const PHONE_RECT := Rect2(-21.0, -40.0, 42.0, 80.0)
const PHONE_LEAN_ANGLE := -0.16

var _fraction := 0.0

@onready var subtitle_label: Label = $SubtitleLabel


func reset() -> void:
	_fraction = 0.0
	subtitle_label.text = current_line()
	queue_redraw()


func set_progress(fraction: float) -> void:
	# The director reports the played share of the video; the subtitle picks
	# its beat from it.
	_fraction = clampf(fraction, 0.0, 1.0)
	subtitle_label.text = current_line()
	queue_redraw()


func current_line() -> String:
	var beat := mini(int(_fraction * float(SCRIPT_LINES.size())), SCRIPT_LINES.size() - 1)
	return SCRIPT_LINES[beat]


func _draw() -> void:
	# A lab at night: black room, a table, a beaker, the leaning phone, and
	# Dr. Morgen in lab clothes. Placeholder stills only.
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	var table_top := size.y * 0.66
	draw_rect(Rect2(Vector2(0.0, table_top), Vector2(size.x, size.y - table_top)), TABLE_COLOR)
	_draw_beaker(Vector2(size.x * 0.66, table_top))
	_draw_phone(Vector2(size.x * 0.5, table_top))
	_draw_morgen(Vector2(size.x * 0.42, table_top))
	draw_circle(Vector2(34.0, 34.0), REC_RADIUS, REC_COLOR)


func _draw_morgen(at: Vector2) -> void:
	draw_rect(Rect2(at + HAIR_RECT.position, HAIR_RECT.size), HAIR_COLOR)
	draw_rect(Rect2(at + COAT_RECT.position, COAT_RECT.size), COAT_COLOR)
	draw_circle(at + HEAD_OFFSET, HEAD_RADIUS, SKIN_COLOR)
	# Tired eyes: two closed lids.
	draw_line(
		at + HEAD_OFFSET + Vector2(-12.0, -2.0),
		at + HEAD_OFFSET + Vector2(-4.0, -2.0),
		HAIR_COLOR,
		2.0
	)
	draw_line(
		at + HEAD_OFFSET + Vector2(4.0, -2.0),
		at + HEAD_OFFSET + Vector2(12.0, -2.0),
		HAIR_COLOR,
		2.0
	)


func _draw_beaker(at: Vector2) -> void:
	draw_rect(Rect2(at + BEAKER_RECT.position, BEAKER_RECT.size), BEAKER_COLOR, false, 3.0)
	var liquid := Rect2(
		at + BEAKER_RECT.position + Vector2(4.0, BEAKER_RECT.size.y * 0.4),
		BEAKER_RECT.size - Vector2(8.0, BEAKER_RECT.size.y * 0.4)
	)
	draw_rect(liquid, LIQUID_COLOR)


func _draw_phone(at: Vector2) -> void:
	# The phone leans against the beaker, screen toward Morgen.
	draw_set_transform(at + Vector2(-52.0, -6.0), PHONE_LEAN_ANGLE, Vector2.ONE)
	draw_rect(PHONE_RECT, PHONE_COLOR)
	draw_rect(
		Rect2(PHONE_RECT.position + Vector2(5.0, 6.0), PHONE_RECT.size - Vector2(10.0, 14.0)),
		PHONE_SCREEN_COLOR
	)
	draw_set_transform(Vector2.ZERO)
