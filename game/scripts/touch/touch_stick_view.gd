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

var _pointer := -1

var _knob_offset := Vector2.ZERO


func _ready() -> void:
	# The zone eats the mouse click a touch emulates, so a thumb on the stick
	# never leaks into the mouse-bound gameplay actions below the layer.
	mouse_filter = MOUSE_FILTER_STOP
	model = TouchStick.new()
	model.balance = balance
	queue_redraw()


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


func move_pointer(pointer_id: int, position: Vector2) -> void:
	if _pointer != pointer_id:
		return
	_drag_to(position)


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


func _draw() -> void:
	var center := size * 0.5
	var base_radius: float = balance.stick_max_distance_pixels if balance != null else 88.0
	draw_circle(center, base_radius + BORDER_WIDTH, BOARD_COLOR)
	draw_arc(center, base_radius, 0.0, TAU, 64, CHALK_COLOR, BORDER_WIDTH)
	var dead_zone: float = balance.stick_dead_zone_pixels if balance != null else 20.0
	draw_arc(center, dead_zone, 0.0, TAU, 24, CHALK_COLOR, BORDER_WIDTH * 0.5)
	draw_circle(center + _knob_offset, base_radius * 0.36, KNOB_COLOR)
