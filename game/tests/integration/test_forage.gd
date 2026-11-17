# ABOUTME: Integration tests for the section 6 foraging rule: sleepwalkers
# ABOUTME: eat everything they find, also the coffee plants the player plants.
extends GdUnitTestSuite

const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PLANT_SCENE := preload("res://scenes/components/coffee_plant.tscn")
const SEEDLING_ITEM := preload("res://resources/items/materials/coffee_seedling.tres")

const MAX_FRAMES_TO_WAIT := 600
# The neighbor spawns far away: no forage test wants a player spot first.
const FAR_SPAWN := Vector2(5000.0, 0.0)

var _player: Player
var _neighbor: Sleepwalker
var _eaten_count: Array[int] = [0]


func before_test() -> void:
	_eaten_count[0] = 0
	_player = auto_free(PLAYER_SCENE.instantiate()) as Player
	add_child(_player)
	_player.global_position = FAR_SPAWN
	_neighbor = auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	add_child(_neighbor)
	_neighbor.global_position = FAR_SPAWN + Vector2(200.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A plant that no walker ate is a plain child of the suite node: free it
	# here, or it outlives the case and lands in the orphan count.
	for child: Node in get_children():
		if is_instance_valid(child) and child is ForageFood:
			child.free()


func _spawn_plant(position: Vector2) -> CoffeePlant:
	var plant := auto_free(PLANT_SCENE.instantiate()) as CoffeePlant
	add_child(plant)
	plant.global_position = position
	plant.eaten.connect(func() -> void: _eaten_count[0] += 1)
	return plant


func _spawn_walker(position: Vector2) -> Sleepwalker:
	var walker := auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	add_child(walker)
	walker.global_position = position
	return walker


func _wait_for_state(walker: Sleepwalker, target: Sleepwalker.State) -> bool:
	var frames := 0
	while walker.state != target and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	return walker.state == target


func _wait_frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame


func _wait_until_freed(node: Variant) -> bool:
	# queue_free runs deferred, so the frame that eats the plant can still
	# hold a valid instance: wait the deletion out before any assert. The
	# parameter stays Variant on purpose: a typed parameter refuses an
	# already freed object at the call itself.
	var frames := 0
	while is_instance_valid(node) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	return not is_instance_valid(node)


func test_planting_spends_a_seedling_and_places_a_plant() -> void:
	_player.global_position = Vector2.ZERO
	assert_int(_player.pickup_item(SEEDLING_ITEM, 1)).is_equal(1)
	assert_bool(_player.try_action(&"plant_coffee")).is_true()
	assert_int(_player.inventory.count("coffee_seedling")).is_equal(0)

	var plants: Array[CoffeePlant] = []
	for child: Node in get_children():
		if child is CoffeePlant:
			plants.append(child as CoffeePlant)
	assert_int(plants.size()).is_equal(1)
	assert_vector(plants[0].global_position).is_equal(_player.global_position)

	# An empty bag plants nothing, and a dazzled barista plants nothing.
	assert_bool(_player.try_action(&"plant_coffee")).is_false()
	for child: Node in get_children():
		if is_instance_valid(child) and child is CoffeePlant:
			(child as CoffeePlant).free()
	_player.apply_stun(1.0)
	assert_int(_player.pickup_item(SEEDLING_ITEM, 1)).is_equal(1)
	assert_bool(_player.try_action(&"plant_coffee")).is_false()


func test_a_wandering_sleepwalker_walks_to_the_plant_and_eats_it() -> void:
	var plant := _spawn_plant(Vector2.ZERO)
	_neighbor.global_position = Vector2(60.0, 0.0)
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.FORAGE)).is_true()

	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.EATING)).is_true()

	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.WANDER)).is_true()
	assert_int(_eaten_count[0]).is_equal(1)
	assert_bool(await _wait_until_freed(plant)).is_true()
	# Raw plant caffeine wakes nobody: the walker sleeps on, section 6.
	assert_bool(_neighbor.is_awake()).is_false()

	# The distraction ends with the meal: the player gets spotted again.
	_player.global_position = _neighbor.global_position + Vector2(60.0, 0.0)
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.CHASE)).is_true()


func test_a_chasing_sleepwalker_ignores_food() -> void:
	# A calm chaser keeps its distance: the spot and the chase still run, but
	# the feet never carry it into the hug.
	var calm := _neighbor.balance.duplicate() as SleepwalkerBalance
	calm.chase_speed = 0.0
	_neighbor.balance = calm
	_player.global_position = Vector2(2000.0, 0.0)
	_neighbor.global_position = _player.global_position + Vector2(60.0, 0.0)
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.CHASE)).is_true()

	var plant := _spawn_plant(_neighbor.global_position + Vector2(30.0, 0.0))
	await _wait_frames(60)
	# The dream of the warm hug wins over food, section 6.
	assert_int(_neighbor.state).is_equal(Sleepwalker.State.CHASE)
	assert_int(_eaten_count[0]).is_equal(0)
	assert_bool(plant.is_consumed()).is_false()


func test_an_awake_sleepwalker_ignores_food() -> void:
	_neighbor.wake_up()
	var plant := _spawn_plant(_neighbor.global_position + Vector2(10.0, 0.0))
	await _wait_frames(60)
	assert_bool(_neighbor.is_awake()).is_true()
	assert_int(_eaten_count[0]).is_equal(0)
	assert_bool(plant.is_consumed()).is_false()


func test_a_staggered_sleepwalker_takes_the_food_after_the_stagger() -> void:
	var plant := _spawn_plant(Vector2.ZERO)
	_neighbor.global_position = Vector2(60.0, 0.0)
	_neighbor.stagger(0.5)
	await _wait_frames(12)
	# A body under tool control has no say: the offer stands, the meal waits.
	assert_int(_neighbor.state).is_equal(Sleepwalker.State.WANDER)

	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.FORAGE)).is_true()
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.WANDER)).is_true()
	assert_int(_eaten_count[0]).is_equal(1)
	assert_bool(await _wait_until_freed(plant)).is_true()


func test_balance_data_stands_the_foraging_rule_down() -> void:
	var plant := _spawn_plant(Vector2.ZERO)
	_neighbor.global_position = Vector2(60.0, 0.0)
	var off := plant.balance.duplicate() as ForageBalance
	off.foraging_enabled = false
	_neighbor.forage_balance = off
	await _wait_frames(120)
	assert_int(_neighbor.state).is_equal(Sleepwalker.State.WANDER)
	assert_int(_eaten_count[0]).is_equal(0)
	assert_bool(plant.is_consumed()).is_false()


func test_two_walkers_share_one_plant_and_one_meal_ends_it() -> void:
	var plant := _spawn_plant(Vector2.ZERO)
	_neighbor.global_position = Vector2(60.0, 0.0)
	var second := _spawn_walker(Vector2(-100.0, 0.0))
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.EATING)).is_true()
	assert_bool(await _wait_for_state(second, Sleepwalker.State.EATING)).is_true()

	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.WANDER)).is_true()
	assert_bool(await _wait_for_state(second, Sleepwalker.State.WANDER)).is_true()
	assert_int(_eaten_count[0]).is_equal(1)
	assert_bool(await _wait_until_freed(plant)).is_true()


func test_waking_a_sleepwalker_stops_the_meal_and_keeps_the_plant() -> void:
	var plant := _spawn_plant(Vector2.ZERO)
	_neighbor.global_position = Vector2(60.0, 0.0)
	assert_bool(await _wait_for_state(_neighbor, Sleepwalker.State.EATING)).is_true()

	_neighbor.wake_up()
	await _wait_frames(30)
	assert_bool(_neighbor.is_awake()).is_true()
	assert_int(_eaten_count[0]).is_equal(0)
	assert_bool(plant.is_consumed()).is_false()
