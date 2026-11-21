# ABOUTME: ChibiPainter draws one chibi figure, awake or asleep, for masters and quest people.
# ABOUTME: About 3.5 heads tall with one strong hair shape and one gear item, ART_DIRECTION 7.
class_name ChibiPainter
extends RefCounted

# The one item that tells a role at a glance: an apron for baristas, a guitar
# for a band member, a fleece vest for a founder, and so on.
enum Gear { NONE, APRON, TIE, HEADSET, GUITAR, BASS, STICKS, MIC, VEST, RUBBER_APRON }

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
# Sleepers get a light lavender wash over skin and hair, ART_DIRECTION 1.
const SLEEP_WASH := Color("#B9B2DE")
const SLEEP_WASH_AMOUNT := 0.25
const CREAM := Color("#F3E6C8")
const FLEECE_GRAY := Color("#8E8A86")
const LOGO_TEAL := Color("#3E9C9A")
const RUBBER_YELLOW := Color("#E8B84B")
const DROOL_COLOR := Color(1.0, 1.0, 1.0, 0.95)


static func look_for(key: String) -> Dictionary:
	# One stable look per name: the same master keeps the same skin and hair
	# on every run, with no extra data to author.
	var h := absi(hash(key))
	return {
		"skin": SKIN_TONES[h % SKIN_TONES.size()],
		"hair": HAIR_COLORS[(h / 7) % HAIR_COLORS.size()],
		"long_hair": (h / 3) % 2 == 0,
	}


static func paint(
	canvas: CanvasItem, outfit: Color, key: String, gear := Gear.APRON, awake := true
) -> void:
	var look := look_for(key)
	var skin: Color = look["skin"]
	var hair: Color = look["hair"]
	if not awake:
		skin = skin.lerp(SLEEP_WASH, SLEEP_WASH_AMOUNT)
		hair = hair.lerp(SLEEP_WASH, SLEEP_WASH_AMOUNT)
	var line := ChalkTheme.ESPRESSO_COLOR
	# The ground shadow falls to the bottom-left in the low sun, section 5.
	_ellipse(canvas, Vector2(-4.0, FEET_Y + 1.0), Vector2(18.0, 5.0), Color(0.2, 0.22, 0.32, 0.3))
	for side: float in [-1.0, 1.0]:
		if awake:
			var boot := Rect2(Vector2(side * 7.0 - 5.0, BODY_BOTTOM - 2.0), Vector2(10.0, 12.0))
			canvas.draw_rect(boot, line.lerp(outfit, 0.15))
		else:
			# Sleepers shuffle in soft slippers.
			_ellipse(canvas, Vector2(side * 7.0, FEET_Y - 3.0), Vector2(6.5, 4.5), CREAM)
	var body := _body_polygon()
	canvas.draw_colored_polygon(body, outfit)
	_paint_worn_gear(canvas, gear, outfit)
	var closed := body.duplicate()
	closed.append(body[0])
	canvas.draw_polyline(closed, line, OUTLINE_WIDTH, true)
	_paint_held_gear(canvas, gear, outfit, line)
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
	if awake:
		_paint_face(canvas, skin, line)
	else:
		_paint_sleeping_face(canvas, line)
		_paint_nightcap(canvas, outfit.lightened(0.45), line)
	if gear == Gear.HEADSET:
		_paint_headset(canvas, line)


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


static func _paint_sleeping_face(canvas: CanvasItem, line: Color) -> void:
	# Closed eyes, a small snore mouth, and one white drool arc: comic and
	# never gross, section 20.
	for side: float in [-1.0, 1.0]:
		canvas.draw_arc(HEAD_CENTER + Vector2(side * 5.5, 1.0), 2.8, 0.2, PI - 0.2, 8, line, 1.8)
	canvas.draw_circle(HEAD_CENTER + Vector2(0.0, 7.0), 1.8, line)
	var drool := PackedVector2Array(
		[
			HEAD_CENTER + Vector2(2.5, 7.5),
			HEAD_CENTER + Vector2(4.5, 10.5),
			HEAD_CENTER + Vector2(4.0, 14.0)
		]
	)
	canvas.draw_polyline(drool, DROOL_COLOR, 1.8, true)


static func _paint_nightcap(canvas: CanvasItem, cap: Color, line: Color) -> void:
	# A floppy cone that tips to one side, with a pompom at the hanging tip.
	var top := HEAD_CENTER + Vector2(0.0, -HEAD_RADIUS + 2.0)
	var cone := PackedVector2Array(
		[
			top + Vector2(-14.0, 4.0),
			top + Vector2(-4.0, -9.0),
			top + Vector2(10.0, -8.0),
			top + Vector2(20.0, 4.0),
			top + Vector2(13.0, 3.0),
			top + Vector2(12.0, 6.0),
		]
	)
	canvas.draw_colored_polygon(cone, cap)
	var rim := cone.duplicate()
	rim.append(cone[0])
	canvas.draw_polyline(rim, line, 1.5, true)
	canvas.draw_circle(top + Vector2(20.0, 6.0), 3.5, CREAM)
	canvas.draw_arc(top + Vector2(20.0, 6.0), 3.5, 0.0, TAU, 10, line, 1.2, true)


static func _paint_worn_gear(canvas: CanvasItem, gear: Gear, outfit: Color) -> void:
	# Gear that lies on the body, under the outline.
	match gear:
		Gear.APRON:
			canvas.draw_colored_polygon(_apron_polygon(8.0, 10.0), CREAM)
			canvas.draw_line(
				Vector2(-6.0, BODY_TOP + 12.0),
				Vector2(6.0, BODY_TOP + 12.0),
				outfit.darkened(0.2),
				2.0
			)
		Gear.RUBBER_APRON:
			canvas.draw_colored_polygon(_apron_polygon(10.0, 13.0), RUBBER_YELLOW)
			canvas.draw_line(
				Vector2(-4.0, BODY_TOP + 2.0), Vector2(-8.0, BODY_TOP + 6.0), RUBBER_YELLOW, 2.0
			)
			canvas.draw_line(
				Vector2(4.0, BODY_TOP + 2.0), Vector2(8.0, BODY_TOP + 6.0), RUBBER_YELLOW, 2.0
			)
		Gear.TIE:
			var collar := PackedVector2Array(
				[Vector2(-7.0, BODY_TOP), Vector2(7.0, BODY_TOP), Vector2(0.0, BODY_TOP + 7.0)]
			)
			canvas.draw_colored_polygon(collar, Color.WHITE)
			var tie := PackedVector2Array(
				[
					Vector2(-2.0, BODY_TOP + 4.0),
					Vector2(2.0, BODY_TOP + 4.0),
					Vector2(3.5, BODY_BOTTOM - 6.0),
					Vector2(0.0, BODY_BOTTOM - 3.0),
					Vector2(-3.5, BODY_BOTTOM - 6.0)
				]
			)
			canvas.draw_colored_polygon(tie, Color("#A8432F"))
		Gear.VEST:
			# The gray fleece vest over a dark shirt, with one teal logo.
			for side: float in [-1.0, 1.0]:
				var panel := PackedVector2Array(
					[
						Vector2(side * 3.0, BODY_TOP),
						Vector2(side * (BODY_HALF_WIDTH - 3.0), BODY_TOP),
						Vector2(side * BODY_HALF_WIDTH, BODY_TOP + 6.0),
						Vector2(side * (BODY_HALF_WIDTH + 2.0), BODY_BOTTOM),
						Vector2(side * 3.0, BODY_BOTTOM)
					]
				)
				canvas.draw_colored_polygon(panel, FLEECE_GRAY)
			canvas.draw_circle(Vector2(-8.0, BODY_TOP + 8.0), 2.2, LOGO_TEAL)
		_:
			pass


static func _paint_held_gear(canvas: CanvasItem, gear: Gear, outfit: Color, line: Color) -> void:
	# Gear held in the hands: the hands draw over it.
	match gear:
		Gear.GUITAR, Gear.BASS:
			var neck_length := 30.0 if gear == Gear.BASS else 22.0
			var wood := Color("#C9772E") if gear == Gear.GUITAR else Color("#3B2418")
			var neck_end := Vector2(
				BODY_HALF_WIDTH + neck_length * 0.7, BODY_TOP - neck_length * 0.5
			)
			canvas.draw_line(Vector2(0.0, BODY_TOP + 12.0), neck_end, line, 4.0, true)
			for lobe: Vector2 in [Vector2(-6.0, BODY_TOP + 16.0), Vector2(-1.0, BODY_TOP + 11.0)]:
				canvas.draw_circle(lobe, 7.5 if lobe.x < -2.0 else 6.0, wood)
			canvas.draw_circle(Vector2(-3.0, BODY_TOP + 13.0), 2.2, line)
		Gear.STICKS:
			for side: float in [-1.0, 1.0]:
				var hand := Vector2(side * (BODY_HALF_WIDTH + 2.0), BODY_TOP + 12.0)
				canvas.draw_line(hand, hand + Vector2(side * 6.0, -16.0), CREAM, 3.0, true)
		Gear.MIC:
			var hand := Vector2(BODY_HALF_WIDTH + 2.0, BODY_TOP + 12.0)
			canvas.draw_line(hand, hand + Vector2(-2.0, -12.0), line, 3.0, true)
			canvas.draw_circle(hand + Vector2(-2.0, -14.0), 4.0, FLEECE_GRAY)
			canvas.draw_arc(hand + Vector2(-2.0, -14.0), 4.0, 0.0, TAU, 10, line, 1.2, true)
		Gear.HEADSET:
			# A small laptop held in front: he routes cabs even in his sleep.
			var lid := Rect2(Vector2(-12.0, BODY_TOP + 8.0), Vector2(24.0, 14.0))
			canvas.draw_rect(lid, FLEECE_GRAY.darkened(0.3))
			canvas.draw_rect(lid, line, false, 1.5)
			canvas.draw_circle(lid.get_center(), 2.0, outfit.lightened(0.5))
		_:
			pass


static func _paint_headset(canvas: CanvasItem, line: Color) -> void:
	canvas.draw_arc(HEAD_CENTER, HEAD_RADIUS + 2.0, PI * 1.1, PI * 1.9, 12, line, 2.5, true)
	for side: float in [-1.0, 1.0]:
		canvas.draw_circle(HEAD_CENTER + Vector2(side * (HEAD_RADIUS + 1.0), 0.0), 4.0, line)
	canvas.draw_line(
		HEAD_CENTER + Vector2(-HEAD_RADIUS - 1.0, 2.0),
		HEAD_CENTER + Vector2(-6.0, 9.0),
		line,
		1.5,
		true
	)


static func _apron_polygon(top_half: float, bottom_half: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-top_half, BODY_TOP + 6.0),
			Vector2(top_half, BODY_TOP + 6.0),
			Vector2(bottom_half, BODY_BOTTOM - 1.0),
			Vector2(-bottom_half, BODY_BOTTOM - 1.0)
		]
	)


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
