# ABOUTME: GrindDialView draws and drives the Grind Dial pre-step minigame.
# ABOUTME: Presentation only: every grade comes from the pure GrindDial model.
class_name GrindDialView
extends Control

signal finished(grind_result: GrindResult)

# Chalk colors of the gauges. MinigamePainter draws the board and the coffee.
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const ZONE_COLOR := Color(0.62, 0.82, 0.55, 1)
const MARKER_COLOR := Color(0.95, 0.8, 0.3, 1)
const BORDER_WIDTH := 2.0
# Dial geometry inside the 520 by 200 panel.
const TRACK_LEFT := 60.0
const TRACK_RIGHT := 460.0
const TRACK_TOP := 104.0
const TRACK_HEIGHT := 10.0
const ZONE_TOP := 92.0
const ZONE_HEIGHT := 34.0
const MARKER_TOP := 82.0
const MARKER_HEIGHT := 54.0
const MARKER_WIDTH := 5.0

@export var balance: GrindDialBalance
@export var method: BrewingMethod

var model: GrindDial = null

var _announced := false

@onready var method_label: Label = $MethodLabel
@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	begin(method)


func _process(delta: float) -> void:
	if model == null or _announced:
		return
	model.tick(delta)
	if not model.is_running():
		_announce(model.result)
	else:
		queue_redraw()


func begin(p_method: BrewingMethod) -> void:
	# Start one dial run for a method. The brew flow calls this for every cup.
	model = GrindDial.new(p_method, balance)
	_announced = false
	method_label.text = "GRIND: %s" % p_method.display_name.to_upper()
	result_label.text = ""
	result_label.visible = false
	queue_redraw()


func request_stop() -> GrindResult:
	# Stop the marker where it stands. Safe to call twice and safe after a miss.
	if model == null:
		return null
	var dial_result := model.stop()
	_announce(dial_result)
	return dial_result


func _announce(dial_result: GrindResult) -> void:
	if _announced or dial_result == null:
		return
	_announced = true
	result_label.text = _result_text(dial_result)
	result_label.visible = true
	queue_redraw()
	finished.emit(dial_result)


func _result_text(dial_result: GrindResult) -> String:
	match dial_result.outcome:
		GrindResult.Outcome.HIT:
			return "Right grind. Score %d." % roundi(dial_result.score)
		GrindResult.Outcome.WRONG_ZONE:
			return "Wrong grind. Score %d." % roundi(dial_result.score)
		_:
			return "No grind. The dial ran away. Score %d." % roundi(dial_result.score)


func _unhandled_input(event: InputEvent) -> void:
	# Touch first: any tap stops the marker. Emulated mouse clicks from touch
	# are skipped so the same tap cannot leak into the next minigame view.
	if event is InputEventMouseButton and event.device == TouchControls.EMULATED_MOUSE_DEVICE:
		return
	if event.is_action_pressed(&"stop_grind") or _is_screen_tap(event):
		request_stop()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _is_screen_tap(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.pressed


func _draw() -> void:
	# Chalkboard panel, dial track, the correct zone of the method, the marker.
	if model == null:
		return
	var board := Rect2(Vector2.ZERO, size)
	MinigamePainter.paint_board(self, board.size)
	MinigamePainter.paint_track(self, _track_rect())
	MinigamePainter.paint_zone(self, _zone_rect(), ZONE_COLOR)
	MinigamePainter.paint_marker(self, _marker_rect(), MARKER_COLOR)


func _track_rect() -> Rect2:
	return Rect2(TRACK_LEFT, TRACK_TOP, TRACK_RIGHT - TRACK_LEFT, TRACK_HEIGHT)


func _zone_rect() -> Rect2:
	return Rect2(
		_x_for(model.zone_start()),
		ZONE_TOP,
		_x_for(model.zone_end()) - _x_for(model.zone_start()),
		ZONE_HEIGHT
	)


func _marker_rect() -> Rect2:
	return Rect2(
		_x_for(model.position) - MARKER_WIDTH * 0.5, MARKER_TOP, MARKER_WIDTH, MARKER_HEIGHT
	)


func _x_for(dial_position: float) -> float:
	return TRACK_LEFT + (TRACK_RIGHT - TRACK_LEFT) * dial_position
