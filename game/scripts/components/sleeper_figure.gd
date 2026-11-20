# ABOUTME: SleeperFigure draws one sleepwalker as placeholder vector art, ART_DIRECTION section 7.
# ABOUTME: The cast rule: 3.5 heads tall, oversized hands, pastel pajamas, nightcap, one drool arc.
class_name SleeperFigure
extends RefCounted


# One drawn shape of a figure. The polygon is local to the walker Visual node.
class Part:
	extends RefCounted

	var part_name := ""
	var polygon := PackedVector2Array()
	var color := Color.WHITE
	var outlined := true

	func _init(
		part_name: String, polygon: PackedVector2Array, color: Color, outlined := true
	) -> void:
		self.part_name = part_name
		self.polygon = polygon
		self.color = color
		self.outlined = outlined


# Shared body metrics, ART_DIRECTION section 7: big head, small body, about
# 3.5 heads tall, hands made to hold cups. The readability test reads these.
const HEAD_RADIUS := 9.0
const HAND_RADIUS := 6.0
const OUTLINE_WIDTH := 2.0
# The pale sleepwalker skin, "pale people", section 6.
const SKIN := Color("#E9C3A0")
# The gray of the Tech Bro fleece vest.
const VEST_GRAY := Color("#8E8A86")
# The silver of the tinfoil hat, the only shiny silver in the cast.
const SILVER := Color("#C9CDD6")
const HAIR_DARK := Color("#3A2A22")
# The drool is white chalk, comic and never gross, section 20.
const DROOL_COLOR := Color(1.0, 1.0, 1.0, 0.95)
# The part name of the cap figure. The live build draws the cap through the
# Nightcap node of the scene, so the part data alone must not add a second one.
const NIGHTCAP_PART := "NightcapFigure"
# The wake front of ART_DIRECTION section 1: a sleeping walker is a pencil
# sketch in a lavender wash, and the coffee colors the figure in, from the
# hit outwards. The shader stays a path, loaded at use time (T102).
const HAND_DRAWN_SHADER_PATH := "res://shaders/hand_drawn.gdshader"
const WAKE_FILL_PART := "WakeFill"
const WAKE_FILL_SECONDS := 0.9
const WAKE_FILL_RADIUS := 120.0
# Actors are pencil: dark graphite contours and a light lavender wash, so a
# hazard stays readable on a sleeping street, like the style lab cast.
const ACTOR_GRAPHITE := Color("#3E3446")
const ACTOR_SLEEP_TINT := 0.2
# The awake-only eye dots stay out of the sleeping silhouette data.
const AWAKE_ONLY_PREFIX := "EyeOpen"


# The full part list of one type: the pure data the readability test reads.
static func parts_for(type: EnemyType, palette: ArtPalette) -> Array[Part]:
	if type == null or palette == null:
		return []
	var pajama := type.pajama_color
	var pajama_light := pajama.lightened(0.45)
	var pajama_dark := pajama.darkened(0.3)
	var parts: Array[Part] = []
	match type.special_behavior:
		EnemyType.SpecialBehavior.PHOTO_FLASH:
			_add_tourist_parts(parts, pajama_dark, pajama_light, palette)
		EnemyType.SpecialBehavior.DRONE_ATTACK:
			_add_tech_bro_parts(parts, pajama_dark, palette)
		EnemyType.SpecialBehavior.DASH_CHARGE:
			_add_gamer_parts(parts, pajama, pajama_dark, palette)
		EnemyType.SpecialBehavior.TINFOIL_HAT:
			_add_tinfoil_parts(parts, pajama_dark, pajama_light)
		EnemyType.SpecialBehavior.KAREN_SURPRISE:
			_add_karen_parts(parts, pajama.darkened(0.3), palette)
		EnemyType.SpecialBehavior.MOONWALK:
			_add_moonwalker_parts(parts, pajama_dark)
		_:
			_add_neighbor_parts(parts, pajama_dark, pajama_light, palette)
	_add_face_parts(parts, palette, _head_center(type))
	_add_drool_parts(parts, _head_center(type))
	_add_nightcap_part(parts, type, pajama_light, _head_center(type))
	return parts


# Every shape as one solid silhouette, the one-centimeter read of a type.
static func silhouette_parts(type: EnemyType) -> Array[PackedVector2Array]:
	var palette := ArtPalette.world()
	var shapes: Array[PackedVector2Array] = [_torso_polygon(type)]
	for part: Part in parts_for(type, palette):
		if part.polygon.is_empty() or part.part_name.begins_with(AWAKE_ONLY_PREFIX):
			continue
		shapes.append(part.polygon)
	return shapes


# Applies the figure to a live walker: the Visual node keeps the pajama torso
# and the Nightcap node keeps the cap, and every other part lands as a child.
static func build(visual: Polygon2D, nightcap: Polygon2D, type: EnemyType) -> void:
	if visual == null or type == null:
		return
	var palette := ArtPalette.world()
	if palette == null:
		return
	_clear_parts(visual, nightcap)
	visual.polygon = _torso_polygon(type)
	visual.color = type.pajama_color
	if nightcap != null:
		if _wears_nightcap(type):
			nightcap.polygon = _nightcap_polygon(_head_center(type))
			nightcap.color = type.pajama_color.lightened(0.45)
		else:
			nightcap.polygon = PackedVector2Array()
	for part: Part in parts_for(type, palette):
		if part.part_name == NIGHTCAP_PART:
			continue
		_add_part_node(visual, part, palette)
	if nightcap != null and visual.is_ancestor_of(nightcap):
		# The cap draws last, over the head it sits on.
		visual.move_child(nightcap, visual.get_child_count() - 1)
	_apply_hand_drawn_material(visual)
	_attach_cast_sprite(visual, nightcap, type)


static func _attach_cast_sprite(visual: Polygon2D, nightcap: Polygon2D, type: EnemyType) -> void:
	var path := "res://assets/art/sprites/%s.png" % type.type_id
	if not ResourceLoader.exists(path):
		return
	var tex := load(path) as Texture2D
	if tex == null:
		return
	visual.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	if nightcap != null:
		nightcap.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	for child: Node in visual.get_children():
		if child is Polygon2D:
			(child as Polygon2D).self_modulate = Color(1.0, 1.0, 1.0, 0.0)
			for sub: Node in child.get_children():
				if sub is Line2D:
					(sub as Line2D).self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	var sprite := Sprite2D.new()
	sprite.name = "CastSprite"
	sprite.texture = tex
	sprite.scale = Vector2(0.34, 0.34)
	sprite.position = Vector2(0.0, -4.0)
	sprite.modulate = Color(0.84, 0.82, 0.95, 1.0)
	visual.add_child(sprite)


static func set_awake(visual: Polygon2D, awake: bool, hit_point: Vector2, instant := false) -> void:
	# The wake beat of ART_DIRECTION section 1: the eyes pop open, the drool
	# arc goes, and the color front runs out from the cup hit. An instant
	# call skips the beat: the front stands complete at once, because the
	# save already played it, T134.
	for part_name: String in ["EyeOpenL", "EyeOpenR", "EyeL", "EyeR", "DroolArc", "DroolShine"]:
		var part := visual.get_node_or_null(NodePath(part_name)) as CanvasItem
		if part == null:
			continue
		part.visible = awake if part_name.begins_with(AWAKE_ONLY_PREFIX) else not awake
	var sprite := visual.get_node_or_null(^"CastSprite") as Sprite2D
	if sprite != null:
		sprite.modulate = Color(1.05, 1.02, 0.96, 1.0) if awake else Color(0.84, 0.82, 0.95, 1.0)
	var fill := visual.get_node_or_null(NodePath(WAKE_FILL_PART)) as ColorFill
	if fill == null:
		return
	if awake:
		if instant:
			fill.fill_now()
		else:
			fill.start(hit_point)
	else:
		fill.reset()


static func _apply_hand_drawn_material(visual: Polygon2D) -> void:
	# One shared look for the whole cast: the hand_drawn shader holds the
	# sketch state, and the ColorFill child drives the wake front into it.
	var material := ShaderMaterial.new()
	material.shader = load(HAND_DRAWN_SHADER_PATH) as Shader
	material.set_shader_parameter("graphite", ACTOR_GRAPHITE)
	material.set_shader_parameter("sleep_tint_amount", ACTOR_SLEEP_TINT)
	visual.material = material
	var fill := ColorFill.new()
	fill.name = WAKE_FILL_PART
	fill.duration = WAKE_FILL_SECONDS
	fill.radius = WAKE_FILL_RADIUS
	visual.add_child(fill)


static func _clear_parts(visual: Polygon2D, nightcap: Polygon2D) -> void:
	# A rebuild frees the parts of the previous build at once, like the
	# BaristaPortrait repaint does. The Nightcap node stays: the walker
	# engine holds a ready-time reference to it.
	for child: Node in visual.get_children():
		if child is Polygon2D or child is Line2D or child is ColorFill or child is Sprite2D:
			if child != nightcap:
				child.free()


static func _add_part_node(visual: Polygon2D, part: Part, palette: ArtPalette) -> void:
	var node := Polygon2D.new()
	node.name = part.part_name
	node.polygon = part.polygon
	node.color = part.color
	node.visible = not part.part_name.begins_with(AWAKE_ONLY_PREFIX)
	visual.add_child(node)
	if part.outlined:
		var outline := Line2D.new()
		outline.name = part.part_name + "Outline"
		outline.points = part.polygon
		outline.closed = true
		outline.width = OUTLINE_WIDTH
		outline.default_color = palette.espresso
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		node.add_child(outline)


# --- Shared body pieces --------------------------------------------------------


static func _add_neighbor_parts(
	parts: Array[Part], pajama_dark: Color, pajama_light: Color, palette: ArtPalette
) -> void:
	# The basic sleepwalker of section 16: pajamas, slow walk, simple hug.
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-6, 20), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(6, 20), 5.0), pajama_dark))
	# The bathrobe opening reads down the front, the robe hook of the type.
	parts.append(
		Part.new(
			"RobeFront",
			_band([Vector2(-3, -16), Vector2(-2, -3), Vector2(-3, 10)], 2.5),
			pajama_light,
			false
		)
	)
	parts.append(Part.new("ArmL", _capsule(Vector2(-11, -11), Vector2(-15, 11), 5.0), pajama_dark))
	parts.append(Part.new("ArmR", _capsule(Vector2(11, -11), Vector2(15, 11), 5.0), pajama_dark))
	parts.append(Part.new("HandL", _circle(Vector2(-15, 13), HAND_RADIUS), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(15, 13), HAND_RADIUS), SKIN))
	# One slipper only, the asymmetric detail of the type.
	parts.append(Part.new("SlipperR", _rect(Vector2(6, 21), Vector2(10, 5)), palette.cream))
	parts.append(Part.new("ToesL", _circle(Vector2(-6, 21), 2.5), SKIN, false))
	# The coffee-less mug in the left hand: an open arc, empty.
	parts.append(
		Part.new("EmptyMug", _arc_band(Vector2(-15, 13), 4.5, 2.0, 0.5, 5.8), palette.cream)
	)
	parts.append(Part.new("Head", _circle(Vector2(0, -25), HEAD_RADIUS), SKIN))


static func _add_tourist_parts(
	parts: Array[Part], pajama_dark: Color, pajama_light: Color, palette: ArtPalette
) -> void:
	# The wide hat and the big camera carry the silhouette, ART_DIRECTION 7.
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-6, 20), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(6, 20), 5.0), pajama_dark))
	parts.append(Part.new("SlipperL", _rect(Vector2(-6, 21), Vector2(10, 5)), palette.cream))
	parts.append(Part.new("SlipperR", _rect(Vector2(6, 21), Vector2(10, 5)), palette.cream))
	# The fanny pack, the tourist uniform.
	parts.append(Part.new("FannyPack", _rect(Vector2(0, 5), Vector2(17, 8)), palette.brick))
	parts.append(Part.new("ArmL", _capsule(Vector2(-11, -11), Vector2(-14, 10), 5.0), pajama_dark))
	# The right arm holds the camera up: he photographs everything, section 6.
	parts.append(
		Part.new(
			"ArmR", _band([Vector2(11, -11), Vector2(17, -16), Vector2(14, -24)], 5.0), pajama_dark
		)
	)
	parts.append(Part.new("HandL", _circle(Vector2(-14, 12), HAND_RADIUS), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(14, -25), HAND_RADIUS), SKIN))
	# The wide hat: a big brim and a crown, the widest top of the cast.
	parts.append(Part.new("HatBrim", _ellipse(Vector2(0, -32), 17.0, 4.5), pajama_light))
	parts.append(Part.new("HatCrown", _ellipse(Vector2(0, -36), 8.5, 5.5), pajama_light))
	parts.append(
		Part.new(
			"HatBand",
			_band([Vector2(-8, -33), Vector2(0, -34), Vector2(8, -33)], 2.0),
			palette.brick,
			false
		)
	)
	parts.append(Part.new("Head", _circle(Vector2(0, -25), HEAD_RADIUS), SKIN))
	# The camera with its lens, held up before the face.
	parts.append(Part.new("Camera", _rect(Vector2(15, -19), Vector2(12, 9)), palette.espresso))
	parts.append(
		Part.new("Lens", _arc_band(Vector2(18, -19), 3.0, 1.8, 0.6, 5.6), palette.rain, false)
	)


static func _add_tech_bro_parts(
	parts: Array[Part], pajama_dark: Color, palette: ArtPalette
) -> void:
	# The gray fleece vest and the raised pitch arm, section 6.
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-6, 20), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(6, 20), 5.0), pajama_dark))
	parts.append(Part.new("SlipperL", _rect(Vector2(-6, 21), Vector2(10, 5)), palette.cream))
	parts.append(Part.new("SlipperR", _rect(Vector2(6, 21), Vector2(10, 5)), palette.cream))
	# The fleece vest over the pajamas, with one teal startup logo.
	parts.append(Part.new("VestL", _rect(Vector2(-8, -5), Vector2(9, 20)), VEST_GRAY))
	parts.append(Part.new("VestR", _rect(Vector2(8, -5), Vector2(9, 20)), VEST_GRAY))
	parts.append(
		Part.new(
			"VestCollar",
			_band([Vector2(-7, -14), Vector2(0, -16), Vector2(7, -14)], 3.5),
			VEST_GRAY,
			false
		)
	)
	parts.append(Part.new("Logo", _circle(Vector2(0, -8), 2.5), palette.teal, false))
	parts.append(Part.new("ArmL", _capsule(Vector2(-11, -11), Vector2(-14, 10), 5.0), pajama_dark))
	# The pitch arm: he sleep-pitches to nobody, so one arm stays up with the phone.
	parts.append(
		Part.new(
			"ArmR", _band([Vector2(11, -11), Vector2(18, -18), Vector2(15, -28)], 5.0), pajama_dark
		)
	)
	parts.append(Part.new("HandL", _circle(Vector2(-14, 12), HAND_RADIUS), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(15, -29), HAND_RADIUS), SKIN))
	parts.append(Part.new("Phone", _rect(Vector2(15, -29), Vector2(6, 10)), palette.espresso))
	parts.append(Part.new("Screen", _rect(Vector2(15, -30), Vector2(4, 6)), Color.WHITE, false))
	parts.append(Part.new("Head", _circle(Vector2(0, -25), HEAD_RADIUS), SKIN))
	# The earbuds, white dots at the ears.
	parts.append(Part.new("EarbudL", _circle(Vector2(-9, -25), 1.8), Color.WHITE, false))
	parts.append(Part.new("EarbudR", _circle(Vector2(9, -25), 1.8), Color.WHITE, false))


static func _add_gamer_parts(
	parts: Array[Part], pajama: Color, pajama_dark: Color, palette: ArtPalette
) -> void:
	# Hunched, headset on, one glowing can in both hands, section 6.
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-6, 20), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(6, 20), 5.0), pajama_dark))
	parts.append(Part.new("SlipperL", _rect(Vector2(-6, 21), Vector2(10, 5)), palette.cream))
	parts.append(Part.new("SlipperR", _rect(Vector2(6, 21), Vector2(10, 5)), palette.cream))
	# The hunch: the shoulders pull up and the head sinks into them.
	(
		parts
		. append(
			(
				Part
				. new(
					"HoodieShoulders",
					PackedVector2Array(
						[
							Vector2(-14, -13),
							Vector2(14, -13),
							Vector2(16, -2),
							Vector2(13, 11),
							Vector2(-13, 11),
							Vector2(-16, -2),
						]
					),
					pajama
				)
			)
		)
	)
	parts.append(
		Part.new(
			"Zipper",
			_band([Vector2(0, -13), Vector2(-1, -2), Vector2(0, 10)], 1.8),
			pajama_dark,
			false
		)
	)
	parts.append(Part.new("ArmL", _capsule(Vector2(-11, -9), Vector2(-6, 12), 5.0), pajama_dark))
	parts.append(Part.new("ArmR", _capsule(Vector2(11, -9), Vector2(6, 12), 5.0), pajama_dark))
	parts.append(Part.new("HandL", _circle(Vector2(-6, 13), HAND_RADIUS), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(6, 13), HAND_RADIUS), SKIN))
	# The glowing can: the highest synthetic caffeine level in the country.
	parts.append(Part.new("EnergyCan", _rect(Vector2(0, 14), Vector2(9, 13)), palette.rain))
	parts.append(
		Part.new(
			"CanBand",
			_band([Vector2(-4, 14), Vector2(0, 15), Vector2(4, 14)], 2.2),
			palette.butter,
			false
		)
	)
	parts.append(Part.new("Head", _circle(Vector2(0, -22), HEAD_RADIUS), SKIN))
	# The headset: a band over the head and one cup on each ear.
	parts.append(
		Part.new(
			"HeadsetBand",
			_band([Vector2(-9, -28), Vector2(0, -33), Vector2(9, -28)], 2.5),
			palette.espresso,
			false
		)
	)
	parts.append(Part.new("CupL", _circle(Vector2(-9, -23), 3.5), palette.espresso))
	parts.append(Part.new("CupR", _circle(Vector2(9, -23), 3.5), palette.espresso))
	parts.append(Part.new("CupGlowL", _circle(Vector2(-9, -23), 1.6), palette.rain, false))
	parts.append(Part.new("CupGlowR", _circle(Vector2(9, -23), 1.6), palette.rain, false))


static func _add_tinfoil_parts(parts: Array[Part], pajama_dark: Color, pajama_light: Color) -> void:
	# The tall foil cone hat stops thrown coffee, section 6, so it is the
	# tallest top of the cast and the only shiny silver.
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-6, 20), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(6, 20), 5.0), pajama_dark))
	parts.append(Part.new("SlipperL", _rect(Vector2(-6, 21), Vector2(10, 5)), pajama_light))
	parts.append(Part.new("SlipperR", _rect(Vector2(6, 21), Vector2(10, 5)), pajama_light))
	parts.append(Part.new("ArmL", _capsule(Vector2(-12, -10), Vector2(-19, 8), 5.0), pajama_dark))
	parts.append(Part.new("ArmR", _capsule(Vector2(12, -10), Vector2(19, 8), 5.0), pajama_dark))
	parts.append(Part.new("HandL", _circle(Vector2(-19, 10), HAND_RADIUS), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(19, 10), HAND_RADIUS), SKIN))
	parts.append(Part.new("Head", _circle(Vector2(0, -27), HEAD_RADIUS), SKIN))
	parts.append(
		Part.new(
			"FoilCone",
			PackedVector2Array(
				[Vector2(-9, -35), Vector2(9, -35), Vector2(3, -58), Vector2(-2, -50)]
			),
			SILVER
		)
	)
	parts.append(
		Part.new(
			"FoilFacet",
			_band([Vector2(-4, -35), Vector2(-2, -49), Vector2(0, -56)], 1.6),
			Color.WHITE,
			false
		)
	)
	parts.append(
		Part.new(
			"FoilCrumple",
			PackedVector2Array(
				[
					Vector2(-9, -35),
					Vector2(-3, -39),
					Vector2(2, -34),
					Vector2(6, -38),
					Vector2(9, -35)
				]
			),
			Color("#AEB3BD"),
			false
		)
	)


static func _add_karen_parts(parts: Array[Part], pajama_dark: Color, palette: ArtPalette) -> void:
	# The large round shape and the sharp asymmetric haircut, section 6.
	parts.append(Part.new("LegL", _capsule(Vector2(-7, 12), Vector2(-7, 19), 6.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(7, 12), Vector2(7, 19), 6.0), pajama_dark))
	parts.append(Part.new("SlipperL", _rect(Vector2(-7, 21), Vector2(11, 5)), palette.cream))
	parts.append(Part.new("SlipperR", _rect(Vector2(7, 21), Vector2(11, 5)), palette.cream))
	parts.append(Part.new("ArmL", _capsule(Vector2(-17, -8), Vector2(-21, 6), 6.0), pajama_dark))
	parts.append(Part.new("ArmR", _capsule(Vector2(17, -8), Vector2(21, 6), 6.0), pajama_dark))
	parts.append(Part.new("HandL", _circle(Vector2(-21, 8), HAND_RADIUS + 1.0), SKIN))
	parts.append(Part.new("HandR", _circle(Vector2(21, 8), HAND_RADIUS + 1.0), SKIN))
	parts.append(Part.new("Head", _circle(Vector2(0, -26), HEAD_RADIUS + 0.5), SKIN))
	# The sharp asymmetric bob: one side sweeps far past the face.
	(
		parts
		. append(
			(
				Part
				. new(
					"BobSweep",
					PackedVector2Array(
						[
							Vector2(-11, -32),
							Vector2(0, -36),
							Vector2(11, -32),
							Vector2(14, -24),
							Vector2(7, -27),
							Vector2(0, -30),
							Vector2(-8, -28),
						]
					),
					HAIR_DARK
				)
			)
		)
	)
	# The buttery sunglasses pushed up on the forehead, section 7.
	parts.append(
		Part.new("ShadesL", _rect(Vector2(-4.5, -30), Vector2(5, 3)), palette.butter, false)
	)
	parts.append(
		Part.new("ShadesR", _rect(Vector2(4.5, -30), Vector2(5, 3)), palette.butter, false)
	)


static func _add_moonwalker_parts(parts: Array[Part], pajama_dark: Color) -> void:
	# One white glove held high, white socks, the lean of the slide, section 24.
	# The white socks pull up over the ankles and cover the feet.
	parts.append(Part.new("SockL", _rect(Vector2(-7, 18), Vector2(10, 7)), Color.WHITE))
	parts.append(Part.new("SockR", _rect(Vector2(7, 18), Vector2(10, 7)), Color.WHITE))
	parts.append(Part.new("LegL", _capsule(Vector2(-6, 10), Vector2(-7, 18), 5.0), pajama_dark))
	parts.append(Part.new("LegR", _capsule(Vector2(6, 10), Vector2(8, 18), 5.0), pajama_dark))
	# The white shirt triangle under the deep red jacket.
	parts.append(
		Part.new(
			"Shirt",
			PackedVector2Array([Vector2(-4, -16), Vector2(4, -16), Vector2(0, -7)]),
			Color("#F6EFE0"),
			false
		)
	)
	parts.append(
		Part.new(
			"ArmR", _band([Vector2(11, -11), Vector2(16, -2), Vector2(15, 10)], 5.0), pajama_dark
		)
	)
	# The gloved arm stays raised: the read of the type even at a standstill.
	parts.append(
		Part.new(
			"ArmL",
			_band([Vector2(-11, -11), Vector2(-18, -22), Vector2(-14, -33)], 5.0),
			pajama_dark
		)
	)
	parts.append(Part.new("HandR", _circle(Vector2(15, 12), HAND_RADIUS), SKIN))
	parts.append(Part.new("Glove", _circle(Vector2(-14, -34), HAND_RADIUS + 0.5), Color.WHITE))
	parts.append(Part.new("Sparkle", _circle(Vector2(-17, -37), 1.6), Color("#FFF6D8"), false))
	parts.append(Part.new("Head", _circle(Vector2(0, -25), HEAD_RADIUS), SKIN))
	# The sequin band of the jacket, one small shine.
	parts.append(
		Part.new(
			"SequinBand",
			_band([Vector2(-12, -6), Vector2(0, -4), Vector2(12, -6)], 2.0),
			Color("#E8B84B"),
			false
		)
	)


static func _add_face_parts(parts: Array[Part], palette: ArtPalette, head_center: Vector2) -> void:
	# Eyes closed and a happy little smile: they dream of the warm hug.
	var eye_y := head_center.y + 1.0
	parts.append(
		Part.new(
			"EyeL",
			_band([Vector2(-6, eye_y), Vector2(-4.5, eye_y + 1.2), Vector2(-3, eye_y)], 1.6),
			palette.espresso,
			false
		)
	)
	parts.append(
		Part.new(
			"EyeR",
			_band([Vector2(3, eye_y), Vector2(4.5, eye_y + 1.2), Vector2(6, eye_y)], 1.6),
			palette.espresso,
			false
		)
	)
	# The open eyes of the awake state. They stay hidden while the sleeper
	# sleeps, and they never enter the sleeping silhouette data.
	parts.append(
		Part.new("EyeOpenL", _circle(Vector2(-4.5, eye_y + 0.5), 1.7), palette.espresso, false)
	)
	parts.append(
		Part.new("EyeOpenR", _circle(Vector2(4.5, eye_y + 0.5), 1.7), palette.espresso, false)
	)
	(
		parts
		. append(
			(
				Part
				. new(
					"Smile",
					_band(
						[
							Vector2(head_center.x - 3.5, head_center.y + 5.0),
							Vector2(head_center.x, head_center.y + 6.8),
							Vector2(head_center.x + 3.5, head_center.y + 5.0),
						],
						1.6
					),
					palette.espresso,
					false
				)
			)
		)
	)


static func _add_drool_parts(parts: Array[Part], head_center: Vector2) -> void:
	# One white chalk shine arc from the mouth corner, comic and never gross.
	(
		parts
		. append(
			(
				Part
				. new(
					"DroolArc",
					_band(
						[
							Vector2(head_center.x + 4.0, head_center.y + 5.0),
							Vector2(head_center.x + 7.0, head_center.y + 9.0),
							Vector2(head_center.x + 6.0, head_center.y + 15.0),
						],
						2.2
					),
					DROOL_COLOR,
					false
				)
			)
		)
	)
	parts.append(
		Part.new(
			"DroolShine",
			_circle(Vector2(head_center.x + 5.0, head_center.y + 7.0), 1.6),
			DROOL_COLOR,
			false
		)
	)


static func _add_nightcap_part(
	parts: Array[Part], type: EnemyType, pajama_light: Color, head_center: Vector2
) -> void:
	# Types with a hat of their own drop the cap: the hat carries the top.
	if not _wears_nightcap(type):
		return
	parts.append(Part.new(NIGHTCAP_PART, _nightcap_polygon(head_center), pajama_light))


static func _nightcap_polygon(head_center: Vector2) -> PackedVector2Array:
	# A floppy cone that tips to one side, with the tip hanging down.
	var top := head_center + Vector2(0, -HEAD_RADIUS - 1.0)
	return PackedVector2Array(
		[
			top + Vector2(-8, 1),
			top + Vector2(-2, -4),
			top + Vector2(9, -2),
			top + Vector2(16, 6),
			top + Vector2(10, 9),
			top + Vector2(0, 6),
		]
	)


static func _wears_nightcap(type: EnemyType) -> bool:
	match type.special_behavior:
		EnemyType.SpecialBehavior.PHOTO_FLASH:
			return false
		EnemyType.SpecialBehavior.TINFOIL_HAT:
			return false
		EnemyType.SpecialBehavior.KAREN_SURPRISE:
			return false
		_:
			return true


static func _head_center(type: EnemyType) -> Vector2:
	match type.special_behavior:
		EnemyType.SpecialBehavior.DASH_CHARGE:
			return Vector2(0, -22)
		EnemyType.SpecialBehavior.TINFOIL_HAT:
			return Vector2(0, -27)
		EnemyType.SpecialBehavior.KAREN_SURPRISE:
			return Vector2(0, -26)
		_:
			return Vector2(0, -25)


static func _torso_polygon(type: EnemyType) -> PackedVector2Array:
	# The pajama body on the Visual node itself. The Karen reads widest: the
	# silhouette test and the enemy data suite both read this width.
	if type.special_behavior == EnemyType.SpecialBehavior.KAREN_SURPRISE:
		return PackedVector2Array(
			[
				Vector2(-22, -16),
				Vector2(0, -19),
				Vector2(22, -16),
				Vector2(21, 2),
				Vector2(12, 12),
				Vector2(-12, 12),
				Vector2(-21, 2),
			]
		)
	if type.special_behavior == EnemyType.SpecialBehavior.DASH_CHARGE:
		return PackedVector2Array(
			[
				Vector2(-14, -13),
				Vector2(14, -13),
				Vector2(16, -1),
				Vector2(13, 11),
				Vector2(-13, 11),
				Vector2(-16, -1),
			]
		)
	return PackedVector2Array(
		[
			Vector2(-13, -16),
			Vector2(13, -16),
			Vector2(15, -2),
			Vector2(13, 11),
			Vector2(-13, 11),
			Vector2(-15, -2),
		]
	)


# --- Shape helpers -------------------------------------------------------------


static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	return _ellipse(center, radius, radius)


static func _ellipse(center: Vector2, radius_x: float, radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 16
	for step: int in steps:
		var angle := TAU * float(step) / float(steps)
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	return points


static func _rect(center: Vector2, size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array(
		[
			center + Vector2(-half.x, -half.y),
			center + Vector2(half.x, -half.y),
			center + half,
			center + Vector2(-half.x, half.y),
		]
	)


static func _arc_band(
	center: Vector2, radius: float, width: float, from_angle: float, to_angle: float
) -> PackedVector2Array:
	# A strip along an arc, like an open mug rim or a lens ring.
	var path: Array = []
	var steps := 6
	for step: int in steps:
		var angle := lerpf(from_angle, to_angle, float(step) / float(steps - 1))
		path.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return _band(path, width)


static func _capsule(from: Vector2, to: Vector2, width: float) -> PackedVector2Array:
	# A limb with round caps, wide enough to read at a distance.
	var direction := from.direction_to(to)
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	var normal := Vector2(-direction.y, direction.x) * width * 0.5
	var cap := direction * width * 0.5
	return PackedVector2Array(
		[
			from + normal - cap,
			to + normal + cap,
			to - normal + cap,
			from - normal - cap,
		]
	)


static func _band(points: Array, width: float) -> PackedVector2Array:
	# A strip along a curve: the hand-made look of a chalk or pencil stroke.
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i: int in points.size():
		var direction := Vector2.ZERO
		if i == 0:
			direction = (points[1] - points[0]).normalized()
		elif i == points.size() - 1:
			direction = (points[i] - points[i - 1]).normalized()
		else:
			var ahead: Vector2 = (points[i + 1] - points[i]).normalized()
			var behind: Vector2 = (points[i] - points[i - 1]).normalized()
			direction = (ahead + behind).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2.RIGHT
		var normal := Vector2(-direction.y, direction.x) * width * 0.5
		left.append(points[i] + normal)
		right.append(points[i] - normal)
	var polygon := PackedVector2Array()
	for point: Vector2 in left:
		polygon.append(point)
	for i: int in range(right.size() - 1, -1, -1):
		polygon.append(right[i])
	return polygon
