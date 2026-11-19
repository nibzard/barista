# ABOUTME: CharacterAppearance is the cosmetic state of the barista, section 5.
# ABOUTME: Pure data: every option is cosmetic, nothing changes gameplay.
class_name CharacterAppearance
extends RefCounted

const BODY_MALE := "male"
const BODY_FEMALE := "female"
const HAIR_BALD := "bald"
const BEARD_CLEAN := "clean"
const BEARD_STUBBLE := "stubble"
const BEARD_HIPSTER := "hipster"
const BEARD_LUMBERJACK := "lumberjack"
const BEARD_WIZARD := "wizard"
const HAT_NONE := "none"
const GOGGLES_NONE := "none"
const TATTOO_LEFT_ARM := "left_arm"
const TATTOO_RIGHT_ARM := "right_arm"
const TATTOO_NECK := "neck"
const TATTOO_LEFT_HAND := "left_hand"
const TATTOO_RIGHT_HAND := "right_hand"

# Every choice rides as a catalog option id, so the save stays plain values.
var body_type := ""
var skin_tone := ""
var hair_style := ""
var beard_length := ""
# Tattoos are number and placement in one list: one entry per inked placement.
var tattoo_placements: Array[String] = []
var hat := ""
var goggles := ""
var apron := ""
var boots := ""


static func make_default(catalog: AppearanceCatalog) -> CharacterAppearance:
	# The catalog owns the order, so its first option is the default look.
	return from_dict({}, catalog)


static func from_dict(saved: Dictionary, catalog: AppearanceCatalog) -> CharacterAppearance:
	# A foreign or missing id reads as the catalog default, so a slot from
	# another build never paints an unknown look.
	var appearance := CharacterAppearance.new()
	appearance.body_type = _id_or_first(saved, "body_type", catalog.body_types)
	appearance.skin_tone = _id_or_first(saved, "skin_tone", catalog.skin_tones)
	appearance.hair_style = _id_or_first(saved, "hair_style", catalog.hair_styles)
	appearance.beard_length = _id_or_first(saved, "beard_length", catalog.beard_lengths)
	appearance.hat = _id_or_first(saved, "hat", catalog.hats)
	appearance.goggles = _id_or_first(saved, "goggles", catalog.goggles)
	appearance.apron = _id_or_first(saved, "apron", catalog.aprons)
	appearance.boots = _id_or_first(saved, "boots", catalog.boots)
	appearance.tattoo_placements = _placements(saved, catalog)
	return appearance


func to_dict() -> Dictionary:
	# The document hands out a copy, so a caller cannot change the look by
	# holding the dict.
	return {
		"body_type": body_type,
		"skin_tone": skin_tone,
		"hair_style": hair_style,
		"beard_length": beard_length,
		"tattoos": tattoo_placements.duplicate(),
		"hat": hat,
		"goggles": goggles,
		"apron": apron,
		"boots": boots,
	}


func matches(other: CharacterAppearance) -> bool:
	return (
		other != null
		and body_type == other.body_type
		and skin_tone == other.skin_tone
		and hair_style == other.hair_style
		and beard_length == other.beard_length
		and hat == other.hat
		and goggles == other.goggles
		and apron == other.apron
		and boots == other.boots
		and _same_tattoos(other)
	)


func tattoo_count() -> int:
	return tattoo_placements.size()


func _same_tattoos(other: CharacterAppearance) -> bool:
	if tattoo_placements.size() != other.tattoo_placements.size():
		return false
	for placement: String in tattoo_placements:
		if not other.tattoo_placements.has(placement):
			return false
	return true


static func _id_or_first(
	saved: Dictionary, key: String, options: Array[AppearanceOption]
) -> String:
	var option_id := SaveData.string_or_default(saved.get(key, ""), "")
	if AppearanceCatalog.find_option(options, option_id) != null:
		return option_id
	return AppearanceCatalog.first_id(options)


static func _placements(saved: Dictionary, catalog: AppearanceCatalog) -> Array[String]:
	# Duplicates, foreign values, and placements the catalog does not list
	# drop out. The catalog size caps the list: one tattoo per placement.
	var placements: Array[String] = []
	var raw_placements: Array = SaveData.array_or_empty(saved.get("tattoos", []))
	for entry: Variant in raw_placements:
		var placement := SaveData.string_or_default(entry, "")
		if placement.is_empty() or placements.has(placement):
			continue
		if AppearanceCatalog.find_option(catalog.tattoo_placements, placement) == null:
			continue
		placements.append(placement)
		if placements.size() >= catalog.tattoo_placements.size():
			break
	return placements
