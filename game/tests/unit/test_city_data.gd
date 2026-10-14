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

const EXPECTED_BLOCK_COUNTS := {"san_coffesco": 7, "steamtle": 8, "pourtland": 6}


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
			var is_kit_kind := block.kind == CityBlock.Kind.SCAVENGE
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
