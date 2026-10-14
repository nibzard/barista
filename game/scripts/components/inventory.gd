# ABOUTME: Inventory is the player bag: beans, gear, materials, and appliances.
# ABOUTME: Pure logic with no nodes; brewed cups stay in CoffeeSupply, their own limited pool.
class_name Inventory
extends RefCounted

var _counts: Dictionary = {}
var _types: Dictionary = {}


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
	_types[item.item_id] = item
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
		_types.erase(item_id)
	else:
		_counts[item_id] = current - amount
	return true


func count(item_id: String) -> int:
	return int(_counts.get(item_id, 0))


func has_item(item_id: String) -> bool:
	return count(item_id) > 0


func held_items() -> Array[ItemType]:
	# One ItemType per held stack, in a stable display order: category, then id.
	# The HUD reads this to draw the bag; it never walks the item catalog itself.
	var items: Array[ItemType] = []
	for item_id: String in _counts:
		var item := _types[item_id] as ItemType
		if item != null:
			items.append(item)
	items.sort_custom(_compare_for_display)
	return items


func _compare_for_display(a: ItemType, b: ItemType) -> bool:
	if a.category != b.category:
		return a.category < b.category
	return a.item_id < b.item_id
