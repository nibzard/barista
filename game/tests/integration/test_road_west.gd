# ABOUTME: Integration tests for the road west of section 23, T096: the
# ABOUTME: post-game player returns from Pourtland to the earlier cities and
# ABOUTME: walks the open route back east, with every beat kept.
extends GdUnitTestSuite

const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const SAN_COFFESCO_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"
const STEAMTLE_SCENE_PATH := "res://scenes/city/steamtle.tscn"
const POURTLAND_SCENE_PATH := "res://scenes/city/pourtland.tscn"
const TEST_SAVE_ROOT := "user://test-road-west"
const MAX_FRAMES_TO_WAIT := 1200
const SETTLE_FRAMES := 6

var _scene_leftovers: Array[Node] = []


func before() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	_reset_session_statics()


func after() -> void:
	_reset_session_statics()
	_clear_current_scene()
	for node: Node in _scene_leftovers:
		if is_instance_valid(node):
			node.free()
	_scene_leftovers.clear()
	_remove_dir(TEST_SAVE_ROOT)


func before_test() -> void:
	# Each case walks its own slot from a clean folder, so the saved city world
	# of one walk never turns another case's first visit into a return trip.
	_remove_dir(TEST_SAVE_ROOT)
	_reset_session_statics()


func after_test() -> void:
	_clear_current_scene()


func test_the_route_scenes_name_their_cities_west() -> void:
	# Pourtland returns to Steamtle and Steamtle to San Coffesco. The west
	# destination rides as a path, because a west ext_resource would close a
	# load cycle with the east links. The first city holds no road west, and
	# the last city keeps none east, section 16.
	var pourtland := (load(POURTLAND_SCENE_PATH) as PackedScene).instantiate() as CityRun
	assert_str(pourtland.west_city_path).is_equal(STEAMTLE_SCENE_PATH)
	assert_object(pourtland.east_city_scene).is_null()
	var steamtle := (load(pourtland.west_city_path) as PackedScene).instantiate() as CityRun
	assert_str(steamtle.definition.city_id).is_equal("steamtle")
	assert_int(steamtle.city_index).is_equal(2)
	assert_str(steamtle.west_city_path).is_equal(SAN_COFFESCO_SCENE_PATH)
	assert_object(steamtle.east_city_scene).is_not_null()
	var san_coffesco := (load(steamtle.west_city_path) as PackedScene).instantiate() as CityRun
	assert_str(san_coffesco.definition.city_id).is_equal("san_coffesco")
	assert_int(san_coffesco.city_index).is_equal(1)
	assert_str(san_coffesco.west_city_path).is_empty()
	assert_object(san_coffesco.east_city_scene).is_not_null()
	pourtland.free()
	steamtle.free()
	san_coffesco.free()


func test_the_road_west_stays_closed_until_the_city_completes() -> void:
	var city := await _build_city(STEAMTLE_SCENE_PATH)
	assert_object(city.roads.west()).is_not_null()
	assert_bool(city.roads.west_active()).is_false()
	var west_signals: Array[int] = []
	city.west_road_taken.connect(func() -> void: west_signals.append(1))

	# The player presses against the west wall before the beats land: the
	# trigger stays deaf, like the road east.
	city.player.global_position = city.roads.west().global_position
	await _settle(SETTLE_FRAMES)
	assert_int(west_signals.size()).is_equal(0)
	assert_bool(city.roads.west_active()).is_false()

	# The player steps back inside before the beats land, so the arming of the
	# road never fires the travel by itself. The physics frame between the move
	# and the beats flushes the overlap state of the stand on the trigger.
	city.player.global_position = city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	_complete_the_city(city)
	await _settle(SETTLE_FRAMES)
	assert_bool(city.is_city_complete()).is_true()
	assert_bool(city.roads.west_active()).is_true()
	assert_bool(city.roads.east_active()).is_true()
	assert_int(west_signals.size()).is_equal(0)


func test_the_post_game_walk_returns_west_and_back() -> void:
	# One slot walks the route east to the credits, then west through the open
	# cities to San Coffesco and east again: the finished cities stay finished,
	# the traveler crosses both ways, and the ended version never replays.
	var san_coffesco := await _build_city(SAN_COFFESCO_SCENE_PATH)
	_complete_the_city(san_coffesco)
	san_coffesco.unlock_state.unlock()
	await _settle(SETTLE_FRAMES)
	var steamtle := await _travel_east(san_coffesco, STEAMTLE_SCENE_PATH)
	assert_str(steamtle.definition.city_id).is_equal("steamtle")
	# Moving day first, section 10: the unload beat lands before the city
	# beats write their save points, so the stored world holds it done.
	steamtle.player.global_position = steamtle.van().global_position + Vector2(0.0, -50.0)
	var unloaded := 0
	while not steamtle.is_moving_day_done() and unloaded < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		unloaded += 1
	assert_bool(steamtle.is_moving_day_done()).is_true()
	_complete_the_city(steamtle)
	var pourtland := await _travel_east(steamtle, POURTLAND_SCENE_PATH)
	assert_str(pourtland.definition.city_id).is_equal("pourtland")
	assert_bool(pourtland.roads.west_active()).is_false()

	# The version ends: the Karen blocks the road east and the credits roll.
	_complete_the_city(pourtland)
	var outro := pourtland.get_node(^"Outro") as OutroDirector
	await _await_outro_step(outro, OutroFlow.Step.CREDITS)
	var skip := InputEventKey.new()
	skip.pressed = true
	outro._unhandled_input(skip)
	await _await_outro_step(outro, OutroFlow.Step.POST_GAME)
	assert_bool(pourtland.player.is_input_locked()).is_false()
	assert_bool(pourtland.roads.west_active()).is_true()
	assert_bool(pourtland.sleepy_dex().is_found("karen")).is_true()

	# The road west lands in a finished Steamtle: the world came back with the
	# traveler, and both roads stand open around the awake city.
	var west := await _travel_west(pourtland, STEAMTLE_SCENE_PATH)
	assert_bool(west.is_city_complete()).is_true()
	assert_bool(west.city_map().broadcast_tower().is_switched_off()).is_true()
	assert_bool((west.boss() as FishThrowers).is_cured()).is_true()
	assert_bool(west.roads.east_active()).is_true()
	assert_bool(west.roads.west_active()).is_true()
	assert_int(west.quest_log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	# The traveler crossed west: the van, the paid bridge, and the dex.
	assert_bool(west.van_state.is_owned()).is_true()
	assert_bool(west.unlock_state.is_unlocked()).is_true()
	assert_bool(west.sleepy_dex().is_found("karen")).is_true()
	assert_bool(west.is_moving_day_done()).is_true()
	# T134: the woken street stays woken, section 23: the saved city world
	# carries one awake flag per walker, so the crowd the walk woke before the
	# save points stands awake on the return, asleep walkers and all.
	for i: int in range(west.crowd_count()):
		assert_bool(west.crowd_enemy(i).is_awake()).is_true()

	# The first city stands west of Steamtle, awake, with its paid bridge open.
	var first := await _travel_west(west, SAN_COFFESCO_SCENE_PATH)
	assert_str(first.definition.city_id).is_equal("san_coffesco")
	assert_bool(first.is_city_complete()).is_true()
	assert_bool((first.boss() as SamOatman).is_cured()).is_true()
	assert_bool(first.city_map().broadcast_tower().is_switched_off()).is_true()
	assert_bool(first.bridge_gate().is_open()).is_true()
	assert_bool(first.roads.east_active()).is_true()
	assert_object(first.roads.west()).is_null()
	assert_bool(first.van_state.is_owned()).is_true()
	# The plain city scene never replays the tutorial of the intro run.
	assert_object(first.get_node_or_null(^"Tutorial")).is_null()
	# The first city crowd stands awake the same way, T134.
	for i: int in range(first.crowd_count()):
		assert_bool(first.crowd_enemy(i).is_awake()).is_true()

	# The road east returns through the finished cities: the ended version
	# never replays, the Karen keeps the deck, and the road west reopens.
	var east := await _travel_east(first, STEAMTLE_SCENE_PATH)
	assert_bool(east.is_city_complete()).is_true()
	var again := await _travel_east(east, POURTLAND_SCENE_PATH)
	assert_bool(again.is_city_complete()).is_true()
	var staged_outro := again.get_node(^"Outro") as OutroDirector
	assert_int(staged_outro.flow.current_step()).is_equal(OutroFlow.Step.POST_GAME)
	var staged := 0
	while staged_outro.karen() == null and staged < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		staged += 1
	assert_object(staged_outro.karen()).is_not_null()
	assert_bool(staged_outro.karen().is_in_place()).is_true()
	assert_bool(again.player.is_input_locked()).is_false()
	assert_bool(again.roads.west_active()).is_true()


func _complete_the_city(city: CityRun) -> void:
	# The real beats of section 7 through the live run: fuse, switch, and the
	# boss drinking the cure, so the saved boss state holds the cure too.
	_wake_the_crowd(city)
	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	var cup := _perfect_cup()
	var market := city.boss() as FishThrowers
	if market != null:
		assert_bool(market.head().try_wake(cup)).is_true()
		return
	var band := city.boss() as SleepJamBand
	if band != null:
		assert_bool(band.try_wake(cup)).is_true()
		return
	var keynote := city.boss() as SamOatman
	assert_bool(keynote.demo_table().try_wake(cup)).is_true()


func _perfect_cup() -> BrewedCup:
	# A perfect cup wakes every boss, section 15, so one brew serves all three
	# cities of the walk.
	return BrewedCup.new(
		BREWING_LIBRARY.find_bean("house"),
		BREWING_LIBRARY.find_roast("medium"),
		BREWING_LIBRARY.find_method("filter"),
		"",
		99.0
	)


func _travel_east(city: CityRun, expected_path: String) -> CityRun:
	# The slot parks for the change like a player build hands it east.
	return await _travel(city, city.roads.east(), expected_path)


func _travel_west(city: CityRun, expected_path: String) -> CityRun:
	return await _travel(city, city.roads.west(), expected_path)


func _travel(city: CityRun, road: Area2D, expected_path: String) -> CityRun:
	# The helper awaits the scene change, so every caller must await it too.
	SaveSystem.park_for_scene_change(SaveSystem.new(_slot_path()))
	city.player.global_position = road.global_position
	var frames := 0
	while (
		(get_tree().current_scene == null or get_tree().current_scene == city)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	var current := get_tree().current_scene
	assert_object(current).is_not_null()
	assert_str(current.scene_file_path).is_equal(expected_path)
	await _settle(SETTLE_FRAMES)
	return current as CityRun


func _build_city(scene_path: String) -> CityRun:
	# The run lands as the tree's current scene with its own slot, the same
	# topology a real scene change acts on.
	var scene := load(scene_path) as PackedScene
	var city := scene.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot_path())
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _settle(SETTLE_FRAMES)
	return city


func _await_outro_step(outro: OutroDirector, step: OutroFlow.Step) -> void:
	# The helper awaits physics frames, so every caller must await it too.
	var frames := 0
	while outro.flow.current_step() != step and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)


func _wake_the_crowd(city: CityRun) -> void:
	# Awakened sleepwalkers never hug or stun, so the flow stays steady.
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()


func _settle(frames: int) -> void:
	for _frame: int in range(frames):
		await get_tree().physics_frame


func _reset_session_statics() -> void:
	SaveSystem.take_after_scene_change()
	VanHandoff.reset()
	ColdBrewHandoff.reset()
	MoveHandoff.reset()


func _clear_current_scene() -> void:
	var tree := get_tree()
	var current := tree.current_scene
	if current != null:
		tree.current_scene = null
		current.free()


func _slot_path() -> String:
	return TEST_SAVE_ROOT + "/slot.json"


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for child: String in entries:
		var child_path := path.path_join(child)
		if DirAccess.dir_exists_absolute(child_path):
			_remove_dir(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	DirAccess.remove_absolute(path)
