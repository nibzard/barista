# ABOUTME: Unit tests for the cure weapon data and the CureArmory of section 11.
# ABOUTME: Pins the section 14 costs, the weapon areas, the route finds, and the
# ABOUTME: French Press pump state.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/cure_weapons.tres")
const SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")
const ITEM_CATALOG := preload("res://resources/items/catalog.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

# Section 11, the route order: San Coffesco hands over the mug and the thermos,
# Steamtle the press and the launcher, Pourtland the minigun and the turret.
const ROUTE_FINDS := {
	"san_coffesco": ["travel_mug", "thermos"],
	"steamtle": ["french_press", "moka_launcher"],
	"pourtland": ["coffee_minigun", "auto_drip_turret"],
}


func test_balance_pins_the_section_14_weapon_costs() -> void:
	assert_bool(BALANCE is CureWeaponsBalance).is_true()
	assert_int(SUPPLY_BALANCE.travel_mug_cost).is_equal(0)
	assert_int(SUPPLY_BALANCE.thermos_cost).is_equal(3)
	assert_int(SUPPLY_BALANCE.moka_launcher_cost).is_equal(4)
	assert_float(SUPPLY_BALANCE.minigun_cups_per_second).is_equal(6.0)
	# Working values for the two weapons section 14 leaves open: the press
	# pays a short cone, the turret pays its whole tank at deploy.
	assert_int(SUPPLY_BALANCE.french_press_cost).is_equal(2)
	assert_int(SUPPLY_BALANCE.auto_drip_turret_cost).is_equal(4)


func test_balance_pins_the_weapon_areas() -> void:
	# The thermos splashes wide and the moka pot large, section 11, and both
	# outrange the perfect-cup splash of section 15.
	assert_float(BALANCE.thermos_splash_radius).is_equal(150.0)
	assert_float(BALANCE.moka_splash_radius).is_equal(190.0)
	assert_float(BALANCE.thermos_splash_radius).is_greater(100.0)
	assert_float(BALANCE.moka_splash_radius).is_greater(BALANCE.thermos_splash_radius)
	assert_float(BALANCE.french_press_reach).is_equal(90.0)
	assert_float(BALANCE.french_press_half_angle_degrees).is_equal(45.0)
	assert_float(BALANCE.minigun_range).is_equal(260.0)
	assert_float(BALANCE.minigun_half_angle_degrees).is_equal(12.0)
	assert_float(BALANCE.turret_drip_radius).is_equal(120.0)


func test_balance_pins_the_weapon_clocks() -> void:
	# The mug flies faster than the cup, the moka pot slower on its high arc,
	# and the turret drips on a slow cadence until the tank runs dry.
	assert_float(BALANCE.travel_mug_flight_time_seconds).is_equal(0.6)
	assert_float(BALANCE.travel_mug_bounce_seek_radius).is_equal(260.0)
	assert_float(BALANCE.travel_mug_return_speed).is_equal(520.0)
	assert_float(BALANCE.moka_flight_time_seconds).is_equal(1.2)
	assert_float(BALANCE.moka_arc_peak_height).is_equal(150.0)
	assert_float(BALANCE.turret_drip_interval_seconds).is_equal(1.0)
	assert_float(BALANCE.turret_tank_seconds).is_equal(8.0)


func test_armory_starts_empty() -> void:
	var armory := CureArmory.new()

	assert_bool(armory.has_any()).is_false()
	assert_int(armory.equipped_weapon()).is_equal(CureArmory.NO_WEAPON)
	assert_str(TouchControls.weapon_name_for(armory.equipped_weapon())).is_equal("")
	assert_bool(armory.cycle()).is_false()
	assert_bool(armory.equip(CureArmory.Weapon.THERMOS)).is_false()


func test_the_first_found_weapon_equips_itself() -> void:
	var armory := CureArmory.new()

	armory.unlock(CureArmory.Weapon.THERMOS)

	assert_bool(armory.has_any()).is_true()
	assert_bool(armory.is_found(CureArmory.Weapon.THERMOS)).is_true()
	assert_int(armory.equipped_weapon()).is_equal(CureArmory.Weapon.THERMOS)
	assert_str(TouchControls.weapon_name_for(armory.equipped_weapon())).is_equal("Thermos")


func test_the_cycle_wraps_through_the_found_weapons_only() -> void:
	var armory := CureArmory.new()
	armory.unlock(CureArmory.Weapon.TRAVEL_MUG)
	armory.unlock(CureArmory.Weapon.MOKA_LAUNCHER)
	armory.equip(CureArmory.Weapon.TRAVEL_MUG)

	assert_bool(armory.cycle()).is_true()
	assert_int(armory.equipped_weapon()).is_equal(CureArmory.Weapon.MOKA_LAUNCHER)
	assert_str(TouchControls.weapon_name_for(armory.equipped_weapon())).is_equal("Moka Launcher")
	assert_bool(armory.cycle()).is_true()
	assert_int(armory.equipped_weapon()).is_equal(CureArmory.Weapon.TRAVEL_MUG)
	assert_str(TouchControls.weapon_name_for(armory.equipped_weapon())).is_equal("Travel Mug")


func test_the_unlock_all_hands_the_whole_armory_over() -> void:
	var armory := CureArmory.new()

	armory.unlock_all()

	for weapon: CureArmory.Weapon in CureArmory.CYCLE_ORDER:
		assert_bool(armory.is_found(weapon)).is_true()
	assert_int(armory.found_weapons().size()).is_equal(6)


func test_the_french_press_loads_on_one_pump_and_clears_on_the_next() -> void:
	var armory := CureArmory.new()

	assert_bool(armory.is_press_loaded()).is_false()
	armory.load_press()
	assert_bool(armory.is_press_loaded()).is_true()
	armory.consume_press_load()
	assert_bool(armory.is_press_loaded()).is_false()


func test_a_weapon_gear_item_unlocks_its_weapon() -> void:
	var armory := CureArmory.new()

	assert_bool(armory.grant_item("thermos")).is_true()
	assert_bool(armory.is_found(CureArmory.Weapon.THERMOS)).is_true()
	assert_int(armory.weapon_for_item("thermos")).is_equal(CureArmory.Weapon.THERMOS)
	# Gear that carries no weapon changes nothing.
	assert_bool(armory.grant_item("thermos_belt")).is_false()
	assert_int(armory.weapon_for_item("fuse")).is_equal(CureArmory.NO_WEAPON)
	assert_bool(armory.is_found(CureArmory.Weapon.TRAVEL_MUG)).is_false()


func test_a_loaded_bag_restocks_the_armory() -> void:
	# Section 18: the weapons ride the bag as gear, so a save or a move east
	# rebuilds the found set from the loaded bag.
	var armory := CureArmory.new()
	var bag := Inventory.new()
	bag.add(ITEM_CATALOG.find_item("travel_mug"), 1)
	bag.add(ITEM_CATALOG.find_item("coffee_minigun"), 1)
	bag.add(ITEM_CATALOG.find_item("fuse"), 3)

	armory.sync_found_from_inventory(bag)

	assert_bool(armory.is_found(CureArmory.Weapon.TRAVEL_MUG)).is_true()
	assert_bool(armory.is_found(CureArmory.Weapon.MINIGUN)).is_true()
	assert_bool(armory.is_found(CureArmory.Weapon.THERMOS)).is_false()


func test_every_weapon_gear_item_resolves_through_the_catalog() -> void:
	# The save resolves bag ids through the catalog, so a weapon that misses
	# from it would vanish on reload. The interface name of a weapon is the
	# display name of its gear item, so the readout and the bag row agree.
	for weapon: CureArmory.Weapon in CureArmory.CYCLE_ORDER:
		var item: ItemType = ITEM_CATALOG.find_item(CureArmory.ITEM_IDS[weapon])
		assert_object(item).is_not_null()
		assert_int(item.max_stack).is_equal(1)
		assert_int(item.category).is_equal(ItemType.Category.GEAR)
		assert_str(CureArmory.WEAPON_NAMES[weapon]).is_equal(item.display_name)


func test_every_weapon_waits_exactly_once_along_the_route() -> void:
	# Section 11: the player finds the cure weapons along the route. Every
	# weapon of the armory waits as a find in one city, and no city hands the
	# same weapon over twice.
	var found_cities: Dictionary = {}
	for city: CityDefinition in [SAN_COFFESCO, STEAMTLE, POURTLAND]:
		var expected: Array = ROUTE_FINDS[city.city_id]
		var weapon_finds: Array[String] = []
		for block: CityBlock in city.blocks:
			for drop: ScavengeDrop in block.finds:
				if CureArmory.weapon_for_item(drop.item.item_id) != CureArmory.NO_WEAPON:
					weapon_finds.append(drop.item.item_id)
		assert_int(weapon_finds.size()).override_failure_message(city.city_id).is_equal(
			expected.size()
		)
		for item_id: String in weapon_finds:
			assert_bool(expected.has(item_id)).is_true()
			assert_bool(found_cities.has(item_id)).is_false()
			found_cities[item_id] = city.city_id
	assert_int(found_cities.size()).is_equal(6)


func test_the_route_hands_the_weapons_over_in_the_power_order() -> void:
	# The early cities arm the player gently: the free reusable mug and the
	# wide thermos in San Coffesco, the cone and the arc in Steamtle, the
	# heavy stream and the autonomous tower in Pourtland.
	assert_str(_city_weapon_finds(SAN_COFFESCO)[0]).is_equal("travel_mug")
	assert_str(_city_weapon_finds(SAN_COFFESCO)[1]).is_equal("thermos")
	assert_str(_city_weapon_finds(STEAMTLE)[0]).is_equal("french_press")
	assert_str(_city_weapon_finds(STEAMTLE)[1]).is_equal("moka_launcher")
	assert_str(_city_weapon_finds(POURTLAND)[0]).is_equal("coffee_minigun")
	assert_str(_city_weapon_finds(POURTLAND)[1]).is_equal("auto_drip_turret")


func _city_weapon_finds(city: CityDefinition) -> Array[String]:
	var weapon_finds: Array[String] = []
	for block: CityBlock in city.blocks:
		for drop: ScavengeDrop in block.finds:
			if CureArmory.weapon_for_item(drop.item.item_id) != CureArmory.NO_WEAPON:
				weapon_finds.append(drop.item.item_id)
	return weapon_finds
