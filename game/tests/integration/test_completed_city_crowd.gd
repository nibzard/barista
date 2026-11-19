# ABOUTME: Integration tests for the saved street crowd of a completed city,
# ABOUTME: T134: the woken walkers stay awake on reload and on the return west.
extends GdUnitTestSuite

const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const SAN_COFFESCO_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"
const STEAMTLE_SCENE_PATH := "res://scenes/city/steamtle.tscn"
const TEST_SAVE_ROOT := "user://test-completed-city-crowd"
const MAX_FRAMES_TO_WAIT := 1200
const SETTLE_FRAMES := 6
# Two walkers of the street wake with a sleeper between them, so a restored
# crowd proves its per-walker flags and not a plain awake count.
const WOKEN_INDICES := [1, 3]

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
	# of one walk never turns another case's build into a return trip.
	_remove_dir(TEST_SAVE_ROOT)
	_reset_session_statics()


func after_test() -> void:
	_clear_current_scene()


func test_a_reload_restores_the_woken_street_crowd() -> void:
	# Section 18: every save point of the city holds one awake flag per street
	# walker, so a reload of the completed city builds the street as it stood:
	# the two woken walkers stand awake and the sleepers between them sleep on.
	var city := await _build_city(SAN_COFFESCO_SCENE_PATH)
	assert_int(city.crowd_count()).is_greater(WOKEN_INDICES.max())
	_wake_the_saved_subset(city)
	_complete_the_city(city)

	# A closed app opens again on the same slot and the same scene.
	_clear_current_scene()
	await get_tree().physics_frame
	var reloaded := await _build_city(SAN_COFFESCO_SCENE_PATH)
	_assert_crowd_matches_the_saved_subset(reloaded)
	_assert_the_restore_replayed_no_wake_beat(reloaded)


func test_the_return_west_restores_the_woken_street_crowd() -> void:
	# Section 23: the road west lands the post-game player back in the finished
	# first city, and the stored city world hands the street crowd back with
	# the world beats: the same two walkers stand awake, so the outro promise
	# of the open and awake city reads true on arrival.
	var san_coffesco := await _build_city(SAN_COFFESCO_SCENE_PATH)
	_wake_the_saved_subset(san_coffesco)
	_complete_the_city(san_coffesco)
	san_coffesco.unlock_state.unlock()
	await _settle(SETTLE_FRAMES)

	var steamtle := await _travel_east(san_coffesco, STEAMTLE_SCENE_PATH)
	_complete_the_city(steamtle)
	_park_the_crowd_west(steamtle)
	var west := await _travel_west(steamtle, SAN_COFFESCO_SCENE_PATH)

	assert_bool(west.is_city_complete()).is_true()
	_assert_crowd_matches_the_saved_subset(west)
	_assert_the_restore_replayed_no_wake_beat(west)


func _wake_the_saved_subset(city: CityRun) -> void:
	# The two saved walkers wake by hand, and the sleeping crowd parks west of
	# the walls, away from the player, so no hug slows the beats that follow.
	for i: int in range(city.crowd_count()):
		if WOKEN_INDICES.has(i):
			city.crowd_enemy(i).wake_up()
		else:
			city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)


func _park_the_crowd_west(city: CityRun) -> void:
	# The whole crowd of a passing city stands west of the walls, so no
	# sleeper wanders into the player while the road carries him.
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)


func _assert_crowd_matches_the_saved_subset(city: CityRun) -> void:
	for i: int in range(city.crowd_count()):
		assert_bool(city.crowd_enemy(i).is_awake()).is_equal(WOKEN_INDICES.has(i))


func _assert_the_restore_replayed_no_wake_beat(city: CityRun) -> void:
	# A restored wake colors the figure in at once: the wake front stands
	# complete and never runs, because the slot already recorded the beat.
	var restored := city.crowd_enemy(WOKEN_INDICES[0])
	var fill := restored.visual.get_node_or_null(^"WakeFill") as ColorFill
	assert_object(fill).is_not_null()
	assert_float(fill.progress()).is_equal(1.0)
	assert_bool(fill.is_running()).is_false()


func _complete_the_city(city: CityRun) -> void:
	# The real beats of section 7 through the live run: fuse, switch, and the
	# boss drinking the cure. Each beat writes its save point, so the crowd
	# snapshot rides the slot with them.
	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	var cup := _perfect_cup()
	var market := city.boss() as FishThrowers
	if market != null:
		assert_bool(market.head().try_wake(cup)).is_true()
		return
	var keynote := city.boss() as SamOatman
	assert_bool(keynote.demo_table().try_wake(cup)).is_true()


func _perfect_cup() -> BrewedCup:
	# A perfect cup wakes every boss, section 15, so one brew serves both
	# cities of the walk.
	return BrewedCup.new(
		BREWING_LIBRARY.find_bean("house"),
		BREWING_LIBRARY.find_roast("medium"),
		BREWING_LIBRARY.find_method("filter"),
		"",
		99.0
	)


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


func _travel_east(city: CityRun, expected_path: String) -> CityRun:
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
