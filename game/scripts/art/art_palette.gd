# ABOUTME: ArtPalette holds the eight world colors and the two corporate colors of ART_DIRECTION.md.
# ABOUTME: Art code reads colors from this resource, never from hardcoded numbers.
class_name ArtPalette
extends Resource

# Loaded at use time, never const-preloaded: several scripts share this one
# resource, and a compile-time const can bind an empty resource while another
# load of it still runs (T102).
const WORLD_PALETTE_PATH := "res://resources/art/world_palette.tres"

@export var cream := Color("#F3E6C8")
@export var espresso := Color("#3B2418")
@export var brick := Color("#A8432F")
@export var butter := Color("#F2C866")
@export var teal := Color("#5E9A94")
@export var moss := Color("#6F7F45")
@export var rain := Color("#6C87A6")
@export var lavender := Color("#A99BC4")
# Mug Roasters Co. only. These two colors never go on world art or the interface.
@export var mug_red := Color("#D6202A")
@export var mug_black := Color("#151112")


static func world() -> ArtPalette:
	return load(WORLD_PALETTE_PATH) as ArtPalette
