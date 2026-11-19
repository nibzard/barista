# ABOUTME: Integration tests for the playable Steamtle run, city 2 on the route.
# ABOUTME: Proves the roster, the Sleepvana sites, the bigger cafe, and moving day.
extends GdUnitTestSuite

const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const SAN_COFFESCO_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600

# The deterministic spawn rule, Steamtle densities [3, 3, 3, 3, 3, 4, 4, 4]:
# the cafe block holds only the basic type, every later block cycles the
# roster of three, so 24 later spawns split evenly and the cafe adds three
# neighbors on top.
const EXPECTED_CROWD_TOTAL := 30
const EXPECTED_NEIGHBORS := 12
const EXPECTED_TOURISTS := 9
const EXPECTED_GAMERS := 9

# The named places of the city: the three Sleepvana sites, section 13, plus
# the public market that carries the Fish Throwers arena.
const QUEST_SITE_NAMES := ["Greenhouse", "The Garage", "The Sofa"]

var _city: CityRun
# The travel test owns whole scenes under the root; they leave the physics
# space when the case ends, one way or the other.
var _travel_leftovers: Array[Node] = []
var _travel_error_spy: PhysicsCallbackErrorSpy = null


func before_test() -> void:
	# A parked traveler from an earlier suite must never leak into the runs
	# this suite builds.
	MoveHandoff.reset()
	_city = STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")
	if _travel_error_spy != null:
		OS.remove_logger(_travel_error_spy)
		_travel_error_spy = null
	var tree := get_tree()
	if tree.current_scene != null and _travel_leftovers.has(tree.current_scene):
		tree.current_scene = null
	for node: Node in _travel_leftovers:
		if is_instance_valid(node):
			node.free()
	_travel_leftovers.clear()
	# A travel case that stops between its park and the arrival must not
	# leave its traveler for the next suite that builds a city.
	MoveHandoff.reset()


func test_the_city_loads_with_the_full_landmark_set() -> void:
	assert_int(_city.city_index).is_equal(2)
	assert_str(_city.definition.city_id).is_equal("steamtle")
	var map := _city.city_map()
	assert_int(map.block_count()).is_equal(9)
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


func test_the_sleepvana_sites_stand_in_the_city() -> void:
	var map := _city.city_map()
	for site_name: String in QUEST_SITE_NAMES:
		var view := map.find_quest_site(site_name)
		assert_object(view).override_failure_message(site_name).is_not_null()
		assert_object(view.quest_site_marker()).is_not_null()
	# The garage is the signature quest block; the encore plays there.
	var garage := map.find_quest_site("The Garage")
	assert_int(garage.kind()).is_equal(CityBlock.Kind.QUEST)
	assert_str(garage.landmark_label).is_equal("Sleepvana")
	# The public market carries the Fish Throwers arena.
	var market := map.find_quest_site("The Public Market")
	assert_int(market.kind()).is_equal(CityBlock.Kind.BOSS_ARENA)
	assert_str(market.landmark_label).is_equal("The Fish Throwers")


func test_the_fish_throwers_play_at_the_public_market() -> void:
	# T029: the boss of the city plays its fight on the market arena, one head
	# fishmonger and his crew, all asleep until the cure lands.
	var map := _city.city_map()
	var market := map.find_quest_site("The Public Market")
	var boss := _city.boss() as FishThrowers
	assert_object(boss).is_not_null()
	assert_vector(boss.global_position).is_equal(market.global_position + market.size * 0.5)
	assert_bool(boss.is_cured()).is_false()
	assert_int(boss.members().size()).is_equal(4)
	assert_bool(boss.head().is_head).is_true()


func test_the_crowd_spawns_the_roster_at_full_density() -> void:
	assert_int(_city.crowd_count()).is_equal(EXPECTED_CROWD_TOTAL)
	var counts := {"neighbor": 0, "tourist": 0, "gamer": 0}
	for i: int in range(_city.crowd_count()):
		var enemy := _city.crowd_enemy(i)
		assert_bool(enemy.is_awake()).is_false()
		counts[enemy.enemy_type.type_id] += 1
	assert_int(counts["neighbor"]).is_equal(EXPECTED_NEIGHBORS)
	assert_int(counts["tourist"]).is_equal(EXPECTED_TOURISTS)
	assert_int(counts["gamer"]).is_equal(EXPECTED_GAMERS)
	# The cafe block teaches the basic throw: only neighbors stand there.
	for i: int in range(3):
		assert_str(_city.crowd_enemy(i).enemy_type.type_id).is_equal("neighbor")


func test_the_hud_binds_to_the_city_player() -> void:
	# T079: the city scene carries its own Hud, and its player_path names
	# this run's Player, so the section 9 chalkboard reads live from the start.
	assert_object(_city.hud.player).is_equal(_city.player)
	assert_str(_city.hud.awake_value.text).is_equal("100/100")


func test_the_rain_blue_accent_covers_the_blocks() -> void:
	var expected := Color(0.424, 0.529, 0.651, 1)
	var map := _city.city_map()
	for i: int in range(map.block_count()):
		assert_bool(map.block_view(i).accent_color == expected).is_true()


func test_the_new_cafe_is_bigger_than_the_old_one() -> void:
	# Section 10: the Steamtle cafe is tier 2, one step bigger and better than
	# the San Coffesco cafe. The player starts inside the bigger safe zone.
	var map := _city.city_map()
	var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
	assert_float(cafe_block.cafe_zone_radius()).is_equal(240.0)
	assert_float(cafe_block.cafe_zone_radius()).is_greater(
		CityRules.cafe_zone_radius(CITY_BALANCE, SAN_COFFESCO_DEFINITION.cafe_tier)
	)
	var safe_zone := cafe_block.safe_zone()
	assert_object(safe_zone).is_not_null()
	assert_bool(safe_zone.has_player_inside()).is_true()


func test_the_player_arrives_with_the_van() -> void:
	# Moving day, section 10: the van of the first city comes along, so the
	# gift beat never plays in Steamtle.
	assert_object(_city.van()).is_not_null()
	assert_bool(_city.van_state.is_owned()).is_true()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.VAN)
	assert_bool(_city.is_moving_day_done()).is_false()
	assert_bool(_city.hud.is_toast_visible()).is_false()


func test_moving_day_completes_at_the_van_once() -> void:
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


func test_steamtle_names_pourtland_as_the_city_east() -> void:
	# T030: Steamtle completes and the road east travels to Pourtland. The
	# wired scene is a Pourtland run: city 3 on the route, the last city of
	# the version, so it names no city further east.
	assert_object(_city.east_city_scene).is_not_null()
	var east := auto_free(_city.east_city_scene.instantiate()) as CityRun
	assert_object(east).is_not_null()
	assert_str(east.definition.city_id).is_equal("pourtland")
	assert_int(east.city_index).is_equal(3)
	assert_object(east.east_city_scene).is_null()


func test_steamtle_keeps_the_tower_beat_of_the_kit() -> void:
	# City 2 runs the same tower beat: one fuse at the foot, the switch
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


func test_the_wired_road_east_travels_outside_the_physics_step() -> void:
	# T088: the road-east trigger fires inside the physics step, so the scene
	# change on the wired east path must wait for idle time. The direct change
	# logged an engine error on every live travel east. The run here sits in
	# the tree as the real current scene, so the change frees its collision
	# nodes exactly like a live playthrough.
	var tree := get_tree()
	var run := SAN_COFFESCO_SCENE.instantiate() as CityRun
	tree.root.add_child(run)
	tree.current_scene = run
	_travel_leftovers.append(run)
	_travel_error_spy = PhysicsCallbackErrorSpy.new()
	OS.add_logger(_travel_error_spy)
	_complete_the_city(run)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(run.roads.east_active()).is_true()

	run.player.global_position = run.roads.east().global_position
	var frames := 0
	while (tree.current_scene == null or tree.current_scene == run) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	var physics_errors := _travel_error_spy.physics_callback_errors()
	OS.remove_logger(_travel_error_spy)
	_travel_error_spy = null

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	var arrived := tree.current_scene as CityRun
	assert_object(arrived).is_not_null()
	assert_str(arrived.definition.city_id).is_equal("steamtle")
	assert_str(physics_errors).is_equal("")

	# The arrived city leaves the tree, so the next case starts clean.
	tree.current_scene = null
	arrived.free()
	await get_tree().physics_frame


func _complete_the_city(run: CityRun) -> void:
	# The wired travel needs a completed city behind it: fuse, switch, cure.
	run.player.pickup_item(FUSE_ITEM, 1)
	var tower := run.city_map().broadcast_tower()
	tower.insert_fuse(run.player)
	tower.switch_off()
	run.notify_boss_cured()


class PhysicsCallbackErrorSpy:
	# An OS logger that records the engine error of a collision removal
	# inside a physics callback. The engine routes every engine-level error
	# through its loggers, so the test reads the same text the live log
	# prints.
	extends Logger

	var _physics_callback_errors: Array[String] = []

	func _log_error(
		_function: String,
		_source_file: String,
		_source_line: int,
		message: String,
		_rationale: String,
		_editor_notify: bool,
		_error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if message.contains("during a physics callback"):
			_physics_callback_errors.append(message)

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func physics_callback_errors() -> String:
		return ", ".join(_physics_callback_errors)
