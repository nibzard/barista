# ABOUTME: Pins the Geisha Vault placement: one locked side room per city.
# ABOUTME: The vault key opens the door; the Sleep Jam cure stays brewable.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const ROOM_SCENE := preload("res://scenes/components/locked_side_room.tscn")
const SCAVENGE_POINT_SCENE := preload("res://scenes/components/scavenge_point.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const BALANCE := preload("res://resources/balance/city.tres")

const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

const VAULT_KEY := preload("res://resources/items/materials/vault_key.tres")
const GEISHA_VAULT := preload("res://resources/items/beans/geisha_vault.tres")
const CURE := preload("res://resources/brewing/recipes/geisha_vault_cup.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BREW_BALANCE := preload("res://resources/brewing/brewing_balance.tres")

const MAX_FRAMES_TO_WAIT := 600


func test_every_city_holds_one_locked_side_room_on_a_scavenge_block() -> void:
	# Section 15 beans table: the Geisha Vault beans wait in one locked side
	# room per city. The room stands beside a scavenge building, its door
	# locked, its beans inside, in every city on the route.
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var holders: Array[CityBlockView] = []
		for i: int in range(map.block_count()):
			var room := map.block_view(i).locked_side_room()
			if room != null:
				holders.append(map.block_view(i))
		assert_int(holders.size()).override_failure_message(city.city_id).is_equal(1)
		assert_int(holders[0].kind()).override_failure_message(city.city_id).is_equal(
			CityBlock.Kind.SCAVENGE
		)
		var room := holders[0].locked_side_room()
		assert_bool(room.is_locked()).override_failure_message(city.city_id).is_true()
		assert_int(room.loot_point().remaining_amount(GEISHA_VAULT)).is_greater_equal(1)
		# The beans wait behind the door, inside the walls of the vault.
		var loot_local := room.to_local(room.loot_point().global_position)
		assert_bool(room.interior_rect().has_point(loot_local)).is_true()
		# The vault stands clear of the scavenge building it shares the block
		# with, stays inside its block, and keeps the crowd lane on the street.
		var building := holders[0].building()
		(
			assert_bool(_global_footprint(room).intersects(_global_footprint(building), true))
			. override_failure_message(city.city_id)
			. is_false()
		)
		var block_rect := Rect2(holders[0].global_position, holders[0].size)
		(
			assert_bool(block_rect.encloses(_global_footprint(room)))
			. override_failure_message(city.city_id)
			. is_true()
		)
		for marker: Marker2D in holders[0].crowd_spawn_markers():
			assert_bool(_global_footprint(room).has_point(marker.global_position)).is_false()


func test_the_locked_door_blocks_the_player() -> void:
	# The lock is solid: a walk into the door gap stops on the street, and the
	# beans stay out of reach of the pickup circle.
	var room := _make_room()
	var player := _make_player_at(room.door_position() + Vector2(0.0, 100.0))
	await get_tree().physics_frame

	Input.action_press(&"move_up")
	for _i: int in range(90):
		await get_tree().physics_frame
	Input.action_release(&"move_up")

	assert_bool(room.contains_point(room.to_local(player.global_position))).is_false()
	assert_bool(room.is_locked()).is_true()
	assert_int(room.loot_point().remaining_amount(GEISHA_VAULT)).is_greater_equal(1)
	assert_bool(player.inventory.has_item(GEISHA_VAULT.item_id)).is_false()


func test_the_key_opens_the_door_once_and_is_consumed() -> void:
	# One vault key opens one locked door, the fuse idiom of section 15: the
	# key leaves the bag for good, and a second key never re-locks it.
	var room := _make_room()
	var player := _make_player_at(room.door_position() + Vector2(0.0, 40.0))

	assert_bool(room.try_unlock(player)).is_false()
	assert_bool(room.is_locked()).is_true()

	assert_int(player.pickup_item(VAULT_KEY, 1)).is_equal(1)
	assert_bool(room.try_unlock(player)).is_true()
	assert_bool(room.is_locked()).is_false()
	assert_int(player.inventory.count(VAULT_KEY.item_id)).is_equal(0)
	assert_object(room.door_barrier()).is_null()

	assert_int(player.pickup_item(VAULT_KEY, 1)).is_equal(1)
	assert_bool(room.try_unlock(player)).is_false()
	assert_bool(room.is_locked()).is_false()


func test_the_interact_action_opens_the_door() -> void:
	# The door answers the interact action, the same action the touch USE
	# button fires, so the vault opens with no keyboard, section 4.
	var room := _make_room()
	var player := _make_player_at(room.door_position() + Vector2(0.0, 40.0))
	assert_int(player.pickup_item(VAULT_KEY, 1)).is_equal(1)
	await _await_player_at_door(room)

	_fire_interact_action()
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(room.is_locked()).is_false()
	assert_int(player.inventory.count(VAULT_KEY.item_id)).is_equal(0)


func test_the_unlocked_door_lets_the_player_reach_the_beans() -> void:
	# Section 4: the player enters the vault through the open door and picks
	# up the Geisha Vault beans from the floor inside.
	var room := _make_room()
	var player := _make_player_at(room.door_position() + Vector2(0.0, 100.0))
	await get_tree().physics_frame
	room.load_state(true)

	Input.action_press(&"move_up")
	var frames := 0
	while not room.loot_point().is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_up")

	assert_int(frames).override_failure_message("the beans never left the vault").is_less(
		MAX_FRAMES_TO_WAIT
	)
	assert_int(player.inventory.count(GEISHA_VAULT.item_id)).is_greater_equal(1)


func test_every_scavenge_crate_of_every_city_stocks_a_vault_key() -> void:
	# The lock stays honest: the key that opens the room spawns in the city.
	# Every scavenge crate holds the city-wide crate stock, so the first
	# building the player loots already carries the way into the vault.
	for city: CityDefinition in _cities():
		var key_stock := _crate_key_stock(city)
		assert_int(key_stock).override_failure_message(city.city_id).is_greater_equal(1)
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			if view.kind() != CityBlock.Kind.SCAVENGE:
				continue
			assert_int(view.scavenge_point().remaining_amount(VAULT_KEY)).is_equal(key_stock)


func test_the_pourtland_beans_brew_the_sleep_jam_cure() -> void:
	# The tie T074 exists to keep: the beans placed in Pourtland satisfy the
	# Sleep Jam cure recipe, so the boss cure can never become unbrewable.
	var placed_bean: BeanType = GEISHA_VAULT.bean
	assert_int(placed_bean.quality).is_equal(CURE.min_bean_quality)
	var cup := BrewedCup.new(
		placed_bean, LIBRARY.find_roast("medium"), LIBRARY.find_method("filter"), "", 85.0
	)
	assert_bool(SleepJamBand.cure_accepted(cup, CURE, BREW_BALANCE)).is_true()


func test_the_full_vault_loop_in_the_live_pourtland_run() -> void:
	# The live-play acceptance: a player who scavenges Pourtland holds the
	# key, opens the vault, bags the beans, and brews a cup the band accepts.
	var city := POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()

	var map := city.city_map()
	var room: LockedSideRoom = null
	var crate: ScavengePoint = null
	for i: int in range(map.block_count()):
		if room == null:
			room = map.block_view(i).locked_side_room()
		if crate == null and map.block_view(i).kind() == CityBlock.Kind.SCAVENGE:
			crate = map.block_view(i).scavenge_point()
	assert_object(room).is_not_null()
	assert_object(crate).is_not_null()
	assert_int(crate.remaining_amount(VAULT_KEY)).is_greater_equal(1)

	# Step 1: the crate hands the key to the player through plain pickup.
	city.player.global_position = crate.global_position
	var frames := 0
	while not crate.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).override_failure_message("the crate never emptied").is_less(
		MAX_FRAMES_TO_WAIT
	)
	assert_bool(city.player.inventory.has_item(VAULT_KEY.item_id)).is_true()

	# Step 2: the door opens on the interact action at the threshold.
	city.player.global_position = room.global_position + room.door_position() + Vector2(0.0, 30.0)
	await _await_player_at_door(room)
	assert_bool(room.is_locked()).is_true()
	_fire_interact_action()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(room.is_locked()).is_false()
	assert_bool(city.player.inventory.has_item(VAULT_KEY.item_id)).is_false()

	# Step 3: the beans leave the vault floor and brew the cure.
	Input.action_press(&"move_up")
	frames = 0
	while not room.loot_point().is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_up")
	assert_int(frames).override_failure_message("the vault never gave up its beans").is_less(
		MAX_FRAMES_TO_WAIT
	)
	var bagged: int = city.player.inventory.count(GEISHA_VAULT.item_id)
	assert_int(bagged).is_greater_equal(1)
	var cup := BrewedCup.new(
		GEISHA_VAULT.bean, LIBRARY.find_roast("medium"), LIBRARY.find_method("filter"), "", 85.0
	)
	assert_bool(SleepJamBand.cure_accepted(cup, CURE, BREW_BALANCE)).is_true()


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _global_footprint(node: Node2D) -> Rect2:
	# The world rect of one building-like node: its local footprint, shifted
	# to its world spot. The kit never rotates a block piece.
	var footprint: Rect2
	if node is LockedSideRoom:
		footprint = (node as LockedSideRoom).footprint_rect()
	else:
		footprint = (node as BuildingShell).footprint_rect()
	return Rect2(node.global_position + footprint.position, footprint.size)


func _build_city(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = BALANCE
	add_child(auto_free(map))
	return map


func _make_room() -> LockedSideRoom:
	# A bare vault, off any city: the room scene carries its own walls, door,
	# and lock, and the test stocks its floor with the Geisha Vault beans.
	var vault := ROOM_SCENE.instantiate() as LockedSideRoom
	var loot := ScavengeDrop.new()
	loot.item = GEISHA_VAULT
	loot.amount = 3
	vault.key = VAULT_KEY
	add_child(auto_free(vault))
	var vault_loot := SCAVENGE_POINT_SCENE.instantiate() as ScavengePoint
	vault_loot.name = "Loot"
	vault_loot.drops = [loot]
	vault.add_child(vault_loot)
	return vault


func _make_player_at(at: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = at
	add_child(auto_free(player))
	return player


func _crate_key_stock(city: CityDefinition) -> int:
	for drop: ScavengeDrop in city.crate_extras:
		if drop.item == VAULT_KEY:
			return drop.amount
	return 0


func _fire_interact_action() -> void:
	# One synthesized press through the normal input pipeline, the same event
	# the touch USE button fires. The flush pushes the buffered pair out at
	# once: under load, the headless input transport drops events that wait
	# for the next frame.
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _await_player_at_door(room: LockedSideRoom) -> void:
	# The press must land only after the room's own poll has seen the player:
	# the door reach reports a teleport after a physics flush, and the room
	# reads that flush one step later in its physics tick. The wait runs on
	# the outcome, never on a fixed frame count, plus one extra step for the
	# room's poll.
	var frames := 0
	while not _reach_holds_player(room) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	await get_tree().physics_frame


func _reach_holds_player(room: LockedSideRoom) -> bool:
	var reach := room.get_node_or_null(^"DoorReach") as Area2D
	if reach == null:
		return false
	for body: Node2D in reach.get_overlapping_bodies():
		if body is Player:
			return true
	return false
