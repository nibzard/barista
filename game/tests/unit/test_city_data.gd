# ABOUTME: Pins the three V1 city definitions to the section 17 structure rules.
# ABOUTME: Every city must keep the landmark set and the density budget.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/city.tres")

const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

const SAN_COFFESCO_ACCENT := Color(0.1, 0.65, 0.65, 1)
const STEAMTLE_ACCENT := Color(0.35, 0.5, 0.78, 1)
const POURTLAND_ACCENT := Color(0.38, 0.6, 0.3, 1)

const EXPECTED_BLOCK_COUNTS := {"san_coffesco": 7, "steamtle": 8, "pourtland": 8}


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _pole_indices(city: CityDefinition) -> Array[int]:
	var indices: Array[int] = []
	for i: int in range(city.blocks.size()):
		if city.blocks[i].has_speaker_pole:
			indices.append(i)
	return indices


func test_every_city_passes_the_rules() -> void:
	for city: CityDefinition in _cities():
		var violations := CityRules.validate(city, BALANCE)
		(
			assert_int(violations.size())
			. override_failure_message("%s: %s" % [city.city_id, str(violations)])
			. is_equal(0)
		)


func test_every_city_holds_the_landmark_set() -> void:
	for city: CityDefinition in _cities():
		var kinds: Array[CityBlock.Kind] = [
			CityBlock.Kind.CAFE,
			CityBlock.Kind.TOWER,
			CityBlock.Kind.BOSS_ARENA,
			CityBlock.Kind.QUEST,
		]
		for kind: CityBlock.Kind in kinds:
			(
				assert_int(CityRules.count_kind(city, kind))
				. override_failure_message(city.city_id)
				. is_equal(1)
			)
		var block_count := city.blocks.size()
		assert_int(city.blocks[0].kind).is_equal(CityBlock.Kind.CAFE)
		assert_int(city.blocks[block_count - 1].kind).is_equal(CityBlock.Kind.TOWER)
		for block: CityBlock in city.blocks:
			# Quest sites are extra named places on top of the landmark set.
			var is_kit_kind := (
				block.kind == CityBlock.Kind.SCAVENGE or block.kind == CityBlock.Kind.QUEST_SITE
			)
			for kind: CityBlock.Kind in kinds:
				is_kit_kind = is_kit_kind or block.kind == kind
			assert_bool(is_kit_kind).is_true()


func test_every_city_keeps_the_density_budget() -> void:
	for city: CityDefinition in _cities():
		var block_count := city.blocks.size()
		for i: int in range(block_count):
			var count := city.blocks[i].sleepwalker_count
			(
				assert_int(count)
				. override_failure_message("%s block %d" % [city.city_id, i])
				. is_between(BALANCE.density_min, BALANCE.density_max)
			)
			if i > 0:
				var previous := city.blocks[i - 1].sleepwalker_count
				assert_int(count).is_greater_equal(previous)
		var tower_count := city.blocks[block_count - 1].sleepwalker_count
		assert_int(tower_count).is_greater(city.blocks[0].sleepwalker_count)


func test_every_city_guards_the_last_blocks_with_poles() -> void:
	for city: CityDefinition in _cities():
		var expected := CityRules.pole_block_indices(city.blocks.size(), BALANCE)
		var found := _pole_indices(city)
		assert_int(found.size()).is_equal(BALANCE.speaker_pole_count)
		for index: int in found:
			assert_bool(expected.has(index)).is_true()
		assert_bool(city.blocks[0].has_speaker_pole).is_false()
		assert_bool(city.blocks[city.blocks.size() - 1].has_speaker_pole).is_false()


func test_city_identity_pins() -> void:
	assert_str(SAN_COFFESCO.city_id).is_equal("san_coffesco")
	assert_str(SAN_COFFESCO.display_name).is_equal("San Coffesco")
	assert_str(SAN_COFFESCO.boss_name).is_equal("Sam Oatman")
	assert_str(SAN_COFFESCO.quest_name).is_equal("The Robotaxi Depot")
	assert_bool(SAN_COFFESCO.accent_color == SAN_COFFESCO_ACCENT).is_true()

	assert_str(STEAMTLE.city_id).is_equal("steamtle")
	assert_str(STEAMTLE.display_name).is_equal("Steamtle")
	assert_str(STEAMTLE.boss_name).is_equal("The Fish Throwers")
	assert_str(STEAMTLE.quest_name).is_equal("Sleepvana")
	assert_bool(STEAMTLE.accent_color == STEAMTLE_ACCENT).is_true()

	assert_str(POURTLAND.city_id).is_equal("pourtland")
	assert_str(POURTLAND.display_name).is_equal("Pourtland")
	assert_str(POURTLAND.boss_name).is_equal("The Sleep Jam")
	assert_str(POURTLAND.quest_name).is_equal("The Aisle 7")
	assert_bool(POURTLAND.accent_color == POURTLAND_ACCENT).is_true()


func test_city_block_counts_pin_the_planned_sizes() -> void:
	for city: CityDefinition in _cities():
		var expected: int = EXPECTED_BLOCK_COUNTS[city.city_id]
		assert_int(city.blocks.size()).is_equal(expected)


func test_every_city_hosts_exactly_one_brewing_master() -> void:
	# Section 8: each V1 master lives in a different city, and the master
	# data names its own city.
	var expected_masters := {
		"san_coffesco": "offmug",
		"steamtle": "hedrip",
		"pourtland": "raoast",
	}
	for city: CityDefinition in _cities():
		assert_int(city.masters.size()).override_failure_message(city.city_id).is_equal(1)
		var master: BrewingMaster = city.masters[0]
		assert_str(master.master_id).is_equal(expected_masters[city.city_id])
		assert_str(master.city_id).is_equal(city.city_id)


func test_san_coffesco_roster_pins_the_free_city_types() -> void:
	# Section 16: the San Coffesco roster is the Neighbor, the Tourist, and
	# the Tech Bro. The first entry is the basic type that teaches the throw.
	var ids: Array[String] = []
	for entry: EnemySpawn in SAN_COFFESCO.roster:
		assert_object(entry.enemy_type).is_not_null()
		assert_object(entry.scene).is_not_null()
		ids.append(entry.enemy_type.type_id)
	assert_array(ids).is_equal(["neighbor", "tourist", "tech_bro"])


func test_steamtle_roster_pins_the_city_two_types() -> void:
	# Section 16: the Steamtle roster is the Neighbor, the Tourist, and the
	# Gamer. The first entry stays the basic type that teaches the throw.
	var ids: Array[String] = []
	for entry: EnemySpawn in STEAMTLE.roster:
		assert_object(entry.enemy_type).is_not_null()
		assert_object(entry.scene).is_not_null()
		ids.append(entry.enemy_type.type_id)
	assert_array(ids).is_equal(["neighbor", "tourist", "gamer"])


func test_pourtland_roster_pins_the_city_three_types() -> void:
	# Section 16: the Pourtland roster is the Neighbor, the Tinfoil Man, and
	# the first Karen. The first entry stays the basic type that teaches the
	# throw.
	var ids: Array[String] = []
	for entry: EnemySpawn in POURTLAND.roster:
		assert_object(entry.enemy_type).is_not_null()
		assert_object(entry.scene).is_not_null()
		ids.append(entry.enemy_type.type_id)
	assert_array(ids).is_equal(["neighbor", "tinfoil_man", "karen"])


func test_cafe_tiers_grow_along_the_route() -> void:
	# Section 10: each new city holds a cafe one tier bigger than the old one.
	assert_int(SAN_COFFESCO.cafe_tier).is_equal(1)
	assert_int(STEAMTLE.cafe_tier).is_equal(2)
	assert_int(POURTLAND.cafe_tier).is_equal(3)
	assert_int(STEAMTLE.cafe_tier).is_greater(SAN_COFFESCO.cafe_tier)
	assert_int(POURTLAND.cafe_tier).is_greater(STEAMTLE.cafe_tier)


func test_steamtle_pins_the_sleepvana_sites_and_the_market() -> void:
	# The three Sleepvana places: the greenhouse, the garage, and the sofa,
	# section 13. The garage is the signature quest block, the place of the
	# encore. The public market carries the Fish Throwers arena.
	var sites: Array[String] = []
	for block: CityBlock in STEAMTLE.blocks:
		sites.append(block.site_name)
	assert_array(sites).is_equal(
		["", "Greenhouse", "", "The Public Market", "The Garage", "The Sofa", "", ""]
	)
	assert_str(STEAMTLE.blocks[4].site_name).is_equal("The Garage")
	assert_int(STEAMTLE.blocks[4].kind).is_equal(CityBlock.Kind.QUEST)
	assert_str(STEAMTLE.blocks[3].site_name).is_equal("The Public Market")
	assert_int(STEAMTLE.blocks[3].kind).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_int(STEAMTLE.blocks[1].kind).is_equal(CityBlock.Kind.QUEST_SITE)
	assert_int(STEAMTLE.blocks[5].kind).is_equal(CityBlock.Kind.QUEST_SITE)


func test_pourtland_pins_the_aisle_7_sites_and_the_beanroom() -> void:
	# The Aisle 7 quest, section 13: the husband sleeps in the hardware store
	# between the screws and the sandpaper, so the two sites flank the store
	# block. The Crystal Beanroom carries the Sleep Jam arena.
	var sites: Array[String] = []
	for block: CityBlock in POURTLAND.blocks:
		sites.append(block.site_name)
	assert_array(sites).is_equal(
		[
			"",
			"",
			"The Crystal Beanroom",
			"The Screw Wall",
			"The Hardware Store",
			"The Sandpaper Rack",
			"",
			""
		]
	)
	assert_str(POURTLAND.blocks[4].site_name).is_equal("The Hardware Store")
	assert_int(POURTLAND.blocks[4].kind).is_equal(CityBlock.Kind.QUEST)
	assert_str(POURTLAND.blocks[2].site_name).is_equal("The Crystal Beanroom")
	assert_int(POURTLAND.blocks[2].kind).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_int(POURTLAND.blocks[3].kind).is_equal(CityBlock.Kind.QUEST_SITE)
	assert_int(POURTLAND.blocks[5].kind).is_equal(CityBlock.Kind.QUEST_SITE)


func test_two_shipped_cities_name_their_boss_scenes() -> void:
	# The Sleep Jam fight ships with Pourtland, the Fish Throwers with
	# Steamtle. The arena landmark of San Coffesco still waits for the Sam
	# Oatman task, so it names no scene.
	assert_object(POURTLAND.boss_scene).is_not_null()
	var band := POURTLAND.boss_scene.instantiate() as SleepJamBand
	assert_object(band).is_not_null()
	band.free()
	assert_object(STEAMTLE.boss_scene).is_not_null()
	var market := STEAMTLE.boss_scene.instantiate() as FishThrowers
	assert_object(market).is_not_null()
	market.free()
	assert_object(SAN_COFFESCO.boss_scene).is_null()


func test_steamtle_names_its_signature_quest_scene() -> void:
	# The Sleepvana stage ships with Steamtle, section 13. The Robotaxi Depot
	# of San Coffesco still waits for its task.
	assert_object(STEAMTLE.quest_scene).is_not_null()
	var stage := STEAMTLE.quest_scene.instantiate() as SleepvanaStage
	assert_object(stage).is_not_null()
	stage.free()
	assert_object(SAN_COFFESCO.quest_scene).is_null()


func test_pourtland_names_its_signature_quest_scene() -> void:
	# The Aisle 7 stage ships with Pourtland, section 13, and carries its own
	# data: the Turkish cure, the master the sleeper becomes, the photo item,
	# and the quest balance.
	assert_object(POURTLAND.quest_scene).is_not_null()
	var stage := POURTLAND.quest_scene.instantiate() as Aisle7Stage
	assert_object(stage).is_not_null()
	assert_object(stage.turkish_cure).is_equal(
		preload("res://resources/brewing/recipes/turkish_cup.tres")
	)
	assert_object(stage.master).is_equal(preload("res://resources/masters/turkish_husband.tres"))
	assert_object(stage.photo_item).is_equal(
		preload("res://resources/items/gear/husband_photo.tres")
	)
	assert_object(stage.balance).is_equal(preload("res://resources/balance/aisle_7.tres"))
	stage.free()


func test_every_roster_entry_carries_its_own_scene() -> void:
	# The spawn entry pairs the type data with the scene that plays it, so
	# the run never maps type ids to scenes in code.
	for city: CityDefinition in _cities():
		for entry: EnemySpawn in city.roster:
			var scene_root := entry.scene.instantiate() as Sleepwalker
			assert_object(scene_root).is_not_null()
			assert_str(scene_root.enemy_type.type_id).is_equal(entry.enemy_type.type_id)
			scene_root.free()
