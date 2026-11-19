# ABOUTME: Pins the section 11 support tool placement in live city play: a
# ABOUTME: route find unlocks the belt and opens the TOOL and SWAP buttons.
# ABOUTME: The equipped tool also names itself on the controls, T098.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const TAMPER := preload("res://resources/items/gear/tamper.tres")

const MAX_FRAMES_TO_WAIT := 600


func test_a_live_route_find_unlocks_the_belt() -> void:
	# Section 11: the tamper waits in a scavenge building of the free city.
	# Walking over the find puts the gear in the bag, and the belt unlocks
	# and equips the tool without the cafe development room.
	var city := await _fresh_city()
	var find_point := _find_point_stocking(city, TAMPER)
	assert_object(find_point).is_not_null()
	assert_bool(city.player.toolbelt.has_any()).is_false()

	city.player.global_position = find_point.global_position
	await _await_the_pickup(find_point)

	assert_bool(city.player.inventory.has_item("tamper")).is_true()
	assert_bool(city.player.toolbelt.is_unlocked(SupportToolbelt.Tool.TAMPER)).is_true()
	assert_int(city.player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)


func test_the_tool_and_swap_buttons_open_with_the_first_find() -> void:
	# The buttons hid through every city before the route placement, because
	# nothing in live play unlocked the belt. The find opens both, so a touch
	# player reaches the tools without a keyboard.
	var city := await _fresh_city()
	var find_point := _find_point_stocking(city, TAMPER)
	assert_object(find_point).is_not_null()
	assert_bool(city.touch_controls.button(TouchControls.ButtonKind.TOOL).is_available()).is_false()
	assert_bool(city.touch_controls.button(TouchControls.ButtonKind.SWAP).is_available()).is_false()

	city.player.global_position = find_point.global_position
	await _await_the_pickup(find_point)
	# The pickup lands inside the point's physics step, after the run's own
	# context update of that frame, so one more frame opens the buttons.
	await get_tree().physics_frame

	assert_bool(city.touch_controls.button(TouchControls.ButtonKind.TOOL).is_available()).is_true()
	assert_bool(city.touch_controls.button(TouchControls.ButtonKind.SWAP).is_available()).is_true()


func test_the_route_find_names_the_equipped_tool_on_the_controls() -> void:
	# T098: the swap readout. The SWAP tap carried no feedback, so a touch
	# player could not see which tool rode the slot. The find names the tool
	# in chalk beside the TOOL and SWAP coasters, and the name follows a swap.
	var city := await _fresh_city()
	assert_bool(city.touch_controls.tool_readout.visible).is_false()

	var find_point := _find_point_stocking(city, TAMPER)
	city.player.global_position = find_point.global_position
	await _await_the_pickup(find_point)

	await _until_readout(city.touch_controls, "Tamper")
	assert_bool(city.touch_controls.tool_readout.visible).is_true()

	# The readout follows the swap through the touch button, the only path a
	# touch player has. The label poll of _process can read the belt one frame
	# before the run's physics tick opens the SWAP button, so the tap waits
	# on the button itself, never on a frame count.
	var swap_button := city.touch_controls.button(TouchControls.ButtonKind.SWAP)
	var frames := 0
	while not swap_button.is_available() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(swap_button.is_available()).is_true()

	city.player.toolbelt.grant_item("steam_wand")
	var center: Vector2 = swap_button.get_global_rect().get_center()
	city.touch_controls._input(_touch(true, center))
	city.touch_controls._input(_touch(false, center))
	await _until_readout(city.touch_controls, "Steam Wand")


func _until_readout(controls: TouchControls, tool_name: String) -> void:
	# The readout polls the belt once per process frame, so the wait runs on
	# the drawn text, never on a fixed frame count.
	var frames := 0
	while controls.tool_readout.text != tool_name and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	assert_str(controls.tool_readout.text).is_equal(tool_name)


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = pressed
	touch.position = position
	touch.index = 1
	return touch


func _fresh_city() -> CityRun:
	# A live San Coffesco run. The fresh city needs three physics frames
	# before its area overlaps report, and awakened sleepwalkers never hug,
	# so the pickup wait stays steady.
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()
	return city


func _find_point_stocking(city: CityRun, item: ItemType) -> ScavengePoint:
	# The one find point of the city that stocks the named item.
	var map := city.city_map()
	for i: int in range(map.block_count()):
		var point := map.block_view(i).find_point()
		if point != null and point.remaining_amount(item) > 0:
			return point
	return null


func _await_the_pickup(find_point: ScavengePoint) -> void:
	var frames := 0
	while not find_point.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
