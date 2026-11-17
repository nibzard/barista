# ABOUTME: Integration tests for the enterable building shells of the kit.
# ABOUTME: Walls stop the player and thrown cups; the south door is the way in.
extends GdUnitTestSuite

const BUILDING_SCENE := preload("res://scenes/components/building_shell.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")

const MAX_FRAMES_TO_WAIT := 240
# Negative asserts read state after the cup freed, with margin frames so a
# late splash frame cannot flip the result after the check.
const SETTLE_MARGIN_FRAMES := 5
const STANDARD_SCORE := 85.0
# The kit shell keeps one shape: the walking bodies are 28 by 40, so the 96 px
# door leaves room to spare.
const BUILDING_SIZE := Vector2(460.0, 270.0)
const WALL_THICKNESS := 16.0
const DOOR_WIDTH := 96.0

var _cup_in_flight := false


func test_the_walls_sit_on_the_environment_layer() -> void:
	# T061: environment geometry rides layer 1. The cup flight, the aim cone,
	# and the walking bodies all read that layer, so the house walls count as
	# geometry everywhere.
	var building := _make_building()
	var walls := building.get_node(^"Walls") as StaticBody2D
	assert_object(walls).is_not_null()
	assert_int(walls.collision_layer).is_equal(1)
	assert_int(walls.get_child_count()).is_equal(5)


func test_the_south_wall_carries_one_door_gap() -> void:
	var building := _make_building()
	assert_vector(building.building_size).is_equal(BUILDING_SIZE)
	assert_float(building.wall_thickness).is_equal(WALL_THICKNESS)
	assert_float(building.door_width).is_equal(DOOR_WIDTH)

	var rects := building.wall_rects()
	assert_int(rects.size()).is_equal(5)
	for rect: Rect2 in rects:
		assert_bool(building.footprint_rect().encloses(rect)).is_true()
	# The door opening is open floor: no wall covers its center line.
	var door_line := Vector2(0.0, BUILDING_SIZE.y * 0.5 - WALL_THICKNESS * 0.5)
	for rect: Rect2 in rects:
		assert_bool(rect.has_point(door_line)).is_false()
	# The gap runs the full door width: the wall resumes right past its edge.
	var past_edge := Vector2(DOOR_WIDTH * 0.5 + 2.0, door_line.y)
	var before_edge := Vector2(DOOR_WIDTH * 0.5 - 2.0, door_line.y)
	assert_bool(_any_wall_covers(building, past_edge)).is_true()
	assert_bool(_any_wall_covers(building, before_edge)).is_false()


func test_the_interior_is_open_floor_inside_the_walls() -> void:
	var building := _make_building()
	var interior := building.interior_rect()
	assert_vector(interior.size).is_equal(
		BUILDING_SIZE - Vector2(WALL_THICKNESS, WALL_THICKNESS) * 2.0
	)
	assert_bool(interior.has_point(Vector2.ZERO)).is_true()
	for rect: Rect2 in building.wall_rects():
		assert_bool(rect.intersects(interior)).is_false()


func test_the_player_walks_in_through_the_door() -> void:
	# Section 4: the player enters houses. A walk from the street through the
	# south door reaches the interior floor.
	var building := _make_building()
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = building.door_position() + Vector2(0.0, 100.0)
	add_child(auto_free(player))
	await get_tree().physics_frame

	Input.action_press(&"move_up")
	var frames := 0
	while not _player_inside(building, player) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_up")

	assert_int(frames).override_failure_message("the door never let the player in").is_less(
		MAX_FRAMES_TO_WAIT
	)


func test_the_walls_stop_the_player() -> void:
	# Only the door leads inside: a walk into the north wall stops on the
	# street, outside the footprint.
	var building := _make_building()
	var player := PLAYER_SCENE.instantiate() as Player
	player.global_position = building.door_position() - Vector2(0.0, 400.0)
	add_child(auto_free(player))
	await get_tree().physics_frame

	Input.action_press(&"move_down")
	for _i: int in range(90):
		await get_tree().physics_frame
	Input.action_release(&"move_down")

	assert_bool(building.contains_point(building.to_local(player.global_position))).is_false()
	assert_float(player.global_position.y).is_less(-BUILDING_SIZE.y * 0.5)


func test_a_cup_breaks_on_the_house_wall() -> void:
	# The T061 rule inside a city: coffee never crosses a house wall. A cup
	# thrown at a sleeper inside the building dies on the north wall, and the
	# sleeper behind it stays asleep.
	var building := _make_building()
	var sleeper := _frozen_sleeper_at(Vector2(0.0, -60.0))
	var cup := _throw_cup_from(Vector2(0.0, -300.0), Vector2(0.0, 200.0))

	var deepest_y := -300.0
	var frames := 0
	while _cup_in_flight and frames < MAX_FRAMES_TO_WAIT:
		if is_instance_valid(cup):
			deepest_y = maxf(deepest_y, cup.global_position.y)
		await get_tree().physics_frame
		frames += 1
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(_cup_in_flight).is_false()
	assert_float(deepest_y).is_less(-BUILDING_SIZE.y * 0.5 + WALL_THICKNESS)
	assert_int(sleeper.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_the_player_loots_the_crate_inside_the_building() -> void:
	# The live city flow: the player walks through the door of a scavenge
	# building and picks up the crate that waits inside, section 17.
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()

	var block := city.city_map().find_block_of_kind(CityBlock.Kind.SCAVENGE)
	var building := block.building()
	var loot := block.scavenge_point()
	assert_object(building).is_not_null()
	assert_object(loot).is_not_null()

	city.player.global_position = (
		building.global_position + building.door_position() + Vector2(0.0, 80.0)
	)
	await get_tree().physics_frame
	Input.action_press(&"move_up")
	var frames := 0
	while not loot.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_up")

	assert_int(frames).override_failure_message("the crate never emptied").is_less(
		MAX_FRAMES_TO_WAIT
	)
	assert_bool(city.player.inventory.has_item(HOUSE_BEANS.item_id)).is_true()


func test_every_scavenge_block_ships_one_enterable_building() -> void:
	# Section 17: the rest of the city is scavenge buildings. Every scavenge
	# block wraps its crate and its find inside a shell, the crowd lane stays
	# on the street outside the walls, and the landmark blocks stay open.
	for city: CityDefinition in [SAN_COFFESCO, STEAMTLE, POURTLAND]:
		var map := _build_city_map(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var building := view.building()
			var where := "%s block %d" % [city.city_id, i]
			if view.kind() != CityBlock.Kind.SCAVENGE:
				assert_object(building).override_failure_message(where).is_null()
				continue
			assert_object(building).override_failure_message(where).is_not_null()
			var interior := building.interior_rect()
			var crate_local := building.to_local(view.scavenge_point().global_position)
			assert_bool(interior.has_point(crate_local)).override_failure_message(where).is_true()
			var find := view.find_point()
			if find != null:
				var find_local := building.to_local(find.global_position)
				(
					assert_bool(interior.has_point(find_local))
					. override_failure_message(where)
					. is_true()
				)
			for marker: Marker2D in view.crowd_spawn_markers():
				var marker_local := building.to_local(marker.global_position)
				(
					assert_bool(building.contains_point(marker_local))
					. override_failure_message(where)
					. is_false()
				)


func _build_city_map(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = CITY_BALANCE
	add_child(auto_free(map))
	return map


func _make_building() -> BuildingShell:
	var building := BUILDING_SCENE.instantiate() as BuildingShell
	add_child(auto_free(building))
	return building


func _player_inside(building: BuildingShell, player: Player) -> bool:
	return building.interior_rect().has_point(building.to_local(player.global_position))


func _any_wall_covers(building: BuildingShell, point: Vector2) -> bool:
	for rect: Rect2 in building.wall_rects():
		if rect.has_point(point):
			return true
	return false


func _frozen_sleeper_at(at: Vector2) -> Sleepwalker:
	var sleeper := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	var calm := sleeper.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	sleeper.balance = calm
	sleeper.position = at
	add_child(auto_free(sleeper))
	return sleeper


func _throw_cup_from(from: Vector2, landing_offset: Vector2) -> CoffeeCup:
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = from
	cup.direction = landing_offset.normalized()
	cup.brewed = BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("filter"),
		"",
		STANDARD_SCORE
	)
	add_child(auto_free(cup))
	_cup_in_flight = true
	cup.tree_exited.connect(_on_cup_left_tree)
	cup.launch(from + landing_offset)
	return cup


func _on_cup_left_tree() -> void:
	_cup_in_flight = false
