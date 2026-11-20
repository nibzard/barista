# ABOUTME: CureArmory owns the cure weapons of section 11: the found set, the
# ABOUTME: equipped slot, and the pump state of the French Press.
# ABOUTME: Pure logic with no nodes; the player pays the supply and serves the world.
class_name CureArmory
extends RefCounted

enum Weapon { TRAVEL_MUG, THERMOS, FRENCH_PRESS, MOKA_LAUNCHER, MINIGUN, AUTO_DRIP_TURRET }

# The slot value when no weapon is equipped. Weapons are ints, so -1 works.
const NO_WEAPON := -1

# The canonical cycle order, section 11: the order of the enum itself.
const CYCLE_ORDER: Array[Weapon] = [
	Weapon.TRAVEL_MUG,
	Weapon.THERMOS,
	Weapon.FRENCH_PRESS,
	Weapon.MOKA_LAUNCHER,
	Weapon.MINIGUN,
	Weapon.AUTO_DRIP_TURRET,
]

# The gear item id that unlocks each weapon, section 15: the player finds the
# weapons along the route, so every weapon rides a gear item in the bag and the
# save holds it with the rest of the gear, section 18.
const ITEM_IDS: Dictionary = {
	Weapon.TRAVEL_MUG: "travel_mug",
	Weapon.THERMOS: "thermos",
	Weapon.FRENCH_PRESS: "french_press",
	Weapon.MOKA_LAUNCHER: "moka_launcher",
	Weapon.MINIGUN: "coffee_minigun",
	Weapon.AUTO_DRIP_TURRET: "auto_drip_turret",
}

# The chalk name each weapon wears on the interface: the display name of the
# gear item that carries it, so the readout and the bag row always agree.
const WEAPON_NAMES: Dictionary = {
	Weapon.TRAVEL_MUG: "Travel Mug",
	Weapon.THERMOS: "Thermos",
	Weapon.FRENCH_PRESS: "French Press",
	Weapon.MOKA_LAUNCHER: "Moka Launcher",
	Weapon.MINIGUN: "Coffee Minigun",
	Weapon.AUTO_DRIP_TURRET: "Auto-Drip Turret",
}

var _found: Array[Weapon] = []
var _equipped := NO_WEAPON
var _press_loaded := false


func unlock(weapon: Weapon) -> void:
	# A found weapon joins the armory in canonical cycle order. The first find
	# equips itself, so the armory is ready the moment it stops being empty.
	if _found.has(weapon):
		return
	_found.append(weapon)
	_found.sort_custom(
		func(a: Weapon, b: Weapon) -> bool: return CYCLE_ORDER.find(a) < CYCLE_ORDER.find(b)
	)
	if _equipped == NO_WEAPON:
		_equipped = weapon


func unlock_all() -> void:
	# The development room hands the whole armory over for play and tests.
	for weapon: Weapon in CYCLE_ORDER:
		unlock(weapon)


func is_found(weapon: Weapon) -> bool:
	return _found.has(weapon)


func found_weapons() -> Array[Weapon]:
	return _found.duplicate()


func has_any() -> bool:
	return not _found.is_empty()


func equipped_weapon() -> int:
	return _equipped


func equip(weapon: Weapon) -> bool:
	# Only a found weapon can ride in the slot.
	if not _found.has(weapon):
		return false
	_equipped = weapon
	return true


func cycle() -> bool:
	# The swap: the next found weapon in the canonical order, wrapping around.
	# An empty armory swaps nothing.
	if _found.is_empty():
		return false
	var current := _found.find(_equipped as Weapon)
	var next_index := (current + 1) % _found.size()
	if next_index < 0:
		next_index += _found.size()
	_equipped = _found[next_index]
	return true


static func weapon_for_item(item_id: String) -> int:
	# The gear item of a weapon names it. Unknown gear carries no weapon.
	for weapon: Weapon in CYCLE_ORDER:
		if ITEM_IDS[weapon] == item_id:
			return weapon
	return NO_WEAPON


func grant_item(item_id: String) -> bool:
	# A picked-up gear item unlocks its weapon. Gear that carries no weapon
	# changes nothing.
	var weapon := weapon_for_item(item_id)
	if weapon == NO_WEAPON:
		return false
	unlock(weapon)
	return true


func sync_found_from_inventory(inventory: Inventory) -> void:
	# A loaded bag restocks the armory, section 18: the save and the move east
	# carry the weapons as bag gear, so every weapon item in the bag unlocks
	# its weapon again.
	for weapon: Weapon in CYCLE_ORDER:
		var item_id := ITEM_IDS[weapon] as String
		if inventory.has_item(item_id):
			unlock(weapon)


func is_press_loaded() -> bool:
	# The French Press holds its load until the next press fires it.
	return _press_loaded


func load_press() -> void:
	# One pump loads the chamber, section 11: the next press shoots the cone.
	_press_loaded = true


func consume_press_load() -> void:
	_press_loaded = false
