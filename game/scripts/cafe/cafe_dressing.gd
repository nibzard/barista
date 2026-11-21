# ABOUTME: CafeDressing draws the furniture of the city cafe: counter, machine, rug, tables.
# ABOUTME: Presentation only: nothing collides, so the cafe anchors and walk paths stay free.
class_name CafeDressing
extends Node2D

# Every spot is a fraction of the interior half extents, minus one to one per
# axis, like the cafe anchors of CityBlockView. The spots keep clear of the
# player start (-0.72, -0.45), the master spot (0.65, -0.5), the television
# (-0.75, 0.68), and the walk from the south door.
const COUNTER_SPAN := Vector2(-0.38, 0.32)
const COUNTER_Y := -0.84
const COUNTER_DEPTH := 30.0
const MACHINE_X := 0.08
const RUG_CENTER := Vector2(0.0, 0.12)
const RUG_RADII := Vector2(0.36, 0.3)
const TABLE_SPOTS: Array[Vector2] = [Vector2(0.5, 0.46), Vector2(-0.4, 0.3)]
const TABLE_RADIUS := 17.0
const PLANT_SPOTS: Array[Vector2] = [Vector2(0.9, 0.84), Vector2(-0.92, -0.86), Vector2(0.9, -0.86)]
const LAMP_SPOTS: Array[Vector2] = [Vector2(-0.2, -0.55), Vector2(0.24, -0.55), Vector2(0.5, 0.3)]

# The open floor of the cafe, centered on this node. The city sets it from the
# shell interior before the first draw.
var interior_size := Vector2(480.0, 260.0)

var _palette: ArtPalette


func _ready() -> void:
	_palette = ArtPalette.world()
	queue_redraw()


func spot(fraction: Vector2) -> Vector2:
	return fraction * interior_size * 0.5


func _draw() -> void:
	if _palette == null:
		return
	_draw_rug()
	_draw_lamp_pools()
	_draw_counter()
	for fraction: Vector2 in TABLE_SPOTS:
		_draw_table(spot(fraction))
	for fraction: Vector2 in PLANT_SPOTS:
		_draw_plant(spot(fraction))


func _draw_rug() -> void:
	var center := spot(RUG_CENTER)
	var radii := RUG_RADII * interior_size * 0.5
	_ellipse(center, radii, _palette.brick.lerp(_palette.cream, 0.15))
	_ellipse(center, radii * 0.86, _palette.butter.lerp(_palette.brick, 0.35))
	_ellipse(center, radii * 0.62, _palette.brick.lerp(_palette.cream, 0.3))
	_ellipse(center, radii * 0.22, _palette.butter.lerp(_palette.cream, 0.3))


func _draw_lamp_pools() -> void:
	# Coffee is light: warm butter pools under the pendant lamps, section 5.
	for fraction: Vector2 in LAMP_SPOTS:
		var center := spot(fraction)
		for step: int in range(3):
			_ellipse(
				center,
				Vector2(60.0, 34.0) * (1.0 - 0.25 * float(step)),
				Color(_palette.butter, 0.08)
			)


func _draw_counter() -> void:
	var left := spot(Vector2(COUNTER_SPAN.x, COUNTER_Y))
	var right := spot(Vector2(COUNTER_SPAN.y, COUNTER_Y))
	var top := Rect2(Vector2(left.x, left.y), Vector2(right.x - left.x, COUNTER_DEPTH * 0.55))
	var front := Rect2(Vector2(left.x, top.end.y), Vector2(top.size.x, COUNTER_DEPTH * 0.45))
	draw_rect(
		Rect2(front.position + Vector2(-8.0, 6.0), front.size), Color(_palette.espresso, 0.25)
	)
	draw_rect(front, _palette.brick.lerp(_palette.espresso, 0.25))
	var x := front.position.x + 18.0
	while x < front.end.x:
		draw_line(
			Vector2(x, front.position.y + 2.0),
			Vector2(x, front.end.y - 2.0),
			Color(_palette.espresso, 0.5),
			1.5
		)
		x += 18.0
	draw_rect(top, _palette.cream.lerp(_palette.espresso, 0.2))
	draw_line(
		top.position + Vector2(0.0, 2.0),
		Vector2(top.end.x, top.position.y + 2.0),
		Color(_palette.cream, 0.7),
		2.0
	)
	draw_rect(
		Rect2(top.position, Vector2(top.size.x, COUNTER_DEPTH)), _palette.espresso, false, 2.0
	)
	_draw_machine(Vector2(spot(Vector2(MACHINE_X, COUNTER_Y)).x, top.position.y))
	# A row of cups and a tip jar on the counter.
	for i: int in range(3):
		var cup := Vector2(left.x + 22.0 + 15.0 * float(i), top.get_center().y)
		draw_circle(cup, 5.0, _palette.cream)
		draw_arc(cup, 5.0, 0.0, TAU, 12, _palette.espresso, 1.5)
		draw_circle(cup, 2.5, _palette.espresso.lerp(_palette.brick, 0.3))
	var jar := Vector2(right.x - 20.0, top.get_center().y - 2.0)
	draw_rect(
		Rect2(jar - Vector2(6.0, 8.0), Vector2(12.0, 14.0)),
		Color(_palette.rain.lightened(0.5), 0.8)
	)
	draw_rect(Rect2(jar - Vector2(6.0, 8.0), Vector2(12.0, 14.0)), _palette.espresso, false, 1.5)


func _draw_machine(base: Vector2) -> void:
	# A brass espresso machine: the warmest object in the room, with chalk steam.
	var body := Rect2(base + Vector2(-26.0, -20.0), Vector2(52.0, 30.0))
	draw_rect(body, _palette.butter.lerp(_palette.brick, 0.25))
	draw_rect(Rect2(body.position, Vector2(body.size.x, 8.0)), _palette.butter.lightened(0.2))
	draw_rect(body, _palette.espresso, false, 2.0)
	for side: float in [-12.0, 12.0]:
		draw_circle(base + Vector2(side, -4.0), 5.0, _palette.espresso)
		draw_circle(base + Vector2(side, -4.0), 2.5, _palette.cream.lerp(_palette.butter, 0.4))
	for curl: int in range(2):
		var origin := body.position + Vector2(14.0 + 24.0 * float(curl), -4.0)
		draw_arc(
			origin + Vector2(0.0, -8.0),
			5.0,
			PI * 0.5,
			PI * 1.5,
			8,
			Color(_palette.cream, 0.75),
			2.0
		)
		draw_arc(
			origin + Vector2(0.0, -18.0),
			5.0,
			-PI * 0.5,
			PI * 0.5,
			8,
			Color(_palette.cream, 0.6),
			2.0
		)


func _draw_table(center: Vector2) -> void:
	_ellipse(
		center + Vector2(-6.0, 8.0),
		Vector2(TABLE_RADIUS * 1.6, TABLE_RADIUS * 0.8),
		Color(_palette.espresso, 0.22)
	)
	for side: float in [-1.0, 1.0]:
		var chair := center + Vector2(side * (TABLE_RADIUS + 12.0), 2.0)
		draw_circle(chair, 9.0, _palette.brick.lerp(_palette.espresso, 0.2))
		draw_arc(chair, 9.0, 0.0, TAU, 14, _palette.espresso, 1.5)
	draw_circle(center, TABLE_RADIUS, _palette.cream.lerp(_palette.espresso, 0.12))
	draw_arc(center, TABLE_RADIUS, 0.0, TAU, 20, _palette.espresso, 2.0)
	draw_circle(center + Vector2(-4.0, -3.0), 5.0, _palette.cream)
	draw_arc(center + Vector2(-4.0, -3.0), 5.0, 0.0, TAU, 12, _palette.espresso, 1.5)


func _draw_plant(center: Vector2) -> void:
	draw_rect(Rect2(center + Vector2(-9.0, 0.0), Vector2(18.0, 14.0)), _palette.brick)
	draw_rect(
		Rect2(center + Vector2(-9.0, 0.0), Vector2(18.0, 14.0)), _palette.espresso, false, 1.5
	)
	for leaf: Vector2 in [Vector2(-9.0, -6.0), Vector2(8.0, -7.0), Vector2(0.0, -14.0)]:
		draw_circle(
			center + leaf, 9.0, _palette.moss.lerp(_palette.butter, 0.1 if leaf.y < -10.0 else 0.0)
		)
	draw_arc(
		center + Vector2(0.0, -8.0),
		15.0,
		PI * 1.1,
		PI * 1.9,
		10,
		Color(_palette.espresso, 0.6),
		1.5
	)


func _ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(28):
		var a := TAU * float(i) / 28.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)
