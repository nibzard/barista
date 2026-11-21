# ABOUTME: MinigamePainter draws the shared look of the brew minigames: board, gauges, coffee.
# ABOUTME: Presentation only: views pass in their own geometry, so every hit rect stays unchanged.
class_name MinigamePainter
extends RefCounted

const FRAME_WIDTH := 10.0
const CORNER := 14
const SMUDGE_COUNT := 6
const COFFEE_DARK := Color("#3B2418")
const COFFEE := Color("#6B4126")
const CREMA := Color("#C98E52")
const CERAMIC := Color("#F3E6C8")
const PAPER := Color("#FBF3E2")
const STEAM := Color(0.96, 0.94, 0.9, 0.7)


static func paint_board(canvas: CanvasItem, board_size: Vector2) -> void:
	# A wood-framed cafe chalkboard with soft chalk smudges, ART_DIRECTION
	# section 11, instead of a flat dark rectangle.
	var outer := Rect2(Vector2.ZERO, board_size)
	var frame := StyleBoxFlat.new()
	frame.bg_color = ChalkTheme.WOOD_COLOR
	frame.set_corner_radius_all(CORNER)
	frame.shadow_color = ChalkTheme.SHADOW_COLOR
	frame.shadow_size = 8
	frame.shadow_offset = Vector2(0.0, 6.0)
	frame.anti_aliasing = true
	canvas.draw_style_box(frame, outer)
	var board := StyleBoxFlat.new()
	board.bg_color = ChalkTheme.BOARD_COLOR
	board.set_corner_radius_all(CORNER - 6)
	board.anti_aliasing = true
	var inner := outer.grow(-FRAME_WIDTH)
	canvas.draw_style_box(board, inner)
	# The light top edge of the frame and the chalk ledge at the bottom.
	canvas.draw_line(
		Vector2(CORNER, 3.0), Vector2(board_size.x - CORNER, 3.0), Color(1.0, 0.9, 0.7, 0.25), 2.0
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(board_size.x) * 31 + int(board_size.y)
	for _i: int in range(SMUDGE_COUNT):
		var center := Vector2(
			rng.randf_range(inner.position.x + 30.0, inner.end.x - 30.0),
			rng.randf_range(inner.position.y + 30.0, inner.end.y - 30.0)
		)
		canvas.draw_circle(center, rng.randf_range(70.0, 130.0), Color(1.0, 1.0, 1.0, 0.012))
	var chalk := Rect2(Vector2(board_size.x - 70.0, board_size.y - 9.0), Vector2(26.0, 5.0))
	canvas.draw_rect(chalk, Color(ChalkTheme.CHALK_COLOR, 0.85))


static func paint_track(canvas: CanvasItem, rect: Rect2) -> void:
	# A rounded, inset gauge track with a chalk rim.
	var box := StyleBoxFlat.new()
	box.bg_color = ChalkTheme.BOARD_DEEP_COLOR.darkened(0.3)
	box.set_corner_radius_all(int(minf(minf(rect.size.x, rect.size.y) * 0.5, 10.0)))
	box.border_color = Color(ChalkTheme.CHALK_COLOR, 0.7)
	box.set_border_width_all(2)
	box.anti_aliasing = true
	canvas.draw_style_box(box, rect.grow(3.0))


static func paint_zone(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	# The sweet spot reads as a glowing chalk band, with a brighter core.
	canvas.draw_rect(rect.grow(3.0), Color(color, 0.25))
	canvas.draw_rect(rect, color)
	canvas.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.35), false, 1.5)


static func paint_marker(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.0, 0.0, 0.0, 0.3))
	canvas.draw_rect(rect.grow(1.0), ChalkTheme.ESPRESSO_COLOR)
	canvas.draw_rect(rect, color)


static func paint_glass(canvas: CanvasItem, rect: Rect2, fill_rect: Rect2, fill: float) -> void:
	# A glass of coffee seen from the side: dark body, a crema band on top,
	# a glass shine, and steam once the glass is half full.
	canvas.draw_rect(rect, Color(ChalkTheme.CHALK_COLOR, 0.08))
	if fill > 0.0 and fill_rect.size.y > 0.0:
		canvas.draw_rect(fill_rect, COFFEE)
		var crema := Rect2(
			fill_rect.position, Vector2(fill_rect.size.x, minf(8.0, fill_rect.size.y))
		)
		canvas.draw_rect(crema, CREMA)
	canvas.draw_line(
		rect.position + Vector2(5.0, 8.0),
		Vector2(rect.position.x + 5.0, rect.end.y - 8.0),
		Color(1.0, 1.0, 1.0, 0.25),
		3.0
	)
	canvas.draw_rect(rect, ChalkTheme.CHALK_COLOR, false, 2.5)
	if fill >= 0.5:
		paint_steam(canvas, Vector2(rect.get_center().x, rect.position.y - 6.0), 2)


static func paint_steam(canvas: CanvasItem, base: Vector2, curls: int) -> void:
	var phase := float(Time.get_ticks_msec()) * 0.003
	for i: int in range(curls):
		var x := base.x + (float(i) - float(curls - 1) * 0.5) * 12.0
		var sway := sin(phase + float(i)) * 3.0
		canvas.draw_arc(Vector2(x + sway, base.y - 8.0), 5.0, PI * 0.5, PI * 1.5, 8, STEAM, 2.0)
		canvas.draw_arc(
			Vector2(x - sway, base.y - 18.0), 5.0, -PI * 0.5, PI * 0.5, 8, Color(STEAM, 0.45), 2.0
		)


static func paint_brew_bed(
	canvas: CanvasItem, center: Vector2, bed_radius: float, fill: float, puddle_radius: float
) -> void:
	# A pour-over seen from above: the ceramic dripper rim, the pleated paper
	# filter, and the coffee bed. The bed blooms lighter and bubbles as the
	# fill grows, and spare water pools on top in a pale ring.
	canvas.draw_circle(center + Vector2(-6.0, 8.0), bed_radius + 16.0, Color(0.0, 0.0, 0.0, 0.25))
	canvas.draw_circle(center, bed_radius + 14.0, CERAMIC)
	canvas.draw_arc(center, bed_radius + 14.0, 0.0, TAU, 48, ChalkTheme.ESPRESSO_COLOR, 2.5, true)
	canvas.draw_circle(center, bed_radius + 4.0, PAPER)
	for i: int in range(16):
		var a := TAU * float(i) / 16.0
		canvas.draw_line(
			center + Vector2.from_angle(a) * (bed_radius - 2.0),
			center + Vector2.from_angle(a) * (bed_radius + 4.0),
			Color(ChalkTheme.ESPRESSO_COLOR, 0.25),
			1.5
		)
	var bloom := clampf(fill, 0.0, 1.0)
	canvas.draw_circle(center, bed_radius - 2.0, COFFEE_DARK.lerp(COFFEE, 0.3 + 0.4 * bloom))
	canvas.draw_circle(center, (bed_radius - 2.0) * (0.35 + 0.5 * bloom), CREMA.lerp(COFFEE, 0.45))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bubbles := int(18.0 * bloom)
	for _i: int in range(bubbles):
		var spot := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(4.0, bed_radius * 0.8)
		canvas.draw_arc(
			center + spot, rng.randf_range(2.0, 4.5), 0.0, TAU, 8, Color(CREMA, 0.8), 1.2
		)
	if puddle_radius > 0.0:
		canvas.draw_circle(center, puddle_radius, Color(0.55, 0.72, 0.85, 0.55))
		canvas.draw_arc(center, puddle_radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.5), 1.5, true)
