# ABOUTME: Integration tests for the van in the city run: the gift, the upgrades,
# ABOUTME: the brew-anywhere rule, and the field base of awakened survivors.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")

const MAX_FRAMES_TO_WAIT := 600

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready. A cold-start suite reports area
	# overlaps from the third physics step onward, and the first test reads
	# them, so settle three frames before every case.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak a pressed key.
	Input.action_release(&"move_right")


func test_the_van_waits_by_the_city_cafe_unopened() -> void:
	var van := _city.van()
	assert_object(van).is_not_null()
	var cafe_block := _city.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	assert_vector(van.global_position).is_equal(cafe_block.van_spot().global_position)
	assert_bool(_city.van_state.is_owned()).is_false()
	assert_bool(_city.brewing_allowed_here()).is_true()


func test_walking_up_to_the_van_triggers_the_gift() -> void:
	_wake_the_crowd()
	_city.player.global_position = _city.van().global_position

	var frames := 0
	while not _city.van_state.is_owned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.VAN)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.VAN_GIFT_TEXT)


func test_interact_away_from_the_van_changes_nothing() -> void:
	_wake_the_crowd()
	_city.player.global_position = _tower().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(_city.interact_with_van()).is_equal(MobileCafeVan.Interaction.NOT_AT_VAN)
	assert_bool(_city.van_state.is_owned()).is_false()


func test_one_interact_at_the_van_upgrades_with_scrap() -> void:
	await _own_the_van()
	var player := _city.player
	player.pickup_item(SCRAP_PART, _city.van().balance.kitchen_scrap_cost)

	assert_int(_city.interact_with_van()).is_equal(MobileCafeVan.Interaction.UPGRADED)
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)
	assert_int(player.inventory.count("scrap_part")).is_equal(0)
	assert_str(_city.hud.toast_message()).is_equal(
		CityRun.VAN_KITCHEN_TEXT % player.supply_balance.mobile_cafe_level2_carry_limit
	)


func test_interact_without_scrap_tells_the_cost() -> void:
	await _own_the_van()

	assert_int(_city.interact_with_van()).is_equal(MobileCafeVan.Interaction.NEED_SCRAP)
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.VAN)
	assert_str(_city.hud.toast_message()).is_equal(
		CityRun.VAN_NEED_SCRAP_TEXT % _city.van().balance.kitchen_scrap_cost
	)


func test_the_kitchen_raises_the_carry_limit_and_the_refill() -> void:
	await _own_the_van()
	var player := _city.player
	player.pickup_item(SCRAP_PART, _city.van().balance.kitchen_scrap_cost)
	_city.interact_with_van()

	assert_int(player.coffee_supply.carry_limit()).is_equal(
		player.supply_balance.mobile_cafe_level2_carry_limit
	)
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	player.global_position = _city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(_city.refill_player_supply()).is_equal(
		player.supply_balance.mobile_cafe_level2_carry_limit
	)
	assert_int(player.coffee_supply.cups).is_equal(
		player.supply_balance.mobile_cafe_level2_carry_limit
	)


func test_brewing_outside_the_cafe_needs_the_van_kitchen() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.global_position = _city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.brewing_allowed_here()).is_true()

	# At the level 1 van, brewing stays a cafe privilege.
	await _own_the_van()
	await get_tree().physics_frame
	assert_bool(_city.brewing_allowed_here()).is_false()

	# The level 2 kitchen brews anywhere the van stands.
	player.pickup_item(SCRAP_PART, _city.van().balance.kitchen_scrap_cost)
	_city.interact_with_van()
	await get_tree().physics_frame
	assert_bool(_city.brewing_allowed_here()).is_true()

	# Far from both spots, nothing brews.
	player.global_position = _tower().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.brewing_allowed_here()).is_false()


func test_the_field_cafe_opens_where_the_player_parks() -> void:
	await _own_the_van()
	var player := _city.player
	player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)

	var quest_block := _city.city_map().find_block_of_kind(CityBlock.Kind.QUEST)
	player.global_position = quest_block.global_position + Vector2(200.0, 100.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.call_van()).is_true()
	assert_vector(_city.van().global_position).is_equal(player.global_position)
	assert_bool(_city.van().is_field_base_open()).is_true()
	var zone := _city.van().field_base_zone()
	assert_object(zone).is_not_null()
	assert_int(zone.kind).is_equal(SleepZone.Kind.SAFE)
	var shape := zone.get_node(^"CollisionShape2D") as CollisionShape2D
	assert_float((shape.shape as CircleShape2D).radius).is_equal(
		_city.van().balance.field_base_radius
	)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.FIELD_BASE_OPEN_TEXT)


func test_the_field_base_stays_shut_below_level_three() -> void:
	await _own_the_van()
	_city.player.pickup_item(SCRAP_PART, _city.van().balance.kitchen_scrap_cost)
	_city.interact_with_van()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)

	assert_bool(_city.call_van()).is_false()
	assert_bool(_city.van().is_field_base_open()).is_false()


func test_awakened_survivors_gather_at_the_field_base() -> void:
	await _own_the_van(false)
	var player := _city.player
	player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()

	# The crowd stays asleep: only the one survivor walks to the field base.
	var survivor := _city.crowd_enemy(6)
	player.global_position = survivor.global_position + Vector2(-120.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.call_van()).is_true()

	survivor.wake_up()
	assert_bool(survivor.is_gathering()).is_false()
	var frames := 0
	while _city.van().gathered_survivors().is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_bool(survivor.is_gathering()).is_true()
	assert_int(_city.van().gathered_survivors().size()).is_equal(1)
	# The table ring stands around the parked van.
	var distance := survivor.global_position.distance_to(_city.van().global_position)
	assert_float(distance).is_less(150.0)


func test_packing_the_field_base_releases_the_gathered() -> void:
	await _own_the_van(false)
	var player := _city.player
	player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()

	var survivor := _city.crowd_enemy(6)
	player.global_position = survivor.global_position + Vector2(-120.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_city.call_van()
	survivor.wake_up()
	var frames := 0
	while _city.van().gathered_survivors().is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	assert_int(_city.interact_with_van()).is_equal(MobileCafeVan.Interaction.PACKED_FIELD_BASE)
	assert_bool(_city.van().is_field_base_open()).is_false()
	assert_object(_city.van().field_base_zone()).is_null()
	assert_bool(survivor.is_gathering()).is_false()
	assert_int(_city.van().gathered_survivors().size()).is_equal(0)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.FIELD_BASE_PACKED_TEXT)


func test_released_guests_leave_the_tables_for_a_leader() -> void:
	# The Sleepvana crowd rule, section 13: the van releases gathered guests to
	# a leader, and a follower never takes a table back while the walk lasts.
	await _own_the_van(false)
	var player := _city.player
	player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()

	var survivor := _city.crowd_enemy(6)
	player.global_position = survivor.global_position + Vector2(-120.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_city.call_van()
	survivor.wake_up()
	var frames := 0
	while _city.van().gathered_survivors().is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	var guests: Array[Sleepwalker] = [survivor]
	_city.van().release_survivors(guests)
	assert_bool(survivor.is_gathering()).is_false()
	assert_int(_city.van().gathered_survivors().size()).is_equal(0)

	# The follower stands inside the field base reach, but the invite skips
	# every survivor that walks with a leader.
	survivor.follow(player, survivor.balance.gather_stop_distance)
	for _i: int in range(30):
		await get_tree().physics_frame
	assert_bool(survivor.is_following()).is_true()
	assert_int(_city.van().gathered_survivors().size()).is_equal(0)


func test_a_freed_gathered_survivor_does_not_crash_the_field_base() -> void:
	await _own_the_van(false)
	var player := _city.player
	player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()

	var survivor := _city.crowd_enemy(6)
	player.global_position = survivor.global_position + Vector2(-120.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_city.call_van()
	survivor.wake_up()
	var frames := 0
	while _city.van().gathered_survivors().is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_city.van().gathered_survivors().size()).is_equal(1)

	survivor.free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_city.van().gathered_survivors().size()).is_equal(0)


func _own_the_van(wake_crowd := true) -> void:
	# Walk the player up to the van so the survivors hand it over, then let the
	# overlap report settle. The gathering tests keep the crowd asleep.
	if wake_crowd:
		_wake_the_crowd()
	_city.player.global_position = _city.van().global_position
	var frames := 0
	while not _city.van_state.is_owned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_city.van_state.is_owned()).is_true()


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _tower() -> BroadcastTower:
	return _city.city_map().broadcast_tower()
