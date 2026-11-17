# ABOUTME: Pins the section 15 obtainable placements: region beans and unique finds.
# ABOUTME: Every version 1 obtainable must have a placement owner in city data.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const BALANCE := preload("res://resources/balance/city.tres")

const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const GOLDEN_COAST := preload("res://resources/items/beans/golden_coast_arabica.tres")
const MOSS_HOLLOW := preload("res://resources/items/beans/moss_hollow_organic.tres")
const BLENDER := preload("res://resources/items/appliances/blender.tres")
const THERMOS_BELT := preload("res://resources/items/gear/thermos_belt.tres")
const TURKISH_POT := preload("res://resources/items/appliances/turkish_pot.tres")

const MAX_FRAMES_TO_WAIT := 600


func _cities() -> Array[CityDefinition]:
	return [SAN_COFFESCO, STEAMTLE, POURTLAND]


func _build_city(city: CityDefinition) -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = city
	map.balance = BALANCE
	add_child(auto_free(map))
	return map


func _scavenge_blocks(map: CityMap) -> Array[int]:
	var indexes: Array[int] = []
	for i: int in range(map.block_count()):
		if map.block_view(i).kind() == CityBlock.Kind.SCAVENGE:
			indexes.append(i)
	return indexes


func test_steamtle_scavenge_crates_yield_golden_coast_arabica() -> void:
	# Section 15 beans table: Golden Coast arabica is the good bean of the
	# Steamtle region, so the scavenge buildings of the city yield it.
	var region_bean: ItemType = STEAMTLE.region_bean
	assert_object(region_bean).is_not_null()
	assert_str(region_bean.item_id).is_equal("golden_coast_arabica")
	var map := _build_city(STEAMTLE)
	for index: int in _scavenge_blocks(map):
		var loot := map.block_view(index).scavenge_point()
		assert_object(loot).override_failure_message("block %d" % index).is_not_null()
		assert_int(loot.remaining_amount(GOLDEN_COAST)).is_equal(BALANCE.scavenge_region_beans)


func test_pourtland_scavenge_crates_yield_moss_hollow_organic() -> void:
	# Section 15 beans table: Moss Hollow organic is the good bean of the
	# Pourtland region, so the scavenge buildings of the city yield it.
	var region_bean: ItemType = POURTLAND.region_bean
	assert_object(region_bean).is_not_null()
	assert_str(region_bean.item_id).is_equal("moss_hollow_organic")
	var map := _build_city(POURTLAND)
	for index: int in _scavenge_blocks(map):
		var loot := map.block_view(index).scavenge_point()
		assert_object(loot).override_failure_message("block %d" % index).is_not_null()
		assert_int(loot.remaining_amount(MOSS_HOLLOW)).is_equal(BALANCE.scavenge_region_beans)


func test_san_coffesco_holds_no_region_bean() -> void:
	# Section 15: house beans are the common bean of every city. The free city
	# keeps its crates plain; the good beans belong to the regions east.
	assert_object(SAN_COFFESCO.region_bean).is_null()
	var map := _build_city(SAN_COFFESCO)
	for index: int in _scavenge_blocks(map):
		var loot := map.block_view(index).scavenge_point()
		assert_int(loot.remaining_amount(GOLDEN_COAST)).is_equal(0)
		assert_int(loot.remaining_amount(MOSS_HOLLOW)).is_equal(0)
		assert_int(loot.remaining_amount(HOUSE_BEANS)).is_equal(BALANCE.scavenge_house_beans)


func test_the_region_bean_stock_pin() -> void:
	# The crate stock reads city.tres. The region bean stays at or under the
	# house bean stock, so the good bean of the region is never the common one.
	assert_int(BALANCE.scavenge_region_beans).is_equal(2)
	assert_int(BALANCE.scavenge_region_beans).is_less_equal(BALANCE.scavenge_house_beans)


func test_the_blender_waits_in_a_san_coffesco_scavenge_building() -> void:
	# Section 15: the blender is a cafe appliance the player scavenges. The
	# Tourist of section 16 walks the free city, so the Frappuccino cure has
	# its appliance where the cure is first needed.
	_pin_one_unique_find(SAN_COFFESCO, BLENDER)


func test_the_thermos_belt_waits_in_a_steamtle_scavenge_building() -> void:
	# Section 15: the thermos belt raises the carry limit by 3. The find makes
	# the +3 limit reachable in play.
	_pin_one_unique_find(STEAMTLE, THERMOS_BELT)


func test_the_turkish_pot_waits_in_a_pourtland_scavenge_building() -> void:
	# Section 15: the Turkish pot is a cafe appliance the player scavenges. The
	# Tinfoil Man and the Aisle 7 husband of section 13 both need the Turkish
	# brew, so the pot waits in their city.
	_pin_one_unique_find(POURTLAND, TURKISH_POT)


func test_every_authored_find_is_one_unique_item_on_a_scavenge_block() -> void:
	# The drift guard for future placements: every authored find row holds one
	# copy of one unique item, and it waits in a scavenge building.
	for city: CityDefinition in _cities():
		for block: CityBlock in city.blocks:
			if block.finds.is_empty():
				continue
			assert_int(block.kind).override_failure_message(city.city_id).is_equal(
				CityBlock.Kind.SCAVENGE
			)
			assert_int(block.finds.size()).override_failure_message(city.city_id).is_equal(1)
			var find := block.finds[0]
			assert_object(find.item).is_not_null()
			assert_int(find.amount).is_equal(1)
			assert_int(find.item.max_stack).override_failure_message(find.item.item_id).is_equal(1)


func test_a_find_with_no_item_or_no_amount_reported() -> void:
	# Section 15: a broken authored find row would silently empty the scavenge
	# point, because the point drops every find with no item or no amount, so
	# the city validator reports it before the city ships.
	var city := _make_valid_city()
	var broken := ScavengeDrop.new()
	var finds: Array[ScavengeDrop] = [broken]
	city.blocks[2].finds = finds
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "Block 2 authors a find with no item")).is_true()

	broken.item = THERMOS_BELT
	broken.amount = 0
	violations = CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "Block 2 authors a find of thermos_belt")).is_true()

	broken.amount = 1
	violations = CityRules.validate(city, BALANCE)
	assert_str(str(violations)).is_equal("[]")


func test_the_belt_find_raises_the_carry_limit_in_the_live_city() -> void:
	# The belt equips on pickup, so the Steamtle find makes the +3 carry limit
	# reachable through plain play: walk over the point, wear the belt.
	var city := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Awakened sleepwalkers never hug, so the pickup wait stays steady.
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()

	var map := city.city_map()
	var find_point: ScavengePoint = null
	for i: int in range(map.block_count()):
		find_point = map.block_view(i).find_point()
		if find_point != null:
			break
	assert_object(find_point).is_not_null()
	assert_int(find_point.remaining_amount(THERMOS_BELT)).is_equal(1)

	var limit_before: int = city.player.coffee_supply.carry_limit()
	city.player.global_position = find_point.global_position
	var frames := 0
	while not find_point.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_bool(city.player.inventory.has_item(THERMOS_BELT.item_id)).is_true()
	assert_int(city.player.coffee_supply.carry_limit()).is_equal(limit_before + 3)


func _pin_one_unique_find(city: CityDefinition, item: ItemType) -> void:
	# The city holds exactly one authored find, in a scavenge building, and the
	# composed find point stocks the named item.
	var map := _build_city(city)
	var holders: Array[CityBlockView] = []
	for i: int in range(map.block_count()):
		if map.block_view(i).find_point() != null:
			holders.append(map.block_view(i))
	assert_int(holders.size()).override_failure_message(city.city_id).is_equal(1)
	assert_int(holders[0].kind()).override_failure_message(city.city_id).is_equal(
		CityBlock.Kind.SCAVENGE
	)
	var find_point := holders[0].find_point()
	assert_int(find_point.remaining_amount(item)).is_equal(1)


func _has_violation(violations: Array[String], part: String) -> bool:
	for violation: String in violations:
		if violation.contains(part):
			return true
	return false


func _make_valid_city() -> CityDefinition:
	# A smallest valid city for the validator: 6 blocks, poles on the three
	# blocks before the tower, finds authored on a scavenge block.
	var city := CityDefinition.new()
	city.city_id = "test_city"
	var blocks: Array[CityBlock] = []
	var kinds: Array[CityBlock.Kind] = [
		CityBlock.Kind.CAFE,
		CityBlock.Kind.QUEST,
		CityBlock.Kind.SCAVENGE,
		CityBlock.Kind.SCAVENGE,
		CityBlock.Kind.BOSS_ARENA,
		CityBlock.Kind.TOWER,
	]
	for i: int in range(kinds.size()):
		var block := CityBlock.new()
		block.kind = kinds[i]
		block.sleepwalker_count = 3 if i < 2 else 4
		block.has_speaker_pole = i in [2, 3, 4]
		blocks.append(block)
	city.blocks = blocks
	return city
