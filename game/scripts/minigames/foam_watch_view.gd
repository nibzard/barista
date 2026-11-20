# ABOUTME: FoamWatchView draws and drives The Foam Watch minigame.
# ABOUTME: Presentation only: every grade comes from the pure FoamWatch model.
class_name FoamWatchView
extends Control

signal finished(foam_result: FoamResult)

# Placeholder chalkboard look until the art pass, in the style of the HUD.
const BOARD_COLOR := Color(0.11, 0.15, 0.13, 0.92)
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const TRACK_COLOR := Color(0.07, 0.1, 0.08, 1)
const MARKER_COLOR := Color(0.95, 0.8, 0.3, 1)
const COFFEE_COLOR := Color(0.45, 0.3, 0.18, 0.95)
const FOAM_COLOR := Color(0.9, 0.85, 0.7, 0.95)
const DANGER_COLOR := Color(0.85, 0.35, 0.3, 1)
const FLAME_COLOR := Color(0.95, 0.55, 0.25, 0.9)
const GRACE_ARMED_COLOR := Color(0.93, 0.95, 0.88, 0.3)
const BORDER_WIDTH := 2.0
const TICK_HEIGHT := 3.0
# Pot and flame geometry inside the 520 by 360 panel. The coffee fills the
# bottom of the pot and stays put; the foam grows from the coffee surface up
# to the rim.
const POT_LEFT := 150.0
const POT_TOP := 84.0
const POT_WIDTH := 140.0
const POT_HEIGHT := 200.0
const POT_INSET := 4.0
const COFFEE_SHARE := 0.55
const FLAME_BASE_Y := 316.0
const FLAME_MAX_HEIGHT := 26.0
const FLAME_WIDTH := 84.0
const GRACE_LEFT := 316.0
const GRACE_TOP := 84.0
const GRACE_WIDTH := 28.0
const GRACE_HEIGHT := 200.0
const HEAT_TEXT := "STEP 1: THE POT HEATS UP"
const RISE_TEXT := "STEP 2: LET THE FOAM RISE"
const RUSH_TEXT := "THE FOAM RUSHES!"
const RIM_TEXT := "LIFT NOW!"

@export var balance: FoamWatchBalance
@export var method: BrewingMethod

var model: FoamWatch = null

var _announced := false
var _prompt_text := ""

@onready var method_label: Label = $MethodLabel
@onready var step_label: Label = $StepLabel
@onready var result_label: Label = $ResultLabel


func _ready() -> void:
	begin(method)


func _process(delta: float) -> void:
	if model == null or _announced:
		return
	model.tick(delta)
	_update_step_label()
	if not model.is_running():
		_announce(model.result)
	else:
		queue_redraw()


func begin(p_method: BrewingMethod) -> void:
	# Start one watch for a method. The brew flow calls this for every cup
	# after the Grind Dial pre-step.
	model = FoamWatch.new(balance)
	_announced = false
	_prompt_text = ""
	method_label.text = "FOAM WATCH: %s" % p_method.display_name.to_upper()
	result_label.text = ""
	result_label.visible = false
	_update_step_label()
	queue_redraw()


func request_lift() -> FoamResult:
	# Lift the pot where it stands. Safe to call twice and safe after the end.
	if model == null:
		return null
	var foam_result := model.lift()
	_announce(foam_result)
	return foam_result


func _unhandled_input(event: InputEvent) -> void:
	# Touch first: any tap lifts the pot. Emulated mouse clicks from touch are
	# skipped so a tap that just closed the grind dial cannot lift a cold pot.
	if event is InputEventMouseButton and event.device == TouchControls.EMULATED_MOUSE_DEVICE:
		return
	if event.is_action_pressed(&"lift_pot") or _is_screen_tap(event):
		request_lift()
		if get_viewport() != null:
			get_viewport().set_input_as_handled()


func _is_screen_tap(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.pressed


func _announce(foam_result: FoamResult) -> void:
	if _announced or foam_result == null:
		return
	_announced = true
	result_label.text = _result_text(foam_result)
	result_label.visible = true
	queue_redraw()
	finished.emit(foam_result)


func _result_text(foam_result: FoamResult) -> String:
	match foam_result.outcome:
		FoamResult.Outcome.LIFTED:
			return "Foam lifted. Score %d." % roundi(foam_result.score)
		FoamResult.Outcome.BOILED_OVER:
			return "Boiled over. Greed costs the cup. Score %d." % roundi(foam_result.score)
		_:
			return "Cold pot. No foam. Score %d." % roundi(foam_result.score)


func _update_step_label() -> void:
	var text := _prompt()
	if text != _prompt_text:
		_prompt_text = text
		step_label.text = text


func _prompt() -> String:
	if model.step == FoamWatch.Step.HEAT:
		return HEAT_TEXT
	if model.is_at_rim():
		return RIM_TEXT
	if model.is_rushing():
		return RUSH_TEXT
	return RISE_TEXT


func _draw() -> void:
	# Chalkboard panel, the pot with its coffee and rising foam, the flame
	# under it, and the grace bar that drains while the foam sits at the rim.
	if model == null:
		return
	var board := Rect2(Vector2.ZERO, size)
	draw_rect(board, BOARD_COLOR)
	draw_rect(board, CHALK_COLOR, false, BORDER_WIDTH)
	_draw_pot()
	_draw_flame()
	_draw_grace_bar()


func _draw_pot() -> void:
	var pot := Rect2(POT_LEFT, POT_TOP, POT_WIDTH, POT_HEIGHT)
	draw_rect(pot, TRACK_COLOR)
	draw_rect(_coffee_rect(), COFFEE_COLOR)
	if model.foam > 0.0:
		draw_rect(_foam_rect(), _foam_color())
	draw_rect(_rush_tick_rect(), _rush_tick_color())
	draw_rect(pot, CHALK_COLOR, false, BORDER_WIDTH)


func _draw_flame() -> void:
	# The flame grows with the heat and burns at full size once the boil
	# starts, so the heat step reads without numbers.
	if model.heat <= 0.0:
		return
	var height := FLAME_MAX_HEIGHT * model.heat
	var width := FLAME_WIDTH * (0.4 + 0.6 * model.heat)
	var center_x := POT_LEFT + POT_WIDTH * 0.5
	draw_rect(Rect2(center_x - width * 0.5, FLAME_BASE_Y - height, width, height), FLAME_COLOR)


func _draw_grace_bar() -> void:
	# The last safe moment: the bar stands full and dim until the foam reaches
	# the rim, then drains in the danger color until the pot boils over.
	var bar := Rect2(GRACE_LEFT, GRACE_TOP, GRACE_WIDTH, GRACE_HEIGHT)
	draw_rect(bar, TRACK_COLOR)
	draw_rect(_grace_fill_rect(), _grace_color())
	draw_rect(bar, CHALK_COLOR, false, BORDER_WIDTH)


func _interior() -> Rect2:
	return Rect2(
		POT_LEFT + POT_INSET,
		POT_TOP + POT_INSET,
		POT_WIDTH - POT_INSET * 2.0,
		POT_HEIGHT - POT_INSET * 2.0
	)


func _coffee_rect() -> Rect2:
	var interior := _interior()
	var coffee_height := interior.size.y * COFFEE_SHARE
	return Rect2(
		interior.position.x,
		interior.position.y + interior.size.y - coffee_height,
		interior.size.x,
		coffee_height
	)


func _foam_rect() -> Rect2:
	# The foam band sits on the coffee surface and grows up to the rim.
	var coffee := _coffee_rect()
	var foam_height := _foam_zone_height() * model.foam
	return Rect2(coffee.position.x, coffee.position.y - foam_height, coffee.size.x, foam_height)


func _rush_tick_rect() -> Rect2:
	# The chalk line the foam passes before the rush starts.
	var y := _coffee_surface_y() - _foam_zone_height() * balance.rush_start_foam
	return Rect2(POT_LEFT - 8.0, y - TICK_HEIGHT * 0.5, POT_WIDTH + 16.0, TICK_HEIGHT)


func _coffee_surface_y() -> float:
	return _coffee_rect().position.y


func _foam_zone_height() -> float:
	# The room between the coffee surface and the rim.
	return _interior().size.y * (1.0 - COFFEE_SHARE)


func _grace_fill_rect() -> Rect2:
	var remaining := 1.0
	if model.is_at_rim():
		remaining = clampf(1.0 - model.at_rim_seconds / balance.boil_over_grace_seconds, 0.0, 1.0)
	var height := GRACE_HEIGHT * remaining
	return Rect2(GRACE_LEFT, GRACE_TOP + GRACE_HEIGHT - height, GRACE_WIDTH, height)


func _foam_color() -> Color:
	return DANGER_COLOR if model.is_at_rim() else FOAM_COLOR


func _grace_color() -> Color:
	return DANGER_COLOR if model.is_at_rim() else GRACE_ARMED_COLOR


func _rush_tick_color() -> Color:
	return MARKER_COLOR if model.is_rushing() else CHALK_COLOR
