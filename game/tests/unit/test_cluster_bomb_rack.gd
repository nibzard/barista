# ABOUTME: Unit tests for ClusterBombRack: crafted charges, carry maximum 3.
# ABOUTME: Pure logic tests, no scene tree. Section 14: not from the supply.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/cluster_bomb.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const GOLDEN_COAST_ARABICA := preload("res://resources/items/beans/golden_coast_arabica.tres")
const FUSE := preload("res://resources/items/materials/fuse.tres")


func _rack() -> ClusterBombRack:
	return ClusterBombRack.new(BALANCE)


func _bag_with(beans: int) -> Inventory:
	var inventory := Inventory.new()
	inventory.add(HOUSE_BEANS, beans)
	return inventory


func test_the_balance_pins_the_section_14_numbers() -> void:
	assert_bool(BALANCE is ClusterBombBalance).is_true()
	# Section 14: carry maximum 3.
	assert_int(BALANCE.max_charges).is_equal(3)
	assert_object(BALANCE.bean_item).is_not_null()
	assert_str(BALANCE.bean_item.item_id).is_equal("house")
	# A working prototype number: one charge costs more than one bean.
	assert_int(BALANCE.craft_bean_cost).is_equal(4)


func test_a_fresh_rack_starts_empty() -> void:
	var rack := _rack()
	assert_int(rack.charges).is_equal(0)
	assert_int(rack.carry_max()).is_equal(3)
	assert_int(rack.room_left()).is_equal(3)
	assert_bool(rack.has_charge()).is_false()
	assert_bool(rack.is_full()).is_false()


func test_add_charges_stops_at_the_carry_maximum() -> void:
	var rack := _rack()
	assert_int(rack.add_charges(2)).is_equal(2)
	assert_int(rack.charges).is_equal(2)
	assert_int(rack.add_charges(5)).is_equal(1)
	assert_int(rack.charges).is_equal(3)
	assert_bool(rack.is_full()).is_true()
	assert_int(rack.room_left()).is_equal(0)


func test_add_charges_ignores_non_positive_amounts() -> void:
	var rack := _rack()
	assert_int(rack.add_charges(0)).is_equal(0)
	assert_int(rack.add_charges(-2)).is_equal(0)
	assert_int(rack.charges).is_equal(0)


func test_a_full_rack_grants_nothing() -> void:
	var rack := _rack()
	rack.add_charges(3)
	assert_int(rack.add_charges(1)).is_equal(0)
	assert_int(rack.charges).is_equal(3)


func test_spend_charge_counts_down_to_empty() -> void:
	var rack := _rack()
	rack.add_charges(2)
	assert_bool(rack.spend_charge()).is_true()
	assert_int(rack.charges).is_equal(1)
	assert_bool(rack.spend_charge()).is_true()
	assert_int(rack.charges).is_equal(0)
	assert_bool(rack.has_charge()).is_false()
	assert_bool(rack.spend_charge()).is_false()
	assert_int(rack.charges).is_equal(0)


func test_spending_never_dips_below_zero() -> void:
	var rack := _rack()
	assert_bool(rack.spend_charge()).is_false()
	assert_int(rack.charges).is_equal(0)


func test_craft_from_converts_bag_beans_into_one_charge() -> void:
	var rack := _rack()
	var bag := _bag_with(BALANCE.craft_bean_cost + 1)
	assert_bool(rack.can_craft(bag)).is_true()
	assert_bool(rack.craft_from(bag)).is_true()
	assert_int(rack.charges).is_equal(1)
	assert_int(bag.count("house")).is_equal(1)


func test_a_craft_needs_the_full_bean_cost() -> void:
	var rack := _rack()
	var bag := _bag_with(BALANCE.craft_bean_cost - 1)
	assert_bool(rack.can_craft(bag)).is_false()
	assert_bool(rack.craft_from(bag)).is_false()
	assert_int(rack.charges).is_equal(0)
	# A failed craft leaves the short bag untouched.
	assert_int(bag.count("house")).is_equal(BALANCE.craft_bean_cost - 1)


func test_a_craft_needs_room_on_the_rack() -> void:
	var rack := _rack()
	rack.add_charges(3)
	var bag := _bag_with(99)
	assert_bool(rack.can_craft(bag)).is_false()
	assert_bool(rack.craft_from(bag)).is_false()
	# A full rack burns no beans.
	assert_int(rack.charges).is_equal(3)
	assert_int(bag.count("house")).is_equal(99)


func test_crafting_stops_when_the_bag_runs_dry() -> void:
	var rack := _rack()
	var bag := _bag_with(BALANCE.craft_bean_cost * 2)
	assert_bool(rack.craft_from(bag)).is_true()
	assert_bool(rack.craft_from(bag)).is_true()
	assert_bool(rack.craft_from(bag)).is_false()
	assert_int(rack.charges).is_equal(2)
	assert_int(bag.count("house")).is_equal(0)
	assert_bool(rack.has_charge()).is_true()


func test_only_the_recipe_bean_pays_for_a_charge() -> void:
	# The recipe reads one bean type; other beans and materials stay in the bag.
	var rack := _rack()
	var bag := Inventory.new()
	# The fuse stacks at 9; both amounts sit inside their stack limits.
	bag.add(GOLDEN_COAST_ARABICA, 8)
	bag.add(FUSE, 9)
	assert_bool(rack.can_craft(bag)).is_false()
	assert_bool(rack.craft_from(bag)).is_false()
	assert_int(rack.charges).is_equal(0)
	assert_int(bag.count("golden_coast_arabica")).is_equal(8)
	assert_int(bag.count("fuse")).is_equal(9)


func test_the_rack_has_no_cup_state_of_its_own() -> void:
	# Section 14: the charge counter is not a second coffee pool. It holds a
	# plain charge count and reads its rule values from the balance resource.
	var rack := _rack()
	rack.add_charges(3)
	assert_int(rack.charges).is_equal(rack.carry_max())
	assert_bool(rack is RefCounted).is_true()
