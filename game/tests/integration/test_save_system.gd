# ABOUTME: Integration tests for the section 18 auto-save system, task T040.
# ABOUTME: The three save points, the full reload, and the sleep-versus-death paths.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const CITY_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const HOUSE_BEANS_ITEM := preload("res://resources/items/beans/house.tres")
const THERMOS_BELT_ITEM := preload("res://resources/items/gear/thermos_belt.tres")
const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const TEST_SAVE_ROOT := "user://test-save-system"
const MAX_FRAMES_TO_WAIT := 600
const CITY_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"

# The scenes a case parked as the tree's current scene; after_test frees them
# so the next case starts clean.
var _scene_leftovers: Array[Node] = []


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
	# The runs a case parked as the current scene leave the tree, so the next
	# case starts clean. A scene change already freed some of them.
	var tree := get_tree()
	var current := tree.current_scene
	if current != null:
		tree.current_scene = null
		current.free()
	for node: Node in _scene_leftovers:
		if is_instance_valid(node):
			node.free()
	_scene_leftovers.clear()


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


func _build_pourtland(case_name: String) -> CityRun:
	var city := POURTLAND_SCENE.instantiate() as CityRun
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


func _await_cafe_entry_save(city: CityRun) -> void:
	# The cafe-entry poll lands within the first physics steps of the spawn.
	# The loop caps the wait, so a broken poll fails the case instead of
	# hanging it.
	var frames := 0
	while not city.save_system.has_run_state() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(city.save_system.has_run_state()).is_true()


func _switch_the_tower_off(city: CityRun) -> void:
	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()


func _pole_zones(map: CityMap) -> Array[SleepZone]:
	var poles: Array[SleepZone] = []
	for i: int in range(map.block_count()):
		var pole := map.block_view(i).pole_zone()
		if pole != null:
			poles.append(pole)
	return poles


func _special_cup() -> BrewedCup:
	# A brewed special cup, like one the espresso minigame earned: a payload
	# no plain pot refills.
	return BrewedCup.new(
		BREWING_LIBRARY.find_bean("geisha_vault"),
		BREWING_LIBRARY.find_roast("dark"),
		BREWING_LIBRARY.find_method("espresso"),
		"double_shot",
		92.5
	)


func test_entry_to_the_cafe_writes_the_slot() -> void:
	var city := await _build_city("cafe-entry")
	await _await_cafe_entry_save(city)

	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_CAFE_ENTRY)
	var saved := city.save_system.saved_run_state()
	assert_vector(saved.get("position", Vector2.ZERO) as Vector2).is_equal(
		city.city_map().cafe_spawn().global_position
	)
	assert_str(saved.get("scene_path", "")).is_equal(CITY_SCENE_PATH)

	# A second system on the same slot sees the write: the record went to disk.
	var reopened := SaveSystem.new(_slot("cafe-entry"))
	assert_str(reopened.saved_save_point()).is_equal(SaveData.POINT_CAFE_ENTRY)


func test_the_tower_switch_writes_the_slot() -> void:
	var city := await _build_city("switch-writes")
	city.player.wake_ups.remaining = 2

	_switch_the_tower_off(city)

	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_TOWER_SWITCH)
	(
		assert_int(
			city.save_system.saved_tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING)
		)
		. is_equal(BroadcastTower.Phase.SILENCE)
	)
	# The wake-up restore landed before the record: the slot holds the new
	# count, so a reload revives the player with it.
	var reopened := SaveSystem.new(_slot("switch-writes"))
	assert_int(reopened.saved_run_state().get("wake_ups", -1)).is_equal(3)


func test_a_closed_app_reloads_the_whole_save_point() -> void:
	# Section 18: the player closed the app anywhere, and the game reloads at
	# the last save point. Session one mutates every saved field, switches the
	# tower, and ends; session two rebuilds the city from the slot alone.
	var city := await _build_city("reload-all")
	city.player.wake_ups.remaining = 1
	city.player.sleep_meter.value = 30.0
	city.player.pickup_item(THERMOS_BELT_ITEM, 1)
	city.player.coffee_supply.cups = 3
	city.player.pickup_item(HOUSE_BEANS_ITEM, 5)
	city.player.brew_hand.receive(_special_cup(), 2)
	city.player.brewing_skills.record_master_lesson(&"filter")
	city.sleepy_dex().meet("tech_bro")
	city.van_state.acquire()
	city.unlock_state.unlock()
	var tower := city.city_map().broadcast_tower()
	city.player.global_position = tower.global_position

	_switch_the_tower_off(city)

	var saved := city.save_system.saved_run_state()
	var saved_position: Vector2 = saved.get("position", Vector2.ZERO)
	# Session one ends; the run leaves the tree like a closed app. The free is
	# immediate, so the second city never shares one physics space with it.
	city.free()
	await get_tree().physics_frame

	var reloaded := await _build_city("reload-all")

	# The tower beat stays done and the world rests at the save point.
	assert_int(reloaded.city_map().broadcast_tower().phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(reloaded.city_map().broadcast_tower().is_switched_off()).is_true()
	for pole: SleepZone in _pole_zones(reloaded.city_map()):
		assert_bool(pole.is_broadcast_silenced()).is_true()
	assert_bool(reloaded.address_audio.is_address_cut()).is_true()
	assert_bool(reloaded.progress.is_tower_off()).is_true()
	assert_int(reloaded.quest_log.current_objective()).is_equal(MainQuest.Objective.BOSS)
	# Every field of the run state came back: position, meter, wake-ups, beans
	# and gear (the bag), cups with the belt limit, skill levels, SleepyDex,
	# van level, and the purchase.
	assert_vector(reloaded.player.global_position).is_equal_approx(
		saved_position, Vector2(1.0, 1.0)
	)
	assert_float(reloaded.player.sleep_meter.value).is_between(29.0, 31.0)
	assert_int(reloaded.player.wake_ups.remaining).is_equal(2)
	assert_int(reloaded.player.inventory.count("house")).is_equal(5)
	assert_bool(reloaded.player.inventory.has_item("fuse")).is_false()
	assert_bool(reloaded.player.coffee_supply.has_thermos_belt).is_true()
	assert_int(reloaded.player.coffee_supply.cups).is_equal(3)
	assert_int(reloaded.player.brewing_skills.skill(&"filter")).is_equal(2)
	# The brewed batch in hand came back as its brew: a special cup saves as a
	# special cup, never as a plain one.
	assert_int(reloaded.player.brew_hand.cups_left()).is_equal(2)
	var payload: BrewedCup = reloaded.player.brew_hand.active_payload()
	assert_object(payload).is_not_null()
	assert_str(payload.bean.bean_id).is_equal("geisha_vault")
	assert_str(payload.method.method_id).is_equal("espresso")
	assert_float(payload.score).is_equal(92.5)
	assert_bool(reloaded.sleepy_dex().is_found("tech_bro")).is_true()
	assert_bool(reloaded.van_state.is_owned()).is_true()
	assert_bool(reloaded.bridge_gate().is_open()).is_true()
	# The reload hands the road back: the city needs only the boss now, and a
	# second wake-up never arrives from the load path.
	assert_bool(reloaded.is_city_complete()).is_false()


func test_a_steep_survives_the_closed_app_and_comes_back_ready() -> void:
	# Section 8 on section 18: the player starts the cold brew, closes the app
	# mid-steep, and the reload stands the steep where it stood. The rest of
	# the wait runs out in the reloaded run, and the cup collects at the
	# method ceiling.
	var city := await _build_city("cold-steep")
	(
		assert_bool(
			city.cold_fridge.start(
				BREWING_LIBRARY.find_recipe("cold_brew_concentrate"),
				BREWING_LIBRARY.find_bean("golden_coast_arabica"),
				BREWING_LIBRARY.find_method("cold_brew")
			)
		)
		. is_true()
	)
	for _i: int in range(200):
		city.cold_fridge.tick(1.0)

	# The tower switch is the save point that catches the running steep.
	_switch_the_tower_off(city)
	var saved: Dictionary = city.save_system.saved_run_state().get("cold_brew", {})
	assert_str(saved.get("recipe_id", "")).is_equal("cold_brew_concentrate")
	assert_str(saved.get("bean_id", "")).is_equal("golden_coast_arabica")
	assert_float(saved.get("elapsed", 0.0)).is_between(199.0, 201.0)
	city.free()
	await get_tree().physics_frame

	var reloaded := await _build_city("cold-steep")
	assert_bool(reloaded.cold_fridge.is_steeping()).is_true()
	assert_str(reloaded.cold_fridge.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")
	assert_float(reloaded.cold_fridge.remaining_seconds()).is_between(99.0, 101.0)

	for _i: int in range(101):
		reloaded.cold_fridge.tick(1.0)
	assert_bool(reloaded.cold_fridge.is_ready()).is_true()
	var cup := reloaded.cold_fridge.collect(BREWING_LIBRARY)
	assert_float(cup.score).is_equal(BREWING_LIBRARY.find_method("cold_brew").score_ceiling)
	assert_str(cup.bean.bean_id).is_equal("golden_coast_arabica")


func test_a_run_without_a_save_keeps_the_tower_broadcasting() -> void:
	var city := await _build_city("no-save")

	assert_bool(city.save_system.has_save()).is_false()
	assert_bool(city.save_system.has_run_state()).is_false()
	var tower := city.city_map().broadcast_tower()

	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_bool(tower.is_switched_off()).is_false()
	for pole: SleepZone in _pole_zones(city.city_map()):
		assert_bool(pole.is_broadcast_silenced()).is_false()
	assert_bool(city.address_audio.is_address_cut()).is_false()
	assert_bool(city.progress.is_tower_off()).is_false()
	assert_int(city.quest_log.current_objective()).is_equal(MainQuest.Objective.TOWER)


func test_the_intro_tutorial_ignores_a_foreign_save() -> void:
	# The tutorial run is the fresh start of the game: a slot written by the
	# plain city scene must not darken its tower or bleed its state in, or the
	# fuse step breaks.
	var writer := SaveSystem.new(_slot("intro-foreign"))
	writer.record_save_point(
		SaveData.POINT_TOWER_SWITCH,
		{"city_id": "san_coffesco", "scene_path": CITY_SCENE_PATH, "tower_phase": 3}
	)

	var city := await _build_intro("intro-foreign")
	var tower := city.city_map().broadcast_tower()

	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BROADCASTING)
	assert_bool(tower.is_switched_off()).is_false()
	assert_bool(city.progress.is_tower_off()).is_false()
	assert_int(city.quest_log.current_objective()).is_equal(MainQuest.Objective.TOWER)


func test_meter_sleep_does_not_reload_the_save() -> void:
	# Section 18: an empty meter wakes the player in the cafe and costs one
	# wake-up. The world stays as it is: the same run keeps playing, a woken
	# sleepwalker stays awake, and the slot gains the wake-in-cafe entry
	# instead of a reload.
	var city := await _build_city("sleep-path")
	await _await_cafe_entry_save(city)
	city.crowd_enemy(0).wake_up()

	city.player.wake_ups.remaining = 2
	city.player.global_position = city.city_map().broadcast_tower().global_position
	await get_tree().physics_frame
	city.player.sleep_meter.drain(200.0)
	# The sleep lands on the next player tick, the wake teleports the player
	# into the cafe, and the entry record lands one overlap flush later. Both
	# waits run on the outcome, never on a fixed frame count.
	var slept := 0
	while city.player.wake_ups.remaining != 1 and slept < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		slept += 1
	var recorded := 0
	while (
		city.save_system.saved_run_state().get("wake_ups", -1) != 1
		and recorded < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		recorded += 1

	assert_bool(is_instance_valid(city) and city.is_inside_tree()).is_true()
	assert_int(city.player.wake_ups.remaining).is_equal(1)
	assert_vector(city.player.global_position).is_equal(
		city.city_map().cafe_spawn().global_position
	)
	assert_bool(city.crowd_enemy(0).is_awake()).is_true()
	assert_str(city.status_label.text).is_not_equal(CityRun.DEATH_TEXT)

	# The wake in the cafe is an entry: the slot now holds one wake-up less.
	var reopened := SaveSystem.new(_slot("sleep-path"))
	assert_str(reopened.saved_save_point()).is_equal(SaveData.POINT_CAFE_ENTRY)
	assert_int(reopened.saved_run_state().get("wake_ups", -1)).is_equal(1)


func test_full_death_reloads_the_last_save_with_its_wake_ups() -> void:
	# Section 18: at zero wake-ups the game reloads the last save, with the
	# wake-ups from that save. The run sits in the tree as the real current
	# scene, so the death fires the reload exactly like a live playthrough.
	var tree := get_tree()
	var city := CITY_SCENE.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot("death-path"))
	tree.root.add_child(city)
	tree.current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await _await_cafe_entry_save(city)
	var cafe_spawn := city.city_map().cafe_spawn().global_position

	# A re-entry into the cafe rewrites the slot with fewer wake-ups, so the
	# reload can prove the count came from the save and not from a fresh start.
	city.player.wake_ups.remaining = 3
	city.player.global_position = city.city_map().broadcast_tower().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	city.player.global_position = cafe_spawn
	var entry := 0
	while (
		city.save_system.saved_run_state().get("wake_ups", -1) != 3 and entry < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		entry += 1
	assert_int(city.save_system.saved_run_state().get("wake_ups", -1)).is_equal(3)

	city.player.wake_ups.remaining = 0
	city.player.global_position = city.city_map().broadcast_tower().global_position
	city.player.sleep_meter.drain(200.0)

	# The scene change frees the dying run, so nothing reads it past the
	# travel. A timed-out loop means the death took the overlay branch instead
	# of the reload, and the frame cap fails the case.
	var frames := 0
	while (
		(tree.current_scene == null or tree.current_scene == city) and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	var reloaded := tree.current_scene as CityRun
	assert_object(reloaded).is_not_null()
	assert_str(reloaded.scene_file_path).is_equal(CITY_SCENE_PATH)
	# The arriving run reads the parked slot and restores the save point: the
	# wake-ups come back from the save, and the player stands at the cafe
	# entry the slot was written at.
	assert_bool(reloaded.save_system.has_run_state()).is_true()
	assert_int(reloaded.player.wake_ups.remaining).is_equal(3)
	assert_vector(reloaded.player.global_position).is_equal(cafe_spawn)


func test_a_hardcore_run_holds_no_wake_ups() -> void:
	# Section 9: hardcore mode rides the slot into the run. The player holds
	# no wake-ups from the first step, the HUD says so, and the tower switch
	# restores none while the save point still records the hardcore mode.
	var system := SaveSystem.new(_slot("hardcore-rules"))
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)
	var city := await _build_city("hardcore-rules")

	assert_bool(city.player.wake_ups.hardcore).is_true()
	assert_int(city.player.wake_ups.remaining).is_equal(0)
	assert_bool(city.player.wake_ups.has_wake_ups()).is_false()
	await get_tree().process_frame
	# The icon row holds no clocks at all: the mode never granted a life
	# the row could count.
	assert_int(city.hud.wake_clocks.clock_count()).is_equal(0)
	assert_int(city.hud.wake_clocks.standing_count()).is_equal(0)

	_switch_the_tower_off(city)
	assert_int(city.player.wake_ups.remaining).is_equal(0)
	var saved := city.save_system.saved_run_state()
	assert_str(saved.get("game_mode", "")).is_equal(SaveData.MODE_HARDCORE)
	assert_int(saved.get("wake_ups", -1)).is_equal(0)


func test_a_hardcore_save_point_reloads_still_hardcore() -> void:
	# The mode outlives every save point: a closed app reopens into a run
	# that still holds no wake-ups.
	var system := SaveSystem.new(_slot("hardcore-reload"))
	system.record_game_mode(SaveData.MODE_HARDCORE)
	var city := await _build_city("hardcore-reload")
	await _await_cafe_entry_save(city)
	city.free()
	await get_tree().physics_frame

	var reloaded := await _build_city("hardcore-reload")
	assert_bool(reloaded.player.wake_ups.hardcore).is_true()
	assert_int(reloaded.player.wake_ups.remaining).is_equal(0)
	assert_str(reloaded.save_system.saved_game_mode()).is_equal(SaveData.MODE_HARDCORE)


func test_hardcore_death_deletes_the_save_and_ends_the_run() -> void:
	# Section 18, hardcore mode: the first sleep ends the game and death
	# deletes the slot. No reload fires, the end screen owns the display, and
	# a reopened slot holds nothing at all.
	var tree := get_tree()
	var system := SaveSystem.new(_slot("hardcore-death"))
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)
	var city := CITY_SCENE.instantiate() as CityRun
	city.save_system = system
	tree.root.add_child(city)
	tree.current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await _await_cafe_entry_save(city)
	assert_bool(system.has_save()).is_true()

	city.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame

	assert_bool(city.player.is_asleep()).is_true()
	assert_str(city.status_label.text).is_equal(CityRun.HARDCORE_DEATH_TEXT)
	assert_bool(city.status_label.visible).is_true()
	assert_bool(city.restart_button.visible).is_true()
	assert_bool(system.has_save()).is_false()
	# No reload ever fires: the run that died stays the current scene past
	# any deferred travel window.
	var frames := 0
	while frames < 10:
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_bool(get_tree().current_scene == city).is_true()
	var reopened := SaveSystem.new(_slot("hardcore-death"))
	assert_bool(reopened.has_save()).is_false()
	assert_bool(reopened.has_run_state()).is_false()
	assert_str(reopened.saved_game_mode()).is_equal(SaveData.MODE_NORMAL)


func test_hardcore_death_returns_through_the_menu() -> void:
	# The restart of a deleted run never quietly restarts the city in a
	# normal mode the player never chose: the way back runs through the menu
	# and its mode select.
	var tree := get_tree()
	var system := SaveSystem.new(_slot("hardcore-menu-return"))
	system.record_game_mode(SaveData.MODE_HARDCORE)
	var city := CITY_SCENE.instantiate() as CityRun
	city.save_system = system
	tree.root.add_child(city)
	tree.current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await get_tree().physics_frame

	city.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame
	assert_str(city.status_label.text).is_equal(CityRun.HARDCORE_DEATH_TEXT)
	city.restart_button.pressed.emit()

	var frames := 0
	while (
		(tree.current_scene == null or tree.current_scene == city) and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(tree.current_scene.scene_file_path).is_equal("res://scenes/main/menu.tscn")


func test_the_road_east_carries_the_running_steep_to_the_next_city() -> void:
	# T119: the move east is the one scene travel of the route, and the cold
	# brew crosses it with the player. The steep starts after the last save
	# point of the west city, so the slot alone cannot carry it: the arrival
	# must read it from the travel itself.
	var tree := get_tree()
	var city := CITY_SCENE.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot("steep-travel"))
	tree.root.add_child(city)
	tree.current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The city completes; the boss-cured save point lands as the last one.
	_switch_the_tower_off(city)
	city.notify_boss_cured()
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The steep starts after that save point and runs while the player walks
	# east, two thirds of the way through the wait.
	(
		assert_bool(
			city.cold_fridge.start(
				BREWING_LIBRARY.find_recipe("cold_brew_concentrate"),
				BREWING_LIBRARY.find_bean("golden_coast_arabica"),
				BREWING_LIBRARY.find_method("cold_brew")
			)
		)
		. is_true()
	)
	for _i: int in range(200):
		city.cold_fridge.tick(1.0)
	# The slot holds no steep: its save point predates the start.
	assert_dict(city.save_system.saved_run_state().get("cold_brew", {})).is_empty()

	# The player steps on the road east; the scene travels to Steamtle.
	city.player.global_position = city.roads.east().global_position
	var frames := 0
	while (
		(tree.current_scene == null or tree.current_scene == city) and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	var east := tree.current_scene as CityRun
	assert_object(east).is_not_null()
	assert_str(east.definition.city_id).is_equal("steamtle")
	# The steep crossed the road: the same recipe and bean, and the elapsed
	# seconds stand where the west city left them.
	assert_bool(east.cold_fridge.is_steeping()).is_true()
	assert_str(east.cold_fridge.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")
	assert_str(east.cold_fridge.steeped_bean().bean_id).is_equal("golden_coast_arabica")
	assert_float(east.cold_fridge.remaining_seconds()).is_between(99.0, 101.0)
	# The rest of the wait runs out in the east city, and the cup collects at
	# the method ceiling.
	for _i: int in range(101):
		east.cold_fridge.tick(1.0)
	assert_bool(east.cold_fridge.is_ready()).is_true()
	var cup := east.cold_fridge.collect(BREWING_LIBRARY)
	assert_float(cup.score).is_equal(BREWING_LIBRARY.find_method("cold_brew").score_ceiling)
	assert_str(cup.bean.bean_id).is_equal("golden_coast_arabica")


func test_the_boss_cured_save_point_holds_the_outro_state() -> void:
	# The last city completes at the boss cure: the save lands after the
	# completion, so it holds the outro that just began, and a reload never
	# replays a played ending.
	var city := await _build_pourtland("boss-save")
	_switch_the_tower_off(city)
	city.notify_boss_cured()

	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_BOSS_CURED)
	var saved := city.save_system.saved_run_state()
	var outro: Dictionary = saved.get("outro", {})
	assert_int(outro.get("step", -1)).is_greater_equal(OutroFlow.Step.ARRIVAL)
	assert_bool(city.progress.is_complete()).is_true()

	# A second session on the same slot rests where the save stands.
	var reloaded := await _build_pourtland("boss-save")
	assert_bool(reloaded.progress.is_complete()).is_true()
	var outro_node := reloaded.get_node(^"Outro") as OutroDirector
	assert_int(outro_node.flow.current_step()).is_greater_equal(OutroFlow.Step.ARRIVAL)


func test_the_map_load_path_rests_at_birdsong_and_silences_the_poles() -> void:
	var map := await _build_map()

	map.load_tower_state(BroadcastTower.Phase.SILENCE)

	var tower := map.broadcast_tower()
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(tower.is_switched_off()).is_true()
	for pole: SleepZone in _pole_zones(map):
		assert_bool(pole.is_broadcast_silenced()).is_true()
