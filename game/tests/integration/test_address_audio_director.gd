# ABOUTME: Integration tests for the section 21 address audio loop, T044.
# ABOUTME: Proves the distance layers, the hug swell, the antagonist ramp,
# ABOUTME: the tower cut with its birdsong, the diegetic venues, and the
# ABOUTME: tolerance remedies inside a real city run.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const ADDRESS_BALANCE := preload("res://resources/balance/address_audio.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const BAND_SCENE := preload("res://scenes/bosses/sleep_jam_band.tscn")
const SLEEPVANA_SCENE := preload("res://scenes/quests/sleepvana_stage.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600

# The band stage stands far north of the city, clear of every pole.
const BAND_STAGE_SPOT := Vector2(2000.0, -900.0)

var _city: CityRun
var _map: CityMap
var _director: AddressAudioDirector
var _poles: Array[Vector2]


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready, so the overlaps report from
	# the second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_map = _city.city_map()
	_director = _city.address_audio
	_poles = _map.speaker_pole_positions()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_run_carries_one_loop_per_pole() -> void:
	assert_object(_director).is_not_null()
	assert_int(_director.pole_count()).is_equal(3)
	assert_int(_poles.size()).is_equal(3)
	var offsets := _director.pole_offsets()
	for a: int in offsets.size():
		for b: int in range(a + 1, offsets.size()):
			var direct := absf(offsets[a] - offsets[b])
			var circular := minf(direct, ADDRESS_BALANCE.loop_seconds - direct)
			assert_float(circular).is_greater_equal(ADDRESS_BALANCE.sync_guard_seconds - 0.0001)
		assert_str(_director.pole_player(a).bus).is_equal("AddressFar")


func test_the_layer_follows_the_player() -> void:
	_city.player.global_position = _poles[0]
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.NEAR)
	assert_str(_director.pole_player(0).bus).is_equal("AddressNear")
	assert_float(_director.address_volume_db()).is_equal_approx(
		ADDRESS_BALANCE.near_volume_db, 0.001
	)

	_city.player.global_position = _poles[0] + Vector2(300.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.MID)

	_city.player.global_position = _map.cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_layer()).is_equal(AddressAudio.Layer.FAR)
	assert_str(_director.pole_player(0).bus).is_equal("AddressFar")


func test_a_hug_swells_the_address() -> void:
	_scatter_the_crowd()
	_city.player.global_position = _poles[0]
	await get_tree().physics_frame
	await get_tree().physics_frame
	var plain := _director.address_volume_db()
	assert_float(plain).is_equal_approx(ADDRESS_BALANCE.near_volume_db, 0.001)

	_city.player.set_grabbed_by(_city.crowd_enemy(0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_director.address_volume_db()).is_equal_approx(
		plain + ADDRESS_BALANCE.hug_swell_db, 0.001
	)

	_city.player.clear_grab(_city.crowd_enemy(0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_director.address_volume_db()).is_equal_approx(plain, 0.001)


func test_the_antagonist_track_gets_loud_when_an_enemy_closes() -> void:
	_scatter_the_crowd()
	_city.player.global_position = _map.cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_director.antagonist_volume_db()).is_equal_approx(
		ADDRESS_BALANCE.antagonist_far_volume_db, 0.001
	)

	_city.crowd_enemy(1).global_position = _city.player.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	# The enemy walks a step or two while the frames pass, so the read sits a
	# hair above the close ceiling, loud by any measure.
	assert_float(_director.antagonist_volume_db()).is_greater(
		ADDRESS_BALANCE.antagonist_close_volume_db - 0.5
	)


func test_the_tower_cut_stops_the_address_mid_word_then_birdsong() -> void:
	var tower := _map.broadcast_tower()
	_city.player.pickup_item(FUSE_ITEM, 1)
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(_director.is_address_cut()).is_false()

	assert_bool(tower.switch_off()).is_true()
	assert_bool(_director.is_address_cut()).is_true()
	for i: int in _director.pole_count():
		assert_bool(_director.pole_player(i).playing).is_false()

	var frames := 0
	while tower.phase != BroadcastTower.Phase.BIRDSONG and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(_director.is_address_cut()).is_true()
	assert_bool(_director.birdsong_player() != null).is_true()


func test_diegetic_music_survives_the_tower_cut() -> void:
	var tower := _map.broadcast_tower()
	_city.player.pickup_item(FUSE_ITEM, 1)
	tower.insert_fuse(_city.player)
	tower.switch_off()
	_city.player.global_position = _map.cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.CAFE)
	assert_str(_director.diegetic_track()).is_equal("Vinyl Jazz")
	assert_bool(_director.is_address_cut()).is_true()


func test_the_band_stage_plays_the_endless_song() -> void:
	var band := BAND_SCENE.instantiate() as SleepJamBand
	add_child(auto_free(band))
	band.global_position = BAND_STAGE_SPOT
	_director.band = band
	await get_tree().physics_frame
	await get_tree().physics_frame

	_city.player.global_position = BAND_STAGE_SPOT
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.BAND_STAGE)
	assert_str(_director.diegetic_track()).is_equal("The Endless Song")

	var geisha_cup := BrewedCup.new(
		LIBRARY.find_bean("geisha_vault"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("filter"),
		"",
		85.0
	)
	assert_bool(band.try_wake(geisha_cup)).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.SILENT)
	assert_str(_director.diegetic_track()).is_equal("")


func test_the_concert_plays_the_sleepvana_hit() -> void:
	var stage := SLEEPVANA_SCENE.instantiate() as SleepvanaStage
	add_child(auto_free(stage))
	_director.sleepvana = stage
	await get_tree().physics_frame

	var quest := stage.quest
	assert_bool(quest.record_member_wake(0)).is_true()
	assert_bool(quest.record_member_wake(1)).is_true()
	assert_bool(quest.record_member_wake(2)).is_true()
	assert_bool(quest.recruit_crowd(5)).is_true()
	assert_bool(quest.crowd_arrived(5)).is_true()
	assert_bool(quest.wake_the_frontman()).is_true()

	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_director.current_venue()).is_equal(DiegeticMusic.Venue.SLEEPVANA_CONCERT)
	assert_str(_director.diegetic_track()).is_equal("Smells Like Bean Spirit")


func test_tolerance_filters_the_address_past_thirty_minutes() -> void:
	_city.player.global_position = _poles[0]
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_float(_director.address_filter_hz()).is_equal(ADDRESS_BALANCE.near_low_pass_hz)

	_director.tolerance().expose(AddressAudioDirector.ADDRESS_ID, 30.01)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_director.is_address_cut()).is_false()
	assert_float(_director.address_filter_hz()).is_equal(ADDRESS_BALANCE.tolerance_filter_hz)


func test_tolerance_stops_the_grating_record() -> void:
	_city.player.global_position = _map.cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_str(_director.diegetic_track()).is_equal("Vinyl Jazz")

	_director.tolerance().expose("Vinyl Jazz", 30.01)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_str(_director.diegetic_track()).is_equal("")


func _scatter_the_crowd() -> void:
	# Every walker stands far east, outside every sense and hug radius, so
	# the volume reads stay steady while the test moves the player.
	var far_x := _map.city_size().x + 900.0
	for i: int in _city.crowd_count():
		_city.crowd_enemy(i).global_position = Vector2(far_x + float(i) * 60.0, 240.0)
