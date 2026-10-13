# ABOUTME: Unit tests for CoffeeSupply limits and weapon costs, GAME_DESIGN sections 9, 11, 14.
# ABOUTME: Pure logic tests, no scene tree needed. Coffee is health, mana, and ammunition.
extends GdUnitTestSuite

const SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")

var _supply: CoffeeSupply


func before_test() -> void:
	_supply = CoffeeSupply.new(SUPPLY_BALANCE)


func test_starts_full_at_base_carry_limit() -> void:
	assert_int(_supply.carry_limit()).is_equal(12)
	assert_int(_supply.cups).is_equal(12)
	assert_bool(_supply.is_empty()).is_false()


func test_mobile_cafe_level_two_raises_carry_limit() -> void:
	_supply.set_mobile_cafe_level(1)
	assert_int(_supply.carry_limit()).is_equal(12)
	_supply.set_mobile_cafe_level(2)
	assert_int(_supply.carry_limit()).is_equal(20)
	_supply.set_mobile_cafe_level(3)
	assert_int(_supply.carry_limit()).is_equal(20)


func test_thermos_belt_adds_three_cups() -> void:
	_supply.equip_thermos_belt()
	assert_int(_supply.carry_limit()).is_equal(15)
	_supply.set_mobile_cafe_level(2)
	assert_int(_supply.carry_limit()).is_equal(23)


func test_add_cups_stops_at_carry_limit() -> void:
	_supply.spend_cups(12)
	var added := _supply.add_cups(99)
	assert_int(added).is_equal(12)
	assert_int(_supply.cups).is_equal(12)


func test_add_cups_returns_the_amount_that_fit() -> void:
	_supply.spend_cups(2)
	assert_int(_supply.add_cups(5)).is_equal(2)
	assert_int(_supply.cups).is_equal(12)


func test_add_cups_ignores_non_positive_amounts() -> void:
	assert_int(_supply.add_cups(0)).is_equal(0)
	assert_int(_supply.add_cups(-3)).is_equal(0)
	assert_int(_supply.cups).is_equal(12)


func test_refill_at_cafe_fills_to_limit_for_free() -> void:
	_supply.spend_cups(12)
	assert_int(_supply.refill_at_cafe()).is_equal(12)
	assert_int(_supply.cups).is_equal(12)
	assert_int(_supply.refill_at_cafe()).is_equal(0)


func test_refill_respects_raised_limits() -> void:
	_supply.equip_thermos_belt()
	_supply.set_mobile_cafe_level(2)
	_supply.spend_cups(12)
	assert_int(_supply.refill_at_cafe()).is_equal(23)
	assert_int(_supply.cups).is_equal(23)


func test_spend_cups_rejects_more_than_held() -> void:
	assert_bool(_supply.spend_cups(3)).is_true()
	assert_int(_supply.cups).is_equal(9)
	assert_bool(_supply.spend_cups(10)).is_false()
	assert_int(_supply.cups).is_equal(9)


func test_weapon_costs_come_from_balance() -> void:
	assert_int(_supply.weapon_cups_per_use(CoffeeSupply.Weapon.SUPPORT_TOOL)).is_equal(0)
	assert_int(_supply.weapon_cups_per_use(CoffeeSupply.Weapon.CUP_THROW)).is_equal(1)
	assert_int(_supply.weapon_cups_per_use(CoffeeSupply.Weapon.TRAVEL_MUG)).is_equal(0)
	assert_int(_supply.weapon_cups_per_use(CoffeeSupply.Weapon.THERMOS)).is_equal(3)
	assert_int(_supply.weapon_cups_per_use(CoffeeSupply.Weapon.MOKA_LAUNCHER)).is_equal(4)
	assert_float(_supply.weapon_cups_per_second(CoffeeSupply.Weapon.MINIGUN)).is_equal(6.0)
	for weapon: CoffeeSupply.Weapon in CoffeeSupply.Weapon.values():
		if weapon != CoffeeSupply.Weapon.MINIGUN:
			assert_float(_supply.weapon_cups_per_second(weapon)).is_equal(0.0)


func test_fire_spends_the_per_use_cost() -> void:
	assert_bool(_supply.fire(CoffeeSupply.Weapon.THERMOS)).is_true()
	assert_int(_supply.cups).is_equal(9)
	assert_bool(_supply.fire(CoffeeSupply.Weapon.MOKA_LAUNCHER)).is_true()
	assert_int(_supply.cups).is_equal(5)


func test_fire_fails_when_cups_are_short() -> void:
	_supply.spend_cups(10)
	assert_bool(_supply.fire(CoffeeSupply.Weapon.THERMOS)).is_false()
	assert_int(_supply.cups).is_equal(2)


func test_zero_cost_weapons_fire_when_empty() -> void:
	_supply.spend_cups(12)
	assert_bool(_supply.fire(CoffeeSupply.Weapon.TRAVEL_MUG)).is_true()
	assert_bool(_supply.fire(CoffeeSupply.Weapon.SUPPORT_TOOL)).is_true()
	assert_int(_supply.cups).is_equal(0)


func test_minigun_drains_six_cups_per_second() -> void:
	assert_bool(_supply.fire_continuous(CoffeeSupply.Weapon.MINIGUN, 1.0)).is_true()
	assert_int(_supply.cups).is_equal(6)


func test_minigun_accumulates_partial_seconds() -> void:
	for tick: int in range(4):
		assert_bool(_supply.fire_continuous(CoffeeSupply.Weapon.MINIGUN, 0.25)).is_true()
	# Four quarter seconds at six cups per second spend six whole cups in total.
	assert_int(_supply.cups).is_equal(6)


func test_minigun_stops_when_supply_is_dry() -> void:
	_supply.spend_cups(8)
	assert_bool(_supply.fire_continuous(CoffeeSupply.Weapon.MINIGUN, 1.0)).is_false()
	assert_int(_supply.cups).is_equal(0)
	assert_bool(_supply.fire_continuous(CoffeeSupply.Weapon.MINIGUN, 1.0)).is_false()
	assert_int(_supply.cups).is_equal(0)


func test_fire_continuous_rejects_discrete_weapons() -> void:
	assert_bool(_supply.fire_continuous(CoffeeSupply.Weapon.CUP_THROW, 1.0)).is_false()
	assert_int(_supply.cups).is_equal(12)


func test_drink_costs_the_same_cup_as_a_throw() -> void:
	# The drink-versus-throw tradeoff: both spend the same supply.
	assert_int(SUPPLY_BALANCE.drink_cost).is_equal(SUPPLY_BALANCE.cup_throw_cost)
