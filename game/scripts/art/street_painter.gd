# ABOUTME: StreetPainter draws the ground of one city block: road, curb, sidewalk, and street props.
# ABOUTME: Presentation only: props never collide, and one seed keeps every block the same each run.
class_name StreetPainter
extends RefCounted

# The sidewalk band above the road and the curb lip between them.
const SIDEWALK_DEPTH := 44.0
const SLAB_WIDTH := 52.0
const CURB_HEIGHT := 7.0
# The lane dashes in the middle of the road.
const DASH_LENGTH := 46.0
const DASH_GAP := 34.0
const DASH_WIDTH := 5.0
# The crosswalk at the west end of each block reads the block edge as a corner.
const CROSSWALK_WIDTH := 64.0
const CROSSWALK_STRIPE := 14.0
const CROSSWALK_GAP := 11.0
# Street lamps stand on the sidewalk, one every LAMP_SPACING pixels.
const LAMP_SPACING := 300.0
const LAMP_FIRST_X := 150.0
const LAMP_HEIGHT := 58.0
const LAMP_POOL_RADIUS := 64.0
# Trees line the north edge of the block, in the top band no building uses.
const TREE_SPACING := 210.0
const TREE_ROW_Y := 26.0
const TREE_RADIUS := 26.0
# The low morning sun casts every shadow to the bottom-left, ART_DIRECTION section 5.
const SHADOW_DIRECTION := Vector2(-0.8, 0.45)
const KIND_TEXT_SIZE := 30
const LABEL_TEXT_SIZE := 21


static func lane_rect(size: Vector2, lane_fraction: float) -> Rect2:
	return Rect2(
		Vector2(0.0, size.y * (1.0 - lane_fraction)), Vector2(size.x, size.y * lane_fraction)
	)


static func lamp_positions(size: Vector2, lane_fraction: float) -> Array[Vector2]:
	# The foot of each lamp, on the sidewalk just north of the curb.
	var spots: Array[Vector2] = []
	var foot_y := lane_rect(size, lane_fraction).position.y - SIDEWALK_DEPTH * 0.35
	var x := LAMP_FIRST_X
	while x < size.x - 40.0:
		spots.append(Vector2(x, foot_y))
		x += LAMP_SPACING
	return spots


static func tree_positions(size: Vector2, seed_value: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spots: Array[Vector2] = []
	var x := 70.0 + rng.randf_range(0.0, 60.0)
	while x < size.x - 50.0:
		spots.append(Vector2(x, TREE_ROW_Y + rng.randf_range(-4.0, 6.0)))
		x += TREE_SPACING + rng.randf_range(-40.0, 40.0)
	return spots


static func paint_road(
	canvas: CanvasItem, size: Vector2, lane_fraction: float, palette: ArtPalette, accent: Color
) -> void:
	var lane := lane_rect(size, lane_fraction)
	# The road: a soft blue-brown, mid value and low saturation, so the
	# actors keep the strongest contrast on screen (section 4).
	var asphalt := palette.espresso.lerp(palette.rain, 0.5).lerp(palette.cream, 0.42)
	canvas.draw_rect(lane, asphalt)
	# Pastel smudges break up the flat fill like a soft pastel wash.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _i: int in range(10):
		var center := Vector2(
			rng.randf_range(0.0, size.x), rng.randf_range(lane.position.y, lane.end.y)
		)
		canvas.draw_circle(center, rng.randf_range(30.0, 70.0), Color(palette.cream, 0.05))
	var dash_y := lane.get_center().y
	var x := CROSSWALK_WIDTH + 24.0
	while x < size.x:
		var length := minf(DASH_LENGTH, size.x - x)
		canvas.draw_rect(
			Rect2(Vector2(x, dash_y - DASH_WIDTH * 0.5), Vector2(length, DASH_WIDTH)),
			Color(palette.cream, 0.62)
		)
		x += DASH_LENGTH + DASH_GAP
	_paint_crosswalk(canvas, lane, palette)
	_paint_sidewalk(canvas, size, lane, palette, accent)


static func _paint_crosswalk(canvas: CanvasItem, lane: Rect2, palette: ArtPalette) -> void:
	var y := lane.position.y + CURB_HEIGHT + 8.0
	while y + CROSSWALK_STRIPE < lane.end.y - 6.0:
		canvas.draw_rect(
			Rect2(Vector2(10.0, y), Vector2(CROSSWALK_WIDTH - 20.0, CROSSWALK_STRIPE)),
			Color(palette.cream, 0.7)
		)
		y += CROSSWALK_STRIPE + CROSSWALK_GAP


static func _paint_sidewalk(
	canvas: CanvasItem, size: Vector2, lane: Rect2, palette: ArtPalette, accent: Color
) -> void:
	var walk := Rect2(
		Vector2(0.0, lane.position.y - SIDEWALK_DEPTH), Vector2(size.x, SIDEWALK_DEPTH)
	)
	canvas.draw_rect(walk, palette.cream.lightened(0.08))
	var joint := Color(palette.espresso, 0.22)
	var x := SLAB_WIDTH
	while x < size.x:
		canvas.draw_line(Vector2(x, walk.position.y), Vector2(x, walk.end.y), joint, 1.5)
		x += SLAB_WIDTH
	canvas.draw_line(
		walk.position, Vector2(walk.end.x, walk.position.y), Color(palette.espresso, 0.3), 2.0
	)
	# The curb lip carries the city accent, so each city reads at a glance.
	var curb := Rect2(Vector2(0.0, lane.position.y), Vector2(size.x, CURB_HEIGHT))
	canvas.draw_rect(curb, palette.cream.lerp(accent, 0.35))
	canvas.draw_line(
		Vector2(0.0, curb.end.y), Vector2(size.x, curb.end.y), Color(palette.espresso, 0.55), 2.5
	)
	canvas.draw_rect(
		Rect2(Vector2(0.0, curb.end.y + 1.0), Vector2(size.x, 6.0)), Color(palette.espresso, 0.12)
	)


static func paint_trees(
	canvas: CanvasItem, size: Vector2, seed_value: int, palette: ArtPalette
) -> void:
	for spot: Vector2 in tree_positions(size, seed_value):
		var shadow := spot + SHADOW_DIRECTION * 16.0 + Vector2(0.0, 10.0)
		_ellipse(
			canvas,
			shadow,
			Vector2(TREE_RADIUS * 1.1, TREE_RADIUS * 0.55),
			Color(palette.rain.darkened(0.4), 0.22)
		)
		canvas.draw_rect(
			Rect2(spot + Vector2(-4.0, 0.0), Vector2(8.0, 16.0)),
			palette.espresso.lerp(palette.brick, 0.3)
		)
		var leaf := palette.moss
		canvas.draw_circle(spot + Vector2(-12.0, -4.0), TREE_RADIUS * 0.72, leaf.darkened(0.12))
		canvas.draw_circle(spot + Vector2(12.0, -2.0), TREE_RADIUS * 0.7, leaf.darkened(0.06))
		canvas.draw_circle(spot + Vector2(0.0, -14.0), TREE_RADIUS * 0.8, leaf)
		canvas.draw_circle(
			spot + Vector2(6.0, -20.0), TREE_RADIUS * 0.36, leaf.lerp(palette.butter, 0.35)
		)
		canvas.draw_arc(
			spot + Vector2(0.0, -10.0),
			TREE_RADIUS * 1.02,
			PI * 0.15,
			PI * 1.05,
			18,
			Color(palette.espresso, 0.55),
			2.0,
			true
		)


static func paint_lamps(
	canvas: CanvasItem, size: Vector2, lane_fraction: float, palette: ArtPalette
) -> void:
	# Coffee is light, and so is a street lamp at dawn: each lamp casts a warm
	# butter pool on the sidewalk under its head.
	for foot: Vector2 in lamp_positions(size, lane_fraction):
		var head := foot + Vector2(0.0, -LAMP_HEIGHT)
		for step: int in range(3):
			var radius := LAMP_POOL_RADIUS * (1.0 - 0.28 * float(step))
			_ellipse(
				canvas,
				foot + Vector2(0.0, -6.0),
				Vector2(radius, radius * 0.5),
				Color(palette.butter, 0.07 + 0.04 * float(step))
			)
		canvas.draw_line(
			foot, foot + SHADOW_DIRECTION * 44.0, Color(palette.rain.darkened(0.45), 0.25), 5.0
		)
		_ellipse(canvas, foot, Vector2(7.0, 3.5), palette.espresso)
		canvas.draw_line(foot, head, palette.espresso, 4.0)
		canvas.draw_line(head, head + Vector2(10.0, 2.0), palette.espresso, 3.0)
		canvas.draw_circle(head + Vector2(12.0, 6.0), 9.0, Color(palette.butter, 0.35))
		canvas.draw_circle(head + Vector2(12.0, 6.0), 5.0, palette.butter.lightened(0.3))
		canvas.draw_arc(head + Vector2(12.0, 4.0), 6.5, PI, TAU, 10, palette.espresso, 3.0)


static func paint_marker(
	canvas: CanvasItem, center: Vector2, radius: float, color: Color, palette: ArtPalette
) -> void:
	# A soft pastel pool on the ground, not a flat disc: three rings that grow
	# lighter toward the edge, a dashed chalk rim, and a solid heart.
	for step: int in range(3):
		var r := radius * (1.0 - 0.22 * float(step))
		canvas.draw_circle(center, r, Color(color, 0.22 + 0.18 * float(step)))
	canvas.draw_circle(center, radius * 0.4, color)
	var dashes := 24
	for i: int in range(dashes):
		var a := TAU * float(i) / float(dashes)
		canvas.draw_arc(
			center,
			radius - 3.0,
			a,
			a + TAU / float(dashes) * 0.55,
			4,
			Color(palette.cream, 0.8),
			2.5,
			true
		)


static func paint_sign_text(
	canvas: CanvasItem, top_left: Vector2, width: float, text: String, font_size: int, color: Color
) -> void:
	ChalkTheme.draw_chalk_text(canvas, top_left, text, width, font_size, color)


static func _ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(20):
		var a := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	canvas.draw_colored_polygon(points, color)
