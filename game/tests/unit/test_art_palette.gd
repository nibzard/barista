# ABOUTME: Unit tests for the art palette and the city looks of ART_DIRECTION.md.
# ABOUTME: They stop the shipped colors from drifting away from the documented palette.
extends GdUnitTestSuite

const WORLD_PALETTE := preload("res://resources/art/world_palette.tres")
const SAN_COFFESCO := preload("res://resources/art/city_looks/san_coffesco.tres")
const STEAMTLE := preload("res://resources/art/city_looks/steamtle.tres")
const POURTLAND := preload("res://resources/art/city_looks/pourtland.tres")


func test_world_palette_matches_the_documented_hex_values() -> void:
	var palette := WORLD_PALETTE as ArtPalette
	assert_str(palette.cream.to_html(false)).is_equal("f3e6c8")
	assert_str(palette.espresso.to_html(false)).is_equal("3b2418")
	assert_str(palette.brick.to_html(false)).is_equal("a8432f")
	assert_str(palette.butter.to_html(false)).is_equal("f2c866")
	assert_str(palette.teal.to_html(false)).is_equal("5e9a94")
	assert_str(palette.moss.to_html(false)).is_equal("6f7f45")
	assert_str(palette.rain.to_html(false)).is_equal("6c87a6")
	assert_str(palette.lavender.to_html(false)).is_equal("a99bc4")
	assert_str(palette.mug_red.to_html(false)).is_equal("d6202a")
	assert_str(palette.mug_black.to_html(false)).is_equal("151112")


func test_each_city_accent_is_its_world_palette_color() -> void:
	var palette := WORLD_PALETTE as ArtPalette
	assert_str((SAN_COFFESCO as CityLook).accent.to_html(false)).is_equal(
		palette.teal.to_html(false)
	)
	assert_str((STEAMTLE as CityLook).accent.to_html(false)).is_equal(palette.rain.to_html(false))
	assert_str((POURTLAND as CityLook).accent.to_html(false)).is_equal(palette.moss.to_html(false))


func test_each_city_has_its_own_weather() -> void:
	assert_int((SAN_COFFESCO as CityLook).weather).is_equal(CityLook.Weather.CLEAR_FOG)
	assert_int((STEAMTLE as CityLook).weather).is_equal(CityLook.Weather.DRIZZLE)
	assert_int((POURTLAND as CityLook).weather).is_equal(CityLook.Weather.FALLING_LEAVES)


func test_dusk_is_never_dark() -> void:
	for look: CityLook in [SAN_COFFESCO, STEAMTLE, POURTLAND]:
		assert_float(look.dusk_light.get_luminance()).is_greater(0.6)
