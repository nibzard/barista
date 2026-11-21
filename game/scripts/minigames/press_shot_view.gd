# ABOUTME: PressShotView draws and drives The Press minigame.
# ABOUTME: Presentation only: every grade comes from the pure PressShot model.
class_name PressShotView
extends Control

signal finished(press_result: PressResult)

# Chalk colors of the gauges. MinigamePainter draws the board and the coffee.
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const ZONE_COLOR := Color(0.62, 0.82, 0.55, 1)
const ZONE_DONE_COLOR := Color(0.62, 0.82, 0.55, 0.25)
const MARKER_COLOR := Color(0.95, 0.8, 0.3, 1)
const MARK_WAIT_COLOR := Color(0.95, 0.8, 0.3, 0.25)
const MAX_TICK_COLOR := Color(0.93, 0.95, 0.88, 0.45)
const BORDER_WIDTH := 2.0
const NEEDLE_HEIGHT := 4.0
const NEEDLE_OVERHANG := 8.0
const MARK_HEIGHT := 3.0
const TICK_WIDTH := 2.0
# Gauge and cup geometry inside the 520 by 360 panel. The gauge maps the full
# overload band, so an over-held pull visibly pins above the max tick.
const GAUGE_LEFT := 150.0
const GAUGE_TOP := 84.0
const GAUGE_WIDTH := 120.0
const GAUGE_HEIGHT := 236.0
const CUP_LEFT := 330.0
const CUP_TOP := 84.0
const CUP_WIDTH := 36.0
const CUP_HEIGHT := 236.0
const GAUGE_MAX := 1.0
const STEP_ONE_TEXT := "STEP 1: HOLD THE GREEN ZONE"
const STEP_TWO_TEXT := "STEP 2: RELEASE AT THE MARK"

@export var balance: PressBalance
@export var method: BrewingMethod

var model: PressShot = null
# The hold state for the current frame. Pressed pointers and the hold action
# write it; anything else may drive it directly, so tests can run the press
# headless with no input events at all.
var held := false

var _announced := false
var _active_touch := -1
var _step_text := ""

@onready var method_label: Label = $MethodLabel
@onready var step_label: Label = $StepLabel
@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	begin(method)


func _process(delta: float) -> void:
	if model == null or _announced:
		return
	model.tick(delta, held)
	_update_step_label()
	if not model.is_running():
		_announce(model.result)
	else:
		queue_redraw()


func begin(p_method: BrewingMethod) -> void:
	# Start one press for a method. The brew flow calls this for every cup
	# after the Grind Dial pre-step.
	model = PressShot.new(balance)
	_announced = false
	_active_touch = -1
	held = false
	_step_text = ""
	method_label.text = "PRESS: %s" % p_method.display_name.to_upper()
	result_label.text = ""
	result_label.visible = false
	_update_step_label()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Touch first: press and hold anywhere to build pressure, lift to release.
	# Track one active touch index and skip emulated mouse copies from touch.
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			if _active_touch == -1:
				_active_touch = touch.index
				held = true
		elif touch.index == _active_touch:
			_active_touch = -1
			held = false
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.device == TouchControls.EMULATED_MOUSE_DEVICE:
			return
		held = button.pressed
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"hold_pressure"):
		held = true
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
	elif event.is_action_released(&"hold_pressure"):
		held = false
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _announce(press_result: PressResult) -> void:
	if _announced or press_result == null:
		return
	_announced = true
	result_label.text = _result_text(press_result)
	result_label.visible = true
	queue_redraw()
	finished.emit(press_result)


func _result_text(press_result: PressResult) -> String:
	match press_result.outcome:
		PressResult.Outcome.PRESSED:
			return "Released on the mark. Score %d." % roundi(press_result.score)
		PressResult.Outcome.SOUR:
			return "Too early. Sour cup. Score %d." % roundi(press_result.score)
		PressResult.Outcome.BITTER:
			return "Too late. Bitter cup. Score %d." % roundi(press_result.score)
		_:
			return "No shot. The press ran out. Score %d." % roundi(press_result.score)


func _update_step_label() -> void:
	var text := STEP_TWO_TEXT if model.step == PressShot.Step.RELEASE else STEP_ONE_TEXT
	if text != _step_text:
		_step_text = text
		step_label.text = text


func _draw() -> void:
	# Chalkboard panel, the pressure gauge with the creeping zone and the
	# exact mark, the needle, and the cup that fills while the hold holds.
	if model == null:
		return
	var board := Rect2(Vector2.ZERO, size)
	MinigamePainter.paint_board(self, board.size)
	_draw_gauge()
	_draw_cup()


func _draw_gauge() -> void:
	var gauge := Rect2(GAUGE_LEFT, GAUGE_TOP, GAUGE_WIDTH, GAUGE_HEIGHT)
	MinigamePainter.paint_track(self, gauge)
	MinigamePainter.paint_zone(self, _zone_rect(), _zone_color())
	draw_rect(_max_tick_rect(), MAX_TICK_COLOR)
	draw_rect(_mark_rect(), _mark_color())
	MinigamePainter.paint_marker(self, _needle_rect(), CHALK_COLOR)


func _draw_cup() -> void:
	var cup := Rect2(CUP_LEFT, CUP_TOP, CUP_WIDTH, CUP_HEIGHT)
	MinigamePainter.paint_glass(self, cup, _coffee_rect(), model.fill)


func _zone_rect() -> Rect2:
	var top := _gauge_y_for(model.zone_end())
	var bottom := _gauge_y_for(model.zone_start())
	return Rect2(GAUGE_LEFT, top, GAUGE_WIDTH, bottom - top)


func _mark_rect() -> Rect2:
	return Rect2(
		GAUGE_LEFT - NEEDLE_OVERHANG * 0.5,
		_gauge_y_for(balance.release_mark_pressure) - MARK_HEIGHT * 0.5,
		GAUGE_WIDTH + NEEDLE_OVERHANG,
		MARK_HEIGHT
	)


func _needle_rect() -> Rect2:
	return Rect2(
		GAUGE_LEFT - NEEDLE_OVERHANG,
		_gauge_y_for(model.pressure) - NEEDLE_HEIGHT * 0.5,
		GAUGE_WIDTH + NEEDLE_OVERHANG * 2.0,
		NEEDLE_HEIGHT
	)


func _max_tick_rect() -> Rect2:
	return Rect2(
		GAUGE_LEFT - NEEDLE_OVERHANG * 0.5,
		_gauge_y_for(GAUGE_MAX) - TICK_WIDTH * 0.5,
		GAUGE_WIDTH + NEEDLE_OVERHANG,
		TICK_WIDTH
	)


func _coffee_rect() -> Rect2:
	var top := CUP_TOP + CUP_HEIGHT * (1.0 - model.fill)
	return Rect2(CUP_LEFT, top, CUP_WIDTH, CUP_TOP + CUP_HEIGHT - top)


func _zone_color() -> Color:
	return ZONE_DONE_COLOR if model.step == PressShot.Step.RELEASE else ZONE_COLOR


func _mark_color() -> Color:
	return MARKER_COLOR if model.step == PressShot.Step.RELEASE else MARK_WAIT_COLOR


func _gauge_y_for(pressure_value: float) -> float:
	# Pressure 0.0 sits at the bottom of the gauge and the overload cap at the
	# top.
	return (
		GAUGE_TOP
		+ (
			GAUGE_HEIGHT
			* (1.0 - clampf(pressure_value, 0.0, balance.pressure_max) / balance.pressure_max)
		)
	)
