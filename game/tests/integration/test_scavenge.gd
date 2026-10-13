# ABOUTME: Integration tests for scavenge pickups: walk over a point, loot enters the bag.
# ABOUTME: Drives the real cafe scene with physics frames, like the other flow tests.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")
const SCAVENGE_POINT_SCENE := preload("res://scenes/components/scavenge_point.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const HOUSE_BEANS_ITEM := preload("res://resources/items/beans/house.tres")
const THERMOS_BELT_ITEM := preload("res://resources/items/gear/thermos_belt.tres")

const MAX_FRAMES_TO_WAIT := 600

var _cafe: Cafe


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	await get_tree().physics_frame


func test_walking_over_the_shelf_moves_its_loot_into_the_bag() -> void:
	var shelf := _cafe.get_node("Scavenge/StorageShelf") as ScavengePoint
	var looted_signals: Array[int] = []
	shelf.looted.connect(func() -> void: looted_signals.append(1))

	_cafe.player.position = shelf.position
	var frames := 0
	while not shelf.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_bool(shelf.is_depleted()).is_true()
	assert_int(looted_signals.size()).is_equal(1)
	assert_int(shelf.remaining_amount(FUSE_ITEM)).is_equal(0)
	assert_int(_cafe.player.inventory.count("fuse")).is_equal(1)
	assert_int(_cafe.player.inventory.count("house")).is_equal(3)


func test_a_looted_scavenge_point_stays_empty() -> void:
	var shelf := _cafe.get_node("Scavenge/StorageShelf") as ScavengePoint
	_cafe.player.position = shelf.position
	var frames := 0
	while not shelf.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	for extra_frame: int in range(30):
		await get_tree().physics_frame
	assert_bool(shelf.is_depleted()).is_true()
	assert_int(_cafe.player.inventory.count("fuse")).is_equal(1)
	assert_int(_cafe.player.inventory.count("house")).is_equal(3)


func test_picking_up_the_thermos_belt_raises_the_cup_carry_limit() -> void:
	var belt_point := _make_point(THERMOS_BELT_ITEM, 1)
	belt_point.position = _cafe.player.position
	_cafe.add_child(belt_point)

	var limit_before: int = _cafe.player.coffee_supply.carry_limit()
	var frames := 0
	while not belt_point.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_bool(_cafe.player.inventory.has_item("thermos_belt")).is_true()
	assert_int(_cafe.player.coffee_supply.carry_limit()).is_equal(limit_before + 3)


func test_loot_that_does_not_fit_stays_in_the_point() -> void:
	# The belt is unique gear: an owner cannot pick up a second one.
	_cafe.player.pickup_item(THERMOS_BELT_ITEM, 1)
	var belt_point := _make_point(THERMOS_BELT_ITEM, 1)
	belt_point.position = _cafe.player.position
	_cafe.add_child(belt_point)

	for frame: int in range(30):
		await get_tree().physics_frame

	assert_bool(belt_point.is_depleted()).is_false()
	assert_int(belt_point.remaining_amount(THERMOS_BELT_ITEM)).is_equal(1)
	assert_int(_cafe.player.inventory.count("thermos_belt")).is_equal(1)


func test_partial_pickup_keeps_the_rest_in_the_point() -> void:
	# 97 of 99 bean slots filled: only two of five scavenged beans fit.
	_cafe.player.pickup_item(HOUSE_BEANS_ITEM, 97)
	var bean_point := _make_point(HOUSE_BEANS_ITEM, 5)
	bean_point.position = _cafe.player.position
	_cafe.add_child(bean_point)

	for frame: int in range(30):
		await get_tree().physics_frame

	assert_int(_cafe.player.inventory.count("house")).is_equal(99)
	assert_bool(bean_point.is_depleted()).is_false()
	assert_int(bean_point.remaining_amount(HOUSE_BEANS_ITEM)).is_equal(3)


func test_sleeping_player_picks_up_nothing() -> void:
	_cafe.player.wake_ups.remaining = 0
	_cafe.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame
	assert_bool(_cafe.player.is_asleep()).is_true()

	var belt_point := _make_point(THERMOS_BELT_ITEM, 1)
	belt_point.position = _cafe.player.position
	_cafe.add_child(belt_point)

	for frame: int in range(30):
		await get_tree().physics_frame

	assert_bool(belt_point.is_depleted()).is_false()
	assert_bool(_cafe.player.inventory.has_item("thermos_belt")).is_false()


func _make_point(item: ItemType, amount: int) -> ScavengePoint:
	var drop := ScavengeDrop.new()
	drop.item = item
	drop.amount = amount
	var point := SCAVENGE_POINT_SCENE.instantiate() as ScavengePoint
	var drops: Array[ScavengeDrop] = [drop]
	point.drops = drops
	return point
