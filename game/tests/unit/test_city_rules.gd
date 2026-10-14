# ABOUTME: Unit tests for the section 17 city rules validator.
# ABOUTME: Pure data in, violation strings out; no scenes are loaded here.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/city.tres")


func _make_block(kind: CityBlock.Kind, density: int, pole := false) -> CityBlock:
	var block := CityBlock.new()
	block.kind = kind
	block.sleepwalker_count = density
	block.has_speaker_pole = pole
	return block


func _make_valid_city() -> CityDefinition:
	# A smallest valid city: 6 blocks, poles on the three blocks before the tower.
	var city := CityDefinition.new()
	city.city_id = "test_city"
	city.blocks = [
		_make_block(CityBlock.Kind.CAFE, 3),
		_make_block(CityBlock.Kind.QUEST, 3),
		_make_block(CityBlock.Kind.SCAVENGE, 4, true),
		_make_block(CityBlock.Kind.SCAVENGE, 4, true),
		_make_block(CityBlock.Kind.BOSS_ARENA, 4, true),
		_make_block(CityBlock.Kind.TOWER, 4),
	]
	return city


func _has_violation(violations: Array[String], part: String) -> bool:
	for violation: String in violations:
		if violation.contains(part):
			return true
	return false


func test_kind_enum_order_is_stable() -> void:
	# City .tres files pin kinds by number, so the enum order must stay fixed.
	assert_int(CityBlock.Kind.CAFE).is_equal(0)
	assert_int(CityBlock.Kind.TOWER).is_equal(1)
	assert_int(CityBlock.Kind.BOSS_ARENA).is_equal(2)
	assert_int(CityBlock.Kind.QUEST).is_equal(3)
	assert_int(CityBlock.Kind.SCAVENGE).is_equal(4)


func test_valid_city_has_no_violations() -> void:
	var violations := CityRules.validate(_make_valid_city(), BALANCE)
	assert_str(str(violations)).is_equal("[]")


func test_block_count_below_minimum_reported() -> void:
	var city := _make_valid_city()
	city.blocks.remove_at(1)
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "minimum of 6 blocks")).is_true()


func test_block_count_above_maximum_reported() -> void:
	var city := _make_valid_city()
	for _i: int in range(4):
		city.blocks.insert(1, _make_block(CityBlock.Kind.SCAVENGE, 3))
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "maximum of 9 blocks")).is_true()


func test_missing_landmark_reported() -> void:
	var city := _make_valid_city()
	city.blocks[1].kind = CityBlock.Kind.SCAVENGE
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "exactly one quest block, found 0")).is_true()


func test_duplicate_landmark_reported() -> void:
	var city := _make_valid_city()
	city.blocks[1].kind = CityBlock.Kind.CAFE
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "exactly one cafe block, found 2")).is_true()


func test_cafe_and_tower_must_hold_the_edges() -> void:
	var city := _make_valid_city()
	var first_kind := city.blocks[0].kind
	city.blocks[0].kind = city.blocks[city.blocks.size() - 1].kind
	city.blocks[city.blocks.size() - 1].kind = first_kind
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "cafe block must stand at the first edge")).is_true()
	assert_bool(_has_violation(violations, "tower block must stand at the last edge")).is_true()


func test_density_below_minimum_reported() -> void:
	var city := _make_valid_city()
	city.blocks[1].sleepwalker_count = 2
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "Block 1 must hold a minimum of 3")).is_true()


func test_density_above_maximum_reported() -> void:
	var city := _make_valid_city()
	city.blocks[1].sleepwalker_count = 5
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "Block 1 must hold a maximum of 4")).is_true()


func test_density_must_not_fall_toward_the_tower() -> void:
	var city := _make_valid_city()
	city.blocks[3].sleepwalker_count = 3
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "Block 3 density must not fall")).is_true()


func test_tower_must_hold_more_than_the_cafe() -> void:
	var city := _make_valid_city()
	for block: CityBlock in city.blocks:
		block.sleepwalker_count = 3
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "more sleepwalkers than the cafe block")).is_true()


func test_speaker_pole_count_reported() -> void:
	var city := _make_valid_city()
	city.blocks[2].has_speaker_pole = false
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "exactly 3 speaker poles, found 2")).is_true()


func test_speaker_poles_must_guard_the_last_blocks() -> void:
	var city := _make_valid_city()
	city.blocks[2].has_speaker_pole = false
	city.blocks[1].has_speaker_pole = true
	var violations := CityRules.validate(city, BALANCE)
	assert_bool(_has_violation(violations, "must guard the 3 blocks before the tower")).is_true()


func test_pole_block_indices_cover_the_blocks_before_the_tower() -> void:
	var smallest := CityRules.pole_block_indices(6, BALANCE)
	assert_int(smallest.size()).is_equal(3)
	assert_int(smallest[0]).is_equal(2)
	assert_int(smallest[2]).is_equal(4)
	var largest := CityRules.pole_block_indices(9, BALANCE)
	assert_int(largest[0]).is_equal(5)
	assert_int(largest[2]).is_equal(7)


func test_block_size_matches_the_screen_rule() -> void:
	var size := CityRules.block_size(BALANCE)
	assert_bool(absf(size.x * BALANCE.blocks_per_screen - 1280.0) < 0.01).is_true()
	assert_bool(absf(size.y - 720.0) < 0.01).is_true()
	assert_bool(absf(size.x - 1280.0 / 1.5) < 0.01).is_true()
