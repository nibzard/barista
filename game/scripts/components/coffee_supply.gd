# ABOUTME: CoffeeSupply counts the brewed cups in hand: coffee is health, mana, and ammunition.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name CoffeeSupply
extends RefCounted

enum Weapon { SUPPORT_TOOL, CUP_THROW, TRAVEL_MUG, THERMOS, MINIGUN, MOKA_LAUNCHER }

var balance: CoffeeSupplyBalance
var cups: int
var has_thermos_belt := false
var mobile_cafe_level := 1

var _continuous_debt := 0.0


func _init(supply_balance: CoffeeSupplyBalance) -> void:
	balance = supply_balance
	cups = carry_limit()


func carry_limit() -> int:
	var limit := balance.base_carry_limit
	if mobile_cafe_level >= 2:
		limit = balance.mobile_cafe_level2_carry_limit
	if has_thermos_belt:
		limit += balance.thermos_belt_carry_bonus
	return limit


func set_mobile_cafe_level(level: int) -> void:
	mobile_cafe_level = maxi(1, level)


func equip_thermos_belt() -> void:
	has_thermos_belt = true


func add_cups(amount: int) -> int:
	var room := carry_limit() - cups
	if room <= 0:
		return 0
	var added := clampi(amount, 0, room)
	cups += added
	return added


func refill_at_cafe() -> int:
	return add_cups(carry_limit())


func spend_cups(cost: int) -> bool:
	if cups < cost:
		return false
	cups -= cost
	return true


func is_empty() -> bool:
	return cups <= 0


func weapon_cups_per_use(weapon: Weapon) -> int:
	var cost := 0
	match weapon:
		Weapon.CUP_THROW:
			cost = balance.cup_throw_cost
		Weapon.TRAVEL_MUG:
			cost = balance.travel_mug_cost
		Weapon.THERMOS:
			cost = balance.thermos_cost
		Weapon.MOKA_LAUNCHER:
			cost = balance.moka_launcher_cost
		Weapon.SUPPORT_TOOL:
			cost = balance.support_tool_cost
		Weapon.MINIGUN:
			# The minigun pays per second of fire, never per shot.
			pass
		_:
			pass
	return cost


func weapon_cups_per_second(weapon: Weapon) -> float:
	if weapon == Weapon.MINIGUN:
		return balance.minigun_cups_per_second
	return 0.0


func can_fire(weapon: Weapon) -> bool:
	if weapon_cups_per_second(weapon) > 0.0:
		return cups > 0
	return cups >= weapon_cups_per_use(weapon)


func fire(weapon: Weapon) -> bool:
	if not can_fire(weapon):
		return false
	cups -= weapon_cups_per_use(weapon)
	return true


func fire_continuous(weapon: Weapon, delta: float) -> bool:
	var rate := weapon_cups_per_second(weapon)
	if rate <= 0.0:
		return false
	_continuous_debt += rate * delta
	var payable := mini(int(_continuous_debt), cups)
	cups -= payable
	_continuous_debt -= payable
	if cups <= 0:
		_continuous_debt = 0.0
	return cups > 0
