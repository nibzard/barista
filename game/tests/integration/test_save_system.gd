# ABOUTME: Integration tests for the tower save point of section 18, task T085.
# ABOUTME: A run with an injected slot writes the switch and reloads the tower.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const CITY_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const TEST_SAVE_ROOT := "user://test-save-system"


func before_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)


func after_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)


func _slot(case_name: String) -> String:
	return "%s/%s/slot.json" % [TEST_SAVE_ROOT, case_name]


func _remove_dir(path: String) -> void:
	# Godot 4.7 ships no recursive remove, so the suite walks the tree itself
	# and leaves no test slot behind on the device.
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
	for name: String in entries:
		var child := path.path_join(name)
		if DirAccess.dir_exists_absolute(child):
			_remove_dir(child)
		else:
			DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(path)


func _build_city(case_name: String) -> CityRun:
	# Every helper here awaits its builds, so the runs stand ready and the
	# physics spaces settle before the case reads them.
	var city := CITY_SCENE.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot(case_name))
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return city


func _build_intro(case_name: String) -> CityRun:
	var city := INTRO_SCENE.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot(case_name))
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return city


func _build_map() -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = CITY_DEFINITION
	map.balance = CITY_BALANCE
	add_child(auto_free(map))
	await get_tree().physics_frame
	return map


func _pole_zones(map: CityMap) -> Array[SleepZone]:
	var poles: Array[SleepZone] = []
	for i: int in range(map.block_count()):
		var pole := map.block_view(i).pole_zone()
		if pole != null:
			poles.append(pole)
	return poles


func test_the_tower_switch_writes_the_save_slot() -> void:
	var city := await _build_city("switch-writes")
	var tower := city.city_map().broadcast_tower()
	city.player.pickup_item(FUSE_ITEM, 1)

	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()

	# The save point of section 18: the switch writes the slot at once.
	assert_bool(city.save_system.has_save()).is_true()
	(
		assert_int(
			city.save_system.saved_tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING)
		)
		. is_equal(BroadcastTower.Phase.SILENCE)
	)
	# A second system on the same slot sees the write: the record went to disk.
	var reopened := SaveSystem.new(_slot("switch-writes"))
	(
		assert_int(reopened.saved_tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING))
		. is_equal(BroadcastTower.Phase.SILENCE)
	)


func test_a_fresh_run_reloads_the_switched_off_tower() -> void:
	var writer := SaveSystem.new(_slot("reload-off"))
	writer.record_tower_switch("san_coffesco", BroadcastTower.Phase.BIRDSONG)

	var city := await _build_city("reload-off")
	var tower := city.city_map().broadcast_tower()

	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(tower.is_switched_off()).is_true()
	assert_bool(tower.is_wake_up_restored()).is_true()
	for pole: SleepZone in _pole_zones(city.city_map()):
		assert_bool(pole.is_broadcast_silenced()).is_true()
	assert_bool(city.address_audio.is_address_cut()).is_true()
	# The tower beat stays done, so the run keeps its chain and can still
	# complete the city at the boss.
	assert_bool(city.progress.is_tower_off()).is_true()
	assert_int(city.quest_log.current_objective()).is_equal(MainQuest.Objective.BOSS)


func test_a_run_without_a_save_keeps_the_tower_broadcasting() -> void:
	var city := await _build_city("no-save")
	var tower := city.city_map().broadcast_tower()

	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_bool(tower.is_switched_off()).is_false()
	for pole: SleepZone in _pole_zones(city.city_map()):
		assert_bool(pole.is_broadcast_silenced()).is_false()
	assert_bool(city.address_audio.is_address_cut()).is_false()
	assert_bool(city.progress.is_tower_off()).is_false()
	assert_int(city.quest_log.current_objective()).is_equal(MainQuest.Objective.TOWER)


func test_the_intro_tutorial_ignores_a_leftover_save() -> void:
	# The tutorial run is the fresh start of the game: a slot left by an
	# earlier session must not darken its tower, or the fuse step breaks.
	var writer := SaveSystem.new(_slot("intro-leftover"))
	writer.record_tower_switch("san_coffesco", BroadcastTower.Phase.BIRDSONG)

	var city := await _build_intro("intro-leftover")
	var tower := city.city_map().broadcast_tower()

	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_bool(tower.is_switched_off()).is_false()
	assert_bool(city.progress.is_tower_off()).is_false()


func test_the_map_load_path_rests_at_birdsong_and_silences_the_poles() -> void:
	var map := await _build_map()

	map.load_tower_state(BroadcastTower.Phase.SILENCE)

	var tower := map.broadcast_tower()
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(tower.is_switched_off()).is_true()
	for pole: SleepZone in _pole_zones(map):
		assert_bool(pole.is_broadcast_silenced()).is_true()
