# ABOUTME: ChibiPainter draws a fully colored, awake chibi figure for masters and quest people.
# ABOUTME: About 3.5 heads tall with one strong hair shape, per ART_DIRECTION section 7.
class_name ChibiPainter
extends RefCounted

const SKIN_TONES: Array[Color] = [
	Color("#F6D7BC"), Color("#E9B98F"), Color("#C98F62"), Color("#8E5B3C")
]
const HAIR_COLORS: Array[Color] = [
	Color("#3B2418"), Color("#7A4A2A"), Color("#C9A15A"), Color("#A8432F"), Color("#D9D2C5")
]
const HEAD_CENTER := Vector2(0.0, -20.0)
const HEAD_RADIUS := 15.0
const BODY_TOP := -6.0
const BODY_BOTTOM := 20.0
const BODY_HALF_WIDTH := 15.0
const FEET_Y := 30.0
const OUTLINE_WIDTH := 2.0


static func look_for(key: String) -> Dictionary:
	# One stable look per name: the same master keeps the same skin and hair
	# on every run, with no extra data to author.
	var h := absi(hash(key))
	return {
		"skin": SKIN_TONES[h % SKIN_TONES.size()],
		"hair": HAIR_COLORS[(h / 7) % HAIR_COLORS.size()],
		"long_hair": (h / 3) % 2 == 0,
	}


static func paint(canvas: CanvasItem, outfit: Color, key: String) -> void:
	var look := look_for(key)
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	var line := ChalkTheme.ESPRESSO_COLOR
	# The ground shadow falls to the bottom-left in the low sun, section 5.
	_ellipse(canvas, Vector2(-4.0, FEET_Y + 1.0), Vector2(18.0, 5.0), Color(0.2, 0.22, 0.32, 0.3))
	for side: float in [-1.0, 1.0]:
		var boot := Rect2(Vector2(side * 7.0 - 5.0, BODY_BOTTOM - 2.0), Vector2(10.0, 12.0))
		canvas.draw_rect(boot, line.lerp(outfit, 0.15))
	var body := _body_polygon()
	canvas.draw_colored_polygon(body, outfit)
	# A cream apron: every master is a barista first.
	var apron := PackedVector2Array(
		[
			Vector2(-8.0, BODY_TOP + 6.0),
			Vector2(8.0, BODY_TOP + 6.0),
			Vector2(10.0, BODY_BOTTOM - 1.0),
			Vector2(-10.0, BODY_BOTTOM - 1.0)
		]
	)
	canvas.draw_colored_polygon(apron, Color("#F3E6C8"))
	canvas.draw_line(
		Vector2(-6.0, BODY_TOP + 12.0), Vector2(6.0, BODY_TOP + 12.0), outfit.darkened(0.2), 2.0
	)
	var closed := body.duplicate()
	closed.append(body[0])
	canvas.draw_polyline(closed, line, OUTLINE_WIDTH, true)
	# Big hands, drawn to hold a cup.
	for side: float in [-1.0, 1.0]:
		var hand := Vector2(side * (BODY_HALF_WIDTH + 2.0), BODY_TOP + 12.0)
		canvas.draw_circle(hand, 5.0, skin)
		canvas.draw_arc(hand, 5.0, 0.0, TAU, 12, line, 1.5, true)
	if bool(look["long_hair"]):
		canvas.draw_circle(HEAD_CENTER + Vector2(0.0, 5.0), HEAD_RADIUS + 2.0, hair)
	canvas.draw_circle(HEAD_CENTER, HEAD_RADIUS, skin)
	canvas.draw_colored_polygon(_hair_cap(), hair)
	canvas.draw_arc(HEAD_CENTER, HEAD_RADIUS, 0.0, TAU, 28, line, OUTLINE_WIDTH, true)
	_paint_face(canvas, skin, line)


static func _paint_face(canvas: CanvasItem, skin: Color, line: Color) -> void:
	# Awake people have open eyes with a chalk shine, and a small smile.
	for side: float in [-1.0, 1.0]:
		var eye := HEAD_CENTER + Vector2(side * 5.5, 2.0)
		canvas.draw_circle(eye, 2.6, line)
		canvas.draw_circle(eye + Vector2(0.8, -0.9), 0.9, Color.WHITE)
		canvas.draw_circle(
			HEAD_CENTER + Vector2(side * 9.0, 7.0),
			2.6,
			Color(skin.lerp(Color("#A8432F"), 0.45), 0.6)
		)
	canvas.draw_arc(HEAD_CENTER + Vector2(0.0, 6.0), 3.5, 0.3, PI - 0.3, 8, line, 1.5, true)


static func _body_polygon() -> PackedVector2Array:
	var points := PackedVector2Array()
	points.append(Vector2(-BODY_HALF_WIDTH + 3.0, BODY_TOP))
	points.append(Vector2(BODY_HALF_WIDTH - 3.0, BODY_TOP))
	points.append(Vector2(BODY_HALF_WIDTH, BODY_TOP + 6.0))
	points.append(Vector2(BODY_HALF_WIDTH + 2.0, BODY_BOTTOM))
	points.append(Vector2(-BODY_HALF_WIDTH - 2.0, BODY_BOTTOM))
	points.append(Vector2(-BODY_HALF_WIDTH, BODY_TOP + 6.0))
	return points


static func _hair_cap() -> PackedVector2Array:
	# The top of the head plus a fringe: the hair carries the identity in the
	# top-down view, section 7.
	var points := PackedVector2Array()
	for i: int in range(13):
		var a := PI + PI * float(i) / 12.0
		points.append(HEAD_CENTER + Vector2(cos(a), sin(a)) * (HEAD_RADIUS + 1.5))
	points.append(HEAD_CENTER + Vector2(HEAD_RADIUS * 0.6, -2.0))
	points.append(HEAD_CENTER + Vector2(0.0, -5.0))
	points.append(HEAD_CENTER + Vector2(-HEAD_RADIUS * 0.6, -1.0))
	return points


static func _ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(20):
		var a := TAU * float(i) / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	canvas.draw_colored_polygon(points, color)
