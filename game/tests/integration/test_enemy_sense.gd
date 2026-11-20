# ABOUTME: Integration tests for the crowd sense rule against the player.
# ABOUTME: Pins the opening-video repair: a locked player is out of enemy play.
extends GdUnitTestSuite

const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

const MAX_FRAMES_TO_WAIT := 120
# The neighbor spawns far away: no test wants a spot before it arranges its
# own lock state first.
const FAR_SPAWN := Vector2(5000.0, 0.0)

var _player: Player
var _neighbor: Sleepwalker
var _meet_count: Array[int] = [0]


func before_test() -> void:
	_meet_count[0] = 0
	_player = auto_free(PLAYER_SCENE.instantiate()) as Player
	add_child(_player)
	_player.global_position = Vector2.ZERO
	_neighbor = auto_free(NEIGHBOR_SCENE.instantiate()) as Sleepwalker
	add_child(_neighbor)
	_neighbor.global_position = FAR_SPAWN
	_neighbor.first_met.connect(_on_first_met)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	_player.set_input_locked(false)


func _on_first_met(_type_id: String) -> void:
	_meet_count[0] += 1


func test_a_locked_player_is_never_spotted() -> void:
	# The opening video holds the input for 20 seconds. A Neighbor pressed
	# onto that player still sees nothing: no chase and no first meeting.
	_player.set_input_locked(true)
	_neighbor.global_position = _player.global_position + Vector2(10.0, 0.0)
	for i: int in range(60):
		await get_tree().physics_frame

	assert_int(_neighbor.state).is_equal(Sleepwalker.State.WANDER)
	assert_int(_meet_count[0]).is_equal(0)
	assert_object(_neighbor.player).is_null()


func test_an_unlocked_player_is_spotted_once() -> void:
	_neighbor.global_position = _player.global_position + Vector2(60.0, 0.0)
	var frames := 0
	while _neighbor.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_neighbor.state).is_equal(Sleepwalker.State.CHASE)
	assert_int(_meet_count[0]).is_equal(1)


func test_a_hug_never_lands_on_a_locked_player() -> void:
	# The chase runs from before the lock, like a crowd that spotted the
	# barista and then the video took the screen: the hug slides off while
	# the input stays locked, and the meter never drains.
	_neighbor.global_position = _player.global_position + Vector2(60.0, 0.0)
	var frames := 0
	while _neighbor.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	_player.set_input_locked(true)
	_neighbor.global_position = _player.global_position + Vector2(10.0, 0.0)
	var meter_at_lock := _player.sleep_meter.value
	for i: int in range(60):
		await get_tree().physics_frame

	assert_int(_neighbor.state).is_equal(Sleepwalker.State.CHASE)
	assert_bool(_player.is_grabbed()).is_false()
	assert_float(_player.sleep_meter.value).is_equal(meter_at_lock)

	_player.set_input_locked(false)
	frames = 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_true()


func test_a_building_wall_hides_the_player_from_chase_sense() -> void:
	# T110: solid environment walls block sleepwalker chase sense and first_met.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(40.0, 0.0)
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 240.0)
	shape_node.shape = rect
	wall.add_child(shape_node)
	add_child(auto_free(wall))
	var frozen := _neighbor.balance.duplicate() as SleepwalkerBalance
	frozen.walk_speed = 0.0
	_neighbor.balance = frozen
	_neighbor.global_position = Vector2(80.0, 0.0)
	for _i: int in range(30):
		await get_tree().physics_frame

	assert_int(_neighbor.state).is_equal(Sleepwalker.State.WANDER)
	assert_int(_meet_count[0]).is_equal(0)
	assert_object(_neighbor.player).is_null()
