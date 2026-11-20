# ABOUTME: Integration tests for The Tech Bro: the pitch and the diving drone.
# ABOUTME: Drives the real tech bro, drone, and player scenes with physics frames.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const TECH_BRO_SCENE := preload("res://scenes/enemies/tech_bro.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600
# The pair spawns out of sense range; each test walks the player into place.
const PLAYER_START_OFFSET := Vector2(400, 0)

var _tech_bro: Sleepwalker
var _drone: Drone
var _player: Player
var _pitches := 0
var _met_types: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_pitches = 0
	_met_types.clear()
	_tech_bro = TECH_BRO_SCENE.instantiate() as Sleepwalker
	# Freeze the wander so the drone geometry stays exact.
	var frozen := _tech_bro.balance.duplicate() as SleepwalkerBalance
	frozen.walk_speed = 0.0
	_tech_bro.balance = frozen
	_tech_bro.position = Vector2(400, 200)
	add_child(auto_free(_tech_bro))
	_drone = _tech_bro.get_node("Drone") as Drone
	_tech_bro.pitched.connect(func() -> void: _pitches += 1)
	_tech_bro.first_met.connect(func(type_id: String) -> void: _met_types.append(type_id))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = _tech_bro.position + PLAYER_START_OFFSET
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_the_tech_bro_pitches_to_nobody_on_a_cadence() -> void:
	# The player stays far away. He still sells startup ideas to the empty air.
	for _first_interval: int in range(160):
		await get_tree().physics_frame
	assert_int(_pitches).is_equal(1)
	for _second_interval: int in range(170):
		await get_tree().physics_frame
	assert_int(_pitches).is_equal(2)


func test_the_tech_bro_stands_to_pitch_and_never_hugs() -> void:
	_place_player_near(Vector2(0, -10))
	for _i: int in range(150):
		await get_tree().physics_frame
		assert_int(_tech_bro.state).is_not_equal(Sleepwalker.State.HUG)
	assert_int(_tech_bro.state).is_equal(Sleepwalker.State.CHASE)
	assert_vector(_tech_bro.velocity).is_equal(Vector2.ZERO)
	assert_bool(_player.is_grabbed()).is_false()


func test_the_drone_circles_the_tech_bro_on_the_ring() -> void:
	# The player stays far away, so the drone keeps its patrol ring.
	var previous := _drone.global_position
	var path := 0.0
	for _i: int in range(60):
		await get_tree().physics_frame
		assert_int(_drone.state).is_equal(Drone.State.ORBIT)
		var ring_distance := _drone.global_position.distance_to(_tech_bro.global_position)
		assert_float(ring_distance).is_between(55.0, 57.0)
		path += _drone.global_position.distance_to(previous)
		previous = _drone.global_position
	# One second at 140 degrees per second on a ring of radius 56 is about
	# 137 pixels of arc.
	assert_float(path).is_between(130.0, 144.0)


func test_the_drone_ignores_players_beyond_its_reach() -> void:
	# 350 px away: outside the sense circle of the bro and of the drone.
	_place_player_near(Vector2(350, 0))
	for _i: int in range(120):
		await get_tree().physics_frame
		assert_int(_drone.state).is_equal(Drone.State.ORBIT)
	assert_int(_tech_bro.state).is_equal(Sleepwalker.State.WANDER)


func test_the_drone_dives_and_bumps_the_player() -> void:
	_place_player_near(Vector2(0, 60))
	await _dive_begins()

	var frames := 0
	while not _player.is_stunned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_stunned()).is_true()

	var stun_frames := 0
	while _player.is_stunned():
		await get_tree().physics_frame
		stun_frames += 1
	# 0.35 seconds at 60 physics frames per second.
	assert_int(stun_frames).is_between(16, 26)
	assert_bool(_player.is_stunned()).is_false()


func test_the_drone_cools_down_between_dives() -> void:
	_place_player_near(Vector2(0, 60))
	await _dive_begins()
	await _bump_the_player()
	await _drone_returns_to_orbit()

	# The player stays in reach, but the cooldown holds the drone back.
	var dives := 0
	for _i: int in range(40):
		await get_tree().physics_frame
		if _drone.state == Drone.State.DIVE:
			dives += 1
	assert_int(dives).is_equal(0)

	# The cooldown ends and the next dive comes.
	await _dive_begins()


func test_dodge_roll_sidesteps_the_dive() -> void:
	await _wait_for_drone_near_angle_zero()
	_place_player_near(Vector2(100, 0))
	await _dive_begins()
	# The pass is locked on the spot where the player stands. Roll away
	# sideways and the bump misses.
	assert_bool(_player.begin_dodge(Vector2(0, 1))).is_true()

	var frames := 0
	while _drone.state == Drone.State.DIVE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
		assert_bool(_player.is_stunned()).is_false()
	assert_int(_drone.state).is_not_equal(Drone.State.DIVE)
	assert_bool(_player.is_stunned()).is_false()


func test_the_drone_lands_when_bulletproof_wakes_the_tech_bro() -> void:
	_place_player_near(Vector2(0, 60))
	await _dive_begins()
	var bulletproof := BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("espresso"),
		"butter",
		85.0
	)
	assert_bool(_tech_bro.try_wake(bulletproof)).is_true()
	assert_int(_tech_bro.state).is_equal(Sleepwalker.State.AWAKE)
	assert_int(_drone.state).is_equal(Drone.State.LANDED)

	# The landed drone is harmless and stays put, even with the player on it.
	var landed_position := _drone.global_position
	_player.global_position = landed_position
	for _i: int in range(90):
		await get_tree().physics_frame
		assert_bool(_player.is_stunned()).is_false()
	assert_vector(_drone.global_position).is_equal(landed_position)


func test_tech_bro_emits_first_met_for_the_sleepydex() -> void:
	_place_player_near(Vector2(0, 120))
	var frames := 0
	while _met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_met_types.size()).is_equal(1)
	assert_str(_met_types[0]).is_equal("tech_bro")
	for _i: int in range(30):
		await get_tree().physics_frame
	assert_int(_met_types.size()).is_equal(1)


func test_the_drone_lands_when_the_tech_bro_restores_awake() -> void:
	# A restored awake Tech Bro never emits woke_up; its drone must still land
	# instead of orbiting and diving at the player after reload.
	var restored := TECH_BRO_SCENE.instantiate() as Sleepwalker
	restored.position = Vector2(200, 200)
	add_child(auto_free(restored))
	restored.wake_up(true)
	var drone := restored.get_node("Drone") as Drone
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(drone.state).is_equal(Drone.State.LANDED)


func _place_player_near(offset: Vector2) -> void:
	_player.global_position = _tech_bro.global_position + offset


func _dive_begins() -> void:
	var frames := 0
	while _drone.state != Drone.State.DIVE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_drone.state).is_equal(Drone.State.DIVE)


func _bump_the_player() -> void:
	var frames := 0
	while not _player.is_stunned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_stunned()).is_true()


func _drone_returns_to_orbit() -> void:
	var frames := 0
	while _drone.state != Drone.State.ORBIT and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_drone.state).is_equal(Drone.State.ORBIT)


func _wait_for_drone_near_angle_zero() -> void:
	# The drone starts its lap at angle zero. Wait for the near pass so the
	# dive geometry in the dodge test is short and exact.
	var frames := 0
	while (
		(_drone.position.x < 50.0 or absf(_drone.position.y) > 12.0) and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1
	assert_float(_drone.position.x).is_greater_equal(50.0)
