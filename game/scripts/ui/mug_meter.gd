# ABOUTME: MugMeter draws the awake meter as a coffee mug, ART_DIRECTION section 11.
# ABOUTME: The coffee level in the mug is the meter; low coffee cools and stops the steam.
class_name MugMeter
extends Range

# Placeholder vector art until the real art pass, chalk on the dark board.
# The mug body sits under a steam band, and the handle rides to its right.
const HANDLE_FRACTION := 0.26
const STEAM_BAND_FRACTION := 0.36
const BODY_INNER_MARGIN := 2.0
const RIM_WIDTH := 2.0
const BODY_CORNER := 6
const HANDLE_RADIUS_FRACTION := 0.12
const HANDLE_OFFSET_FRACTION := 0.1
const MIN_COFFEE_PIXELS := 1.0
# The empty mug interior, the dark of the chalkboard.
const INTERIOR_COLOR := Color(0.13, 0.14, 0.12, 1.0)
# Steam is white chalk, section 3. It boils at about eight steps a
# second, like every steam and line in the game, section 12.
const STEAM_COLOR := Color(0.93, 0.95, 0.88, 0.8)
const STEAM_CURLS := 2
const BOIL_STEPS_PER_SECOND := 8.0

# Below this fraction of the full meter the coffee reads low: the steam
# stops and the coffee cools toward rainy blue. The scene sets the number.
@export var low_fraction := 0.25

var _palette: ArtPalette = null
var _steam_time := 0.0
var _boil_step := -1


func fill_fraction() -> float:
	# The coffee level in the mug, from 0 (empty) to 1 (full).
	if max_value <= min_value:
		return 0.0
	var span := max_value - min_value
	return clampf((value - min_value) / span, 0.0, 1.0)


func is_steam_on() -> bool:
	# Steam rises while the coffee stands above the low line.
	return fill_fraction() > low_fraction


func is_low() -> bool:
	return not is_steam_on()


func coffee_color() -> Color:
	# Hot coffee glows buttery yellow, section 5. Below the low line it
	# cools toward rainy blue, the shade color of the world.
	var hot := _world().butter
	if is_steam_on():
		return hot
	return hot.lerp(_world().rain, _cool_weight())


func coffee_rect() -> Rect2:
	# The coffee surface: it fills the mug interior from the bottom up to
	# the meter value.
	var interior := _interior_rect()
	var level_height := interior.size.y * fill_fraction()
	return Rect2(
		Vector2(interior.position.x, interior.end.y - level_height),
		Vector2(interior.size.x, level_height)
	)


func _process(delta: float) -> void:
	# The steam boils in discrete steps of eight a second, section 12. The
	# redraw fires only when a boil step moves, never every frame.
	if not is_steam_on():
		_boil_step = -1
		return
	_steam_time += delta
	var step := floori(_steam_time * BOIL_STEPS_PER_SECOND)
	if step == _boil_step:
		return
	_boil_step = step
	queue_redraw()


func _draw() -> void:
	var body := _body_rect()
	draw_style_box(_interior_box(), body)
	_draw_coffee()
	_draw_handle(body)
	draw_style_box(_rim_box(), body)
	if is_steam_on():
		_draw_steam(body)


func _draw_coffee() -> void:
	var level := coffee_rect()
	if level.size.y < MIN_COFFEE_PIXELS:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = coffee_color()
	box.corner_radius_bottom_left = BODY_CORNER
	box.corner_radius_bottom_right = BODY_CORNER
	draw_style_box(box, level)


func _draw_handle(body: Rect2) -> void:
	# One chalk half-circle that leaves the mug from the right side.
	var radius := size.x * HANDLE_RADIUS_FRACTION
	var center := Vector2(body.size.x + size.x * HANDLE_OFFSET_FRACTION, body.get_center().y)
	draw_arc(center, radius, -PI * 0.5, PI * 0.5, 24, ChalkTheme.CHALK_COLOR, RIM_WIDTH)


func _draw_steam(body: Rect2) -> void:
	# Two chalk curls over the rim. The boil phase freezes in steps, so the
	# steam sways like a hand-made line, not a smooth sine.
	var phase := float(floori(_steam_time * BOIL_STEPS_PER_SECOND)) / BOIL_STEPS_PER_SECOND
	for curl: int in STEAM_CURLS:
		var base_x := body.position.x + body.size.x * (0.34 + 0.42 * float(curl))
		var sway := sin(TAU * (phase * 0.5 + float(curl) * 0.4)) * body.size.x * 0.06
		var center := Vector2(base_x + sway, body.position.y - body.size.y * 0.16)
		var start := PI * (0.6 + 0.5 * float(curl % 2))
		draw_arc(center, body.size.x * 0.12, start, start + PI, 16, STEAM_COLOR, RIM_WIDTH)


func _body_rect() -> Rect2:
	# The mug body under the steam band, without the handle band.
	var width := size.x * (1.0 - HANDLE_FRACTION)
	var top := size.y * STEAM_BAND_FRACTION
	return Rect2(Vector2(0.0, top), Vector2(width, size.y - top))


func _interior_rect() -> Rect2:
	return _body_rect().grow(-BODY_INNER_MARGIN)


func _interior_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = INTERIOR_COLOR
	box.set_corner_radius_all(BODY_CORNER)
	return box


func _rim_box() -> StyleBoxFlat:
	# A transparent box that draws only the chalk contour of the mug.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	box.border_color = ChalkTheme.CHALK_COLOR
	box.set_border_width_all(int(RIM_WIDTH))
	box.set_corner_radius_all(BODY_CORNER)
	return box


func _cool_weight() -> float:
	# One at an empty mug, zero at the low line: the coffee cools as it
	# runs out.
	if low_fraction <= 0.0:
		return 1.0
	return clampf(1.0 - fill_fraction() / low_fraction, 0.0, 1.0)


func _world() -> ArtPalette:
	# Loaded at use time, never const-preloaded: several scripts share this
	# one resource, and a compile-time const can bind it empty (T102).
	if _palette == null:
		_palette = ArtPalette.world()
		if _palette == null:
			_palette = ArtPalette.new()
	return _palette
