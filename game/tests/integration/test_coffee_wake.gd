# ABOUTME: Integration tests that a thrown cup wakes a sleepwalker on contact.
# ABOUTME: Pins the entity wake rules: wrong cup does not wake, right cup does.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 120


func test_cup_wakes_the_neighbor() -> void:
	var neighbor := _frozen_neighbor()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "filter", "", 10.0)
	add_child(auto_free(cup))

	var frames := 0
	while neighbor.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(neighbor.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


func test_thrown_wrong_cup_splashes_without_waking() -> void:
	var sleepwalker := _frozen_neighbor_typed_as("karen")
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "filter", "", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(sleepwalker.state).is_not_equal(Sleepwalker.State.AWAKE)
	assert_bool(is_instance_valid(cup)).is_false()


func test_wrong_cup_does_not_wake_a_special_type() -> void:
	var sleepwalker := _frozen_neighbor_typed_as("karen")
	var plain_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(sleepwalker.try_wake(plain_cup)).is_false()
	assert_int(sleepwalker.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_right_cup_wakes_a_special_type() -> void:
	var sleepwalker := _frozen_neighbor_typed_as("karen")
	var cure_cup := _brew("house", "medium", "filter", "tall_size", 85.0)
	assert_bool(sleepwalker.try_wake(cure_cup)).is_true()
	assert_int(sleepwalker.state).is_equal(Sleepwalker.State.AWAKE)
	assert_bool(sleepwalker.try_wake(cure_cup)).is_false()


func test_weak_cup_wakes_the_basic_type() -> void:
	var neighbor := _frozen_neighbor()
	var weak_cup := _brew("house", "dark", "filter", "", 10.0)
	assert_bool(neighbor.try_wake(weak_cup)).is_true()
	assert_int(neighbor.state).is_equal(Sleepwalker.State.AWAKE)


func test_perfect_cup_wakes_a_special_type_without_its_recipe() -> void:
	var sleepwalker := _frozen_neighbor_typed_as("karen")
	var perfect_plain := _brew("house", "medium", "filter", "", 99.0)
	assert_bool(sleepwalker.try_wake(perfect_plain)).is_true()
	assert_int(sleepwalker.state).is_equal(Sleepwalker.State.AWAKE)


func _frozen_neighbor() -> Sleepwalker:
	var neighbor := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	var balance := neighbor.balance.duplicate() as SleepwalkerBalance
	balance.walk_speed = 0.0
	neighbor.balance = balance
	neighbor.position = Vector2(400, 200)
	add_child(auto_free(neighbor))
	return neighbor


func _frozen_neighbor_typed_as(type_id: String) -> Sleepwalker:
	var sleepwalker := _frozen_neighbor()
	var special_type := EnemyType.new()
	special_type.type_id = type_id
	special_type.display_name = type_id
	special_type.cure = LIBRARY.find_cure(type_id)
	sleepwalker.enemy_type = special_type
	return sleepwalker


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
