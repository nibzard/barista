# ABOUTME: WakeLinePresenter floats one wake line above the sleeper that spoke.
# ABOUTME: A passive view of the spoke signal: the owner connects speak to it.
class_name WakeLinePresenter
extends Node2D

# The spoken line holds for a few seconds, like the master line.
const LINE_HOLD_SECONDS := 4.0
# The speech rect of the house style, the shape of the master and member
# labels: wide enough for the manager line, the text hugs the rect bottom.
const LINE_LEFT := -130.0
const LINE_TOP := -112.0
const LINE_RIGHT := 130.0
const LINE_BOTTOM := -44.0
const FONT_SIZE := 15
const TEXT_COLOR := Color(0.96, 0.93, 0.85, 1)
# The wake line rides above the crowd, so a passing sleeper never hides it.
const LINE_Z_INDEX := 40

var _label: Label = null
var _time_left := 0.0


static func attach(
	speaker: Node2D, spoke: Signal, offset: Vector2 = Vector2.ZERO
) -> WakeLinePresenter:
	# The wiring of one spoken line, T092: the presenter rides the speaker and
	# the spoke signal drives it, so the beat plays wherever the speaker wakes.
	# The offset lifts the line above raised stages, like the band platform.
	var presenter := WakeLinePresenter.new()
	presenter.name = "WakeLine"
	presenter.position = offset
	speaker.add_child(presenter)
	spoke.connect(presenter.speak)
	return presenter


func speak(line_text: String) -> void:
	# The woken sleeper says its line once, section 6: the line holds above the
	# body for one beat, then it fades. An empty line never shows.
	if line_text.is_empty():
		return
	if _label == null:
		_compose_label()
	_label.text = line_text
	_label.visible = true
	_time_left = LINE_HOLD_SECONDS


func spoken_line() -> String:
	# The line of the last speak, also after it faded.
	if _label == null:
		return ""
	return _label.text


func is_speaking() -> bool:
	return _label != null and _label.visible


func _ready() -> void:
	if _label == null:
		_compose_label()


func _physics_process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left = maxf(0.0, _time_left - delta)
	if _time_left == 0.0:
		_label.visible = false


func _compose_label() -> void:
	_label = Label.new()
	_label.name = "LineLabel"
	_label.visible = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.offset_left = LINE_LEFT
	_label.offset_top = LINE_TOP
	_label.offset_right = LINE_RIGHT
	_label.offset_bottom = LINE_BOTTOM
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	z_index = LINE_Z_INDEX
	add_child(_label)
