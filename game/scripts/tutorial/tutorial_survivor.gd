# ABOUTME: TutorialSurvivor is the awake survivor at the cafe door, section 19
# ABOUTME: step 7: an awake figure that speaks the tower line once.
class_name TutorialSurvivor
extends Node2D

# The awake survivor: a ChibiPainter person in green clothes, with
# one raised arm that waves the player over.
const BODY_COLOR := Color(0.45, 0.6, 0.42, 1.0)
const ARM_COLOR := Color(0.96, 0.85, 0.72, 1.0)
const LINE_WIDTH := 300.0
const LINE_TEXT_SIZE := 18
const LINE_COLOR := Color(0.96, 0.93, 0.85, 1.0)

var _has_spoken := false
var _line_time_left := 0.0
var _line_label: Label


func _ready() -> void:
	_line_label = Label.new()
	_line_label.position = Vector2(-LINE_WIDTH * 0.5, -108.0)
	_line_label.size = Vector2(LINE_WIDTH, 64.0)
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_font_size_override("font_size", LINE_TEXT_SIZE)
	_line_label.add_theme_color_override("font_color", LINE_COLOR)
	_line_label.visible = false
	add_child(_line_label)


func _physics_process(delta: float) -> void:
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0:
		_line_label.visible = false


func speak(line_text: String, hold_seconds: float) -> void:
	# The one line of section 19 step 7, spoken once.
	_has_spoken = true
	_line_label.text = line_text
	_line_label.visible = true
	_line_time_left = hold_seconds


func has_spoken() -> bool:
	return _has_spoken


func spoken_line() -> String:
	return _line_label.text


func is_speaking() -> bool:
	return _line_label.visible


func _draw() -> void:
	ChibiPainter.paint(self, BODY_COLOR, "tutorial_survivor")
	# The waving arm, raised toward the player.
	draw_line(Vector2(10.0, -8.0), Vector2(26.0, -26.0), ARM_COLOR, 4.0)
