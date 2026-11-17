# ABOUTME: Integration tests for the environment rule of thrown cups.
# ABOUTME: A wall stops the cup, so no coffee wakes a sleeper through geometry.
extends GdUnitTestSuite

const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 120
# Negative asserts read state after the cup freed, with margin frames so a
# late splash frame cannot flip the result after the check.
const SETTLE_MARGIN_FRAMES := 5
const STANDARD_SCORE := 85.0
const PERFECT_SCORE := 99.0
# Every throw flies east along y = 200 from x = 100.
const LANE_Y := 200.0
const START_X := 100.0
# A wall like the cafe walls: 40 px thick, centered on x = 320. The west face
# stands at x = 300 between the throw start and every sleeper behind.
const WALL_CENTER_X := 320.0
const WALL_THICKNESS := 40.0
const WALL_WEST_FACE := WALL_CENTER_X - WALL_THICKNESS * 0.5
# The perfect splash radius is 100 px. The behind sleeper sits inside that
# radius of the burst point but behind the wall; the beside sleeper sits the
# same distance in front of the wall, in open space.
const BEHIND_X := 370.0
const BESIDE_POSITION := Vector2(240.0, 270.0)

# GdUnit reuses one suite instance for every test case, so the flag resets
# on each throw, not in the declaration.
var _cup_in_flight := false


func test_cup_breaks_on_the_wall_before_a_sleeper_behind_it() -> void:
	_vertical_wall_at(WALL_CENTER_X)
	var sleeper := _frozen_sleeper_at(Vector2(450.0, LANE_Y))
	var cup := _throw_cup_to(Vector2(500.0, LANE_Y), _standard_cup())

	var furthest_x := START_X
	var frames := 0
	while _cup_in_flight and frames < MAX_FRAMES_TO_WAIT:
		if is_instance_valid(cup):
			furthest_x = maxf(furthest_x, cup.global_position.x)
		await get_tree().physics_frame
		frames += 1
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(_cup_in_flight).is_false()
	assert_float(furthest_x).is_less(WALL_CENTER_X + WALL_THICKNESS * 0.5)
	assert_int(sleeper.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_wall_splash_wakes_the_beside_sleeper_not_the_one_behind() -> void:
	_vertical_wall_at(WALL_CENTER_X)
	var beside := _frozen_sleeper_at(BESIDE_POSITION)
	var behind := _frozen_sleeper_at(Vector2(BEHIND_X, LANE_Y))
	_throw_cup_to(Vector2(500.0, LANE_Y), _perfect_cup())
	await _await_awake(beside)
	await _await_cup_settled()

	assert_int(beside.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(behind.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_aim_cone_skips_the_sleeper_behind_the_wall() -> void:
	var player := _player_at(Vector2(START_X, LANE_Y))
	_vertical_wall_at(WALL_CENTER_X)
	var sleeper := _frozen_sleeper_at(Vector2(450.0, LANE_Y))

	var cup := player.throw_cup(Vector2.RIGHT)
	assert_object(cup).is_not_null()
	# Nothing snaps through the wall: the cup flies to full range instead.
	assert_vector(cup.landing).is_equal_approx(Vector2(622.0, 190.0), Vector2(0.5, 0.5))

	await _await_cup_settled()
	assert_int(sleeper.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_aim_cone_still_snaps_to_a_sleeper_in_the_clear() -> void:
	var player := _player_at(Vector2(START_X, LANE_Y))
	# Geometry stands in the room, south of the throw lane.
	_horizontal_wall_at(660.0)
	var sleeper := _frozen_sleeper_at(Vector2(400.0, LANE_Y))

	var cup := player.throw_cup(Vector2.RIGHT)
	assert_object(cup).is_not_null()
	assert_vector(cup.landing).is_equal(sleeper.global_position)

	await _await_awake(sleeper)
	assert_int(sleeper.state).is_equal(Sleepwalker.State.AWAKE)


func _vertical_wall_at(center_x: float) -> StaticBody2D:
	return _wall_at(Vector2(center_x, LANE_Y), Vector2(WALL_THICKNESS, 900.0))


func _horizontal_wall_at(center_y: float) -> StaticBody2D:
	return _wall_at(Vector2(640.0, center_y), Vector2(1600.0, WALL_THICKNESS))


func _wall_at(center: Vector2, wall_size: Vector2) -> StaticBody2D:
	# A wall built like the cafe and city walls: a StaticBody2D with a
	# rectangle on the default environment layer 1.
	var wall := StaticBody2D.new()
	wall.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	shape_node.shape = shape
	wall.add_child(shape_node)
	add_child(auto_free(wall))
	return wall


func _frozen_sleeper_at(at: Vector2) -> Sleepwalker:
	var sleeper := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	# Freeze the wander so the wall geometry stays honest.
	var calm := sleeper.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	sleeper.balance = calm
	sleeper.position = at
	add_child(auto_free(sleeper))
	return sleeper


func _player_at(at: Vector2) -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = at
	player.cup_scene = CUP_SCENE
	add_child(auto_free(player))
	return player


func _throw_cup_to(landing: Vector2, payload: BrewedCup) -> CoffeeCup:
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(START_X, LANE_Y)
	cup.direction = Vector2.RIGHT
	cup.brewed = payload
	add_child(auto_free(cup))
	_cup_in_flight = true
	cup.tree_exited.connect(_on_cup_left_tree)
	cup.launch(landing)
	return cup


func _on_cup_left_tree() -> void:
	# queue_free() pulls the cup from the tree at the frame end, so the flag
	# marks the death without holding the freed object.
	_cup_in_flight = false


func _standard_cup() -> BrewedCup:
	return _brew(STANDARD_SCORE)


func _perfect_cup() -> BrewedCup:
	return _brew(PERFECT_SCORE)


func _brew(score: float) -> BrewedCup:
	# The light roast carries the full splash radius, so the wall geometry
	# reads the plain balance values. The roast scaling lives in
	# test_perfect_cup_splash.gd.
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("light"),
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
