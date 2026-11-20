# ABOUTME: OutroCreditsView draws the version credits, section 16: her frozen
# ABOUTME: demand hangs at the top, cut mid-sentence, while the roll runs under it.
class_name OutroCreditsView
extends Control

signal finished

const BACKDROP_COLOR := Color(0.02, 0.02, 0.04, 0.92)
const TEXT_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const CAUGHT_COLOR := Color(0.98, 0.83, 0.25, 1.0)
const CAUGHT_TEXT_SIZE := 42
const CAUGHT_ANCHOR_FRACTION := 0.18
const SKIP_TEXT := "TAP TO SKIP"
const SKIP_TEXT_SIZE := 16
const SKIP_COLOR := Color(0.93, 0.95, 0.88, 0.55)
const LINE_TEXT_SIZE := 26
const LINE_GAP := 46.0

# The credit roll, top to bottom. The version ends after Pourtland and the
# three cities stay open for the post-game activities of section 23.
const CREDIT_LINES: Array[String] = [
	"POURTLAND IS AWAKE.",
	"THE TOWER IS SILENT.",
	"THE SLEEP JAM SINGS NO MORE.",
	"",
	"APOCALYPSE BARISTA",
	"VERSION 1: THE WEST COAST RUN",
	"",
	"MAXIMUM FROTH",
	"GAME DIRECTOR: NIKO DIGGER",
	"",
	"THE CITIES STAY OPEN AND AWAKE.",
	"FINISH THE SIDE QUESTS.",
	"COMPLETE THE SLEEPYDEX.",
	"FIND EVERY HIDDEN GLOVE.",
	"",
	"BREW IT STRONG.",
]

var _caught_line := ""
var _roll_seconds := 1.0
var _time := 0.0
var _rolling := false
var _finished := false


func begin(caught_line: String, roll_seconds: float) -> void:
	# The roll starts on the caught demand and ends on its own after the tuned
	# seconds. A begun roll restarts cleanly.
	_caught_line = caught_line
	_roll_seconds = maxf(0.1, roll_seconds)
	_time = 0.0
	_finished = false
	_rolling = true
	queue_redraw()


func skip() -> void:
	# Any press ends the roll at once. The end fires exactly once.
	if not _rolling:
		return
	_time = _roll_seconds
	_finish()


func caught_line() -> String:
	return _caught_line


func is_rolling() -> bool:
	return _rolling


func is_done() -> bool:
	return _finished


func roll_progress() -> float:
	# How far the roll has traveled, 0 to 1, for tests and the skip state.
	return clampf(_time / _roll_seconds, 0.0, 1.0)


func _process(delta: float) -> void:
	if not _rolling:
		return
	_time += delta
	queue_redraw()
	if _time >= _roll_seconds:
		_finish()


func _finish() -> void:
	_rolling = false
	if _finished:
		return
	_finished = true
	queue_redraw()
	finished.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKDROP_COLOR)
	if not _caught_line.is_empty():
		_draw_centered(
			Vector2(size.x * 0.5, size.y * CAUGHT_ANCHOR_FRACTION),
			_caught_line,
			CAUGHT_TEXT_SIZE,
			CAUGHT_COLOR
		)
	_draw_roll()
	_draw_centered(Vector2(size.x * 0.5, size.y - 40.0), SKIP_TEXT, SKIP_TEXT_SIZE, SKIP_COLOR)


func _draw_roll() -> void:
	# The lines scroll from below the bottom edge to above the top edge, so
	# every line crosses the whole screen.
	var travel := size.y + CREDIT_LINES.size() * LINE_GAP
	var top := size.y - roll_progress() * travel
	for i: int in range(CREDIT_LINES.size()):
		_draw_centered(
			Vector2(size.x * 0.5, top + float(i) * LINE_GAP),
			CREDIT_LINES[i],
			LINE_TEXT_SIZE,
			TEXT_COLOR
		)


func _draw_centered(at: Vector2, text: String, text_size: int, color: Color) -> void:
	if text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(
		font, at + Vector2(-width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, color
	)
