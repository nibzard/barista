# ABOUTME: Integration tests for the playable Pourtland run, city 3 on the route.
# ABOUTME: Proves the roster, the Aisle 7 sites, the tier 3 cafe, and moving day.
extends GdUnitTestSuite

const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const STEAMTLE_DEFINITION := preload("res://resources/city/steamtle.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600

# The deterministic spawn rule, Pourtland densities [3, 3, 3, 3, 3, 4, 4, 4]:
# the cafe block holds only the basic type, every later block cycles the
# roster of two, so 24 later spawns split evenly and the cafe adds three
# neighbors on top. Section 16 keeps the Karen off the street: she appears
# only in the Pourtland outro.
const EXPECTED_CROWD_TOTAL := 27
const EXPECTED_NEIGHBORS := 15
const EXPECTED_TINFOIL_MEN := 12
const EXPECTED_KARENS := 0

# The named places of the city: the hardware store of the Aisle 7 quest with
# the screw wall and the sandpaper rack around it, section 13, plus the
# Crystal Beanroom that carries the Sleep Jam arena.
const QUEST_SITE_NAMES := ["The Screw Wall", "The Hardware Store", "The Sandpaper Rack"]

var _city: CityRun


func before_test() -> void:
	_city = POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_city_loads_with_the_full_landmark_set() -> void:
	assert_int(_city.city_index).is_equal(3)
	assert_str(_city.definition.city_id).is_equal("pourtland")
	var map := _city.city_map()
	assert_int(map.block_count()).is_equal(8)
	var landmarks: Array[CityBlock.Kind] = [
		CityBlock.Kind.CAFE,
		CityBlock.Kind.TOWER,
		CityBlock.Kind.BOSS_ARENA,
		CityBlock.Kind.QUEST,
	]
	for kind: CityBlock.Kind in landmarks:
		(
			assert_object(map.find_block_of_kind(kind))
			. override_failure_message(CityRules.kind_name(kind))
			. is_not_null()
		)
	assert_int(map.block_view(0).kind()).is_equal(CityBlock.Kind.CAFE)
	assert_int(map.block_view(map.block_count() - 1).kind()).is_equal(CityBlock.Kind.TOWER)
	# The three speaker poles guard the last blocks before the tower.
	var pole_blocks := CityRules.pole_block_indices(map.block_count(), CITY_BALANCE)
	for index: int in pole_blocks:
		assert_object(map.block_view(index).pole_zone()).is_not_null()
	# The road east ends here: Pourtland is the last city of the version, so
	# no city stands beyond the bridge.
	assert_object(_city.east_city_scene).is_null()


func test_the_aisle_7_sites_stand_in_the_city() -> void:
	var map := _city.city_map()
	for site_name: String in QUEST_SITE_NAMES:
		var view := map.find_quest_site(site_name)
		assert_object(view).override_failure_message(site_name).is_not_null()
		assert_object(view.quest_site_marker()).is_not_null()
	# The hardware store is the signature quest block; the husband sleeps in
	# its aisle 7, section 13.
	var store := map.find_quest_site("The Hardware Store")
	assert_int(store.kind()).is_equal(CityBlock.Kind.QUEST)
	assert_str(store.landmark_label).is_equal("The Aisle 7")
	# He sleeps between the screws and the sandpaper: the two sites flank the
	# store block on the block row.
	var screws := map.find_quest_site("The Screw Wall")
	var sandpaper := map.find_quest_site("The Sandpaper Rack")
	assert_float(screws.position.x).is_less(store.position.x)
	assert_float(sandpaper.position.x).is_greater(store.position.x)
	# The Crystal Beanroom carries the Sleep Jam arena.
	var beanroom := map.find_quest_site("The Crystal Beanroom")
	assert_int(beanroom.kind()).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_str(beanroom.landmark_label).is_equal("The Sleep Jam")


func test_the_crowd_spawns_the_roster_at_full_density() -> void:
	assert_int(_city.crowd_count()).is_equal(EXPECTED_CROWD_TOTAL)
	var counts := {"neighbor": 0, "tinfoil_man": 0, "karen": 0}
	for i: int in range(_city.crowd_count()):
		var enemy := _city.crowd_enemy(i)
		assert_bool(enemy.is_awake()).is_false()
		counts[enemy.enemy_type.type_id] += 1
	assert_int(counts["neighbor"]).is_equal(EXPECTED_NEIGHBORS)
	assert_int(counts["tinfoil_man"]).is_equal(EXPECTED_TINFOIL_MEN)
	# The outro-only rule of section 16: no Karen ever walks the street crowd.
	assert_int(counts["karen"]).is_equal(EXPECTED_KARENS)
	# The cafe block teaches the basic throw: only neighbors stand there.
	for i: int in range(3):
		assert_str(_city.crowd_enemy(i).enemy_type.type_id).is_equal("neighbor")


func test_the_moss_green_accent_covers_the_blocks() -> void:
	var expected := Color(0.38, 0.6, 0.3, 1)
	var map := _city.city_map()
	for i: int in range(map.block_count()):
		assert_bool(map.block_view(i).accent_color == expected).is_true()


func test_the_new_cafe_is_bigger_than_the_old_one() -> void:
	# Section 10: the Pourtland cafe is tier 3, one step bigger and better
	# than the Steamtle cafe. The player starts inside the bigger safe zone.
	var map := _city.city_map()
	var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
	assert_float(cafe_block.cafe_zone_radius()).is_equal(300.0)
	assert_float(cafe_block.cafe_zone_radius()).is_greater(
		CityRules.cafe_zone_radius(CITY_BALANCE, STEAMTLE_DEFINITION.cafe_tier)
	)
	var safe_zone := cafe_block.safe_zone()
	assert_object(safe_zone).is_not_null()
	assert_bool(safe_zone.has_player_inside()).is_true()


func test_the_player_arrives_with_the_van() -> void:
	# Moving day, section 10: the van of the first city comes along, so the
	# gift beat never plays in Pourtland.
	assert_object(_city.van()).is_not_null()
	assert_bool(_city.van_state.is_owned()).is_true()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.VAN)
	assert_bool(_city.is_moving_day_done()).is_false()
	assert_bool(_city.hud.is_toast_visible()).is_false()


func test_moving_day_completes_at_the_van_once() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.global_position = _city.van().global_position
	var frames := 0
	while not _city.hud.is_toast_visible() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.MOVING_DAY_TEXT)
	assert_bool(_city.is_moving_day_done()).is_true()

	# The beat never replays: a second stay at the van changes nothing.
	player.global_position = _city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	player.global_position = _city.van().global_position
	for _i: int in range(10):
		await get_tree().physics_frame
	assert_bool(_city.moving_day.unload()).is_false()


func test_pourtland_keeps_the_tower_beat_of_the_kit() -> void:
	# City 3 runs the same tower beat: one fuse at the foot, the switch
	# silences the poles and restores one wake-up.
	_wake_the_crowd()
	var player := _city.player
	player.wake_ups.register_sleep()
	player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_bool(_city.progress.is_tower_off()).is_true()
	assert_int(player.wake_ups.remaining).is_equal(5)

	var map := _city.city_map()
	var pole_blocks := CityRules.pole_block_indices(map.block_count(), CITY_BALANCE)
	for index: int in pole_blocks:
		assert_bool(map.block_view(index).pole_zone().is_broadcast_silenced()).is_true()


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()
