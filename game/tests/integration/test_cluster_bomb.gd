# ABOUTME: Integration tests for the caffeine cluster bomb charge rack, section 14.
# ABOUTME: Charges are crafted from bag beans and never touch the coffee supply.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const BALANCE := preload("res://resources/balance/cluster_bomb.tres")

var _player: Player


func before_test() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(auto_free(_player))
	await get_tree().physics_frame


func _fill_bag(beans: int) -> void:
	assert_int(_player.pickup_item(HOUSE_BEANS, beans)).is_equal(beans)


func test_the_player_carries_a_rack_with_a_maximum_of_three() -> void:
	# Section 14: carry maximum 3, and the rack starts with no charges.
	assert_object(_player.cluster_bomb_balance).is_not_null()
	assert_int(_player.cluster_bombs.carry_max()).is_equal(3)
	assert_int(_player.cluster_bombs.charges).is_equal(0)


func test_crafting_through_the_player_bag_spends_beans() -> void:
	_fill_bag(BALANCE.craft_bean_cost)
	assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_true()
	assert_int(_player.cluster_bombs.charges).is_equal(1)
	assert_int(_player.inventory.count("house")).is_equal(0)


func test_crafting_never_draws_from_the_coffee_supply() -> void:
	_fill_bag(BALANCE.craft_bean_cost * 3)
	var cups_before := _player.coffee_supply.cups
	var limit_before := _player.coffee_supply.carry_limit()
	for craft: int in range(3):
		assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_true()
	assert_int(_player.cluster_bombs.charges).is_equal(3)
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)
	assert_int(_player.coffee_supply.carry_limit()).is_equal(limit_before)


func test_a_charge_fires_with_an_empty_coffee_supply() -> void:
	# Section 14: the cluster bomb is not from the supply. The rack spends
	# its own charge while the player holds zero cups.
	_fill_bag(BALANCE.craft_bean_cost)
	assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_true()
	_player.coffee_supply.spend_cups(_player.coffee_supply.cups)
	assert_int(_player.coffee_supply.cups).is_equal(0)
	assert_bool(_player.cluster_bombs.spend_charge()).is_true()
	assert_int(_player.cluster_bombs.charges).is_equal(0)
	assert_int(_player.coffee_supply.cups).is_equal(0)


func test_the_player_holds_at_most_three_charges() -> void:
	_fill_bag(BALANCE.craft_bean_cost * 5)
	for craft: int in range(3):
		assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_true()
	assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_false()
	assert_int(_player.cluster_bombs.charges).is_equal(3)
	# The fourth craft burns no beans.
	assert_int(_player.inventory.count("house")).is_equal(BALANCE.craft_bean_cost * 2)
	assert_bool(_player.cluster_bombs.spend_charge()).is_true()
	assert_bool(_player.cluster_bombs.craft_from(_player.inventory)).is_true()
	assert_int(_player.cluster_bombs.charges).is_equal(3)


func test_a_granted_reward_also_stops_at_three() -> void:
	# The chemist's reward, section 12, lands as a grant, not as a craft.
	assert_int(_player.cluster_bombs.add_charges(5)).is_equal(3)
	assert_int(_player.cluster_bombs.charges).is_equal(3)
