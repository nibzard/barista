# ABOUTME: Integration tests that compose the three V1 cities from the block kit.
# ABOUTME: Proves the kit scenes build every landmark and hold the density budget.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BALANCE := preload("res://resources/balance/city.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

const KIT_LOOT_AMOUNT := 3
const KIT_SCRAP_AMOUNT := 2
# A Neighbor senses the player within 110 px. The cafe crowd lane keeps
# every spawn past twice that reach, so no chase starts on the wake-up
# frames of any city, section 19 steps 2 and 3.
const CAFE_CROWD_SENSE_CLEAR_DISTANCE := 220.0


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _cafe_zone_radius(city: CityDefinition) -> float:
	return CityRules.cafe_zone_radius(BALANCE, city.cafe_tier)


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


func test_the_cafe_crowd_lane_stands_off_the_player_start() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var spawn := map.cafe_spawn()
		for marker: Marker2D in map.block_view(0).crowd_spawn_markers():
			(
				assert_float(marker.global_position.distance_to(spawn.global_position))
				. override_failure_message(city.city_id)
				. is_greater_equal(CAFE_CROWD_SENSE_CLEAR_DISTANCE)
			)


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


func test_cafe_block_carries_the_player_spawn_inside_the_safe_zone() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var spawn := map.cafe_spawn()
		assert_object(spawn).is_not_null()
		var safe_zone := map.block_view(0).safe_zone()
		var spawn_offset := spawn.global_position - safe_zone.global_position
		assert_float(spawn_offset.length()).override_failure_message(city.city_id).is_less(
			_cafe_zone_radius(city)
		)


func test_scavenge_blocks_carry_a_stocked_loot_point() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			var loot := view.scavenge_point()
			if view.kind() == CityBlock.Kind.SCAVENGE:
				assert_object(loot).is_not_null()
				assert_int(loot.remaining_amount(HOUSE_BEANS)).is_equal(KIT_LOOT_AMOUNT)
				# Section 15: scrap parts pay for the van upgrades.
				assert_int(loot.remaining_amount(SCRAP_PART)).is_equal(KIT_SCRAP_AMOUNT)
			else:
				assert_object(loot).is_null()


func test_the_cafe_block_carries_a_van_spot_outside_the_safe_zone() -> void:
	# Section 10: the van stands by the cafe, and the survivors hand it over
	# there. The spot stays outside the safe zone, so the cafe brew and the van
	# brew stay two different places.
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		var spot := cafe_block.van_spot()
		assert_object(spot).override_failure_message(city.city_id).is_not_null()
		var safe_zone := cafe_block.safe_zone()
		var offset := spot.global_position - safe_zone.global_position
		assert_float(offset.length()).override_failure_message(city.city_id).is_greater(
			_cafe_zone_radius(city)
		)


func test_the_cafe_block_carries_a_master_spot_inside_the_safe_zone() -> void:
	# Section 8: the brewing master of the city teaches at the cafe, inside
	# the safe zone where the awake coffee experts gather.
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
		var spot := cafe_block.master_spot()
		assert_object(spot).override_failure_message(city.city_id).is_not_null()
		var safe_zone := cafe_block.safe_zone()
		var offset := spot.global_position - safe_zone.global_position
		assert_float(offset.length()).override_failure_message(city.city_id).is_less(
			_cafe_zone_radius(city)
		)
		# The master stands clear of the player start and the van spot.
		var distance_to_spawn := spot.global_position.distance_to(map.cafe_spawn().global_position)
		assert_float(distance_to_spawn).is_greater(100.0)
		(
			assert_float(spot.global_position.distance_to(cafe_block.van_spot().global_position))
			. is_greater(100.0)
		)


func test_the_tower_block_holds_one_fuse_at_its_foot() -> void:
	# Section 19 step 9: the player scavenges one fuse at the tower, inserts
	# it, and switches the tower off. The kit stocks that fuse.
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		var tower_block := map.find_block_of_kind(CityBlock.Kind.TOWER)
		var fuse_point := tower_block.tower_fuse_point()
		assert_object(fuse_point).is_not_null()
		assert_int(fuse_point.remaining_amount(FUSE_ITEM)).is_equal(1)
		assert_int(fuse_point.remaining_amount(HOUSE_BEANS)).is_equal(0)


func test_named_landmarks_carry_the_city_labels() -> void:
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		assert_str(map.find_block_of_kind(CityBlock.Kind.BOSS_ARENA).landmark_label).is_equal(
			city.boss_name
		)
		assert_str(map.find_block_of_kind(CityBlock.Kind.QUEST).landmark_label).is_equal(
			city.quest_name
		)
		assert_str(map.find_block_of_kind(CityBlock.Kind.SCAVENGE).landmark_label).is_equal("")
		assert_str(map.find_block_of_kind(CityBlock.Kind.CAFE).landmark_label).is_equal("")
		assert_str(map.find_block_of_kind(CityBlock.Kind.TOWER).landmark_label).is_equal("")


func test_named_sites_carry_their_label_and_marker() -> void:
	# A named place draws its site label and holds a marker for the quest
	# scripts to anchor on. Plain kit blocks hold neither.
	for city: CityDefinition in _cities():
		var map := _build_city(city)
		for i: int in range(map.block_count()):
			var view := map.block_view(i)
			if view.block.site_name.is_empty():
				assert_object(view.quest_site_marker()).is_null()
				assert_str(view.site_label).is_equal("")
			else:
				assert_object(view.quest_site_marker()).is_not_null()
				assert_str(view.site_label).is_equal(view.block.site_name)


func test_the_cafe_zone_grows_with_the_city_tier() -> void:
	# Section 10: the Steamtle cafe is bigger than the San Coffesco cafe, and
	# the Pourtland cafe is bigger still. The safe zone circle on the map
	# reads the tier from the balance table.
	var san_coffesco_map := _build_city(SAN_COFFESCO)
	var steamtle_map := _build_city(STEAMTLE)
	var pourtland_map := _build_city(POURTLAND)
	var first_cafe := san_coffesco_map.find_block_of_kind(CityBlock.Kind.CAFE)
	var second_cafe := steamtle_map.find_block_of_kind(CityBlock.Kind.CAFE)
	var third_cafe := pourtland_map.find_block_of_kind(CityBlock.Kind.CAFE)
	assert_float(first_cafe.cafe_zone_radius()).is_equal(180.0)
	assert_float(second_cafe.cafe_zone_radius()).is_equal(240.0)
	assert_float(third_cafe.cafe_zone_radius()).is_equal(300.0)
	assert_float(second_cafe.cafe_zone_radius()).is_greater(first_cafe.cafe_zone_radius())
	assert_float(third_cafe.cafe_zone_radius()).is_greater(second_cafe.cafe_zone_radius())


func test_steamtle_holds_the_sleepvana_sites_on_the_map() -> void:
	var map := _build_city(STEAMTLE)
	for site_name: String in ["Greenhouse", "The Garage", "The Sofa"]:
		var view := map.find_quest_site(site_name)
		assert_object(view).override_failure_message(site_name).is_not_null()
		assert_str(view.site_label).is_equal(site_name)
		assert_object(view.quest_site_marker()).is_not_null()
	# The public market carries the Fish Throwers boss arena.
	var market := map.find_quest_site("The Public Market")
	assert_object(market).is_not_null()
	assert_int(market.kind()).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_str(market.landmark_label).is_equal("The Fish Throwers")
	# The garage is the signature quest block of the Sleepvana quest.
	var garage := map.find_quest_site("The Garage")
	assert_int(garage.kind()).is_equal(CityBlock.Kind.QUEST)
	assert_str(garage.landmark_label).is_equal("Sleepvana")


func test_pourtland_holds_the_aisle_7_sites_on_the_map() -> void:
	# The Aisle 7 quest, section 13: the husband sleeps in the hardware store
	# between the screws and the sandpaper. The Crystal Beanroom carries the
	# Sleep Jam boss arena.
	var map := _build_city(POURTLAND)
	for site_name: String in ["The Screw Wall", "The Hardware Store", "The Sandpaper Rack"]:
		var view := map.find_quest_site(site_name)
		assert_object(view).override_failure_message(site_name).is_not_null()
		assert_str(view.site_label).is_equal(site_name)
		assert_object(view.quest_site_marker()).is_not_null()
	var store := map.find_quest_site("The Hardware Store")
	assert_int(store.kind()).is_equal(CityBlock.Kind.QUEST)
	assert_str(store.landmark_label).is_equal("The Aisle 7")
	var beanroom := map.find_quest_site("The Crystal Beanroom")
	assert_int(beanroom.kind()).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_str(beanroom.landmark_label).is_equal("The Sleep Jam")


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
