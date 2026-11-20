# ABOUTME: TouchButton is one round on-screen action button of the touch controls.
# ABOUTME: Presentation only: the TouchControls layer routes the taps, the button draws.
class_name TouchButton
extends Control

signal tapped
signal released

# The glyph a coaster wears, ART_DIRECTION section 11: icons replace words
# where possible. Cup for throw, mug for drink, roll arrow for dodge; the
# rest follow the interface kit of the artboard.
enum Icon {
	CUP,
	MUG,
	ROLL_ARROW,
	UP_ARROW,
	SERVE_CUP,
	WRENCH,
	SWAP_ARROWS,
	CYCLE_ARROWS,
	FILL_CUP,
	VAN,
	POT,
	SPROUT,
	RETICLE,
}

# Placeholder chalk look until the art pass. The coaster is kraft paper with
# a dashed rim and a white chalk glyph, like the interface kit.
const COASTER_COLOR := Color("#C9935E")
const RIM_COLOR := Color("#8A5A36")
const CHALK_COLOR := Color(0.93, 0.95, 0.88, 0.9)
const PRESSED_COLOR := Color(0.62, 0.82, 0.55, 0.85)
const BORDER_WIDTH := 2.0
const RIM_RADIUS_FRACTION := 0.72
const RIM_DASH := 4.0
const RIM_GAP := 3.0
const ICON_WIDTH := 2.8
# The glyph art draws inside a box of this radius; every other radius scales it.
const ICON_UNIT_RADIUS := 48.0

@export var icon: Icon = Icon.CUP
@export var radius := 48.0

var caption := ""
var highlighted := false

var _pressed := false
var _available := true
var _pulse_time := 0.0


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
		lift()
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


func _process(delta: float) -> void:
	if highlighted and visible:
		_pulse_time += delta
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	if highlighted:
		var pulse := 0.5 + 0.5 * sin(_pulse_time * 7.5)
		var ring_r := radius + 5.0 + pulse * 4.0
		var ring_c := Color(0.98, 0.82, 0.32, 0.55 + pulse * 0.4)
		draw_arc(center, ring_r, 0.0, TAU, 48, ring_c, 4.5, true)
	draw_circle(center, radius, COASTER_COLOR)
	draw_arc(center, radius - BORDER_WIDTH * 0.5, 0.0, TAU, 48, CHALK_COLOR, BORDER_WIDTH)
	if _pressed:
		draw_circle(center, radius - BORDER_WIDTH * 2.0, PRESSED_COLOR)
	_draw_rim(center)
	_draw_icon(center - Vector2(0.0, 5.0 if not caption.is_empty() else 0.0))
	if not caption.is_empty():
		_draw_caption(center)


func _draw_caption(center: Vector2) -> void:
	var font := ChalkTheme.body_font()
	if font == null:
		font = ThemeDB.fallback_font
	var font_size := 13 if radius >= 46.0 else 11
	var text_w := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pill_w := maxf(text_w + 14.0, 44.0)
	var pill_h := float(font_size + 7)
	var pill_rect := Rect2(
		Vector2(center.x - pill_w * 0.5, center.y + radius - pill_h - 1.0), Vector2(pill_w, pill_h)
	)
	draw_rect(pill_rect, Color(0.14, 0.11, 0.09, 0.92))
	var border_c := Color(0.98, 0.82, 0.32, 0.95) if highlighted else RIM_COLOR
	draw_rect(pill_rect, border_c, false, 1.6)
	draw_string(
		font,
		Vector2(center.x - text_w * 0.5, pill_rect.position.y + pill_h - 4.0),
		caption,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		Color(0.99, 0.88, 0.48, 1.0) if highlighted else CHALK_COLOR
	)


func _draw_rim(center: Vector2) -> void:
	# The dashed inner ring of the coaster, like the interface kit.
	var circle := ChalkLines.arc_points(center, radius * RIM_RADIUS_FRACTION, 0.0, TAU, 40)
	var segments := ChalkLines.dash_segments(circle, RIM_DASH, RIM_GAP)
	for i: int in range(0, segments.size(), 2):
		draw_line(segments[i], segments[i + 1], RIM_COLOR, BORDER_WIDTH * 0.8)


func _draw_icon(center: Vector2) -> void:
	# Every glyph is chalk line art in a local frame around the center, sized
	# by the button radius.
	var glyph_scale := radius / ICON_UNIT_RADIUS
	draw_set_transform(center, 0.0, Vector2.ONE * glyph_scale)
	match icon:
		Icon.CUP:
			_draw_cup_icon()
		Icon.MUG:
			_draw_mug_icon()
		Icon.ROLL_ARROW:
			_draw_roll_arrow_icon()
		Icon.UP_ARROW:
			_draw_up_arrow_icon()
		Icon.SERVE_CUP:
			_draw_serve_cup_icon()
		Icon.WRENCH:
			_draw_wrench_icon()
		Icon.SWAP_ARROWS:
			_draw_swap_arrows_icon()
		Icon.CYCLE_ARROWS:
			_draw_cycle_arrows_icon()
		Icon.FILL_CUP:
			_draw_fill_cup_icon()
		Icon.VAN:
			_draw_van_icon()
		Icon.POT:
			_draw_pot_icon()
		Icon.SPROUT:
			_draw_sprout_icon()
		Icon.RETICLE:
			_draw_reticle_icon()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _chalk_line(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, CHALK_COLOR, ICON_WIDTH, true)


func _chalk_closed(points: PackedVector2Array) -> void:
	# A chalk outline that closes back on its first point.
	var closed := points.duplicate()
	closed.append(closed[0])
	draw_polyline(closed, CHALK_COLOR, ICON_WIDTH, true)


func _chalk_curve(from: Vector2, control: Vector2, to: Vector2) -> void:
	# One chalk curl, like steam over a mug.
	draw_polyline(ChalkLines.curve_points(from, control, to), CHALK_COLOR, ICON_WIDTH, true)


func _arrow_head(tip: Vector2, direction: Vector2) -> void:
	# Two chalk barbs that mark the head of an arrow.
	var back := -direction.normalized()
	for turn: float in [deg_to_rad(32.0), deg_to_rad(-32.0)]:
		_chalk_line(tip, tip + back.rotated(turn) * 4.5)


func _draw_cup_icon() -> void:
	# A paper cup under two motion curls: the throw, section 11.
	_chalk_closed(
		PackedVector2Array(
			[Vector2(-7.0, -3.0), Vector2(7.0, -3.0), Vector2(4.5, 12.0), Vector2(-4.5, 12.0)]
		)
	)
	_chalk_curve(Vector2(-5.5, -6.0), Vector2(-8.5, -10.0), Vector2(-5.0, -14.0))
	_chalk_curve(Vector2(5.5, -6.0), Vector2(8.5, -10.0), Vector2(5.0, -14.0))


func _draw_mug_icon() -> void:
	# A mug with a handle and one steam curl: the drink, section 11.
	draw_rect(Rect2(-8.0, -6.0, 13.0, 17.0), CHALK_COLOR, false, ICON_WIDTH)
	draw_arc(Vector2(9.0, 3.0), 4.5, -PI * 0.5, PI * 0.5, 16, CHALK_COLOR, ICON_WIDTH, true)
	_chalk_curve(Vector2(-1.5, -9.0), Vector2(-4.5, -12.0), Vector2(-1.0, -15.0))


func _draw_roll_arrow_icon() -> void:
	# A near-full circle with an arrowhead: the roll, section 11.
	var start := deg_to_rad(60.0)
	var end := start + TAU * 0.8
	draw_arc(Vector2.ZERO, 9.0, start, end, 32, CHALK_COLOR, ICON_WIDTH, true)
	var tip := Vector2(9.0, 0.0).rotated(end)
	var tangent := Vector2(-sin(end), cos(end))
	_arrow_head(tip, tangent)


func _draw_up_arrow_icon() -> void:
	# An up arrow: the interact action, like the interface kit.
	_chalk_closed(
		PackedVector2Array(
			[
				Vector2(-4.0, 12.0),
				Vector2(-4.0, -2.0),
				Vector2(-9.0, -2.0),
				Vector2(0.0, -12.0),
				Vector2(9.0, -2.0),
				Vector2(4.0, -2.0),
				Vector2(4.0, 12.0),
			]
		)
	)


func _draw_serve_cup_icon() -> void:
	# A cup handed to the right: the serve.
	_chalk_closed(
		PackedVector2Array(
			[Vector2(-10.0, -9.0), Vector2(-2.0, -9.0), Vector2(-3.5, 3.0), Vector2(-8.5, 3.0)]
		)
	)
	_chalk_line(Vector2(-5.0, 8.0), Vector2(9.0, 8.0))
	_arrow_head(Vector2(12.0, 8.0), Vector2(1.0, 0.0))


func _draw_wrench_icon() -> void:
	# An open-end wrench across the diagonal: the support tool. The head is a
	# circle with its notch open away from the handle, up and to the left.
	draw_arc(
		Vector2(-5.0, -5.0),
		5.0,
		deg_to_rad(-65.0),
		deg_to_rad(115.0),
		20,
		CHALK_COLOR,
		ICON_WIDTH,
		true
	)
	_chalk_line(Vector2(-1.5, -1.5), Vector2(9.0, 9.0))


func _draw_swap_arrows_icon() -> void:
	# Two opposing arrows: the tool swap.
	_chalk_line(Vector2(-9.0, -4.0), Vector2(8.0, -4.0))
	_arrow_head(Vector2(11.0, -4.0), Vector2(1.0, 0.0))
	_chalk_line(Vector2(9.0, 5.0), Vector2(-8.0, 5.0))
	_arrow_head(Vector2(-11.0, 5.0), Vector2(-1.0, 0.0))


func _draw_cycle_arrows_icon() -> void:
	# Two chasing arcs: the weapon swap.
	var first := deg_to_rad(10.0)
	var first_end := deg_to_rad(150.0)
	draw_arc(Vector2.ZERO, 9.0, first, first_end, 16, CHALK_COLOR, ICON_WIDTH, true)
	_arrow_head(Vector2(9.0, 0.0).rotated(first_end), Vector2(-sin(first_end), cos(first_end)))
	var second := deg_to_rad(190.0)
	var second_end := deg_to_rad(330.0)
	draw_arc(Vector2.ZERO, 9.0, second, second_end, 16, CHALK_COLOR, ICON_WIDTH, true)
	_arrow_head(Vector2(9.0, 0.0).rotated(second_end), Vector2(-sin(second_end), cos(second_end)))


func _draw_fill_cup_icon() -> void:
	# A down arrow over a cup: the refill.
	_chalk_line(Vector2(0.0, -13.0), Vector2(0.0, -6.0))
	_arrow_head(Vector2(0.0, -3.0), Vector2(0.0, 1.0))
	_chalk_closed(
		PackedVector2Array(
			[Vector2(-7.0, 2.0), Vector2(7.0, 2.0), Vector2(4.5, 13.0), Vector2(-4.5, 13.0)]
		)
	)


func _draw_van_icon() -> void:
	# The mobile cafe van: a box, a cab, and two wheels.
	_chalk_closed(
		PackedVector2Array(
			[
				Vector2(-11.0, -5.0),
				Vector2(3.0, -5.0),
				Vector2(9.0, -1.0),
				Vector2(9.0, 6.0),
				Vector2(-11.0, 6.0),
			]
		)
	)
	draw_arc(Vector2(-6.0, 8.0), 2.6, 0.0, TAU, 12, CHALK_COLOR, ICON_WIDTH, true)
	draw_arc(Vector2(4.0, 8.0), 2.6, 0.0, TAU, 12, CHALK_COLOR, ICON_WIDTH, true)


func _draw_pot_icon() -> void:
	# A moka pot under two steam curls: the brew.
	_chalk_closed(
		PackedVector2Array(
			[
				Vector2(-4.0, -6.0),
				Vector2(4.0, -6.0),
				Vector2(7.0, 1.0),
				Vector2(5.0, 11.0),
				Vector2(-5.0, 11.0),
				Vector2(-7.0, 1.0),
			]
		)
	)
	_chalk_curve(Vector2(-3.0, -9.0), Vector2(-5.5, -12.0), Vector2(-2.5, -15.0))
	_chalk_curve(Vector2(3.0, -9.0), Vector2(5.5, -12.0), Vector2(2.5, -15.0))


func _draw_sprout_icon() -> void:
	# A seedling with two leaves: the plant.
	_chalk_line(Vector2(0.0, 12.0), Vector2(0.0, 0.0))
	_chalk_curve(Vector2(0.0, 0.0), Vector2(-10.0, -1.0), Vector2(-9.0, -9.0))
	_chalk_curve(Vector2(0.0, 0.0), Vector2(10.0, -1.0), Vector2(9.0, -9.0))


func _draw_reticle_icon() -> void:
	# A target ring with four ticks: the cure weapon.
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 24, CHALK_COLOR, ICON_WIDTH, true)
	for angle_deg: float in [0.0, 90.0, 180.0, 270.0]:
		var direction := Vector2(1.0, 0.0).rotated(deg_to_rad(angle_deg))
		_chalk_line(direction * 7.0, direction * 11.0)
	draw_circle(Vector2.ZERO, 1.2, CHALK_COLOR)
