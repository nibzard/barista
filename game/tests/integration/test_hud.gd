# ABOUTME: Integration tests for the HUD bindings: components change, the chalkboard follows.
# ABOUTME: Every status from GAME_DESIGN section 9 must read live from the logic components.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const HOUSE_BEANS_ITEM := preload("res://resources/items/beans/house.tres")
const THERMOS_BELT_ITEM := preload("res://resources/items/gear/thermos_belt.tres")

var _cafe: Cafe
var _hud: Hud


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	_hud = _cafe.get_node("Hud") as Hud
	await get_tree().physics_frame


func test_hud_binds_to_the_cafe_player_and_shows_the_starting_status() -> void:
	assert_object(_hud.player).is_equal(_cafe.player)
	assert_float(_hud.awake_bar.value).is_equal_approx(100.0, 0.01)
	assert_str(_hud.awake_value.text).is_equal("100/100")
	assert_str(_hud.coffee_value.text).is_equal("12/12 cups in hand")
	assert_str(_hud.wake_ups_value.text).is_equal("5/5")
	assert_str(_hud.bag_label.text).is_equal("empty bag")


func test_sleepy_meter_reading_follows_the_meter() -> void:
	_cafe.player.sleep_meter.drain(30.0)
	_hud.refresh()
	assert_float(_hud.awake_bar.value).is_equal_approx(70.0, 0.01)
	assert_str(_hud.awake_value.text).is_equal("70/100")
	_cafe.player.sleep_meter.gain(10.0)
	_hud.refresh()
	assert_str(_hud.awake_value.text).is_equal("80/100")


func test_coffee_supply_reading_follows_the_supply() -> void:
	_cafe.player.coffee_supply.spend_cups(4)
	_hud.refresh()
	assert_str(_hud.coffee_value.text).is_equal("8/12 cups in hand")


func test_carry_limit_change_updates_the_coffee_reading() -> void:
	# The thermos belt raises the carry limit from 12 to 15.
	_cafe.player.pickup_item(THERMOS_BELT_ITEM, 1)
	_cafe.player.coffee_supply.spend_cups(12)
	_hud.refresh()
	assert_str(_hud.coffee_value.text).is_equal("0/15 cups in hand")


func test_wake_ups_reading_follows_the_wake_ups() -> void:
	_cafe.player.wake_ups.register_sleep()
	_hud.refresh()
	assert_str(_hud.wake_ups_value.text).is_equal("4/5")
	_cafe.player.wake_ups.restore_one()
	_hud.refresh()
	assert_str(_hud.wake_ups_value.text).is_equal("5/5")


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
	assert_float(_hud.awake_bar.value).is_equal_approx(75.0, 0.01)
	assert_str(_hud.coffee_value.text).is_equal("11/12 cups in hand")
	assert_str(_hud.wake_ups_value.text).is_equal("4/5")


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
