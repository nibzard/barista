# ABOUTME: AppearanceCatalog lists every cosmetic option of section 5.
# ABOUTME: The creation screen cycles it; the save resolves ids through it.
class_name AppearanceCatalog
extends Resource

@export var body_types: Array[AppearanceOption] = []
@export var skin_tones: Array[AppearanceOption] = []
@export var hair_styles: Array[AppearanceOption] = []
@export var beard_lengths: Array[AppearanceOption] = []
@export var tattoo_placements: Array[AppearanceOption] = []
@export var hats: Array[AppearanceOption] = []
@export var goggles: Array[AppearanceOption] = []
@export var aprons: Array[AppearanceOption] = []
@export var boots: Array[AppearanceOption] = []


static func find_option(options: Array[AppearanceOption], option_id: String) -> AppearanceOption:
	for option: AppearanceOption in options:
		if option.option_id == option_id:
			return option
	return null


static func first_id(options: Array[AppearanceOption]) -> String:
	if options.is_empty():
		return ""
	return options[0].option_id


static func ids(options: Array[AppearanceOption]) -> Array[String]:
	var option_ids: Array[String] = []
	for option: AppearanceOption in options:
		option_ids.append(option.option_id)
	return option_ids


static func display_name(options: Array[AppearanceOption], option_id: String) -> String:
	var option := find_option(options, option_id)
	if option == null:
		return ""
	return option.display_name


static func color_of(options: Array[AppearanceOption], option_id: String) -> Color:
	var option := find_option(options, option_id)
	if option == null:
		return Color.WHITE
	return option.color
