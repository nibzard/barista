# ABOUTME: MobileCafe is the van state: the survivors' gift and its three levels.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name MobileCafe
extends RefCounted

signal acquired
signal upgraded(level: int)

enum Level { NONE, VAN, KITCHEN, FIELD_CAFE }

var balance: MobileCafeBalance

var _level: int = Level.NONE


func _init(van_balance: MobileCafeBalance = null) -> void:
	balance = van_balance


func level() -> int:
	return _level


func is_owned() -> bool:
	return _level >= Level.VAN


func has_kitchen() -> bool:
	# Level 2: a brewing station inside. The player can brew outside the city
	# cafe, section 10.
	return _level >= Level.KITCHEN


func is_field_cafe() -> bool:
	# Level 3: tables, an awning, and a lamp. The player parks anywhere and
	# opens a small field base, section 10.
	return _level >= Level.FIELD_CAFE


func can_brew_outside_cafe() -> bool:
	return has_kitchen()


func acquire() -> bool:
	# The survivors of the first city hand the van over, section 10. The call
	# returns true only on the first ask.
	if is_owned():
		return false
	_level = Level.VAN
	acquired.emit()
	return true


func is_fully_upgraded() -> bool:
	return balance != null and _level >= balance.max_level


func next_level() -> int:
	if is_fully_upgraded():
		return _level
	return _level + 1


func next_upgrade_cost() -> int:
	if balance == null or is_fully_upgraded():
		return 0
	match next_level():
		Level.KITCHEN:
			return balance.kitchen_scrap_cost
		Level.FIELD_CAFE:
			return balance.field_cafe_scrap_cost
		_:
			return 0


func upgrade(inventory: Inventory) -> bool:
	# One upgrade step costs scrap parts from the bag, section 15. The scrap
	# leaves the bag only when the upgrade goes through.
	if not is_owned() or is_fully_upgraded():
		return false
	var cost := next_upgrade_cost()
	if cost <= 0 or balance.scrap_item == null:
		return false
	if inventory.count(balance.scrap_item.item_id) < cost:
		return false
	if not inventory.remove(balance.scrap_item.item_id, cost):
		return false
	_level = next_level()
	upgraded.emit(_level)
	return true


func apply_supply_level(supply: CoffeeSupply) -> void:
	# Section 14: mobile cafe level 2 raises the carry limit to 20. The supply
	# reads the level; the van owns the level.
	supply.set_mobile_cafe_level(_level)


func save_state() -> int:
	# The save system stores the van level as one plain number, section 18.
	return _level


func load_state(saved_level: int) -> void:
	# A loaded van never replays the gift or an upgrade beat.
	var ceiling := balance.max_level if balance != null else Level.FIELD_CAFE
	_level = clampi(saved_level, Level.NONE, ceiling)
