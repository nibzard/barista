# ABOUTME: Integration tests for the perfect-cup splash of section 15.
# ABOUTME: A perfect payload wakes every sleepwalker in a small radius.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BREWING_BALANCE := preload("res://resources/brewing/brewing_balance.tres")

const MAX_FRAMES_TO_WAIT := 120
# Negative asserts read state after the cup freed, with margin frames so a
# late splash frame cannot flip the result after the check.
const SETTLE_MARGIN_FRAMES := 5
const PERFECT_SCORE := 99.0
const GOOD_SCORE := 85.0
# The cup flies along y = 200 from x = 100. It hits the sleeper at
# (400, 200) or lands at (600, 200). The second sleeper sits under the
# splash point: 90 px stays inside the radius, 160 px stays outside.
const SPLASH_LANE_Y := 200.0
const IMPACT_X := 400.0
const LANDING_X := 600.0
const INSIDE_GAP := 90.0
const OUTSIDE_GAP := 160.0

# GdUnit reuses one suite instance for every test case, so the flag resets
# on each throw, not in the declaration.
var _cup_in_flight := false


func test_perfect_cup_splash_wakes_a_second_sleeper_in_radius() -> void:
	var hit := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y))
	var near := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y + INSIDE_GAP))
	_throw_cup_with_score(PERFECT_SCORE)
	await _await_awake(near)

	assert_float(INSIDE_GAP).is_less_equal(BREWING_BALANCE.perfect_wake_radius)
	assert_int(near.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(hit.state).is_equal(Sleepwalker.State.AWAKE)


func test_perfect_cup_splash_leaves_a_far_sleeper_asleep() -> void:
	var hit := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y))
	var far := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y + OUTSIDE_GAP))
	_throw_cup_with_score(PERFECT_SCORE)
	await _await_awake(hit)
	await _await_cup_settled()

	assert_float(OUTSIDE_GAP).is_greater(BREWING_BALANCE.perfect_wake_radius)
	assert_int(hit.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(far.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_perfect_cup_landing_splash_wakes_a_sleeper_off_the_path() -> void:
	var near_landing := _frozen_sleeper_at(
		NEIGHBOR_SCENE, Vector2(LANDING_X, SPLASH_LANE_Y + INSIDE_GAP)
	)
	_throw_cup_with_score(PERFECT_SCORE)
	await _await_awake(near_landing)
	await _await_cup_settled()

	assert_int(near_landing.state).is_equal(Sleepwalker.State.AWAKE)


func test_good_cup_has_no_splash_outside_the_direct_hit() -> void:
	var hit := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y))
	var near := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y + INSIDE_GAP))
	_throw_cup_with_score(GOOD_SCORE)
	await _await_awake(hit)
	await _await_cup_settled()

	assert_int(hit.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(near.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_perfect_splash_spares_the_tinfoil_hat_inside_the_radius() -> void:
	var hit := _frozen_sleeper_at(NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y))
	var hat := _frozen_sleeper_at(TINFOIL_MAN_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y + INSIDE_GAP))
	_throw_cup_with_score(PERFECT_SCORE)
	await _await_awake(hit)
	await _await_cup_settled()

	assert_int(hit.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(hat.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_perfect_cup_dying_on_a_hat_splashes_to_others() -> void:
	var hat := _frozen_sleeper_at(TINFOIL_MAN_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y))
	var bystander := _frozen_sleeper_at(
		NEIGHBOR_SCENE, Vector2(IMPACT_X, SPLASH_LANE_Y + INSIDE_GAP)
	)
	_throw_cup_with_score(PERFECT_SCORE)
	await _await_awake(bystander)
	await _await_cup_settled()

	assert_int(bystander.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(hat.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_cup_scene_wires_the_brewing_balance() -> void:
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	add_child(auto_free(cup))

	assert_object(cup.brewing_balance).is_not_null()


func _frozen_sleeper_at(scene: PackedScene, at: Vector2) -> Sleepwalker:
	var sleeper := scene.instantiate() as Sleepwalker
	# Freeze the wander so the splash geometry stays honest.
	var calm := sleeper.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	sleeper.balance = calm
	sleeper.position = at
	add_child(auto_free(sleeper))
	return sleeper


func _throw_cup_with_score(score: float) -> CoffeeCup:
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100.0, SPLASH_LANE_Y)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew(score)
	_cup_in_flight = true
	cup.tree_exited.connect(_on_cup_left_tree)
	add_child(auto_free(cup))
	return cup


func _on_cup_left_tree() -> void:
	# queue_free() pulls the cup from the tree at the frame end, so the flag
	# marks the death without holding the freed object.
	_cup_in_flight = false


func _brew(score: float) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("filter"),
		"",
		score
	)


func _await_awake(sleeper: Sleepwalker) -> void:
	var frames := 0
	while sleeper.state != Sleepwalker.State.AWAKE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1


func _await_cup_settled() -> void:
	var frames := 0
	while _cup_in_flight and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame
