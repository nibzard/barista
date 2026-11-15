# ABOUTME: Unit tests for the mobile cafe: three levels, scrap costs, brew rule.
# ABOUTME: Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite

const VAN_BALANCE := preload("res://resources/balance/mobile_cafe.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")


func _make_van() -> MobileCafe:
	return MobileCafe.new(VAN_BALANCE)


func _make_inventory(scrap: int) -> Inventory:
	var inventory := Inventory.new()
	inventory.add(SCRAP_PART, scrap)
	return inventory


func test_a_new_game_has_no_van() -> void:
	var van := _make_van()
	assert_int(van.level()).is_equal(MobileCafe.Level.NONE)
	assert_bool(van.is_owned()).is_false()
	assert_bool(van.has_kitchen()).is_false()
	assert_bool(van.is_field_cafe()).is_false()
	assert_bool(van.can_brew_outside_cafe()).is_false()


func test_the_survivors_give_the_van_once() -> void:
	var van := _make_van()
	var gifts: Array[int] = []
	van.acquired.connect(func() -> void: gifts.append(1))

	assert_bool(van.acquire()).is_true()
	assert_int(van.level()).is_equal(MobileCafe.Level.VAN)
	assert_bool(van.is_owned()).is_true()
	assert_int(gifts.size()).is_equal(1)

	assert_bool(van.acquire()).is_false()
	assert_int(van.level()).is_equal(MobileCafe.Level.VAN)
	assert_int(gifts.size()).is_equal(1)


func test_no_upgrade_happens_before_the_gift() -> void:
	var van := _make_van()
	var inventory := _make_inventory(99)
	assert_bool(van.upgrade(inventory)).is_false()
	assert_int(van.level()).is_equal(MobileCafe.Level.NONE)
	assert_int(inventory.count("scrap_part")).is_equal(99)


func test_the_upgrade_path_steps_through_the_three_levels() -> void:
	var van := _make_van()
	van.acquire()
	var upgrade_levels: Array[int] = []
	van.upgraded.connect(func(level: int) -> void: upgrade_levels.append(level))

	assert_bool(van.upgrade(_make_inventory(99))).is_true()
	assert_int(van.level()).is_equal(MobileCafe.Level.KITCHEN)
	assert_bool(van.upgrade(_make_inventory(99))).is_true()
	assert_int(van.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	assert_bool(van.is_fully_upgraded()).is_true()

	assert_bool(van.upgrade(_make_inventory(99))).is_false()
	assert_int(van.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	assert_int(upgrade_levels.size()).is_equal(2)
	assert_int(upgrade_levels[0]).is_equal(MobileCafe.Level.KITCHEN)
	assert_int(upgrade_levels[1]).is_equal(MobileCafe.Level.FIELD_CAFE)


func test_upgrades_never_skip_a_level() -> void:
	var van := _make_van()
	van.acquire()
	van.upgrade(_make_inventory(99))
	assert_int(van.level()).is_equal(MobileCafe.Level.KITCHEN)
	assert_bool(van.is_field_cafe()).is_false()


func test_the_kitchen_costs_scrap_parts_from_the_bag() -> void:
	var van := _make_van()
	van.acquire()
	var inventory := _make_inventory(VAN_BALANCE.kitchen_scrap_cost)

	assert_bool(van.upgrade(inventory)).is_true()
	assert_int(inventory.count("scrap_part")).is_equal(0)


func test_the_field_cafe_costs_its_own_scrap_parts() -> void:
	var van := _make_van()
	van.acquire()
	van.upgrade(_make_inventory(VAN_BALANCE.kitchen_scrap_cost))
	assert_int(van.next_upgrade_cost()).is_equal(VAN_BALANCE.field_cafe_scrap_cost)

	var inventory := _make_inventory(VAN_BALANCE.field_cafe_scrap_cost)
	assert_bool(van.upgrade(inventory)).is_true()
	assert_int(inventory.count("scrap_part")).is_equal(0)
	assert_int(van.next_upgrade_cost()).is_equal(0)


func test_an_upgrade_without_enough_scrap_fails_and_keeps_the_bag() -> void:
	var van := _make_van()
	van.acquire()
	var inventory := _make_inventory(VAN_BALANCE.kitchen_scrap_cost - 1)

	assert_bool(van.upgrade(inventory)).is_false()
	assert_int(van.level()).is_equal(MobileCafe.Level.VAN)
	assert_int(inventory.count("scrap_part")).is_equal(VAN_BALANCE.kitchen_scrap_cost - 1)


func test_next_upgrade_cost_reports_the_scrap_need() -> void:
	var van := _make_van()
	assert_int(van.next_upgrade_cost()).is_equal(0)
	van.acquire()
	assert_int(van.next_upgrade_cost()).is_equal(VAN_BALANCE.kitchen_scrap_cost)
	van.upgrade(_make_inventory(99))
	assert_int(van.next_upgrade_cost()).is_equal(VAN_BALANCE.field_cafe_scrap_cost)
	van.upgrade(_make_inventory(99))
	assert_int(van.next_upgrade_cost()).is_equal(0)


func test_the_gift_alone_does_not_brew_outside_the_cafe() -> void:
	var van := _make_van()
	van.acquire()
	assert_bool(van.has_kitchen()).is_false()
	assert_bool(van.can_brew_outside_cafe()).is_false()


func test_the_kitchen_opens_brewing_outside_the_cafe() -> void:
	var van := _make_van()
	van.acquire()
	van.upgrade(_make_inventory(99))
	assert_bool(van.has_kitchen()).is_true()
	assert_bool(van.can_brew_outside_cafe()).is_true()

	var field_van := _make_van()
	field_van.acquire()
	field_van.upgrade(_make_inventory(99))
	field_van.upgrade(_make_inventory(99))
	assert_bool(field_van.is_field_cafe()).is_true()
	assert_bool(field_van.can_brew_outside_cafe()).is_true()


func test_the_supply_carry_limit_follows_the_van_level() -> void:
	var van := _make_van()
	var supply := CoffeeSupply.new(SUPPLY_BALANCE)
	assert_int(supply.carry_limit()).is_equal(12)

	van.acquire()
	van.apply_supply_level(supply)
	assert_int(supply.carry_limit()).is_equal(12)

	van.upgrade(_make_inventory(99))
	van.apply_supply_level(supply)
	assert_int(supply.carry_limit()).is_equal(20)

	van.upgrade(_make_inventory(99))
	van.apply_supply_level(supply)
	assert_int(supply.carry_limit()).is_equal(20)


func test_a_level_two_van_fills_to_twenty_at_the_cafe() -> void:
	var van := _make_van()
	van.acquire()
	van.upgrade(_make_inventory(99))
	var supply := CoffeeSupply.new(SUPPLY_BALANCE)
	van.apply_supply_level(supply)

	supply.spend_cups(supply.cups)
	assert_int(supply.refill_at_cafe()).is_equal(20)
	assert_int(supply.cups).is_equal(20)


func test_save_round_trip_carries_the_van_level() -> void:
	var van := _make_van()
	van.acquire()
	van.upgrade(_make_inventory(99))
	var saved: int = van.save_state()

	var loaded := _make_van()
	var upgrade_signals: Array[int] = []
	loaded.upgraded.connect(func(_level: int) -> void: upgrade_signals.append(1))
	loaded.load_state(saved)

	assert_int(loaded.level()).is_equal(MobileCafe.Level.KITCHEN)
	assert_bool(loaded.is_owned()).is_true()
	assert_bool(loaded.has_kitchen()).is_true()
	assert_bool(loaded.is_field_cafe()).is_false()
	assert_int(upgrade_signals.size()).is_equal(0)


func test_load_clamps_impossible_levels() -> void:
	var low := _make_van()
	low.load_state(-3)
	assert_int(low.level()).is_equal(MobileCafe.Level.NONE)
	assert_bool(low.is_owned()).is_false()

	var high := _make_van()
	high.load_state(9)
	assert_int(high.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	assert_bool(high.is_fully_upgraded()).is_true()
