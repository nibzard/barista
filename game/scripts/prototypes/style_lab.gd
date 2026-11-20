# ABOUTME: StyleLab is the playable art prototype of ART_DIRECTION.md: one city street block.
# ABOUTME: Tap a sleepwalker to throw coffee and color it in; the tower switch brings the morning.
class_name StyleLab
extends Node2D

const HAND_DRAWN := preload("res://shaders/hand_drawn.gdshader")
const SLEEP_HAZE := preload("res://shaders/sleep_haze.gdshader")
const PAPER_GRAIN := preload("res://shaders/paper_grain.gdshader")

const VIEW_SIZE := Vector2(1280, 720)
const EDGE_STEP := 20.0
const OUTLINE_WIDTH := 3.0
const BOARD_COLOR := Color("#2E302B")
const WOOD_COLOR := Color("#6B4A30")
const CHALK_COLOR := Color("#F4F0E6")
const STREET_COLOR := Color("#9C8F96")
const GRAY_COLOR := Color("#8E8A86")
const GLASS_COLOR := Color("#B9C9CE")
const BARISTA_SPOT := Vector2(470, 450)
const WALKER_SPOTS: Array[Vector2] = [
	Vector2(720, 446), Vector2(870, 436), Vector2(1010, 456), Vector2(330, 640)
]
const TOWER_BASE := Vector2(1180, 640)
const HAZE_CENTER := Vector2(1150, 520)
const HAZE_SIZE := 560.0
const CAFE_GLOW_SPOT := Vector2(185, 250)
const TAP_RADIUS := 80.0
const CUP_FLIGHT_SECONDS := 0.45
const CUP_ARC_HEIGHT := 170.0
const TRAIL_LENGTH := 14
const STREET_FILL_SECONDS := 2.6
const STREET_FILL_RADIUS := 1500.0
const SUNRISE_SECONDS := 2.4
const HAZE_FADE_SECONDS := 1.4
const UI_FONT_SIZE := 22
const TITLE_FONT_SIZE := 26

@export var palette: ArtPalette
@export var city_looks: Array[CityLook] = []

var _city_index := 0
var _world: Node2D
var _street: Node2D
var _street_fill: ColorFill
var _haze: ColorRect
var _address: Label
var _sunlight: CanvasModulate
var _title: Label
var _barista: LabFigure
var _walkers: Array[LabFigure] = []
var _tower_off := false


func _ready() -> void:
	_sunlight = CanvasModulate.new()
	add_child(_sunlight)
	_build_paper()
	_build_ui()
	rebuild()


func rebuild() -> void:
	if _world != null:
		_world.free()
	_walkers.clear()
	_tower_off = false
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	var look := current_city()
	_sunlight.color = look.dusk_light
	_build_street(look)
	_build_cafe(look)
	_build_billboard()
	_build_cafe_glow()
	_build_cast()
	_build_haze()
	_build_weather(look)
	_title.text = "Style lab · %s · tap a sleepwalker" % look.display_name


func current_city() -> CityLook:
	return city_looks[_city_index]


func next_city() -> void:
	_city_index = (_city_index + 1) % city_looks.size()
	rebuild()


func walker_count() -> int:
	return _walkers.size()


func walker(index: int) -> LabFigure:
	return _walkers[index]


func barista() -> LabFigure:
	return _barista


func street_fill() -> ColorFill:
	return _street_fill


func haze_strength() -> float:
	return (_haze.material as ShaderMaterial).get_shader_parameter("strength") as float


func is_tower_off() -> bool:
	return _tower_off


func throw_at(index: int) -> bool:
	var target := _walkers[index]
	if not target.sleepwalking:
		return false
	var start := _barista.to_global(Vector2(38, -136))
	var hit := target.body_center()
	var cup := Polygon2D.new()
	cup.polygon = PackedVector2Array(
		[Vector2(-8, -12), Vector2(8, -12), Vector2(6, 12), Vector2(-6, 12)]
	)
	cup.color = palette.cream
	cup.position = start
	var trail := Line2D.new()
	trail.width = 10.0
	trail.default_color = Color(palette.butter, 0.6)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_world.add_child(trail)
	_world.add_child(cup)
	var control := (start + hit) * 0.5 + Vector2(0, -CUP_ARC_HEIGHT)
	var flight := _world.create_tween()
	flight.tween_method(
		_fly_cup.bind(cup, trail, start, control, hit), 0.0, 1.0, CUP_FLIGHT_SECONDS
	)
	flight.tween_callback(_land_cup.bind(cup, trail, index, hit))
	return true


func wake_walker(index: int, hit_point: Vector2) -> void:
	var target := _walkers[index]
	if not target.sleepwalking:
		return
	target.wake(hit_point)


func switch_off_tower() -> void:
	if _tower_off:
		return
	_tower_off = true
	_street_fill.start(TOWER_BASE)
	var morning := _world.create_tween().set_parallel()
	morning.tween_property(_sunlight, "color", current_city().morning_light, SUNRISE_SECONDS)
	morning.tween_property(_haze.material, "shader_parameter/strength", 0.0, HAZE_FADE_SECONDS)
	morning.tween_property(_address, "modulate:a", 0.0, HAZE_FADE_SECONDS)


func _unhandled_input(event: InputEvent) -> void:
	var tap := event as InputEventMouseButton
	if tap == null or not tap.pressed or tap.button_index != MOUSE_BUTTON_LEFT:
		return
	var point := get_canvas_transform().affine_inverse() * tap.position
	var nearest := -1
	var nearest_distance := TAP_RADIUS
	for index in _walkers.size():
		var distance := _walkers[index].body_center().distance_to(point)
		if _walkers[index].sleepwalking and distance < nearest_distance:
			nearest = index
			nearest_distance = distance
	if nearest >= 0:
		throw_at(nearest)
		get_viewport().set_input_as_handled()


func _fly_cup(
	t: float, cup: Polygon2D, trail: Line2D, start: Vector2, control: Vector2, hit: Vector2
) -> void:
	cup.position = start.lerp(control, t).lerp(control.lerp(hit, t), t)
	cup.rotation = t * TAU
	trail.add_point(cup.position)
	while trail.get_point_count() > TRAIL_LENGTH:
		trail.remove_point(0)


func _land_cup(cup: Polygon2D, trail: Line2D, index: int, hit: Vector2) -> void:
	cup.queue_free()
	var fade := _world.create_tween()
	fade.tween_property(trail, "modulate:a", 0.0, 0.25)
	fade.tween_callback(trail.queue_free)
	_splash(hit)
	wake_walker(index, hit)


func _splash(point: Vector2) -> void:
	var splash := CPUParticles2D.new()
	splash.position = point
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.amount = 22
	splash.lifetime = 0.6
	splash.spread = 180.0
	splash.initial_velocity_min = 120.0
	splash.initial_velocity_max = 240.0
	splash.gravity = Vector2(0, 420)
	splash.scale_amount_min = 0.3
	splash.scale_amount_max = 0.6
	splash.texture = _soft_dot(24)
	var ramp := Gradient.new()
	ramp.set_color(0, palette.butter)
	ramp.set_color(1, Color(palette.espresso, 0.0))
	splash.color_ramp = ramp
	splash.finished.connect(splash.queue_free)
	_world.add_child(splash)
	splash.emitting = true


# --- Building the block -------------------------------------------------------


func _build_street(look: CityLook) -> void:
	_street = _hand_drawn_layer("Street")
	_street_fill = ColorFill.new()
	_street_fill.duration = STREET_FILL_SECONDS
	_street_fill.radius = STREET_FILL_RADIUS
	_street.add_child(_street_fill)
	var sidewalk := palette.cream.darkened(0.05)
	# Back yards behind the building fronts.
	_shape(_street, Rect2(0, 0, VIEW_SIZE.x, 200), palette.moss.lerp(palette.cream, 0.6), false)
	_shape(_street, Rect2(0, 200, VIEW_SIZE.x, 92), sidewalk, false)
	_shape(_street, Rect2(0, 292, VIEW_SIZE.x, 180), STREET_COLOR, false)
	_shape(_street, Rect2(0, 472, VIEW_SIZE.x, 248), sidewalk, false)
	for slab_x in range(80, int(VIEW_SIZE.x), 120):
		_line(
			_street,
			[Vector2(slab_x, 200), Vector2(slab_x, 292)],
			Color(palette.espresso, 0.18),
			1.5
		)
	_line(_street, [Vector2(0, 246), Vector2(VIEW_SIZE.x, 246)], Color(palette.espresso, 0.18), 1.5)
	_line(_street, [Vector2(0, 292), Vector2(VIEW_SIZE.x, 292)], palette.espresso, 4.0)
	_line(_street, [Vector2(0, 472), Vector2(VIEW_SIZE.x, 472)], palette.espresso, 4.0)
	var rail := palette.espresso.lightened(0.15)
	_line(_street, [Vector2(0, 362), Vector2(VIEW_SIZE.x, 362)], rail, 4.0)
	_line(_street, [Vector2(0, 402), Vector2(VIEW_SIZE.x, 402)], rail, 4.0)
	for stripe in 4:
		_shape(_street, Rect2(606 + stripe * 26, 300, 14, 164), Color(palette.cream, 0.9), false)
	# The painted lady house carries the city accent.
	_shape(
		_street,
		_points([Vector2(350, 50), Vector2(455, 8), Vector2(560, 50)]),
		palette.espresso.lightened(0.15)
	)
	_shape(_street, Rect2(350, 50, 210, 152), look.accent)
	_line(_street, [Vector2(350, 74), Vector2(560, 74)], palette.cream, 5.0)
	_shape(_street, Rect2(380, 90, 56, 58), GLASS_COLOR.lerp(palette.cream, 0.3))
	_shape(_street, Rect2(474, 90, 56, 58), GLASS_COLOR.lerp(palette.cream, 0.3))
	_shape(_street, Rect2(430, 160, 50, 42), palette.brick)
	# The startup office with its banner.
	_shape(_street, Rect2(580, 22, 240, 28), GRAY_COLOR)
	_shape(_street, Rect2(580, 50, 240, 152), Color("#E2DCCF"))
	_shape(_street, Rect2(596, 64, 208, 70), GLASS_COLOR)
	_shape(_street, Rect2(600, 142, 200, 26), look.accent)
	_label(_street, "SLEEP IS A BUG", Vector2(600, 142), Vector2(200, 26), 15, palette.cream)
	_shape(_street, Rect2(676, 170, 48, 32), GRAY_COLOR)
	# Props on the lower sidewalk.
	_shape(_street, Rect2(60, 500, 120, 16), palette.brick)
	_shape(_street, Rect2(70, 484, 100, 10), palette.brick)
	_shape(
		_street,
		_points([Vector2(560, 560), Vector2(600, 560), Vector2(592, 600), Vector2(568, 600)]),
		Color("#C97A52")
	)
	_shape(_street, Rect2(760, 520, 44, 58), palette.rain)
	_build_tower()


func _build_tower() -> void:
	var top := TOWER_BASE + Vector2(0, -330)
	_line(_street, [TOWER_BASE, top], GRAY_COLOR.darkened(0.3), 8.0)
	for rung in range(1, 8):
		var y := TOWER_BASE.y - rung * 40.0
		_line(
			_street,
			[Vector2(TOWER_BASE.x - 14, y), Vector2(TOWER_BASE.x + 14, y - 20)],
			GRAY_COLOR,
			3.0
		)
	_shape(
		_street,
		_points(
			[
				top + Vector2(-34, 0),
				top + Vector2(0, 14),
				top + Vector2(34, 0),
				top + Vector2(28, 24),
				top + Vector2(-28, 24)
			]
		),
		GRAY_COLOR
	)
	_shape(_street, _ellipse_points(top + Vector2(0, -12), 7, 7), palette.brick)
	_address = _label(
		_street,
		'"...and furthermore, my fellow Americanos..."',
		Vector2(820, 676),
		Vector2(440, 30),
		16,
		Color(palette.espresso, 0.75)
	)


func _build_cafe(look: CityLook) -> void:
	# The cafe is the sanctuary: it never sleeps, so its layer starts in full color.
	var cafe := _hand_drawn_layer("Cafe")
	var fill := ColorFill.new()
	fill.start_filled = true
	cafe.add_child(fill)
	_shape(cafe, Rect2(30, 16, 300, 34), palette.espresso.lightened(0.15))
	_shape(cafe, Rect2(30, 50, 300, 152), palette.brick)
	_shape(cafe, Rect2(70, 58, 220, 34), BOARD_COLOR)
	_label(cafe, "THE LAST DROP · café", Vector2(70, 58), Vector2(220, 34), 18, CHALK_COLOR)
	for stripe in 12:
		var stripe_color := look.accent if stripe % 2 == 0 else palette.cream
		_shape(cafe, Rect2(26 + stripe * 26, 124, 26, 26), stripe_color, false)
	_line(cafe, [Vector2(26, 124), Vector2(338, 124)], palette.espresso, OUTLINE_WIDTH)
	_line(cafe, [Vector2(26, 150), Vector2(338, 150)], palette.espresso, OUTLINE_WIDTH)
	_shape(cafe, Rect2(46, 160, 160, 40), palette.butter)
	_shape(cafe, Rect2(120, 166, 16, 10), palette.cream)
	_shape(cafe, Rect2(146, 168, 22, 16), palette.moss)
	_shape(cafe, Rect2(226, 154, 54, 48), palette.espresso.lightened(0.15))


func _build_billboard() -> void:
	# Mug Roasters Co. is flat, perfect print: no hand-drawn layer, no grain, no boil.
	var board := Node2D.new()
	board.name = "Billboard"
	_world.add_child(board)
	_plain(board, Rect2(900, 150, 10, 56), palette.mug_black)
	_plain(board, Rect2(1100, 150, 10, 56), palette.mug_black)
	_plain(board, Rect2(846, 14, 318, 140), palette.mug_black)
	_plain(board, Rect2(852, 20, 306, 128), palette.mug_red)
	_plain(board, Rect2(870, 36, 70, 80), Color.WHITE)
	var handle := Line2D.new()
	handle.points = PackedVector2Array(
		[Vector2(940, 54), Vector2(962, 60), Vector2(966, 76), Vector2(962, 92), Vector2(940, 98)]
	)
	handle.width = 10.0
	handle.default_color = Color.WHITE
	board.add_child(handle)
	_plain(board, Rect2(886, 58, 10, 10), palette.mug_black)
	_plain(board, Rect2(914, 58, 10, 10), palette.mug_black)
	var smile := Polygon2D.new()
	smile.polygon = PackedVector2Array(
		[Vector2(882, 80), Vector2(928, 80), Vector2(918, 96), Vector2(905, 101), Vector2(892, 96)]
	)
	smile.color = palette.mug_black
	board.add_child(smile)
	_label(board, "JOIN THE", Vector2(980, 40), Vector2(170, 36), 28, Color.WHITE)
	_label(board, "GRIND", Vector2(980, 74), Vector2(170, 44), 38, palette.mug_black)
	_label(board, "MUG ROASTERS CO.", Vector2(980, 118), Vector2(170, 20), 11, Color.WHITE)


func _build_cafe_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = _soft_dot(256)
	glow.position = CAFE_GLOW_SPOT
	glow.scale = Vector2(1.5, 0.6)
	glow.modulate = Color(palette.butter, 0.4)
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	_world.add_child(glow)


func _build_cast() -> void:
	var kinds := _roster(current_city().city_id)
	var cast: Array[LabFigure] = []
	_barista = _figure(LabFigure.Kind.BARISTA, BARISTA_SPOT)
	cast.append(_barista)
	for index in WALKER_SPOTS.size():
		var walker_figure := _figure(kinds[index], WALKER_SPOTS[index])
		_walkers.append(walker_figure)
		cast.append(walker_figure)
	# Figures lower on the screen stand nearer to the camera, so they draw last.
	cast.sort_custom(func(a: LabFigure, b: LabFigure) -> bool: return a.position.y < b.position.y)
	for figure in cast:
		_world.move_child(figure, -1)


func _build_haze() -> void:
	_haze = ColorRect.new()
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_haze.position = HAZE_CENTER - Vector2(HAZE_SIZE, HAZE_SIZE) * 0.5
	_haze.size = Vector2(HAZE_SIZE, HAZE_SIZE)
	var haze_material := ShaderMaterial.new()
	haze_material.shader = SLEEP_HAZE
	haze_material.set_shader_parameter("haze", palette.lavender)
	haze_material.set_shader_parameter("strength", 1.0)
	haze_material.set_shader_parameter("rect_size", _haze.size)
	_haze.material = haze_material
	# The haze reads the screen. On its own layer, the dusk tint of the
	# CanvasModulate is not applied a second time on top of the screen copy.
	var haze_layer := CanvasLayer.new()
	haze_layer.layer = 1
	haze_layer.follow_viewport_enabled = true
	haze_layer.add_child(_haze)
	_world.add_child(haze_layer)


func _build_weather(look: CityLook) -> void:
	match look.weather:
		CityLook.Weather.CLEAR_FOG:
			for fog_x: float in [120.0, 1160.0]:
				var fog := Sprite2D.new()
				fog.texture = _soft_dot(256)
				fog.position = Vector2(fog_x, 40)
				fog.scale = Vector2(2.6, 0.9)
				fog.modulate = look.weather_color
				_world.add_child(fog)
		CityLook.Weather.DRIZZLE:
			var rain := _weather_particles(look, 140, Vector2(-60, 520), 1.4)
			var streak := _soft_dot(4)
			streak.fill = GradientTexture2D.FILL_LINEAR
			streak.fill_from = Vector2(0.5, 1.0)
			streak.fill_to = Vector2(0.5, 0.0)
			streak.width = 3
			streak.height = 24
			rain.texture = streak
			rain.angle_min = -6.0
			rain.angle_max = -6.0
		CityLook.Weather.FALLING_LEAVES:
			var leaves := _weather_particles(look, 26, Vector2(-30, 60), 6.0)
			leaves.texture = _soft_dot(14)
			leaves.scale_amount_min = 0.8
			leaves.scale_amount_max = 1.3
			leaves.angular_velocity_min = -90.0
			leaves.angular_velocity_max = 90.0


func _build_paper() -> void:
	var paper_layer := CanvasLayer.new()
	paper_layer.layer = 3
	add_child(paper_layer)
	var paper := ColorRect.new()
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	var paper_material := ShaderMaterial.new()
	paper_material.shader = PAPER_GRAIN
	paper.material = paper_material
	paper_layer.add_child(paper)


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 2
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(24, 664)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", palette.espresso)
	ui.add_child(_title)
	var column := VBoxContainer.new()
	column.position = Vector2(1000, 240)
	column.add_theme_constant_override("separation", 12)
	ui.add_child(column)
	column.add_child(_chalk_button("Switch off tower", switch_off_tower))
	column.add_child(_chalk_button("Next city", next_city))
	column.add_child(_chalk_button("Reset", rebuild))


# --- Small helpers ------------------------------------------------------------


func _roster(city_id: String) -> Array[LabFigure.Kind]:
	match city_id:
		"pourtland":
			return [
				LabFigure.Kind.NEIGHBOR,
				LabFigure.Kind.KAREN,
				LabFigure.Kind.TOURIST,
				LabFigure.Kind.NEIGHBOR
			]
		"steamtle":
			return [
				LabFigure.Kind.TOURIST,
				LabFigure.Kind.NEIGHBOR,
				LabFigure.Kind.TOURIST,
				LabFigure.Kind.NEIGHBOR
			]
	return [
		LabFigure.Kind.NEIGHBOR,
		LabFigure.Kind.TOURIST,
		LabFigure.Kind.TECH_BRO,
		LabFigure.Kind.NEIGHBOR
	]


func _figure(kind: LabFigure.Kind, spot: Vector2) -> LabFigure:
	var figure := LabFigure.new()
	figure.position = spot
	figure.setup(kind, palette, HAND_DRAWN)
	_world.add_child(figure)
	return figure


func _hand_drawn_layer(layer_name: String) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	var layer_material := ShaderMaterial.new()
	layer_material.shader = HAND_DRAWN
	layer.material = layer_material
	_world.add_child(layer)
	return layer


func _weather_particles(
	look: CityLook, amount: int, velocity: Vector2, lifetime: float
) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.position = Vector2(VIEW_SIZE.x * 0.5 + 100, -20)
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(VIEW_SIZE.x * 0.6, 10)
	particles.direction = velocity.normalized()
	particles.spread = 4.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = velocity.length() * 0.85
	particles.initial_velocity_max = velocity.length() * 1.15
	particles.color = look.weather_color
	_world.add_child(particles)
	return particles


func _shape(parent: Node, area: Variant, color: Color, outline := true) -> Polygon2D:
	var points: PackedVector2Array = subdivided_rect(area) if area is Rect2 else area
	var shape := Polygon2D.new()
	shape.use_parent_material = true
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)
	if outline:
		var line := _line(shape, Array(points), palette.espresso, OUTLINE_WIDTH)
		line.closed = true
	return shape


func _line(parent: Node, points: Array, color: Color, width: float) -> Line2D:
	var line := Line2D.new()
	line.use_parent_material = true
	line.points = PackedVector2Array(points)
	line.default_color = color
	line.width = width
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	parent.add_child(line)
	return line


func _plain(parent: Node, rect: Rect2, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(
		[
			rect.position,
			Vector2(rect.end.x, rect.position.y),
			rect.end,
			Vector2(rect.position.x, rect.end.y)
		]
	)
	shape.color = color
	parent.add_child(shape)


func _label(
	parent: Node, text: String, at: Vector2, area: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.use_parent_material = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.position = at
	label.size = area
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _chalk_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 64)
	button.add_theme_font_size_override("font_size", UI_FONT_SIZE)
	button.add_theme_color_override("font_color", CHALK_COLOR)
	button.add_theme_color_override("font_hover_color", palette.butter)
	button.add_theme_color_override("font_pressed_color", palette.butter)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = BOARD_COLOR if state != "pressed" else BOARD_COLOR.lightened(0.1)
		box.border_color = WOOD_COLOR
		box.set_border_width_all(5)
		box.set_corner_radius_all(6)
		button.add_theme_stylebox_override(state, box)
	button.pressed.connect(action)
	return button


func _soft_dot(dot_size: int) -> GradientTexture2D:
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = fade
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = dot_size
	dot.height = dot_size
	return dot


func _points(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)


func _ellipse_points(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in 24:
		var angle := TAU * step / 24.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


# A rectangle outline with a point every EDGE_STEP pixels. The extra points let
# the line boil bend long edges a little, like a hand-drawn line.
static func subdivided_rect(rect: Rect2) -> PackedVector2Array:
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	var points := PackedVector2Array()
	for side in 4:
		var from := corners[side]
		var to := corners[(side + 1) % 4]
		var steps := maxi(1, int(from.distance_to(to) / EDGE_STEP))
		for step in steps:
			points.append(from.lerp(to, float(step) / steps))
	return points
