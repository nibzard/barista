# ABOUTME: TouchButton is one round on-screen action button of the touch controls.
# ABOUTME: Presentation only: the TouchControls layer routes the taps, the button draws.
class_name TouchButton
extends Control

signal tapped
signal released

# Placeholder chalk look until the art pass, in the style of the HUD.
const BOARD_COLOR := Color(0.11, 0.15, 0.13, 0.72)
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const PRESSED_COLOR := Color(0.62, 0.82, 0.55, 0.85)
const BORDER_WIDTH := 2.0
const LABEL_FONT_SIZE := 17

@export var label := ""
@export var radius := 48.0

var _pressed := false
var _available := true


func _ready() -> void:
	# The button zone eats the mouse click a touch emulates, so a tap never
	# leaks into the mouse-bound gameplay actions below the layer.
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(radius * 2.0, radius * 2.0)
	size = custom_minimum_size
	queue_redraw()


func is_available() -> bool:
	return _available


func set_available(available: bool) -> void:
	# Context buttons show only where their action works: REFILL in the cafe,
	# VAN at level 3, BREW at a pot. The state and the visibility always move
	# together, so an open call after a closed start really opens.
	if _available == available and visible == available:
		return
	_available = available
	visible = available
	if not available:
		_pressed = false
	queue_redraw()


func is_pressed() -> bool:
	return _pressed


func is_hit(position: Vector2) -> bool:
	# A tap lands inside the drawn circle, not the square control rect.
	return visible and position.distance_to(get_global_rect().get_center()) <= radius


func press() -> void:
	# The touch lands: the visual dips and the tap fires once.
	if _pressed:
		return
	_pressed = true
	queue_redraw()
	tapped.emit()


func lift() -> void:
	# The touch leaves: only the visual changes, the tap already fired. The
	# release fires too, so a held action like the Minigun stream can stop.
	if not _pressed:
		return
	_pressed = false
	queue_redraw()
	released.emit()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, radius, BOARD_COLOR)
	draw_arc(center, radius - BORDER_WIDTH * 0.5, 0.0, TAU, 48, CHALK_COLOR, BORDER_WIDTH)
	if _pressed:
		draw_circle(center, radius - BORDER_WIDTH * 2.0, PRESSED_COLOR)
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	draw_string(
		font,
		center - text_size * 0.5 + Vector2(0.0, LABEL_FONT_SIZE * 0.35),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		LABEL_FONT_SIZE,
		CHALK_COLOR
	)
