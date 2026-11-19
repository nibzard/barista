# ABOUTME: BaristaPortrait draws the placeholder look of the created barista.
# ABOUTME: One builder serves the city player and the creation preview alike.
class_name BaristaPortrait
extends RefCounted

const TATTOO_INK := Color(0.12, 0.22, 0.28, 1.0)


# The body shapes of section 5. The male silhouette keeps the classic block
# of the placeholder era; the female silhouette narrows the shoulders and
# widens the hips. Everything else paints on top of this skin polygon.
static func body_male_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[Vector2(-16, -24), Vector2(16, -24), Vector2(16, 20), Vector2(-16, 20)]
	)


static func body_female_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[Vector2(-13, -24), Vector2(13, -24), Vector2(15, 20), Vector2(-15, 20)]
	)


# The footprint every part anchors to: the male block spans x -16..16 and
# y -24..20. The hair covers the crown, the beard the chin, and the clothing
# the torso and the feet, section 5 and section 20.


static func build(
	body: Polygon2D, appearance: CharacterAppearance, catalog: AppearanceCatalog
) -> void:
	# The build is a full repaint: the body becomes the skin tone and the
	# shape of the body type, then one polygon per chosen part lands on top
	# in draw order. An empty polygon draws no part, so "bald", "clean", and
	# "none" options stay absent from the tree.
	if body == null or appearance == null or catalog == null:
		return
	_clear_parts(body)
	body.polygon = (
		body_female_polygon()
		if appearance.body_type == CharacterAppearance.BODY_FEMALE
		else body_male_polygon()
	)
	body.color = AppearanceCatalog.color_of(catalog.skin_tones, appearance.skin_tone)
	_add_part(
		body,
		"Hair",
		hair_polygon(appearance.hair_style),
		AppearanceCatalog.color_of(catalog.hair_styles, appearance.hair_style)
	)
	_add_part(
		body,
		"Beard",
		beard_polygon(appearance.beard_length),
		AppearanceCatalog.color_of(catalog.beard_lengths, appearance.beard_length)
	)
	_add_part(
		body,
		"Hat",
		hat_polygon(appearance.hat),
		AppearanceCatalog.color_of(catalog.hats, appearance.hat)
	)
	_add_part(
		body,
		"Goggles",
		goggles_polygon(appearance.goggles),
		AppearanceCatalog.color_of(catalog.goggles, appearance.goggles)
	)
	_add_part(
		body,
		"Apron",
		apron_polygon(appearance.apron),
		AppearanceCatalog.color_of(catalog.aprons, appearance.apron)
	)
	_add_part(
		body,
		"Boots",
		boots_polygon(appearance.boots),
		AppearanceCatalog.color_of(catalog.boots, appearance.boots)
	)
	for placement: String in appearance.tattoo_placements:
		_add_part(body, "Tattoo" + _part_suffix(placement), tattoo_polygon(placement), TATTOO_INK)


static func hair_polygon(hair_style: String) -> PackedVector2Array:
	match hair_style:
		"short":
			return PackedVector2Array(
				[Vector2(-16, -24), Vector2(16, -24), Vector2(16, -15), Vector2(-16, -15)]
			)
		"long":
			return PackedVector2Array(
				[Vector2(-16, -24), Vector2(16, -24), Vector2(19, 0), Vector2(-19, 0)]
			)
		"mohawk":
			return PackedVector2Array(
				[Vector2(-5, -24), Vector2(-2, -36), Vector2(2, -36), Vector2(5, -24)]
			)
		"bun":
			return PackedVector2Array(
				[
					Vector2(-16, -15),
					Vector2(-16, -24),
					Vector2(-4, -24),
					Vector2(-4, -32),
					Vector2(4, -32),
					Vector2(4, -24),
					Vector2(16, -24),
					Vector2(16, -15)
				]
			)
	return PackedVector2Array()


static func beard_polygon(beard_length: String) -> PackedVector2Array:
	match beard_length:
		"stubble":
			return PackedVector2Array(
				[Vector2(-13, 10), Vector2(13, 10), Vector2(13, 18), Vector2(-13, 18)]
			)
		"hipster":
			return PackedVector2Array(
				[Vector2(-13, 4), Vector2(13, 4), Vector2(13, 20), Vector2(-13, 20)]
			)
		"lumberjack":
			return PackedVector2Array(
				[Vector2(-14, -2), Vector2(14, -2), Vector2(14, 22), Vector2(-14, 22)]
			)
		"wizard":
			return PackedVector2Array(
				[Vector2(-14, 6), Vector2(14, 6), Vector2(10, 44), Vector2(-10, 44)]
			)
	return PackedVector2Array()


static func hat_polygon(hat: String) -> PackedVector2Array:
	match hat:
		"top_hat":
			return PackedVector2Array(
				[
					Vector2(-20, -26),
					Vector2(-8, -26),
					Vector2(-8, -40),
					Vector2(8, -40),
					Vector2(8, -26),
					Vector2(20, -26),
					Vector2(20, -30),
					Vector2(-20, -30)
				]
			)
		"bowler":
			return PackedVector2Array(
				[
					Vector2(-18, -26),
					Vector2(-18, -32),
					Vector2(-6, -38),
					Vector2(6, -38),
					Vector2(18, -32),
					Vector2(18, -26)
				]
			)
		"aviator_cap":
			return PackedVector2Array(
				[
					Vector2(-17, -22),
					Vector2(-17, -34),
					Vector2(-7, -38),
					Vector2(7, -38),
					Vector2(17, -34),
					Vector2(17, -22)
				]
			)
	return PackedVector2Array()


static func goggles_polygon(goggles: String) -> PackedVector2Array:
	match goggles:
		"brass":
			return PackedVector2Array(
				[Vector2(-16, -13), Vector2(16, -13), Vector2(16, -6), Vector2(-16, -6)]
			)
		"welding":
			return PackedVector2Array(
				[Vector2(-16, -16), Vector2(16, -16), Vector2(16, -4), Vector2(-16, -4)]
			)
	return PackedVector2Array()


static func apron_polygon(apron: String) -> PackedVector2Array:
	match apron:
		"leather":
			return PackedVector2Array(
				[Vector2(-11, -8), Vector2(11, -8), Vector2(13, 18), Vector2(-13, 18)]
			)
		"canvas":
			return PackedVector2Array(
				[Vector2(-10, -6), Vector2(10, -6), Vector2(12, 18), Vector2(-12, 18)]
			)
	return PackedVector2Array()


static func boots_polygon(boots: String) -> PackedVector2Array:
	match boots:
		"steel":
			return PackedVector2Array(
				[Vector2(-14, 16), Vector2(14, 16), Vector2(14, 26), Vector2(-14, 26)]
			)
		"leather":
			return PackedVector2Array(
				[Vector2(-14, 18), Vector2(14, 18), Vector2(14, 26), Vector2(-14, 26)]
			)
	return PackedVector2Array()


static func tattoo_polygon(placement: String) -> PackedVector2Array:
	match placement:
		CharacterAppearance.TATTOO_LEFT_ARM:
			return PackedVector2Array(
				[Vector2(-16, 0), Vector2(-12, 0), Vector2(-12, 4), Vector2(-16, 4)]
			)
		CharacterAppearance.TATTOO_RIGHT_ARM:
			return PackedVector2Array(
				[Vector2(12, 0), Vector2(16, 0), Vector2(16, 4), Vector2(12, 4)]
			)
		CharacterAppearance.TATTOO_NECK:
			return PackedVector2Array(
				[Vector2(-3, -8), Vector2(3, -8), Vector2(3, -4), Vector2(-3, -4)]
			)
		CharacterAppearance.TATTOO_LEFT_HAND:
			return PackedVector2Array(
				[Vector2(-16, 12), Vector2(-12, 12), Vector2(-12, 16), Vector2(-16, 16)]
			)
		CharacterAppearance.TATTOO_RIGHT_HAND:
			return PackedVector2Array(
				[Vector2(12, 12), Vector2(16, 12), Vector2(16, 16), Vector2(12, 16)]
			)
	return PackedVector2Array()


static func _add_part(
	body: Node2D, part_name: String, polygon: PackedVector2Array, color: Color
) -> void:
	if polygon.is_empty():
		return
	var part := Polygon2D.new()
	part.name = part_name
	part.polygon = polygon
	part.color = color
	body.add_child(part)


static func _clear_parts(body: Node2D) -> void:
	# The repaint frees the parts of the previous build at once, so a caller
	# that reads a part by name after the build always sees the new one.
	for child: Node in body.get_children():
		if child is Polygon2D:
			child.free()


static func _part_suffix(placement: String) -> String:
	return placement.replace("_", " ").capitalize().replace(" ", "")
