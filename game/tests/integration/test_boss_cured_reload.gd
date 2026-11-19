# ABOUTME: Integration tests for the saved cure state of the boss fights, T130.
# ABOUTME: A boss-cured save point reloads with the arena show still ended.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const TEST_SAVE_ROOT := "user://test-boss-cured-reload"
# The volley of the market throws one fish every 1.2 seconds, so the watch
# spans two beats: a replayed show could not stay quiet that long.
const VOLLEY_WATCH_FRAMES := 150


func before_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	# A slot parked through a scene change by an earlier case must never leak
	# into this one.
	SaveSystem.take_after_scene_change()
	VanHandoff.reset()
	ColdBrewHandoff.reset()


func after_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	SaveSystem.take_after_scene_change()
	VanHandoff.reset()
	ColdBrewHandoff.reset()


func test_a_cured_sam_oatman_reloads_without_replaying_the_show() -> void:
	# Section 18: the boss-cured save point holds the fight state of the
	# arena. The reload ends the show silent: the guru stands cured, no line
	# speaks, no toast shows, and the completed city hands the road east back.
	var city := await _build_city(SAN_COFFESCO_SCENE, "sam")
	_switch_the_tower_off(city)
	var keynote := city.boss() as SamOatman
	assert_bool(keynote.demo_table().try_wake(_perfect_cup())).is_true()
	_assert_cured_save(city)

	var reloaded := _add_reload(SAN_COFFESCO_SCENE, "sam")
	var cured_show := reloaded.boss() as SamOatman
	var lines: Array[String] = []
	cured_show.spoke.connect(func(line: String) -> void: lines.append(line))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(cured_show.is_cured()).is_true()
	assert_bool(cured_show.slides_zone().is_active()).is_false()
	var screen := cured_show.get_node(^"Screen") as Polygon2D
	assert_bool(screen.color == SamOatman.SCREEN_DARK_COLOR).is_true()
	for member: Polygon2D in cured_show.hall_members():
		assert_bool(member.color == SamOatman.AWAKE_COLOR).is_true()
	assert_int(lines.size()).is_equal(0)
	assert_bool(reloaded.hud.is_toast_visible()).is_false()
	assert_bool(reloaded.progress.is_complete()).is_true()
	assert_bool(reloaded.roads.east_active()).is_true()


func test_a_cured_fish_market_reloads_without_replaying_the_show() -> void:
	# The Steamtle market of the same hook: the reload keeps the crew awake
	# and the volley dead, even with a customer standing in the reach.
	var city := await _build_city(STEAMTLE_SCENE, "market")
	_switch_the_tower_off(city)
	var market := city.boss() as FishThrowers
	assert_bool(market.head().try_wake(_perfect_cup())).is_true()
	_assert_cured_save(city)

	var reloaded := _add_reload(STEAMTLE_SCENE, "market")
	var cured_market := reloaded.boss() as FishThrowers
	var lines: Array[String] = []
	cured_market.spoke.connect(func(line: String) -> void: lines.append(line))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(cured_market.is_cured()).is_true()
	for member: FishSeller in cured_market.members():
		assert_bool(member.is_awake()).is_true()
	assert_int(cured_market.live_fish().size()).is_equal(0)
	assert_int(lines.size()).is_equal(0)
	assert_bool(reloaded.hud.is_toast_visible()).is_false()
	assert_bool(reloaded.progress.is_complete()).is_true()
	assert_bool(reloaded.roads.east_active()).is_true()

	# The sleeping show never restarts: a player inside the market reach
	# draws no fish across two full volley beats.
	reloaded.player.global_position = cured_market.head().global_position
	for _frame: int in range(VOLLEY_WATCH_FRAMES):
		await get_tree().physics_frame
	assert_int(cured_market.live_fish().size()).is_equal(0)


func test_a_cured_sleep_jam_reloads_without_replaying_the_show() -> void:
	# The Pourtland band of the same hook: the reload keeps the song over,
	# the lullaby off, and the band awake from the first frame.
	var city := await _build_city(POURTLAND_SCENE, "band")
	_switch_the_tower_off(city)
	var band := city.boss() as SleepJamBand
	assert_bool(band.try_wake(_perfect_cup())).is_true()
	_assert_cured_save(city)

	var reloaded := _add_reload(POURTLAND_SCENE, "band")
	var cured_band := reloaded.boss() as SleepJamBand
	var lines: Array[String] = []
	cured_band.spoke.connect(func(line: String) -> void: lines.append(line))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(cured_band.is_awake()).is_true()
	assert_bool(cured_band.lullaby_zone().is_active()).is_false()
	for member: Polygon2D in cured_band.band_members():
		assert_bool(member.color == SleepJamBand.AWAKE_COLOR).is_true()
	assert_int(lines.size()).is_equal(0)
	assert_bool(reloaded.hud.is_toast_visible()).is_false()
	assert_bool(reloaded.progress.is_complete()).is_true()


func _build_city(scene: PackedScene, case_name: String) -> CityRun:
	# The live session that cures its boss and writes the slot. The build
	# waits two physics frames, so the run stands ready before the case
	# drives its beats.
	var city := scene.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot(case_name))
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return city


func _add_reload(scene: PackedScene, case_name: String) -> CityRun:
	# The second session on the same slot, the same scene. The caller wires
	# its asserts before the first physics frame, so a replayed opening line
	# cannot slip past unseen.
	var city := scene.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot(case_name))
	add_child(auto_free(city))
	return city


func _assert_cured_save(city: CityRun) -> void:
	# The cure wrote the slot last and the fight state rides it, so the reload
	# has a cure to apply.
	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_BOSS_CURED)
	var saved_boss: Dictionary = city.save_system.saved_run_state().get("boss", {})
	assert_bool(bool(saved_boss.get("cured", false))).is_true()


func _switch_the_tower_off(city: CityRun) -> void:
	# The tower beat before the cure, so the saved city stands complete and
	# its reload arms the road east.
	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()


func _perfect_cup() -> BrewedCup:
	# A perfect cup wakes every boss, section 15, so one brew serves all three
	# fights of the reload cases.
	return BrewedCup.new(
		BREWING_LIBRARY.find_bean("house"),
		BREWING_LIBRARY.find_roast("medium"),
		BREWING_LIBRARY.find_method("filter"),
		"",
		99.0
	)


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
