# ABOUTME: Integration tests for the V1 playthrough modes, T055.
# ABOUTME: Normal and Hardcore death handling through the real boot chain.
extends GdUnitTestSuite

const MENU_SCENE := preload("res://scenes/main/menu.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const CREATION_SCENE_PATH := "res://scenes/main/character_creation.tscn"
const INTRO_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
const SAN_COFFESCO_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"
const MENU_SCENE_PATH := "res://scenes/main/menu.tscn"
const TEST_SAVE_ROOT := "user://test-v1-modes"
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
	_reset_session_statics()


func after_test() -> void:
	_clear_current_scene()


func test_a_normal_sleep_wakes_the_player_in_the_cafe() -> void:
	# Section 18: an empty meter costs one wake-up and wakes the player in
	# the cafe. The world stays as it is, and the slot holds the new count.
	var city := await _build_current_city(SAN_COFFESCO_SCENE_PATH)
	await _await_cafe_entry_save(city)
	city.crowd_enemy(0).wake_up()
	city.player.wake_ups.remaining = 2
	city.player.global_position = city.city_map().broadcast_tower().global_position
	await get_tree().physics_frame
	city.player.sleep_meter.drain(200.0)

	var slept := 0
	while city.player.wake_ups.remaining != 1 and slept < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		slept += 1
	assert_int(city.player.wake_ups.remaining).is_equal(1)
	assert_bool(city.player.is_asleep()).is_false()
	assert_vector(city.player.global_position).is_equal(
		city.city_map().cafe_spawn().global_position
	)
	assert_bool(city.crowd_enemy(0).is_awake()).is_true()
	assert_str(city.status_label.text).is_not_equal(CityRun.DEATH_TEXT)

	# The wake in the cafe is an entry: the slot now holds one wake-up less.
	var recorded := 0
	while (
		city.save_system.saved_run_state().get("wake_ups", -1) != 1
		and recorded < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		recorded += 1
	var reopened := SaveSystem.new(_slot_path())
	assert_int(reopened.saved_run_state().get("wake_ups", -1)).is_equal(1)


func test_a_full_death_reloads_the_last_save_with_its_wake_ups() -> void:
	# Section 18: at zero wake-ups the game reloads the last save through a
	# real scene change, and the count comes back from the save point.
	var city := await _build_current_city(SAN_COFFESCO_SCENE_PATH)
	await _await_cafe_entry_save(city)
	var cafe_spawn := city.city_map().cafe_spawn().global_position

	# The cafe-entry save must carry THIS run, not the slot an earlier case
	# left, and never a spot a teleport raced past. The area overlap of a
	# fresh city needs frames, so the player walks out of the cafe, waits the
	# overlap flush out, and walks back in: the save then holds the cafe spot
	# and the new count together.
	city.player.wake_ups.remaining = 3
	city.player.global_position = city.city_map().broadcast_tower().global_position
	for flush: int in range(12):
		await get_tree().physics_frame
	city.player.global_position = cafe_spawn
	var entry := 0
	while (
		(
			city.save_system.saved_run_state().get("wake_ups", -1) != 3
			or (
				(
					(city.save_system.saved_run_state().get("position", Vector2.INF) as Vector2)
					. distance_to(cafe_spawn)
				)
				> 1.0
			)
		)
		and entry < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		entry += 1
	assert_int(entry).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(city.save_system.saved_run_state().get("wake_ups", -1)).is_equal(3)

	city.player.wake_ups.remaining = 0
	city.player.global_position = city.city_map().broadcast_tower().global_position
	city.player.sleep_meter.drain(200.0)
	var frames := 0
	while (
		(get_tree().current_scene == null or get_tree().current_scene == city)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)

	var reloaded := get_tree().current_scene as CityRun
	assert_object(reloaded).is_not_null()
	assert_str(reloaded.scene_file_path).is_equal(SAN_COFFESCO_SCENE_PATH)
	assert_bool(reloaded.save_system.has_run_state()).is_true()
	assert_int(reloaded.player.wake_ups.remaining).is_equal(3)
	assert_vector(reloaded.player.global_position).is_equal(cafe_spawn)


func test_the_menu_mode_select_boots_a_hardcore_run() -> void:
	# Section 9: the mode rides the slot from the menu. A hardcore start
	# holds no wake-ups, and the tower switch restores none. The boot needs a
	# fresh slot: a saved run sends the menu Play straight into the city.
	_remove_dir(TEST_SAVE_ROOT)
	_reset_session_statics()
	var menu := _build_menu()
	(menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button).pressed.emit()
	(menu.get_node(^"Center/VBox/PlayButton") as Button).pressed.emit()
	var creation := await _await_scene_change(menu, CREATION_SCENE_PATH)
	creation.set(&"save_file_path", _slot_path())
	(creation.get_node(^"Main/Right/Bottom/StartButton") as Button).pressed.emit()
	var city := await _await_scene_change(creation, INTRO_SCENE_PATH) as CityRun
	await _settle(SETTLE_FRAMES)

	assert_bool(city.player.wake_ups.hardcore).is_true()
	assert_int(city.player.wake_ups.remaining).is_equal(0)
	assert_bool(city.player.wake_ups.has_wake_ups()).is_false()
	await get_tree().process_frame
	assert_str(city.hud.wake_ups_value.text).is_equal("none")

	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_int(city.player.wake_ups.remaining).is_equal(0)
	assert_str(city.save_system.saved_game_mode()).is_equal(SaveData.MODE_HARDCORE)


func test_a_hardcore_death_deletes_the_slot_and_returns_to_the_menu() -> void:
	# Section 18: the first sleep of a hardcore run ends the game, deletes
	# the slot, and the end screen sends the player back to the menu.
	var system := SaveSystem.new(_slot_path())
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)
	var city := await _build_current_city(SAN_COFFESCO_SCENE_PATH)
	await _await_cafe_entry_save(city)
	assert_bool(system.has_save()).is_true()

	city.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame
	assert_bool(city.player.is_asleep()).is_true()
	assert_str(city.status_label.text).is_equal(CityRun.HARDCORE_DEATH_TEXT)
	assert_bool(city.status_label.visible).is_true()
	assert_bool(city.restart_button.visible).is_true()
	assert_bool(system.has_save()).is_false()
	var reopened := SaveSystem.new(_slot_path())
	assert_bool(reopened.has_run_state()).is_false()

	city.restart_button.pressed.emit()
	var frames := 0
	while (
		(get_tree().current_scene == null or get_tree().current_scene == city)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(get_tree().current_scene.scene_file_path).is_equal(MENU_SCENE_PATH)


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


func _build_menu() -> Node:
	var menu := MENU_SCENE.instantiate()
	menu.set(&"save_file_path", _slot_path())
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	_scene_leftovers.append(menu)
	return menu


func _build_current_city(scene_path: String) -> CityRun:
	var scene := load(scene_path) as PackedScene
	var city := scene.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot_path())
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return city


func _await_cafe_entry_save(city: CityRun) -> void:
	var frames := 0
	while not city.save_system.has_run_state() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(city.save_system.has_run_state()).is_true()


func _await_scene_change(old_scene: Node, expected_path: String) -> Node:
	var frames := 0
	while (
		(get_tree().current_scene == null or get_tree().current_scene == old_scene)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	var current := get_tree().current_scene
	assert_object(current).is_not_null()
	assert_str(current.scene_file_path).is_equal(expected_path)
	return current


func _settle(frames: int) -> void:
	for _frame: int in range(frames):
		await get_tree().physics_frame
