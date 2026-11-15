# ABOUTME: PourBloomView draws and drives The Pour minigame.
# ABOUTME: Presentation only: every grade comes from the pure PourBloom model.
class_name PourBloomView
extends Control

signal finished(pour_result: PourResult)

# Placeholder chalkboard look until the art pass, in the style of the HUD.
const BOARD_COLOR := Color(0.11, 0.15, 0.13, 0.92)
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const TRACK_COLOR := Color(0.07, 0.1, 0.08, 1)
const ZONE_COLOR := Color(0.62, 0.82, 0.55, 1)
const MARKER_COLOR := Color(0.95, 0.8, 0.3, 1)
const BLOOM_COLOR := Color(0.72, 0.55, 0.35, 0.95)
const WATER_COLOR := Color(0.45, 0.7, 0.85, 0.9)
const BORDER_WIDTH := 2.0
const STREAM_WIDTH := 3.0
# Ring and gauge geometry inside the 520 by 360 panel.
const RING_CENTER := Vector2(172.0, 196.0)
const BED_RADIUS := 88.0
const RING_RADIUS := 112.0
const RING_WIDTH := 14.0
const POUR_DOT_RADIUS := 9.0
const STREAM_INSET := 6.0
const GAUGE_LEFT := 402.0
const GAUGE_TOP := 64.0
const GAUGE_WIDTH := 44.0
const GAUGE_HEIGHT := 256.0
const MARKER_HEIGHT := 4.0
const ARC_POINTS := 64

@export var balance: PourBalance
@export var method: BrewingMethod

var model: PourBloom = null
# The pour rate for the current frame, from 0.0 to 1.0. A pressed pointer
# writes it from its circle speed; anything else may drive it directly, so
# tests can run the bloom headless with no input events at all.
var pour_rate := 0.0

var _announced := false
var _pointer_down := false
var _pointer_angle := 0.0
var _angle_travel := 0.0

@onready var method_label: Label = $MethodLabel
@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	begin(method)


func _process(delta: float) -> void:
	if model == null or _announced:
		return
	if _pointer_down:
		_update_pour_rate(delta)
	model.tick(delta, pour_rate)
	if not model.is_running():
		_announce(model.result)
	else:
		queue_redraw()


func begin(p_method: BrewingMethod) -> void:
	# Start one pour for a method. The brew flow calls this for every cup
	# after the Grind Dial pre-step.
	model = PourBloom.new(balance)
	_announced = false
	pour_rate = 0.0
	method_label.text = "POUR: %s" % p_method.display_name.to_upper()
	result_label.text = ""
	result_label.visible = false
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Touch first: press and drag a slow circle around the ring to pour. The
	# same path covers a held mouse button on the desktop build. The pointer
	# owns the pour rate only while it is down; lifting it stops the pour.
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_begin_pointer(touch.position)
		else:
			_end_pointer()
		return
	var drag := event as InputEventScreenDrag
	if drag != null and _pointer_down:
		_follow_pointer(drag.position)
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			_begin_pointer(button.position)
		else:
			_end_pointer()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _pointer_down:
		_follow_pointer(motion.position)


func _update_pour_rate(delta: float) -> void:
	# The pour rate is the pointer speed around the ring: one full circle in
	# full_turn_seconds is rate 1.0, and anything faster clamps there.
	if delta <= 0.0:
		return
	var turns_this_frame := _angle_travel / TAU
	pour_rate = clampf(turns_this_frame / delta * balance.full_turn_seconds, 0.0, 1.0)
	_angle_travel = 0.0


func _begin_pointer(screen_position: Vector2) -> void:
	_pointer_down = true
	_angle_travel = 0.0
	_pointer_angle = _ring_angle(screen_position)


func _end_pointer() -> void:
	_pointer_down = false
	pour_rate = 0.0


func _follow_pointer(screen_position: Vector2) -> void:
	var new_angle := _ring_angle(screen_position)
	_angle_travel += absf(wrapf(new_angle - _pointer_angle, -PI, PI))
	_pointer_angle = new_angle


func _ring_angle(screen_position: Vector2) -> float:
	# The angle of the pointer around the ring center, in panel space.
	var local := get_global_transform_with_canvas().affine_inverse() * screen_position
	return (local - RING_CENTER).angle()


func _announce(pour_result: PourResult) -> void:
	if _announced or pour_result == null:
		return
	_announced = true
	result_label.text = _result_text(pour_result)
	result_label.visible = true
	queue_redraw()
	finished.emit(pour_result)


func _result_text(pour_result: PourResult) -> String:
	match pour_result.outcome:
		PourResult.Outcome.BLOOMED:
			return "Full bloom. Score %d." % roundi(pour_result.score)
		PourResult.Outcome.FLOODED:
			return "Flooded bed. Score %d." % roundi(pour_result.score)
		_:
			return "The bloom stalled. Score %d." % roundi(pour_result.score)


func _draw() -> void:
	# Chalkboard panel, brew bed with pooled water, bloom fill arc, the pour
	# dot with its stream, and the rate gauge with the sweet-spot band.
	if model == null:
		return
	var board := Rect2(Vector2.ZERO, size)
	draw_rect(board, BOARD_COLOR)
	draw_rect(board, CHALK_COLOR, false, BORDER_WIDTH)
	_draw_bed()
	_draw_gauge()


func _draw_bed() -> void:
	draw_arc(RING_CENTER, BED_RADIUS, 0.0, TAU, ARC_POINTS, CHALK_COLOR, BORDER_WIDTH)
	if model.excess > 0.0:
		draw_circle(RING_CENTER, _puddle_radius(), WATER_COLOR)
	draw_arc(RING_CENTER, RING_RADIUS, 0.0, TAU, ARC_POINTS, TRACK_COLOR, RING_WIDTH)
	if model.fill > 0.0:
		draw_arc(
			RING_CENTER,
			RING_RADIUS,
			-PI * 0.5,
			-PI * 0.5 + TAU * model.fill,
			ARC_POINTS,
			BLOOM_COLOR,
			RING_WIDTH
		)
	if _pointer_down:
		draw_line(_dot_position(), _stream_end(), WATER_COLOR, STREAM_WIDTH)
		draw_circle(_dot_position(), POUR_DOT_RADIUS, MARKER_COLOR)


func _draw_gauge() -> void:
	var gauge := Rect2(GAUGE_LEFT, GAUGE_TOP, GAUGE_WIDTH, GAUGE_HEIGHT)
	draw_rect(gauge, TRACK_COLOR)
	draw_rect(_band_rect(), ZONE_COLOR)
	draw_rect(_marker_rect(), MARKER_COLOR)
	draw_rect(gauge, CHALK_COLOR, false, BORDER_WIDTH)


func _puddle_radius() -> float:
	return model.excess / balance.flood_excess * BED_RADIUS * 0.75


func _dot_position() -> Vector2:
	return RING_CENTER + Vector2.from_angle(_pointer_angle) * RING_RADIUS


func _stream_end() -> Vector2:
	return RING_CENTER + Vector2.from_angle(_pointer_angle) * (BED_RADIUS + STREAM_INSET)


func _band_rect() -> Rect2:
	var top := _gauge_y_for(balance.sweet_spot_end)
	var bottom := _gauge_y_for(balance.sweet_spot_start)
	return Rect2(GAUGE_LEFT, top, GAUGE_WIDTH, bottom - top)


func _marker_rect() -> Rect2:
	return Rect2(
		GAUGE_LEFT, _gauge_y_for(pour_rate) - MARKER_HEIGHT * 0.5, GAUGE_WIDTH, MARKER_HEIGHT
	)


func _gauge_y_for(rate: float) -> float:
	# Rate 0.0 sits at the bottom of the gauge and 1.0 at the top.
	return GAUGE_TOP + GAUGE_HEIGHT * (1.0 - clampf(rate, 0.0, 1.0))
