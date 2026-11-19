# ABOUTME: AlarmClocks draws the wake-ups as a row of alarm clocks, ART_DIRECTION section 11.
# ABOUTME: A used wake-up is a clock that rings and falls over.
class_name AlarmClocks
extends Control

# Placeholder vector art until the real art pass, chalk on the dark board.
# The standing clocks count the wake-ups left. A used one tips over by
# seventy degrees, loses its hands, and cools to lavender, like the fallen
# clock of the interface kit.
const PITCH := 20.0
const ROW_HEIGHT := 22.0
const BODY_RADIUS := 7.0
const BELL_RADIUS := 2.8
# The bells sit over the case at the diagonal of the interface kit clock.
const BELL_OFFSET := Vector2(5.6, -7.0)
const HAND_LENGTH := 3.9
const FALLEN_ANGLE_DEGREES := 70.0
const FALLEN_ALPHA := 0.55
const OUTLINE_WIDTH := 1.2
# The ring marks beside a fallen case: two short chalk arcs, one on each side.
const RING_RADIUS := BODY_RADIUS + 4.0

var _remaining := 0
var _maximum := 0
var _hardcore := false

var _palette: ArtPalette = null


func read(remaining: int, maximum: int, hardcore: bool) -> void:
	# The HUD polls every frame, so only a real change pays for a redraw.
	if remaining == _remaining and maximum == _maximum and hardcore == _hardcore:
		return
	_remaining = remaining
	_maximum = maximum
	_hardcore = hardcore
	custom_minimum_size = _row_minimum_size()
	queue_redraw()


func clock_count() -> int:
	# Section 9, hardcore mode: the run holds no wake-ups at all, so the row
	# shows no clocks instead of counting a life the mode never grants.
	if _hardcore:
		return 0
	return maxi(_maximum, 0)


func standing_count() -> int:
	# The clocks still on their feet: the wake-ups left.
	if _hardcore:
		return 0
	return clampi(_remaining, 0, clock_count())


func fallen_count() -> int:
	# The clocks that rang and fell over: the wake-ups spent.
	return clock_count() - standing_count()


func is_fallen(index: int) -> bool:
	# The row stands its clocks first, then tips the used ones over.
	return index >= standing_count() and index < clock_count()


func clock_angle(index: int) -> float:
	# Zero degrees stands a clock up; the fallen angle tips it over.
	if is_fallen(index):
		return FALLEN_ANGLE_DEGREES
	return 0.0


func clock_center(index: int) -> Vector2:
	# The middle of one clock case, packed at a fixed pitch.
	return Vector2(PITCH * 0.5 + PITCH * float(index), ROW_HEIGHT * 0.5)


func _draw() -> void:
	for index: int in clock_count():
		if is_fallen(index):
			_draw_fallen_clock(index)
		else:
			_draw_standing_clock(index)


func _draw_standing_clock(index: int) -> void:
	# A clock on its feet: butter case, brick bells, chalk hands at ten past.
	var center := clock_center(index)
	_draw_case(center, 0.0, _world().butter, _world().brick, 1.0)
	draw_line(center, center + Vector2(0.0, -HAND_LENGTH), _world().espresso, OUTLINE_WIDTH)
	draw_line(center, center + Vector2(HAND_LENGTH, 0.0), _world().espresso, OUTLINE_WIDTH)


func _draw_fallen_clock(index: int) -> void:
	# The used wake-up: the case tips over, cools toward lavender, and loses
	# its hands, while two chalk arcs ring out beside it.
	var center := clock_center(index)
	var cooled := _world().cream.lerp(_world().lavender, 0.5)
	_draw_case(center, deg_to_rad(FALLEN_ANGLE_DEGREES), cooled, _world().lavender, FALLEN_ALPHA)
	var ring_color := Color(ChalkTheme.CHALK_COLOR, FALLEN_ALPHA)
	for side: float in [-1.0, 1.0]:
		var base := center + Vector2(side * (RING_RADIUS + 1.5), -RING_RADIUS * 0.7)
		var points := ChalkLines.arc_points(base, 2.6, PI * 1.25, PI * 1.75, 6)
		draw_polyline(points, ring_color, OUTLINE_WIDTH)


func _draw_case(
	center: Vector2, angle: float, case_color: Color, bell_color: Color, alpha: float
) -> void:
	# One clock case under a rotation, with its two bells over the rim.
	draw_set_transform(center, angle, Vector2.ONE)
	var case_paint := Color(case_color, alpha)
	var bell_paint := Color(bell_color, alpha)
	for side: float in [-1.0, 1.0]:
		var bell_center := Vector2(side * BELL_OFFSET.x, BELL_OFFSET.y)
		draw_circle(bell_center, BELL_RADIUS, bell_paint)
		draw_arc(
			bell_center,
			BELL_RADIUS,
			0.0,
			TAU,
			16,
			Color(ChalkTheme.CHALK_COLOR, alpha),
			OUTLINE_WIDTH
		)
	draw_circle(Vector2.ZERO, BODY_RADIUS, case_paint)
	draw_arc(
		Vector2.ZERO, BODY_RADIUS, 0.0, TAU, 24, Color(ChalkTheme.CHALK_COLOR, alpha), OUTLINE_WIDTH
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _row_minimum_size() -> Vector2:
	return Vector2(float(clock_count()) * PITCH, ROW_HEIGHT)


func _world() -> ArtPalette:
	# Loaded at use time, never const-preloaded: several scripts share this
	# one resource, and a compile-time const can bind it empty (T102).
	if _palette == null:
		_palette = ArtPalette.world()
		if _palette == null:
			_palette = ArtPalette.new()
	return _palette
