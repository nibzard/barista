# ABOUTME: PaperCupRow draws the cups in hand as a row of paper cup icons, ART_DIRECTION section 11.
# ABOUTME: Presentation only: the HUD feeds the live CoffeeSupply counts, the row draws.
class_name PaperCupRow
extends Control

# Placeholder vector art until the real art pass, chalk on the dark board.
# One paper cup per slot of the carry limit: a filled cup counts one brewed
# cup in hand, a dashed cup counts room for one more, like the interface kit.
const MAX_PITCH := 13.0
const MIN_PITCH := 6.0
const ROW_WIDTH := 190.0
const ROW_HEIGHT := 18.0
# The cup of the interface kit: 18 wide over 28 tall, with a narrow base.
const CUP_RATIO := 18.0 / 28.0
const CUP_WIDTH_FRACTION := 0.85
const TAPER_FRACTION := 0.18
const BAND_TOP_FRACTION := 0.36
const BAND_BOTTOM_FRACTION := 0.64
const OUTLINE_WIDTH := 1.4
const DASH := 2.2
const DASH_GAP := 1.8

var _cups := 0
var _carry_limit := 0

var _palette: ArtPalette = null


func read(cups: int, limit: int) -> void:
	# The HUD polls every frame, so only a real change pays for a redraw.
	if cups == _cups and limit == _carry_limit:
		return
	_cups = cups
	_carry_limit = limit
	custom_minimum_size = _row_minimum_size()
	queue_redraw()


func icon_count() -> int:
	# One cup icon per slot of the carry limit.
	return maxi(_carry_limit, 0)


func filled_count() -> int:
	# The brewed cups in hand, never more icons than the row holds.
	return clampi(_cups, 0, icon_count())


func empty_count() -> int:
	# The room left in the hand, drawn as dashed cups.
	return icon_count() - filled_count()


func is_filled(index: int) -> bool:
	# The held cups fill the row from the left; the room follows them.
	return index >= 0 and index < filled_count()


func cup_pitch() -> float:
	# The cups pack tighter when a big carry limit outgrows the row width.
	var count := icon_count()
	if count == 0:
		return MAX_PITCH
	return clampf(ROW_WIDTH / float(count), MIN_PITCH, MAX_PITCH)


func cup_size() -> Vector2:
	var width := minf(cup_pitch() * CUP_WIDTH_FRACTION, MAX_PITCH - 2.0)
	return Vector2(width, width / CUP_RATIO)


func cup_rect(index: int) -> Rect2:
	# The bounds of one paper cup icon, centered in its pitch slot.
	var cup := cup_size()
	var x := float(index) * cup_pitch() + (cup_pitch() - cup.x) * 0.5
	return Rect2(Vector2(x, (ROW_HEIGHT - cup.y) * 0.5), cup)


func _draw() -> void:
	for index: int in icon_count():
		if is_filled(index):
			_draw_filled_cup(cup_rect(index))
		else:
			_draw_empty_cup(cup_rect(index))


func _draw_filled_cup(rect: Rect2) -> void:
	# A paper cup with its coffee band inside, the world palette on the board.
	draw_colored_polygon(_cup_points(rect), _world().cream)
	draw_colored_polygon(_band_points(rect), _world().brick)
	var outline := _cup_points(rect)
	outline.append(outline[0])
	draw_polyline(outline, ChalkTheme.CHALK_COLOR, OUTLINE_WIDTH)


func _draw_empty_cup(rect: Rect2) -> void:
	# Room for one more cup: a dashed chalk outline with no paper inside.
	var outline := _cup_points(rect)
	outline.append(outline[0])
	var segments := ChalkLines.dash_segments(outline, DASH, DASH_GAP)
	for i: int in range(0, segments.size(), 2):
		draw_line(segments[i], segments[i + 1], ChalkTheme.CHALK_DIM_COLOR, OUTLINE_WIDTH)


func _cup_points(rect: Rect2) -> PackedVector2Array:
	# A paper cup: a wide rim over a narrow base.
	var taper := rect.size.x * TAPER_FRACTION
	return PackedVector2Array(
		[
			Vector2(rect.position.x, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x - taper, rect.end.y),
			Vector2(rect.position.x + taper, rect.end.y),
		]
	)


func _band_points(rect: Rect2) -> PackedVector2Array:
	# The coffee band under the rim, inset with the taper of the cup walls.
	var taper := rect.size.x * TAPER_FRACTION
	var top := rect.position.y + rect.size.y * BAND_TOP_FRACTION
	var bottom := rect.position.y + rect.size.y * BAND_BOTTOM_FRACTION
	return PackedVector2Array(
		[
			Vector2(rect.position.x + taper * BAND_TOP_FRACTION, top),
			Vector2(rect.end.x - taper * BAND_TOP_FRACTION, top),
			Vector2(rect.end.x - taper * BAND_BOTTOM_FRACTION, bottom),
			Vector2(rect.position.x + taper * BAND_BOTTOM_FRACTION, bottom),
		]
	)


func _row_minimum_size() -> Vector2:
	return Vector2(minf(float(icon_count()) * MAX_PITCH, ROW_WIDTH), ROW_HEIGHT)


func _world() -> ArtPalette:
	# Loaded at use time, never const-preloaded: several scripts share this
	# one resource, and a compile-time const can bind it empty (T102).
	if _palette == null:
		_palette = ArtPalette.world()
		if _palette == null:
			_palette = ArtPalette.new()
	return _palette
