# ABOUTME: Integration tests for the address loop inside the cafe dev room, T099.
# ABOUTME: Proves the room wires the director without a CityMap and keeps the
# ABOUTME: section 21 sound rules: layers, venues, antagonist, tower cut.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")
const ADDRESS_BALANCE := preload("res://resources/balance/address_audio.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
# A mid-layer spot west of the pole, clear of the walls and the shelf.
const MID_LAYER_SPOT := Vector2(620.0, 380.0)

var _cafe: Cafe
var _director: AddressAudioDirector
var _pole: SleepZone


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate() as Cafe
	add_child(auto_free(_cafe))
	# The room builds its bodies inside _ready, so the overlaps report from
	# the second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_director = _cafe.address_audio
	_pole = _cafe.speaker_pole


func test_the_room_carries_one_loop_for_its_pole() -> void:
	assert_object(_director).is_not_null()
	assert_int(_director.pole_count()).is_equal(1)
	var offsets := _director.pole_offsets()
	assert_int(offsets.size()).is_equal(1)
	assert_float(offsets[0]).is_between(0.0, ADDRESS_BALANCE.loop_seconds)
	assert_str(_director.pole_player(0).bus).is_equal("AddressFar")


func test_the_layer_follows_the_player() -> void:
	# The spawn sits far from the pole, the whole room width away.
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.FAR)

	_cafe.player.global_position = MID_LAYER_SPOT
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.MID)

	_cafe.player.global_position = _pole.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.NEAR)
	assert_str(_director.pole_player(0).bus).is_equal("AddressNear")
	assert_float(_director.address_volume_db()).is_equal_approx(
		ADDRESS_BALANCE.near_volume_db, 0.001
	)


func test_the_cafe_record_plays_inside_the_safe_zone() -> void:
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.CAFE)
	assert_str(_director.diegetic_track()).is_equal("Vinyl Jazz")

	_cafe.player.global_position = MID_LAYER_SPOT
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.SILENT)
	assert_str(_director.diegetic_track()).is_equal("")


func test_the_antagonist_track_gets_loud_when_a_neighbor_closes() -> void:
	for index: int in range(1, _cafe.sleepwalkers.get_child_count()):
		_cafe.get_sleepwalker(index).wake_up()
	# The last sleeping neighbor waits in the far corner of the room.
	var enemy := _cafe.get_sleepwalker(0)
	enemy.global_position = Vector2(1120.0, 580.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_director.antagonist_volume_db()).is_equal_approx(
		ADDRESS_BALANCE.antagonist_far_volume_db, 0.001
	)

	enemy.global_position = _cafe.player.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	# The neighbor walks a step or two while the frames pass, so the read sits
	# a hair above the close ceiling, loud by any measure.
	assert_float(_director.antagonist_volume_db()).is_greater(
		ADDRESS_BALANCE.antagonist_close_volume_db - 0.5
	)


func test_the_tower_cut_stops_the_address_mid_word() -> void:
	assert_bool(_director.is_address_cut()).is_false()

	_cafe.player.pickup_item(FUSE_ITEM, 1)
	assert_bool(_cafe.broadcast_tower.insert_fuse(_cafe.player)).is_true()
	assert_bool(_cafe.broadcast_tower.switch_off()).is_true()
	assert_bool(_director.is_address_cut()).is_true()
	assert_bool(_director.pole_player(0).playing).is_false()
	assert_bool(_pole.is_broadcast_silenced()).is_true()

	var frames := 0
	while (
		_cafe.broadcast_tower.phase != BroadcastTower.Phase.BIRDSONG and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1
	assert_int(_cafe.broadcast_tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(_director.is_address_cut()).is_true()
	assert_object(_director.birdsong_player()).is_not_null()
