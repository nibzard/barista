# ABOUTME: TouchStickView draws the virtual stick and turns raw touches into the
# ABOUTME: move actions the player polls, so movement needs no keyboard.
class_name TouchStickView
extends Control

# Placeholder chalk look until the art pass, in the style of the HUD.
const BOARD_COLOR := Color(0.11, 0.15, 0.13, 0.55)
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.7)
const KNOB_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const BORDER_WIDTH := 2.0

@export var balance: TouchControlsBalance

var model: TouchStick = null
var highlighted := false

var _pointer := -1
var _pulse_time := 0.0
var _knob_offset := Vector2.ZERO


func _ready() -> void:
	# The zone eats the mouse click a touch emulates, so a thumb on the stick
	# never leaks into the mouse-bound gameplay actions below the layer.
	mouse_filter = MOUSE_FILTER_STOP
	model = TouchStick.new()
	model.balance = balance
	queue_redraw()


func _exit_tree() -> void:
	force_release()


func direction() -> Vector2:
	if model == null:
		return Vector2.ZERO
	return model.direction()


func is_held() -> bool:
	return model != null and model.is_held()


func try_press(pointer_id: int, position: Vector2) -> bool:
	# A touch lands inside the zone: this stick owns the pointer. The control
	# rect is bigger than the drawn base, so a landing thumb never misses.
	if model == null or _pointer != -1:
		return false
	if not get_global_rect().has_point(position):
		return false
	_pointer = pointer_id
	model.press()
	_drag_to(position)
	return true


func move_pointer(pointer_id: int, position: Vector2) -> bool:
	if _pointer != pointer_id:
		return false
	_drag_to(position)
	return true


func release_pointer(pointer_id: int) -> bool:
	if _pointer != pointer_id:
		return false
	force_release()
	return true


func force_release() -> void:
	# The controls hid while the thumb rested: center the stick and stop.
	_pointer = -1
	if model != null:
		model.release()
	_knob_offset = Vector2.ZERO
	_apply_direction(Vector2.ZERO)
	queue_redraw()


func _drag_to(position: Vector2) -> void:
	var offset := position - get_global_rect().get_center()
	model.drag(offset)
	_knob_offset = model.offset()
	_apply_direction(model.direction())
	queue_redraw()


func _apply_direction(direction: Vector2) -> void:
	# The stick drives the same move actions the keys drive, polled by the
	# player every physics frame. Strengths stay analog.
	_set_action(&"move_left", maxf(0.0, -direction.x))
	_set_action(&"move_right", maxf(0.0, direction.x))
	_set_action(&"move_up", maxf(0.0, -direction.y))
	_set_action(&"move_down", maxf(0.0, direction.y))


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	elif Input.is_action_pressed(action):
		Input.action_release(action)


func _process(delta: float) -> void:
	if highlighted and visible:
		_pulse_time += delta
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var base_radius: float = balance.stick_max_distance_pixels if balance != null else 88.0
	if highlighted:
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 7.5)
		var ring_r := base_radius + 7.0 + pulse * 5.0
		var ring_c := Color(0.98, 0.82, 0.32, 0.55 + pulse * 0.4)
		draw_arc(center, ring_r, 0.0, TAU, 64, ring_c, 5.0, true)
	draw_circle(center, base_radius + BORDER_WIDTH, BOARD_COLOR)
	draw_arc(center, base_radius, 0.0, TAU, 64, CHALK_COLOR, BORDER_WIDTH)
	var dead_zone: float = balance.stick_dead_zone_pixels if balance != null else 20.0
	draw_arc(center, dead_zone, 0.0, TAU, 24, CHALK_COLOR, BORDER_WIDTH * 0.5)
	draw_circle(center + _knob_offset, base_radius * 0.36, KNOB_COLOR)
	var font := ChalkTheme.body_font()
	if font == null:
		font = ThemeDB.fallback_font
	var label := "DRAG TO MOVE" if highlighted else "MOVE"
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(
		font,
		Vector2(center.x - tw * 0.5, center.y + base_radius - 10.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		Color(0.99, 0.86, 0.44, 0.95) if highlighted else CHALK_COLOR
	)
