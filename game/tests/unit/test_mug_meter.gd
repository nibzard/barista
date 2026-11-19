# ABOUTME: Unit tests of the mug awake meter, ART_DIRECTION section 11.
# ABOUTME: The coffee level is the meter value; low coffee cools and stops the steam.
extends GdUnitTestSuite

const WORLD_PALETTE := preload("res://resources/art/world_palette.tres")

const LOW_LINE := 0.25


func _meter() -> MugMeter:
	var meter: MugMeter = auto_free(MugMeter.new())
	meter.low_fraction = LOW_LINE
	meter.min_value = 0.0
	meter.max_value = 100.0
	return meter


func test_the_coffee_level_is_the_meter_value() -> void:
	var meter := _meter()
	meter.value = 100.0
	assert_float(meter.fill_fraction()).is_equal_approx(1.0, 0.001)
	meter.value = 70.0
	assert_float(meter.fill_fraction()).is_equal_approx(0.7, 0.001)
	meter.value = 0.0
	assert_float(meter.fill_fraction()).is_equal_approx(0.0, 0.001)


func test_the_meter_keeps_the_progress_bar_value_contract() -> void:
	# The mug reads the same value property the tests and the HUD always
	# read on the old bar, and it clamps like a bar.
	var meter := _meter()
	meter.value = 70.0
	assert_float(meter.value).is_equal_approx(70.0, 0.001)
	meter.value = 150.0
	assert_float(meter.value).is_equal_approx(100.0, 0.001)
	meter.max_value = 50.0
	assert_float(meter.value).is_equal_approx(50.0, 0.001)


func test_the_steam_stops_at_the_low_line() -> void:
	var meter := _meter()
	meter.value = 30.0
	assert_bool(meter.is_steam_on()).is_true()
	assert_bool(meter.is_low()).is_false()
	# At the line the mug already reads low, and below it the steam is off.
	meter.value = 25.0
	assert_bool(meter.is_steam_on()).is_false()
	assert_bool(meter.is_low()).is_true()
	meter.value = 10.0
	assert_bool(meter.is_steam_on()).is_false()
	meter.value = 0.0
	assert_bool(meter.is_steam_on()).is_false()


func test_the_coffee_cools_toward_rain_blue_as_the_level_falls() -> void:
	var meter := _meter()
	meter.value = 100.0
	assert_bool(meter.coffee_color().is_equal_approx(WORLD_PALETTE.butter)).is_true()
	# Below the low line the color runs from butter at the line to rainy
	# blue at an empty mug. A Range snaps its value to whole steps, so the
	# expected weight comes from the fraction the meter really holds.
	meter.value = 15.0
	var cool_weight := 1.0 - meter.fill_fraction() / LOW_LINE
	var expected := WORLD_PALETTE.butter.lerp(WORLD_PALETTE.rain, cool_weight)
	assert_bool(meter.coffee_color().is_equal_approx(expected)).is_true()
	meter.value = 0.0
	assert_bool(meter.coffee_color().is_equal_approx(WORLD_PALETTE.rain)).is_true()


func test_the_cooling_grows_as_the_level_sinks() -> void:
	var meter := _meter()
	meter.value = 20.0
	var high := meter.coffee_color()
	meter.value = 5.0
	var low := meter.coffee_color()
	assert_float(_travel(low)).is_greater(_travel(high))


func _travel(color: Color) -> float:
	# The distance a cooled color moved away from the hot butter glow.
	var shift := (
		Vector3(color.r, color.g, color.b)
		- Vector3(WORLD_PALETTE.butter.r, WORLD_PALETTE.butter.g, WORLD_PALETTE.butter.b)
	)
	return shift.length()


func test_the_coffee_grows_from_the_bottom_of_the_mug() -> void:
	var meter := _meter()
	meter.size = Vector2(46.0, 46.0)
	meter.value = 100.0
	var full := meter.coffee_rect()
	meter.value = 50.0
	var half := meter.coffee_rect()
	assert_float(half.size.y).is_equal_approx(full.size.y * 0.5, 0.1)
	# The surface sinks, the coffee never leaves the bottom of the mug.
	assert_float(half.end.y).is_equal_approx(full.end.y, 0.1)
	assert_float(half.position.y).is_equal_approx(full.position.y + full.size.y * 0.5, 0.1)
	assert_float(half.size.x).is_equal_approx(full.size.x, 0.1)
	meter.value = 0.0
	assert_float(meter.coffee_rect().size.y).is_equal_approx(0.0, 0.001)
