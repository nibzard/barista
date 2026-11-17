# ABOUTME: LabFigure builds one style lab cast member from simple shapes, after the artboard.
# ABOUTME: The feet stand at the origin; the figure faces right. Sleepwalkers sway until they wake.
class_name LabFigure
extends Node2D

signal woke

enum Kind { BARISTA, NEIGHBOR, TOURIST, TECH_BRO, KAREN }

const HEAD_RADIUS := 22.0
const HEAD_CENTER := Vector2(0, -112)
const BODY_CENTER := Vector2(0, -66)
const OUTLINE_WIDTH := 3.0
const LIMB_WIDTH := 9.0
const SKIN := Color("#E9C3A0")
const SKIN_DARK := Color("#D9A47E")
const SHADOW_OFFSET := Vector2(-16, 2)
const SWAY_ANGLE := 0.06
const SWAY_SPEED := 1.6
const WAKE_FILL_SECONDS := 0.9
const WAKE_FILL_RADIUS := 120.0
const WAKE_HOP := 14.0
const ACTOR_GRAPHITE := Color("#3E3446")
const ACTOR_SLEEP_TINT := 0.2

var kind: Kind = Kind.NEIGHBOR
var palette: ArtPalette
var sleepwalking := true

var _sway_phase := 0.0
var _time := 0.0
var _closed_eyes: Line2D
var _open_eyes: Node2D
var _drool: Line2D
var _fill: ColorFill


func setup(figure_kind: Kind, art_palette: ArtPalette, hand_drawn: Shader) -> void:
	kind = figure_kind
	palette = art_palette
	sleepwalking = kind != Kind.BARISTA
	_sway_phase = randf() * TAU
	var shader_material := ShaderMaterial.new()
	shader_material.shader = hand_drawn
	# Actors are pencil: a sleeping figure keeps dark contours and only a light
	# lavender wash, so a hazard stays readable on the sleeping street.
	shader_material.set_shader_parameter("graphite", ACTOR_GRAPHITE)
	shader_material.set_shader_parameter("sleep_tint_amount", ACTOR_SLEEP_TINT)
	material = shader_material
	_fill = ColorFill.new()
	_fill.duration = WAKE_FILL_SECONDS
	_fill.radius = WAKE_FILL_RADIUS
	_fill.start_filled = not sleepwalking
	add_child(_fill)
	_build()


func body_center() -> Vector2:
	return to_global(BODY_CENTER)


func color_fill() -> ColorFill:
	return _fill


func wake(hit_point: Vector2) -> void:
	if not sleepwalking:
		return
	sleepwalking = false
	rotation = 0.0
	_fill.start(hit_point)
	_closed_eyes.visible = false
	_drool.visible = false
	_open_eyes.visible = true
	# A small surprised hop with squash and stretch.
	var hop := create_tween()
	hop.tween_property(self, "scale", Vector2(1.15, 0.85), 0.08)
	hop.tween_property(self, "scale", Vector2(0.9, 1.12), 0.1)
	hop.parallel().tween_property(self, "position:y", position.y - WAKE_HOP, 0.1)
	hop.tween_property(self, "scale", Vector2.ONE, 0.12)
	hop.parallel().tween_property(self, "position:y", position.y, 0.12)
	woke.emit()


func _process(delta: float) -> void:
	_time += delta
	if sleepwalking:
		rotation = sin(_time * SWAY_SPEED + _sway_phase) * SWAY_ANGLE


func _build() -> void:
	_add_shape(_ellipse(SHADOW_OFFSET, 30, 7), Color(palette.rain, 0.4), false)
	match kind:
		Kind.BARISTA:
			_build_barista()
		Kind.NEIGHBOR:
			_build_sleeper(palette.lavender, palette.lavender)
			_add_shape(_nightcap(), palette.lavender.lightened(0.45))
			_add_shape(_circle(HEAD_CENTER + Vector2(32, -16), 5), palette.cream)
		Kind.TOURIST:
			_build_sleeper(palette.teal, SKIN)
			_add_shape(_ellipse(HEAD_CENTER + Vector2(0, -16), 36, 7), palette.cream)
			_add_shape(_rect(Rect2(-16, -150, 32, 18)), palette.cream)
			_add_shape(_rect(Rect2(6, -88, 22, 15)), palette.espresso)
			_add_shape(_rect(Rect2(-24, -52, 22, 10)), palette.brick)
		Kind.TECH_BRO:
			_build_sleeper(palette.teal, palette.teal)
			_add_shape(_rect(Rect2(-22, -92, 13, 62)), Color("#8E8A86"))
			_add_shape(_rect(Rect2(9, -92, 13, 62)), Color("#8E8A86"))
			_add_shape(_rect(Rect2(-14, -172, 28, 7)), palette.espresso)
			_add_line([Vector2(-26, -176), Vector2(-10, -176)], palette.espresso, 2.0)
			_add_line([Vector2(10, -176), Vector2(26, -176)], palette.espresso, 2.0)
		Kind.KAREN:
			_build_karen()
	_add_face()


func _build_sleeper(body_color: Color, arm_color: Color) -> void:
	_add_limb(Vector2(-8, -30), Vector2(-8, 0), palette.espresso.lightened(0.25))
	_add_limb(Vector2(8, -30), Vector2(8, 0), palette.espresso.lightened(0.25))
	_add_shape(_body(), body_color)
	# Arms straight out for the hug.
	_add_limb(Vector2(10, -82), Vector2(48, -86), arm_color)
	_add_limb(Vector2(10, -68), Vector2(46, -68), arm_color)
	_add_shape(_circle(Vector2(52, -86), 6), SKIN)
	_add_shape(_circle(Vector2(50, -68), 6), SKIN)
	_add_shape(_circle(HEAD_CENTER, HEAD_RADIUS), SKIN)


func _build_barista() -> void:
	_add_limb(Vector2(-8, -30), Vector2(-8, -2), palette.espresso)
	_add_limb(Vector2(8, -30), Vector2(8, -2), palette.espresso)
	_add_shape(_rect(Rect2(-16, -6, 18, 8)), palette.espresso)
	_add_shape(_rect(Rect2(2, -6, 20, 8)), palette.espresso)
	_add_shape(_body(), palette.cream)
	_add_shape(_rect(Rect2(-17, -78, 34, 52)), palette.brick)
	_add_shape(_circle(Vector2(-11, -78), 3), palette.butter)
	_add_shape(_circle(Vector2(11, -78), 3), palette.butter)
	# The throwing arm holds a cup up high.
	_add_limb(Vector2(12, -84), Vector2(36, -118), palette.cream)
	_add_shape(_circle(Vector2(38, -122), 6), SKIN_DARK)
	_add_shape(
		PackedVector2Array(
			[Vector2(30, -146), Vector2(46, -146), Vector2(43, -126), Vector2(33, -126)]
		),
		palette.cream
	)
	_add_shape(_circle(HEAD_CENTER, HEAD_RADIUS), SKIN_DARK)
	_add_shape(
		PackedVector2Array(
			[
				Vector2(-22, -116),
				Vector2(-20, -140),
				Vector2(-4, -150),
				Vector2(4, -170),
				Vector2(18, -162),
				Vector2(14, -150),
				Vector2(24, -136),
				Vector2(22, -122),
				Vector2(6, -130),
			]
		),
		palette.espresso
	)
	_add_shape(
		PackedVector2Array(
			[
				Vector2(-6, -98),
				Vector2(4, -84),
				Vector2(20, -90),
				Vector2(24, -104),
				Vector2(12, -100)
			]
		),
		palette.espresso.lightened(0.15)
	)
	_add_shape(_circle(Vector2(-2, -128), 6), palette.cream, true, Color("#C9A24A"))
	_add_shape(_circle(Vector2(12, -128), 6), palette.cream, true, Color("#C9A24A"))


func _build_karen() -> void:
	_add_limb(Vector2(-12, -24), Vector2(-12, 0), SKIN)
	_add_limb(Vector2(12, -24), Vector2(12, 0), SKIN)
	_add_shape(_ellipse(Vector2(0, -62), 38, 36), palette.brick)
	_add_limb(Vector2(26, -76), Vector2(58, -82), palette.brick)
	_add_limb(Vector2(26, -60), Vector2(56, -62), palette.brick)
	_add_shape(_circle(Vector2(62, -82), 6), SKIN)
	_add_shape(_circle(Vector2(60, -62), 6), SKIN)
	_add_shape(_circle(HEAD_CENTER, HEAD_RADIUS), SKIN)
	_add_shape(
		PackedVector2Array(
			[
				Vector2(-24, -104),
				Vector2(-22, -134),
				Vector2(4, -142),
				Vector2(10, -158),
				Vector2(26, -150),
				Vector2(26, -126),
				Vector2(8, -128),
			]
		),
		Color("#E4C27A")
	)
	_add_shape(_rect(Rect2(6, -118, 10, 7)), palette.butter)
	_add_shape(_rect(Rect2(18, -118, 9, 7)), palette.butter)


func _add_face() -> void:
	var eye_y := HEAD_CENTER.y + 2.0
	_closed_eyes = _add_line(
		[Vector2(4, eye_y), Vector2(8, eye_y + 2), Vector2(12, eye_y)], palette.espresso, 2.0
	)
	var second := _add_line(
		[Vector2(15, eye_y), Vector2(18, eye_y + 2), Vector2(21, eye_y)], palette.espresso, 2.0
	)
	second.reparent(_closed_eyes)
	_open_eyes = Node2D.new()
	_open_eyes.use_parent_material = true
	add_child(_open_eyes)
	for eye_x: float in [8.0, 18.0]:
		var eye := Polygon2D.new()
		eye.use_parent_material = true
		eye.color = palette.espresso
		eye.polygon = _circle(Vector2(eye_x, eye_y - 1.0), 3.0)
		_open_eyes.add_child(eye)
	_open_eyes.visible = not sleepwalking
	_closed_eyes.visible = sleepwalking
	_drool = _add_line(
		[Vector2(16, eye_y + 12), Vector2(19, eye_y + 20), Vector2(18, eye_y + 28)],
		Color.WHITE,
		2.4
	)
	_drool.visible = sleepwalking


func _add_shape(
	points: PackedVector2Array,
	fill_color: Color,
	outline := true,
	outline_color := Color.TRANSPARENT
) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.use_parent_material = true
	shape.polygon = points
	shape.color = fill_color
	add_child(shape)
	if outline:
		var line := Line2D.new()
		line.use_parent_material = true
		line.points = points
		line.closed = true
		line.width = OUTLINE_WIDTH
		line.default_color = palette.espresso if outline_color.a == 0.0 else outline_color
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		shape.add_child(line)
	return shape


func _add_line(points: Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.use_parent_material = true
	line.points = PackedVector2Array(points)
	line.default_color = color
	line.width = width
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	return line


func _add_limb(from: Vector2, to: Vector2, color: Color) -> void:
	_add_line([from, to], palette.espresso, LIMB_WIDTH + OUTLINE_WIDTH * 2.0)
	_add_line([from, to], color, LIMB_WIDTH)


func _body() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-18, -92),
			Vector2(18, -92),
			Vector2(22, -60),
			Vector2(20, -28),
			Vector2(-20, -28),
			Vector2(-22, -60),
		]
	)


func _nightcap() -> PackedVector2Array:
	return PackedVector2Array(
		[
			Vector2(-24, -116),
			Vector2(-16, -136),
			Vector2(4, -142),
			Vector2(24, -138),
			Vector2(34, -128),
			Vector2(20, -128),
			Vector2(8, -124),
		]
	)


static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	return _ellipse(center, radius, radius)


static func _ellipse(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 28
	for step in steps:
		var angle := TAU * step / steps
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func _rect(rect: Rect2) -> PackedVector2Array:
	return StyleLab.subdivided_rect(rect)
