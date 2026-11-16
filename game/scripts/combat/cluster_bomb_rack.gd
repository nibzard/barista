# ABOUTME: ClusterBombRack counts the caffeine cluster bomb charges of section 14:
# ABOUTME: crafted from bag beans, never drawn from the coffee supply, maximum 3.
# ABOUTME: Pure logic with no nodes; the weapons task spends a charge per fired bomb.
class_name ClusterBombRack
extends RefCounted

var balance: ClusterBombBalance

var charges := 0


func _init(bomb_balance: ClusterBombBalance) -> void:
	balance = bomb_balance


func carry_max() -> int:
	return balance.max_charges


func room_left() -> int:
	return maxi(0, carry_max() - charges)


func is_full() -> bool:
	return room_left() <= 0


func has_charge() -> bool:
	return charges > 0


func add_charges(amount: int) -> int:
	# A grant from the world, like the chemist's reward, stops at the maximum.
	var added := clampi(amount, 0, room_left())
	charges += added
	return added


func spend_charge() -> bool:
	# One charge leaves the rack for one fired bomb. The coffee supply pays
	# nothing: the cluster bomb is not a cup weapon, section 14.
	if charges <= 0:
		return false
	charges -= 1
	return true


func can_craft(inventory: Inventory) -> bool:
	# One craft needs the recipe beans in the bag and room on the rack.
	if is_full():
		return false
	return inventory.count(balance.bean_item.item_id) >= balance.craft_bean_cost


func craft_from(inventory: Inventory) -> bool:
	# The craft of section 12: real beans leave the bag, and one charge joins
	# the rack. A short bag or a full rack crafts nothing and burns no beans.
	if not can_craft(inventory):
		return false
	if not inventory.remove(balance.bean_item.item_id, balance.craft_bean_cost):
		return false
	charges += 1
	return true
