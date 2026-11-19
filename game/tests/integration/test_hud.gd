# ABOUTME: Integration tests for the HUD bindings: components change, the chalkboard follows.
# ABOUTME: Every status from GAME_DESIGN section 9 must read live from the logic components.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const HOUSE_BEANS_ITEM := preload("res://resources/items/beans/house.tres")
const THERMOS_BELT_ITEM := preload("res://resources/items/gear/thermos_belt.tres")
const WORLD_PALETTE := preload("res://resources/art/world_palette.tres")

var _cafe: Cafe
var _hud: Hud


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	_hud = _cafe.get_node("Hud") as Hud
	await get_tree().physics_frame


func test_hud_binds_to_the_cafe_player_and_shows_the_starting_status() -> void:
	assert_object(_hud.player).is_equal(_cafe.player)
	assert_float(_hud.awake_meter.value).is_equal_approx(100.0, 0.01)
	assert_str(_hud.awake_value.text).is_equal("100/100")
	assert_int(_hud.cup_row.filled_count()).is_equal(12)
	assert_int(_hud.cup_row.empty_count()).is_equal(0)
	assert_int(_hud.wake_clocks.standing_count()).is_equal(5)
	assert_int(_hud.wake_clocks.fallen_count()).is_equal(0)
	assert_str(_hud.bag_label.text).is_equal("empty bag")


func test_sleepy_meter_reading_follows_the_meter() -> void:
	_cafe.player.sleep_meter.drain(30.0)
	_hud.refresh()
	assert_float(_hud.awake_meter.value).is_equal_approx(70.0, 0.01)
	assert_str(_hud.awake_value.text).is_equal("70/100")
	_cafe.player.sleep_meter.gain(10.0)
	_hud.refresh()
	assert_str(_hud.awake_value.text).is_equal("80/100")


func test_the_awake_meter_reads_as_a_mug_that_cools_and_stops_steaming() -> void:
	# ART_DIRECTION section 11: the awake meter is a mug. The coffee level
	# is the meter; low coffee cools the mug and the steam stops.
	var mug := _hud.awake_meter
	assert_float(mug.fill_fraction()).is_equal_approx(1.0, 0.01)
	assert_bool(mug.is_steam_on()).is_true()
	_cafe.player.sleep_meter.drain(85.0)
	_hud.refresh()
	assert_bool(mug.is_low()).is_true()
	assert_bool(mug.is_steam_on()).is_false()
	# The coffee sits at about 15 of 100, so it cooled about 60 percent of
	# the way from butter to rainy blue. The exact weight comes from the
	# live fraction, because the meter drains a little before this drain.
	var cool_weight := 1.0 - mug.fill_fraction() / mug.low_fraction
	var expected := WORLD_PALETTE.butter.lerp(WORLD_PALETTE.rain, cool_weight)
	assert_bool(mug.coffee_color().is_equal_approx(expected)).is_true()
	# A drunk cup heats the mug up again and the steam comes back.
	_cafe.player.sleep_meter.gain(60.0)
	_hud.refresh()
	assert_bool(mug.is_steam_on()).is_true()
	assert_bool(mug.coffee_color().is_equal_approx(WORLD_PALETTE.butter)).is_true()


func test_coffee_supply_reading_follows_the_supply() -> void:
	_cafe.player.coffee_supply.spend_cups(4)
	_hud.refresh()
	assert_int(_hud.cup_row.filled_count()).is_equal(8)
	assert_int(_hud.cup_row.empty_count()).is_equal(4)


func test_carry_limit_change_updates_the_coffee_reading() -> void:
	# The thermos belt raises the carry limit from 12 to 15.
	_cafe.player.pickup_item(THERMOS_BELT_ITEM, 1)
	_cafe.player.coffee_supply.spend_cups(12)
	_hud.refresh()
	assert_int(_hud.cup_row.filled_count()).is_equal(0)
	assert_int(_hud.cup_row.empty_count()).is_equal(15)
	assert_int(_hud.cup_row.icon_count()).is_equal(15)


func test_wake_ups_reading_follows_the_wake_ups() -> void:
	_cafe.player.wake_ups.register_sleep()
	_hud.refresh()
	assert_int(_hud.wake_clocks.standing_count()).is_equal(4)
	assert_int(_hud.wake_clocks.fallen_count()).is_equal(1)
	assert_bool(_hud.wake_clocks.is_fallen(4)).is_true()
	_cafe.player.wake_ups.restore_one()
	_hud.refresh()
	assert_int(_hud.wake_clocks.standing_count()).is_equal(5)
	assert_int(_hud.wake_clocks.fallen_count()).is_equal(0)


func test_bag_rows_list_held_items_grouped_by_category() -> void:
	_cafe.player.pickup_item(FUSE_ITEM, 2)
	_cafe.player.pickup_item(HOUSE_BEANS_ITEM, 3)
	_cafe.player.pickup_item(THERMOS_BELT_ITEM, 1)
	_hud.refresh()
	var expected: String = (
		"\n"
		. join(
			[
				"Beans",
				"  House Beans x3",
				"Gear",
				"  Thermos Belt x1",
				"Materials",
				"  Fuse x2",
			]
		)
	)
	assert_str(_hud.bag_label.text).is_equal(expected)


func test_bag_row_disappears_when_the_last_item_is_spent() -> void:
	_cafe.player.pickup_item(FUSE_ITEM, 1)
	_cafe.player.inventory.remove("fuse", 1)
	_hud.refresh()
	assert_str(_hud.bag_label.text).is_equal("empty bag")


func test_hud_refreshes_itself_every_frame() -> void:
	# No manual refresh: the HUD polls the components each frame on its own.
	_cafe.player.sleep_meter.drain(25.0)
	_cafe.player.coffee_supply.spend_cups(1)
	_cafe.player.wake_ups.register_sleep()
	for frame: int in range(5):
		await get_tree().process_frame
	assert_float(_hud.awake_meter.value).is_equal_approx(75.0, 0.01)
	assert_int(_hud.cup_row.filled_count()).is_equal(11)
	assert_int(_hud.wake_clocks.standing_count()).is_equal(4)


func test_toast_shows_its_message_and_fades_after_a_hold() -> void:
	assert_bool(_hud.is_toast_visible()).is_false()
	_hud.show_toast("WAKE-UP RESTORED")
	assert_bool(_hud.is_toast_visible()).is_true()
	assert_str(_hud.toast_message()).is_equal("WAKE-UP RESTORED")

	# The toast holds for three seconds of physics time, then fades on its own.
	var frames := 0
	while _hud.is_toast_visible() and frames < 400:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_hud.is_toast_visible()).is_false()
	assert_int(frames).is_between(170, 190)


func test_the_dex_button_stays_hidden_without_a_bound_dex() -> void:
	# The cafe development room binds no dex, so the phone button stays hid.
	assert_bool(_hud.dex_button.visible).is_false()
	assert_bool(_hud.dex_app.is_open()).is_false()
	_hud.open_dex()
	assert_bool(_hud.dex_app.is_open()).is_false()
