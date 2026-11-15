# ABOUTME: Integration tests for The Gamer: the fast, short dash gait.
# ABOUTME: Drives the real gamer and player scenes with physics frames.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const GAMER_SCENE := preload("res://scenes/enemies/gamer.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600
# The pair spawns out of sense range; each test walks the player into place.
const PLAYER_START_OFFSET := Vector2(400, 0)

var _gamer: Sleepwalker
var _player: Player
var _met_types: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_met_types.clear()
	_gamer = GAMER_SCENE.instantiate() as Sleepwalker
	# No idle stands while wandering: every burst carries a real direction.
	var calm := _gamer.balance.duplicate() as SleepwalkerBalance
	calm.idle_chance = 0.0
	_gamer.balance = calm
	_gamer.position = Vector2(400, 200)
	add_child(auto_free(_gamer))
	_gamer.first_met.connect(func(type_id: String) -> void: _met_types.append(type_id))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = _gamer.position + PLAYER_START_OFFSET
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_the_gamer_moves_in_bursts_not_a_steady_walk() -> void:
	# The player stays far away: this is the wander gait alone. Every frame
	# either stands dead still or dashes at full speed. A steady walk speed,
	# like the neighbor's 40 or the chase 70, never appears.
	var burst_frames := 0
	var standing_frames := 0
	for _frame: int in range(170):
		_keep_player_far_away()
		await get_tree().physics_frame
		assert_int(_gamer.state).is_equal(Sleepwalker.State.WANDER)
		var speed := _gamer.velocity.length()
		if speed > 1.0:
			burst_frames += 1
			assert_float(speed).is_between(310.0, 330.0)
		else:
			standing_frames += 1
	# Two full cycles in 170 frames: 14 dash frames and 70 standing per cycle.
	assert_int(burst_frames).is_between(26, 30)
	assert_int(standing_frames).is_between(140, 144)


func test_the_dash_cycle_windups_fires_then_rests() -> void:
	# From spawn: the windup telegraph (the red tint), one short dash, then a
	# standing rest before the next windup. All timings come from gamer.tres.
	for _warmup: int in range(10):
		_keep_player_far_away()
		await get_tree().physics_frame
	assert_int(_gamer.state).is_equal(Sleepwalker.State.WANDER)
	# Mid-windup: he stands still and the red tint telegraphs the dash.
	assert_vector(_gamer.velocity).is_equal(Vector2.ZERO)
	assert_bool(_gamer.visual.modulate == Sleepwalker.DASH_WINDUP_MODULATE).is_true()

	var frames_before_dash := 0
	while _gamer.velocity.length() < 1.0 and frames_before_dash < 60:
		_keep_player_far_away()
		await get_tree().physics_frame
		frames_before_dash += 1
	# The rest of the 0.35-second windup at 60 physics frames per second.
	assert_int(frames_before_dash).is_between(10, 15)
	assert_bool(_gamer.visual.modulate == Color.WHITE).is_true()

	var dash_start := _gamer.global_position
	var dash_frames := 0
	while _gamer.velocity.length() > 1.0 and dash_frames < 40:
		_keep_player_far_away()
		await get_tree().physics_frame
		dash_frames += 1
	# 0.25 seconds at dash speed 320: about 75 pixels in a straight line.
	assert_int(dash_frames).is_between(13, 16)
	assert_float(dash_start.distance_to(_gamer.global_position)).is_between(65.0, 75.0)

	var rest_frames := 0
	while _gamer.velocity.length() < 1.0 and rest_frames < 100:
		_keep_player_far_away()
		await get_tree().physics_frame
		rest_frames += 1
	# The rest (0.8 seconds) plus the next windup (0.35 seconds) both stand.
	assert_int(rest_frames).is_between(66, 76)


func test_chase_dashes_close_in_and_end_in_a_hug() -> void:
	_place_player_near(Vector2(0, 120))
	await _gamer_chases()

	var frames := 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
		var speed := _gamer.velocity.length()
		# The chase never walks: it is dashes and pauses all the way in.
		assert_bool(speed < 1.0 or speed > 300.0).is_true()
	assert_bool(_player.is_grabbed()).is_true()
	assert_int(_gamer.state).is_equal(Sleepwalker.State.HUG)
	# 120 pixels close in about two dash cycles, far faster than a 70-speed
	# steady chase.
	assert_int(frames).is_less(360)

	# Mashing breaks the hug, and the dash chase resumes.
	for _press: int in range(5):
		_player.struggle()
	await get_tree().physics_frame
	assert_bool(_player.is_grabbed()).is_false()
	assert_int(_gamer.state).is_equal(Sleepwalker.State.CHASE)


func test_the_dash_locks_its_direction_when_it_fires() -> void:
	_place_player_near(Vector2(0, 120))
	await _gamer_chases()
	await _burst_begins()

	var locked := _gamer.velocity.normalized()
	var to_player := (_player.global_position - _gamer.global_position).normalized()
	# The burst fires straight at the player's position at the lock moment.
	assert_float(locked.dot(to_player)).is_greater(0.99)

	# The player sidesteps mid-dash. The committed dash does not follow.
	_player.global_position = _gamer.global_position + Vector2(150, 0)
	for _frame: int in range(6):
		await get_tree().physics_frame
		assert_float(_gamer.velocity.normalized().dot(locked)).is_greater(0.99)


func test_a_dodge_roll_slips_the_incoming_dash() -> void:
	_place_player_near(Vector2(0, 100))
	await _gamer_chases()
	await _burst_begins()

	# The dash committed toward the spot where the player stood. Roll
	# perpendicular and the pass misses; a rolling player cannot be grabbed.
	assert_bool(_player.begin_dodge(Vector2(1, 0))).is_true()
	var frames := 0
	while frames < 40 and not _player.is_grabbed():
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_false()


func test_waking_the_gamer_stops_the_gait() -> void:
	var triple_shot := BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("light"),
		LIBRARY.find_method("aeropress"),
		"three_shots",
		85.0
	)
	assert_bool(_gamer.try_wake(triple_shot)).is_true()
	assert_int(_gamer.state).is_equal(Sleepwalker.State.AWAKE)

	var resting_spot := _gamer.global_position
	for _frame: int in range(120):
		await get_tree().physics_frame
		assert_vector(_gamer.velocity).is_equal(Vector2.ZERO)
	assert_vector(_gamer.global_position).is_equal(resting_spot)


func test_gamer_emits_first_met_for_the_sleepydex() -> void:
	_place_player_near(Vector2(0, 120))
	var frames := 0
	while _met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_met_types.size()).is_equal(1)
	assert_str(_met_types[0]).is_equal("gamer")
	for _frame: int in range(30):
		await get_tree().physics_frame
	assert_int(_met_types.size()).is_equal(1)


func _place_player_near(offset: Vector2) -> void:
	_player.global_position = _gamer.global_position + offset


func _keep_player_far_away() -> void:
	# Hold the player outside the sense circle so the gait stays in WANDER.
	_player.global_position = _gamer.global_position + PLAYER_START_OFFSET


func _gamer_chases() -> void:
	var frames := 0
	while _gamer.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_gamer.state).is_equal(Sleepwalker.State.CHASE)
	assert_bool(_met_types.is_empty()).is_false()


func _burst_begins() -> void:
	var frames := 0
	while _gamer.velocity.length() < 1.0 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_float(_gamer.velocity.length()).is_greater(300.0)
