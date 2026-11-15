# ABOUTME: Integration tests for The Tourist: the photo stops and the flash stun.
# ABOUTME: Drives the real tourist and player scenes with physics frames.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const TOURIST_SCENE := preload("res://scenes/enemies/tourist.tscn")

const MAX_FRAMES_TO_WAIT := 600
# The pair spawns out of sense range; each test walks the player into place.
const PLAYER_START_OFFSET := Vector2(400, 0)

var _tourist: Sleepwalker
var _player: Player
var _flashes := 0
var _met_types: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_flashes = 0
	_met_types.clear()
	_tourist = TOURIST_SCENE.instantiate() as Sleepwalker
	# Freeze the wander so the flash-range distances stay exact.
	var frozen := _tourist.balance.duplicate() as SleepwalkerBalance
	frozen.walk_speed = 0.0
	_tourist.balance = frozen
	_tourist.position = Vector2(400, 200)
	add_child(auto_free(_tourist))
	_tourist.flashed.connect(_on_flash)
	_tourist.first_met.connect(func(type_id: String) -> void: _met_types.append(type_id))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = _tourist.position + PLAYER_START_OFFSET
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_flash_stuns_the_player_for_a_moment() -> void:
	_place_player_near(Vector2(0, 120))
	await _stun_the_player()

	# The stun holds for the balanced moment, then the player acts again.
	var stun_frames := 0
	while _player.is_stunned():
		await get_tree().physics_frame
		stun_frames += 1
	# 0.75 seconds at 60 physics frames per second.
	assert_int(stun_frames).is_between(41, 50)
	assert_bool(_player.is_stunned()).is_false()


func test_stunned_player_cannot_throw_drink_or_dodge() -> void:
	_place_player_near(Vector2(0, 120))
	await _stun_the_player()

	var cups_before: int = _player.coffee_supply.cups
	var children_before: int = get_child_count()
	assert_object(_player.throw_cup(Vector2.RIGHT)).is_null()
	assert_bool(_player.drink_cup()).is_false()
	assert_bool(_player.begin_dodge(Vector2.RIGHT)).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)
	assert_int(get_child_count()).is_equal(children_before)
	assert_bool(_player.sleep_meter.is_drinking()).is_false()


func test_dodge_roll_dodges_the_flash() -> void:
	_place_player_near(Vector2(0, 120))
	var frames := 0
	while _tourist.state != Sleepwalker.State.PHOTO and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tourist.state).is_equal(Sleepwalker.State.PHOTO)

	# He raises the camera for the balanced windup. Time the roll so its
	# invulnerability window still covers the flash at the windup's end.
	for index: int in range(8):
		await get_tree().physics_frame
	assert_bool(_player.begin_dodge(Vector2.RIGHT)).is_true()

	while _flashes < 1:
		await get_tree().physics_frame
	assert_int(_flashes).is_equal(1)
	# The flash fired and missed: the rolling player is not dazzled.
	assert_bool(_player.is_stunned()).is_false()


func test_flash_misses_beyond_the_flash_radius() -> void:
	# 145 px away: inside the sense circle, outside the flash circle.
	_place_player_near(Vector2(0, -145))
	var frames := 0
	while _tourist.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tourist.state).is_equal(Sleepwalker.State.CHASE)

	frames = 0
	while _flashes < 1 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_flashes).is_equal(1)
	assert_bool(_player.is_stunned()).is_false()


func test_tourist_stops_to_photograph_even_with_no_player_around() -> void:
	# The player stays away: the Tourist photographs the scenery anyway.
	assert_int(_tourist.state).is_equal(Sleepwalker.State.WANDER)
	assert_bool(_met_types.is_empty()).is_true()

	var frames := 0
	while _tourist.state != Sleepwalker.State.PHOTO and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tourist.state).is_equal(Sleepwalker.State.PHOTO)
	assert_vector(_tourist.velocity).is_equal(Vector2.ZERO)

	while _flashes < 1:
		await get_tree().physics_frame
	assert_bool(_player.is_stunned()).is_false()

	# The photo pause ends and the wandering continues.
	frames = 0
	while _tourist.state == Sleepwalker.State.PHOTO and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tourist.state).is_equal(Sleepwalker.State.WANDER)


func test_the_tourist_never_hugs_the_player() -> void:
	# The Tourist's only attack is the flash. He stands and photographs.
	_place_player_near(Vector2(0, -10))
	var frames := 0
	while _flashes < 2 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		assert_int(_tourist.state).is_not_equal(Sleepwalker.State.HUG)
		frames += 1
	assert_int(_flashes).is_greater_equal(2)
	assert_bool(_player.is_grabbed()).is_false()


func test_stun_follows_the_player_rules() -> void:
	_player.apply_stun(0.2)
	_player.apply_stun(0.1)
	assert_bool(_player.is_stunned()).is_true()
	# A stronger flash extends the stun to its own length; flashes never stack.
	_player.apply_stun(0.5)
	var frames := 0
	while _player.is_stunned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	# 0.5 seconds at 60 physics frames per second.
	assert_int(frames).is_between(26, 35)
	assert_bool(_player.is_stunned()).is_false()

	_player.apply_stun(0.75)
	assert_bool(_player.is_stunned()).is_true()
	# Waking in the cafe starts a clean new day: no dazzle carries over.
	_player.wake_in_cafe()
	assert_bool(_player.is_stunned()).is_false()


func test_tourist_emits_first_met_for_the_sleepydex() -> void:
	_place_player_near(Vector2(0, 120))
	var frames := 0
	while _met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_met_types.size()).is_equal(1)
	assert_str(_met_types[0]).is_equal("tourist")
	for extra_frame: int in range(30):
		await get_tree().physics_frame
	assert_int(_met_types.size()).is_equal(1)


func _place_player_near(offset: Vector2) -> void:
	_player.global_position = _tourist.global_position + offset


func _stun_the_player() -> void:
	var frames := 0
	while not _player.is_stunned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_stunned()).is_true()
	assert_int(_flashes).is_greater_equal(1)


func _on_flash() -> void:
	_flashes += 1
