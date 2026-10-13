# ABOUTME: Inventory is the player bag: beans, gear, materials, and appliances.
# ABOUTME: Pure logic with no nodes; brewed cups stay in CoffeeSupply, their own limited pool.
class_name Inventory
extends RefCounted

var _counts: Dictionary = {}


func add(item: ItemType, amount: int) -> int:
	# Adds up to the item stack limit and reports how many units went in.
	if amount <= 0:
		return 0
	var current := count(item.item_id)
	var room := item.max_stack - current
	if room <= 0:
		return 0
	var added: int = mini(amount, room)
	_counts[item.item_id] = current + added
	return added


func remove(item_id: String, amount: int) -> bool:
	# Spends units of one item; the call fails when the bag holds less than asked.
	if amount <= 0:
		return false
	var current := count(item_id)
	if current < amount:
		return false
	if current == amount:
		_counts.erase(item_id)
	else:
		_counts[item_id] = current - amount
	return true


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has_item(item_id: String) -> bool:
	return count(item_id) > 0
