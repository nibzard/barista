# ABOUTME: Unit tests for the locked side room rules, section 15 beans table.
# ABOUTME: Pure data in, violation strings out; no scenes are loaded here.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/city.tres")
const VAULT_KEY := preload("res://resources/items/materials/vault_key.tres")
const GEISHA_VAULT := preload("res://resources/items/beans/geisha_vault.tres")
const THERMOS_BELT := preload("res://resources/items/gear/thermos_belt.tres")


func test_the_vault_key_item_pins() -> void:
	# The key follows the fuse idiom: one material, stackable, because the
	# crates of a city may hand out more than the one door consumes.
	assert_str(VAULT_KEY.item_id).is_equal("vault_key")
	assert_int(VAULT_KEY.category).is_equal(ItemType.Category.MATERIAL)
	assert_int(VAULT_KEY.max_stack).is_greater_equal(2)


func test_a_valid_city_with_one_room_has_no_violations() -> void:
	var city := _make_valid_city()
	_put_room_on(city, 2)
	var violations := CityRules.validate(city, BALANCE)
	assert_str(str(violations)).is_equal("[]")


func test_a_valid_city_without_a_room_stays_valid() -> void:
	# The room is authored content, not a structural landmark: the validator
	# shapes the rooms a city authors, and the per-city tests pin that each
	# shipped city holds exactly one.
	var violations := CityRules.validate(_make_valid_city(), BALANCE)
	assert_str(str(violations)).is_equal("[]")


func test_a_room_outside_a_scavenge_building_reported() -> void:
	var city := _make_valid_city()
	_put_room_on(city, 1)
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "outside a scavenge building")).is_true()


func test_two_rooms_reported() -> void:
	var city := _make_valid_city()
	_put_room_on(city, 2)
	_put_room_on(city, 3)
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "at most one locked side room, found 2")).is_true()


func test_a_room_with_no_key_reported() -> void:
	var city := _make_valid_city()
	var loot := _make_room()
	loot.key = null
	city.blocks[2].locked_side_room = loot
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "locked side room with no key")).is_true()


func test_a_room_key_with_no_crate_stock_reported() -> void:
	# The lock stays honest: a key no crate stocks locks the finds away for
	# good, the exact dead end T074 exists to close.
	var city := _make_valid_city()
	var loot := _make_room()
	loot.key = THERMOS_BELT
	city.blocks[2].locked_side_room = loot
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "key thermos_belt has no stock")).is_true()


func test_a_room_with_broken_find_rows_reported() -> void:
	var city := _make_valid_city()
	var loot := _make_room()
	var broken := ScavengeDrop.new()
	loot.drops = [broken]
	city.blocks[2].locked_side_room = loot
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "side room find with no item")).is_true()

	broken.item = GEISHA_VAULT
	broken.amount = 0
	violations = CityRules.validate(city, BALANCE)
	(
		assert_bool(_has_violation(violations, "side room find of geisha_vault with no amount"))
		. is_true()
	)

	loot.drops = []
	violations = CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "locked side room with no finds")).is_true()


func test_broken_crate_extra_rows_reported() -> void:
	var city := _make_valid_city()
	_put_room_on(city, 2)
	var broken := ScavengeDrop.new()
	city.crate_extras = [broken]
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "crate extra with no item")).is_true()

	broken.item = VAULT_KEY
	broken.amount = 0
	violations = CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "crate extra of vault_key with no amount")).is_true()


func _make_valid_city() -> CityDefinition:
	# A smallest valid city: 6 blocks, poles on the three blocks before the
	# tower, scavenge blocks at index 2 and 3 to host a room or a crate.
	var city := CityDefinition.new()
	city.city_id = "test_city"
	var kinds: Array[CityBlock.Kind] = [
		CityBlock.Kind.CAFE,
		CityBlock.Kind.QUEST,
		CityBlock.Kind.SCAVENGE,
		CityBlock.Kind.SCAVENGE,
		CityBlock.Kind.BOSS_ARENA,
		CityBlock.Kind.TOWER,
	]
	var blocks: Array[CityBlock] = []
	for i: int in range(kinds.size()):
		var block := CityBlock.new()
		block.kind = kinds[i]
		block.sleepwalker_count = 3 if i < 2 else 4
		block.has_speaker_pole = i in [2, 3, 4]
		blocks.append(block)
	city.blocks = blocks
	city.crate_extras = [_make_key_stock()]
	return city


func _put_room_on(city: CityDefinition, index: int) -> void:
	city.blocks[index].locked_side_room = _make_room()


func _make_room() -> SideRoomLoot:
	var loot := SideRoomLoot.new()
	loot.key = VAULT_KEY
	loot.drops = [_make_geisha_drop(3)]
	return loot


func _make_key_stock() -> ScavengeDrop:
	var drop := ScavengeDrop.new()
	drop.item = VAULT_KEY
	drop.amount = 1
	return drop


func _make_geisha_drop(amount: int) -> ScavengeDrop:
	var drop := ScavengeDrop.new()
	drop.item = GEISHA_VAULT
	drop.amount = amount
	return drop


func _has_violation(violations: Array[String], part: String) -> bool:
	for violation: String in violations:
		if violation.contains(part):
			return true
	return false
