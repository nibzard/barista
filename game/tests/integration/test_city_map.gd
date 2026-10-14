# ABOUTME: Integration tests that compose the three V1 cities from the block kit.
# ABOUTME: Proves the kit scenes build every landmark and hold the density budget.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BALANCE := preload("res://resources/balance/city.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

const KIT_LOOT_AMOUNT := 3


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _build_city(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = BALANCE
	add_child(auto_free(map))
	return map


func test_map_builds_every_city_from_the_shared_kit() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		assert_int(map.block_count()).override_failure_message(city.city_id).is_equal(
			city.blocks.size()
		)


func test_map_keeps_the_landmark_set_in_order() -> void:
	var landmarks: Array[CityBlock.Kind] = [
		CityBlock.Kind.CAFE,
		CityBlock.Kind.TOWER,
		CityBlock.Kind.BOSS_ARENA,
		CityBlock.Kind.QUEST,
	]
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for kind: CityBlock.Kind in landmarks:
			(
				assert_object(map.find_block_of_kind(kind))
				. override_failure_message(
					"%s lacks %s" % [city.city_id, CityRules.kind_name(kind)]
				)
				. is_not_null()
			)
		var last_index := map.block_count() - 1
		assert_int(map.block_view(0).kind()).is_equal(CityBlock.Kind.CAFE)
		assert_int(map.block_view(last_index).kind()).is_equal(CityBlock.Kind.TOWER)


func test_map_holds_the_density_budget() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var markers := view.crowd_spawn_markers()
			assert_int(markers.size()).is_equal(city.blocks[i].sleepwalker_count)
			assert_int(markers.size()).is_between(BALANCE.density_min, BALANCE.density_max)


func test_map_places_the_three_speaker_poles() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var expected := CityRules.pole_block_indices(city.blocks.size(), BALANCE)
		for i: int in range(map.block_count()):
			var pole := map.block_view(i).pole_zone()
			if expected.has(i):
				assert_object(pole).is_not_null()
			else:
				assert_object(pole).is_null()


func test_cafe_block_carries_the_safe_zone() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var safe_zone := map.block_view(i).safe_zone()
			if i == 0:
				assert_object(safe_zone).is_not_null()
				assert_int(safe_zone.kind).is_equal(SleepZone.Kind.SAFE)
			else:
				assert_object(safe_zone).is_null()


func test_scavenge_blocks_carry_a_stocked_loot_point() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var loot := view.scavenge_point()
			if view.kind() == CityBlock.Kind.SCAVENGE:
				assert_object(loot).is_not_null()
				assert_int(loot.remaining_amount(HOUSE_BEANS)).is_equal(KIT_LOOT_AMOUNT)
			else:
				assert_object(loot).is_null()


func test_blocks_carry_the_city_accent() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			assert_bool(view.accent_color == city.accent_color).is_true()


func test_blocks_lay_out_in_one_row_without_gaps() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var block_size := CityRules.block_size(BALANCE)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var expected_x := block_size.x * float(i)
			assert_bool(absf(view.position.x - expected_x) < 0.01).is_true()
			assert_float(view.position.y).is_equal(0.0)
			assert_bool(absf(view.size.x - block_size.x) < 0.01).is_true()


func test_tower_block_composes_the_broadcast_tower() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var tower := map.broadcast_tower()
		assert_object(tower).override_failure_message(city.city_id).is_not_null()
		assert_int(tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)


func test_city_tower_switch_silences_every_speaker_pole() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var player := auto_free(PLAYER_SCENE.instantiate()) as Player
		add_child(player)
		player.pickup_item(FUSE_ITEM, 1)
		var tower := map.broadcast_tower()
		tower.insert_fuse(player)
		tower.switch_off()
		assert_bool(tower.is_switched_off()).is_true()

		var pole_blocks := CityRules.pole_block_indices(map.block_count(), BALANCE)
		for i: int in range(map.block_count()):
			var pole := map.block_view(i).pole_zone()
			if pole_blocks.has(i):
				assert_bool(pole.is_broadcast_silenced()).is_true()
			else:
				assert_object(pole).is_null()
