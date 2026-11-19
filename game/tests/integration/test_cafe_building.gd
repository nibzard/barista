# ABOUTME: Integration tests for the real cafe building of the city kit, T063.
# ABOUTME: The safe zone covers the whole cafe interior; the poles guard the tower.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")
const PLAIN_CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")

# The interior fills the safe circle up to this share of the radius, so a cafe
# far smaller than its zone fails the coverage pin below.
const MIN_INTERIOR_CORNER_SHARE := 0.9
# One held walk leg: every leg stays under a few hundred pixels.
const WALK_FRAMES := 360


func test_every_city_cafe_composes_one_enterable_building() -> void:
	# Section 17 with section 10: the cafe landmark is a real enterable
	# building of the kit, one per city, on the cafe block alone.
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var building := view.cafe_building()
			var where := "%s block %d" % [city.city_id, i]
			if view.kind() != CityBlock.Kind.CAFE:
				assert_object(building).override_failure_message(where).is_null()
				continue
			assert_object(building).override_failure_message(where).is_not_null()
			# The building centers on the safe zone, and its walls ride the
			# environment layer like every kit building, so cups and walkers
			# read them as geometry.
			var zone := view.safe_zone()
			assert_vector(building.global_position).override_failure_message(where).is_equal(
				zone.global_position
			)
			var walls := building.get_node(^"Walls") as StaticBody2D
			assert_int(walls.collision_layer).override_failure_message(where).is_equal(1)


func test_the_safe_zone_covers_the_whole_cafe_interior() -> void:
	# T063: the farthest floor points of the cafe are its interior corners,
	# and every one of them stands inside the safe circle.
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		var block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		var building := block.cafe_building()
		var zone := block.safe_zone()
		var radius := block.cafe_zone_radius()
		var interior := building.interior_rect()
		assert_bool(interior.has_area()).override_failure_message(city.city_id).is_true()
		var corners: Array[Vector2] = [
			interior.position,
			Vector2(interior.end.x, interior.position.y),
			interior.end,
			Vector2(interior.position.x, interior.end.y),
		]
		for corner: Vector2 in corners:
			var distance: float = building.to_global(corner).distance_to(zone.global_position)
			assert_float(distance).override_failure_message(city.city_id).is_less_equal(radius)
			assert_float(distance).override_failure_message(city.city_id).is_greater(
				radius * MIN_INTERIOR_CORNER_SHARE
			)


func test_the_cafe_building_grows_with_the_city_tier() -> void:
	# Section 10: each new city cafe is bigger than the old cafe.
	var sizes: Array[Vector2] = []
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		var building := map.find_block_of_kind(CityBlock.Kind.CAFE).cafe_building()
		sizes.append(building.interior_rect().size)
	assert_float(sizes[1].x).is_greater(sizes[0].x)
	assert_float(sizes[2].x).is_greater(sizes[1].x)
	assert_float(sizes[1].y).is_greater(sizes[0].y)
	assert_float(sizes[2].y).is_greater(sizes[1].y)


func test_the_cafe_anchors_stand_inside_the_building() -> void:
	# The player start, the brewing master, and the television stand on the
	# cafe floor, and the master and the set stay clear of the south door gap.
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		var block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		var building := block.cafe_building()
		var interior := building.interior_rect()
		var spots: Array[Vector2] = [
			map.cafe_spawn().global_position,
			block.master_spot().global_position,
			block.television().global_position,
		]
		for spot: Vector2 in spots:
			(
				assert_bool(interior.has_point(building.to_local(spot)))
				. override_failure_message(city.city_id)
				. is_true()
			)
		var door_half := building.door_width * 0.5
		(
			assert_float(absf(building.to_local(block.master_spot().global_position).x))
			. override_failure_message(city.city_id)
			. is_greater(door_half)
		)
		(
			assert_float(absf(building.to_local(block.television().global_position).x))
			. override_failure_message(city.city_id)
			. is_greater(door_half)
		)


func test_the_crowd_and_the_van_stay_outside_the_cafe_walls() -> void:
	# The cafe crowd wanders the south street and the van stands outside the
	# safe zone, so neither one lands inside the cafe walls.
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		var block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		var building := block.cafe_building()
		for marker: Marker2D in block.crowd_spawn_markers():
			(
				assert_bool(building.contains_point(building.to_local(marker.global_position)))
				. override_failure_message(city.city_id)
				. is_false()
			)
		(
			assert_bool(
				building.contains_point(building.to_local(block.van_spot().global_position))
			)
			. override_failure_message(city.city_id)
			. is_false()
		)


func test_the_player_walks_out_through_the_cafe_door() -> void:
	# Section 4 with section 19: the player starts on the cafe floor and steps
	# out through the south door, then walks back in. The door is the only way
	# through the walls, so the first ten minutes keep their path.
	var city := await _build_run()
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()
	await get_tree().physics_frame
	var building := _cafe_block(city).cafe_building()
	var player := city.player
	(
		assert_bool(building.interior_rect().has_point(building.to_local(player.global_position)))
		. is_true()
	)

	var at_column := func() -> bool: return building.to_local(player.global_position).x >= 0.0
	assert_bool(await _walk_until(&"move_right", at_column)).is_true()

	var outside := func() -> bool:
		return not building.contains_point(building.to_local(player.global_position))
	assert_bool(await _walk_until(&"move_down", outside)).is_true()

	var inside := func() -> bool:
		return building.interior_rect().has_point(building.to_local(player.global_position))
	assert_bool(await _walk_until(&"move_up", inside)).is_true()


func test_the_poles_guard_the_last_blocks_before_the_tower() -> void:
	# Section 17, T063: the three speaker poles guard the last blocks before
	# the tower. The cafe block and the tower block hold none.
	for city: CityDefinition in _cities():
		var map := _build_map(city)
		var expected := CityRules.pole_block_indices(map.block_count(), CITY_BALANCE)
		assert_int(expected.size()).override_failure_message(city.city_id).is_equal(3)
		for i: int in range(map.block_count()):
			var pole := map.block_view(i).pole_zone()
			var where := "%s block %d" % [city.city_id, i]
			if expected.has(i):
				assert_object(pole).override_failure_message(where).is_not_null()
				assert_int(pole.kind).override_failure_message(where).is_equal(SleepZone.Kind.SLEEP)
			else:
				assert_object(pole).override_failure_message(where).is_null()


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _build_map(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = CITY_BALANCE
	add_child(auto_free(map))
	return map


func _build_run() -> CityRun:
	var run := PLAIN_CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return run


func _cafe_block(run: CityRun) -> CityBlockView:
	return run.city_map().find_block_of_kind(CityBlock.Kind.CAFE)


func _walk_until(action: StringName, done: Callable) -> bool:
	# Walks with one move action held until done() holds. Every caller must
	# await this helper: it yields physics frames.
	Input.action_press(action)
	var frames := 0
	while not done.call() and frames < WALK_FRAMES:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(action)
	return done.call()
