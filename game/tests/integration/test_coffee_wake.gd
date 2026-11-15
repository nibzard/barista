# ABOUTME: Integration tests that a thrown cup wakes a sleepwalker on contact.
# ABOUTME: Pins the entity wake rules: wrong cup does not wake, right cup does.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TOURIST_SCENE := preload("res://scenes/enemies/tourist.tscn")
const TECH_BRO_SCENE := preload("res://scenes/enemies/tech_bro.tscn")
const GAMER_SCENE := preload("res://scenes/enemies/gamer.tscn")
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


func test_standard_cup_does_not_wake_the_tourist() -> void:
	var tourist := _frozen_tourist()
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(tourist.try_wake(standard_cup)).is_false()
	assert_int(tourist.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_frappuccino_with_whipped_cream_wakes_the_tourist() -> void:
	var tourist := _frozen_tourist()
	var frappuccino := _brew("house", "dark", "filter", "whipped_cream", 85.0)
	assert_bool(tourist.try_wake(frappuccino)).is_true()
	assert_int(tourist.state).is_equal(Sleepwalker.State.AWAKE)


func test_thrown_frappuccino_cup_wakes_the_tourist() -> void:
	var tourist := _frozen_tourist()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "dark", "filter", "whipped_cream", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while tourist.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(tourist.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


func test_standard_cup_does_not_wake_the_tech_bro() -> void:
	var tech_bro := _frozen_tech_bro()
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(tech_bro.try_wake(standard_cup)).is_false()
	assert_int(tech_bro.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_espresso_without_butter_does_not_wake_the_tech_bro() -> void:
	var tech_bro := _frozen_tech_bro()
	var plain_espresso := _brew("house", "medium", "espresso", "", 85.0)
	assert_bool(tech_bro.try_wake(plain_espresso)).is_false()
	assert_int(tech_bro.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_bulletproof_cup_wakes_the_tech_bro() -> void:
	var tech_bro := _frozen_tech_bro()
	var bulletproof := _brew("house", "medium", "espresso", "butter", 85.0)
	assert_bool(tech_bro.try_wake(bulletproof)).is_true()
	assert_int(tech_bro.state).is_equal(Sleepwalker.State.AWAKE)
	assert_bool(tech_bro.try_wake(bulletproof)).is_false()


func test_thrown_bulletproof_cup_wakes_the_tech_bro() -> void:
	var tech_bro := _frozen_tech_bro()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "espresso", "butter", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while tech_bro.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(tech_bro.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


func test_standard_cup_does_not_wake_the_gamer() -> void:
	var gamer := _frozen_gamer()
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(gamer.try_wake(standard_cup)).is_false()
	assert_int(gamer.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_plain_aeropress_does_not_wake_the_gamer() -> void:
	var gamer := _frozen_gamer()
	# The right method, but the cure needs the three shots.
	var plain_aeropress := _brew("house", "light", "aeropress", "", 85.0)
	assert_bool(gamer.try_wake(plain_aeropress)).is_false()
	assert_int(gamer.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_dark_roast_triple_aeropress_does_not_wake_the_gamer() -> void:
	var gamer := _frozen_gamer()
	# The recipe demands a light roast: most caffeine for the highest
	# synthetic caffeine level in the country.
	var dark_triple := _brew("house", "dark", "aeropress", "three_shots", 85.0)
	assert_bool(gamer.try_wake(dark_triple)).is_false()
	assert_int(gamer.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_triple_aeropress_shot_wakes_the_gamer() -> void:
	var gamer := _frozen_gamer()
	var triple_shot := _brew("house", "light", "aeropress", "three_shots", 85.0)
	assert_bool(gamer.try_wake(triple_shot)).is_true()
	assert_int(gamer.state).is_equal(Sleepwalker.State.AWAKE)
	assert_bool(gamer.try_wake(triple_shot)).is_false()


func test_thrown_triple_aeropress_cup_wakes_the_gamer() -> void:
	var gamer := _frozen_gamer()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "light", "aeropress", "three_shots", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while gamer.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(gamer.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


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


func _frozen_tourist() -> Sleepwalker:
	var tourist := TOURIST_SCENE.instantiate() as Sleepwalker
	var balance := tourist.balance.duplicate() as SleepwalkerBalance
	balance.walk_speed = 0.0
	tourist.balance = balance
	tourist.position = Vector2(400, 200)
	add_child(auto_free(tourist))
	return tourist


func _frozen_tech_bro() -> Sleepwalker:
	var tech_bro := TECH_BRO_SCENE.instantiate() as Sleepwalker
	var balance := tech_bro.balance.duplicate() as SleepwalkerBalance
	balance.walk_speed = 0.0
	tech_bro.balance = balance
	tech_bro.position = Vector2(400, 200)
	add_child(auto_free(tech_bro))
	return tech_bro


func _frozen_gamer() -> Sleepwalker:
	var gamer := GAMER_SCENE.instantiate() as Sleepwalker
	# The dash gait ignores walk_speed, so freeze the dash itself: this suite
	# pins the cure rules, test_gamer_dash.gd owns the movement.
	var dash := gamer.gamer_balance.duplicate() as GamerBalance
	dash.dash_speed = 0.0
	gamer.gamer_balance = dash
	gamer.position = Vector2(400, 200)
	add_child(auto_free(gamer))
	return gamer


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
