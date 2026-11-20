# ABOUTME: DanceOffView draws and drives the dance-off rhythm game.
# ABOUTME: Presentation only: every verdict comes from the pure DanceOff.
class_name DanceOffView
extends Control

signal finished(won: bool)

const TITLE_TEXT := "THE DANCE-OFF"
const PROMPT_TEXT := "TAP THE BEAT. %d OF %d WINS THE MOONWALK."
const PERFECT_TEXT := "SMOOTH!"
const GOOD_TEXT := "GOOD."
const MISS_TEXT := "CLUMSY."
const WIN_TEXT := "HE BOWS. THE MOONWALK IS YOURS."
const LOSE_TEXT := "HE NODS. NOT SMOOTH ENOUGH."

# Placeholder chalkboard look until the art pass, like the brew minigames.
const BOARD_COLOR := Color(0.11, 0.15, 0.13, 0.92)
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const TRACK_COLOR := Color(0.07, 0.1, 0.08, 1)
const BEAT_COLOR := Color(0.95, 0.8, 0.3, 1)
const LINE_COLOR := Color(0.93, 0.95, 0.88, 1)
const GLOVE_COLOR := Color(0.98, 0.98, 0.94, 1)
const BORDER_WIDTH := 2.0
# The track geometry inside the 520 by 360 panel: beats fall from the right
# onto the hit line, and the sequined glove rides the line.
const TRACK_TOP := 120.0
const TRACK_BOTTOM := 280.0
const LINE_X := 130.0
const BEAT_RADIUS := 16.0
const GLOVE_SIZE := Vector2(30.0, 40.0)
# One second of beat time maps to this many pixels of fall.
const FALL_SPEED := 220.0

@export var balance: MoonwalkerBalance

var model: DanceOff = null

var _announced := false

@onready var title_label: Label = $TitleLabel
@onready var prompt_label: Label = $PromptLabel
@onready var verdict_label: Label = $VerdictLabel


func _ready() -> void:
	begin()


func begin() -> void:
	model = DanceOff.new(balance)
	model.begin()
	model.beat_judged.connect(_on_beat_judged)
	model.finished.connect(_on_finished)
	_announced = false
	title_label.text = TITLE_TEXT
	prompt_label.text = PROMPT_TEXT % [balance.dance_win_hits, balance.dance_beat_count]
	verdict_label.text = ""
	verdict_label.visible = false


func _process(delta: float) -> void:
	if model == null or _announced:
		return
	model.tick(delta)
	if not model.is_over():
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Touch first: any tap lands a beat. Emulated mouse clicks from touch are
	# skipped so one tap never judges two consecutive beats.
	if model == null or _announced:
		return
	if event is InputEventMouseButton and event.device == TouchControls.EMULATED_MOUSE_DEVICE:
		return
	if event.is_action_pressed(&"lift_pot") or _is_screen_tap(event):
		_judge(model.tap())
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _is_screen_tap(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.pressed


func request_tap() -> DanceOff.Verdict:
	# The tap path of a caller that drives the beat by hand, like a test.
	if model == null or _announced:
		return DanceOff.Verdict.NONE
	var verdict := model.tap()
	_judge(verdict)
	return verdict


func _judge(verdict: DanceOff.Verdict) -> void:
	match verdict:
		DanceOff.Verdict.PERFECT:
			verdict_label.text = PERFECT_TEXT
		DanceOff.Verdict.GOOD:
			verdict_label.text = GOOD_TEXT
		DanceOff.Verdict.MISS:
			verdict_label.text = MISS_TEXT
		_:
			return
	verdict_label.visible = true


func _on_beat_judged(verdict: DanceOff.Verdict, _beat_index: int) -> void:
	if verdict == DanceOff.Verdict.MISS:
		verdict_label.text = MISS_TEXT
		verdict_label.visible = true


func _on_finished(dance_won: bool) -> void:
	# The dance ends: the result holds on the board, then the director
	# closes the overlay and plays the reward.
	verdict_label.text = WIN_TEXT if dance_won else LOSE_TEXT
	verdict_label.visible = true
	_announced = true
	queue_redraw()
	finished.emit(dance_won)


func _draw() -> void:
	if model == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), BOARD_COLOR)
	var track := Rect2(24.0, TRACK_TOP, size.x - 48.0, TRACK_BOTTOM - TRACK_TOP)
	draw_rect(track, TRACK_COLOR)
	draw_rect(track, CHALK_COLOR, false, BORDER_WIDTH)
	# The hit line: the tall chalk line the beats must meet.
	draw_line(Vector2(LINE_X, TRACK_TOP), Vector2(LINE_X, TRACK_BOTTOM), LINE_COLOR, BORDER_WIDTH)
	_draw_glove(Vector2(LINE_X - GLOVE_SIZE.x * 0.5, TRACK_TOP - GLOVE_SIZE.y - 4.0))
	for index: int in range(model.beats_total()):
		_draw_beat(index)


func _draw_beat(index: int) -> void:
	# One beat falls from the right onto the hit line. A judged beat fades
	# immediately; the waiting ones glow like the Grind Dial sweet spot.
	var remaining := model.beat_time(index) - model.elapsed()
	var x := LINE_X + remaining * FALL_SPEED
	if remaining < -balance.dance_good_window_seconds or x > size.x - 24.0 - BEAT_RADIUS:
		return
	var center := Vector2(x, (TRACK_TOP + TRACK_BOTTOM) * 0.5)
	var color := BEAT_COLOR
	if index < model.next_beat():
		color = color.darkened(0.5)
	draw_circle(center, BEAT_RADIUS, color)


func _draw_glove(top_left: Vector2) -> void:
	# One sequined glove rides the hit line, the prize in plain view.
	var glove := Rect2(top_left, GLOVE_SIZE)
	draw_rect(glove, GLOVE_COLOR)
	draw_rect(glove, LINE_COLOR, false, BORDER_WIDTH)
