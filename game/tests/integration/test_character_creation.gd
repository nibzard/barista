# ABOUTME: Integration tests for character creation, task T046 and section 5.
# ABOUTME: The menu seam, the creation screen, and the look on the intro run.
extends GdUnitTestSuite

const MENU_SCENE := preload("res://scenes/main/menu.tscn")
const CREATION_SCENE := preload("res://scenes/main/character_creation.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const CATALOG := preload("res://resources/player/appearance_catalog.tres")

const INTRO_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
const CITY_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"

const TEST_SAVE_ROOT := "user://test-character-creation"

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


func _stage(scene: Node, save_file_path: String) -> Node:
	# The scene lands as the tree's current scene, the same topology a real
	# scene change acts on, with its save slot pointed at the test root.
	scene.set(&"save_file_path", save_file_path)
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	_scene_leftovers.append(scene)
	return scene


func _press(button: Button) -> void:
	assert_object(button).is_not_null()
	button.pressed.emit()


func _arrived_scene() -> Node:
	# The scene change completes at the end of the frame it was queued in;
	# two frames later the new scene stands as current.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var current := get_tree().current_scene
	if current != null and not _scene_leftovers.has(current):
		_scene_leftovers.append(current)
	return current


func test_the_menu_opens_character_creation_on_a_fresh_slot() -> void:
	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-fresh"))
	# T126: a fresh slot needs no fresh-start gate; Play alone starts the game.
	assert_bool((menu.get_node(^"Center/VBox/NewGameButton") as Button).visible).is_false()
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)

	var current := await _arrived_scene()
	assert_object(current).is_not_null()
	assert_bool(current is CharacterCreation).is_true()


func test_the_menu_skips_creation_when_the_slot_holds_the_look() -> void:
	var system := SaveSystem.new(_slot("menu-has-look"))
	system.record_appearance(CharacterAppearance.from_dict({}, CATALOG))

	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-has-look"))
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CityRun).is_true()
	var run := current as CityRun
	assert_str(run.scene_file_path).is_equal(INTRO_SCENE_PATH)
	assert_bool(run.run_tutorial).is_true()


func test_the_menu_continues_at_the_save_point_over_creation() -> void:
	var system := SaveSystem.new(_slot("menu-continue"))
	var write_error := (
		system
		. record_save_point(
			SaveData.POINT_CAFE_ENTRY,
			{
				"city_id": "san_coffesco",
				"scene_path": CITY_SCENE_PATH,
				"meter_value": 100.0,
				"wake_ups": 5,
				"cups": 12,
			}
		)
	)
	assert_int(write_error).is_equal(OK)
	system.record_appearance(CharacterAppearance.from_dict({}, CATALOG))

	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-continue"))
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CityRun).is_true()
	var run := current as CityRun
	assert_str(run.scene_file_path).is_equal(CITY_SCENE_PATH)
	assert_bool(run.run_tutorial).is_false()
	# The continued run took the parked slot, so it reads the same document
	# the menu read.
	assert_object(run.save_system).is_not_null()


func test_the_menu_defaults_to_the_normal_mode() -> void:
	# Section 9: a fresh slot plays normal, the wake-up system as specced.
	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-mode-default"))
	var normal := menu.get_node(^"Center/VBox/ModeRow/NormalButton") as Button
	var hardcore := menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button
	var note := menu.get_node(^"Center/VBox/ModeNote") as Label
	assert_bool(normal.button_pressed).is_true()
	assert_bool(hardcore.button_pressed).is_false()
	assert_str(note.text).contains("FIVE WAKE-UPS")

	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)
	var current := await _arrived_scene()
	assert_bool(current is CharacterCreation).is_true()
	assert_str(SaveSystem.new(_slot("menu-mode-default")).saved_game_mode()).is_equal(
		SaveData.MODE_NORMAL
	)


func test_the_menu_records_the_hardcore_choice_for_a_fresh_start() -> void:
	# Section 9: the chosen mode rides the slot before the first run starts,
	# so the creation screen and the run behind it play hardcore.
	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-mode-hardcore"))
	_press(menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button)
	var normal := menu.get_node(^"Center/VBox/ModeRow/NormalButton") as Button
	var hardcore := menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button
	var note := menu.get_node(^"Center/VBox/ModeNote") as Label
	assert_bool(hardcore.button_pressed).is_true()
	assert_bool(normal.button_pressed).is_false()
	assert_str(note.text).contains("DEATH DELETES THE SAVE")

	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)
	var current := await _arrived_scene()
	assert_bool(current is CharacterCreation).is_true()
	assert_str(SaveSystem.new(_slot("menu-mode-hardcore")).saved_game_mode()).is_equal(
		SaveData.MODE_HARDCORE
	)


func test_the_menu_keeps_the_mode_of_a_running_save() -> void:
	# A running save answers with its own mode: the buttons never soften a
	# hardcore run that already stands in the slot.
	var system := SaveSystem.new(_slot("menu-mode-running"))
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)
	# The meter rides the save point the way the live recorder writes it, always
	# above zero. A meter of 0 sleeps the continued hardcore run on its first
	# physics tick, and that death deletes the slot before the assert reads it.
	system.record_save_point(
		SaveData.POINT_CAFE_ENTRY,
		{
			"city_id": "san_coffesco",
			"scene_path": CITY_SCENE_PATH,
			"meter_value": 100.0,
			"wake_ups": 3
		}
	)
	system.record_appearance(CharacterAppearance.from_dict({}, CATALOG))

	var menu := _stage(MENU_SCENE.instantiate(), _slot("menu-mode-running"))
	(
		assert_bool((menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button).button_pressed)
		. is_true()
	)
	# T126: the standing save carries its own fresh-start gate beside Play.
	assert_bool((menu.get_node(^"Center/VBox/NewGameButton") as Button).visible).is_true()
	_press(menu.get_node(^"Center/VBox/ModeRow/NormalButton") as Button)
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CityRun).is_true()
	assert_str(SaveSystem.new(_slot("menu-mode-running")).saved_game_mode()).is_equal(
		SaveData.MODE_HARDCORE
	)
	# The continued run plays hardcore: no wake-ups from the first step.
	assert_bool((current as CityRun).player.wake_ups.hardcore).is_true()
	assert_int((current as CityRun).player.wake_ups.remaining).is_equal(0)


func test_new_game_confirmed_clears_the_slot_and_rebuilds_the_barista() -> void:
	# T126: Play only continues, so New Game owns the fresh start. The
	# confirmed reset clears the whole slot, run state and look alike, and the
	# creation screen stands first again.
	var system := SaveSystem.new(_slot("new-game-clears"))
	var write_error := system.record_save_point(
		SaveData.POINT_CAFE_ENTRY,
		{
			"city_id": "san_coffesco",
			"scene_path": CITY_SCENE_PATH,
			"meter_value": 100.0,
			"wake_ups": 5
		}
	)
	assert_int(write_error).is_equal(OK)
	system.record_appearance(CharacterAppearance.from_dict({}, CATALOG))

	var menu := _stage(MENU_SCENE.instantiate(), _slot("new-game-clears"))
	_press(menu.get_node(^"Center/VBox/NewGameButton") as Button)
	# The gate replaces the buttons with the note and its two ways out.
	assert_bool((menu.get_node(^"Center/VBox/NewGameNote") as Label).visible).is_true()
	assert_bool((menu.get_node(^"Center/VBox/ConfirmRow") as HBoxContainer).visible).is_true()
	assert_bool((menu.get_node(^"Center/VBox/PlayButton") as Button).visible).is_false()
	_press(menu.get_node(^"Center/VBox/ConfirmRow/ConfirmButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CharacterCreation).is_true()
	var reopened := SaveSystem.new(_slot("new-game-clears"))
	assert_bool(reopened.has_run_state()).is_false()
	assert_bool(reopened.has_appearance()).is_false()
	assert_str(reopened.saved_game_mode()).is_equal(SaveData.MODE_NORMAL)


func test_new_game_carries_the_picked_mode_into_the_fresh_slot() -> void:
	# T126: the mode buttons own only the fresh start. A normal save stands,
	# the player picks hardcore, and the confirmed new game records the pick.
	var system := SaveSystem.new(_slot("new-game-mode"))
	system.record_save_point(
		SaveData.POINT_CAFE_ENTRY,
		{
			"city_id": "san_coffesco",
			"scene_path": CITY_SCENE_PATH,
			"meter_value": 100.0,
			"wake_ups": 5
		}
	)

	var menu := _stage(MENU_SCENE.instantiate(), _slot("new-game-mode"))
	_press(menu.get_node(^"Center/VBox/ModeRow/HardcoreButton") as Button)
	_press(menu.get_node(^"Center/VBox/NewGameButton") as Button)
	_press(menu.get_node(^"Center/VBox/ConfirmRow/ConfirmButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CharacterCreation).is_true()
	assert_str(SaveSystem.new(_slot("new-game-mode")).saved_game_mode()).is_equal(
		SaveData.MODE_HARDCORE
	)


func test_new_game_cancel_keeps_the_running_save_on_play() -> void:
	# T126: the confirmation stands between a stray tap and the deleted slot.
	# Cancel keeps the save, the buttons return, and Play still continues.
	var system := SaveSystem.new(_slot("new-game-cancel"))
	system.record_save_point(
		SaveData.POINT_CAFE_ENTRY,
		{
			"city_id": "san_coffesco",
			"scene_path": CITY_SCENE_PATH,
			"meter_value": 100.0,
			"wake_ups": 5
		}
	)

	var menu := _stage(MENU_SCENE.instantiate(), _slot("new-game-cancel"))
	_press(menu.get_node(^"Center/VBox/NewGameButton") as Button)
	_press(menu.get_node(^"Center/VBox/ConfirmRow/CancelButton") as Button)
	assert_bool((menu.get_node(^"Center/VBox/NewGameNote") as Label).visible).is_false()
	assert_bool((menu.get_node(^"Center/VBox/ConfirmRow") as HBoxContainer).visible).is_false()
	assert_bool((menu.get_node(^"Center/VBox/PlayButton") as Button).visible).is_true()
	assert_bool((menu.get_node(^"Center/VBox/NewGameButton") as Button).visible).is_true()

	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)
	var current := await _arrived_scene()
	assert_bool(current is CityRun).is_true()
	assert_str((current as CityRun).scene_file_path).is_equal(CITY_SCENE_PATH)


func test_the_start_button_saves_the_selection_and_enters_the_intro() -> void:
	var creation := _stage(CREATION_SCENE.instantiate(), _slot("start-writes-look"))
	# Clean, then stubble, then hipster: the beard row cycles one option per
	# press, and the value label follows the catalog name.
	_press(creation.get_node(^"Main/Right/Rows/RowBeard/Next") as Button)
	_press(creation.get_node(^"Main/Right/Rows/RowBeard/Next") as Button)
	var beard_value := creation.get_node(^"Main/Right/Rows/RowBeard/Value") as Label
	assert_str(beard_value.text).is_equal("HIPSTER")
	_press(creation.get_node(^"Main/Right/Bottom/StartButton") as Button)

	var current := await _arrived_scene()
	assert_bool(current is CityRun).is_true()
	var run := current as CityRun
	assert_str(run.scene_file_path).is_equal(INTRO_SCENE_PATH)
	# The written look persists in the slot and paints the arriving player.
	var reopened := SaveSystem.new(_slot("start-writes-look"))
	assert_str(reopened.saved_appearance(CATALOG).beard_length).is_equal(
		CharacterAppearance.BEARD_HIPSTER
	)
	assert_str(run.player.appearance.beard_length).is_equal(CharacterAppearance.BEARD_HIPSTER)
	assert_object(run.player.visual.get_node_or_null(^"Beard")).is_not_null()


func test_the_intro_run_paints_the_created_barista() -> void:
	var custom := (
		CharacterAppearance
		. from_dict(
			{
				"body_type": CharacterAppearance.BODY_FEMALE,
				"skin_tone": "deep",
				"beard_length": CharacterAppearance.BEARD_WIZARD,
				"hair_style": "mohawk",
				"tattoos": [CharacterAppearance.TATTOO_LEFT_ARM, CharacterAppearance.TATTOO_NECK],
				"hat": "top_hat",
				"goggles": "welding",
				"apron": "leather",
				"boots": "steel",
			},
			CATALOG
		)
	)
	var system := SaveSystem.new(_slot("intro-paints"))
	assert_int(system.record_appearance(custom)).is_equal(OK)
	SaveSystem.park_for_scene_change(system)

	var run := INTRO_SCENE.instantiate() as CityRun
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(run.player.appearance.matches(custom)).is_true()
	var deep_tone := AppearanceCatalog.color_of(CATALOG.skin_tones, "deep")
	assert_bool(run.player.visual.color.is_equal_approx(deep_tone)).is_true()
	assert_object(run.player.visual.get_node_or_null(^"Beard")).is_not_null()
	assert_object(run.player.visual.get_node_or_null(^"Hat")).is_not_null()
	assert_object(run.player.visual.get_node_or_null(^"TattooLeftArm")).is_not_null()
	# The tutorial still runs its first ten minutes, section 19: the creation
	# screen stands before it, never inside it.
	assert_object(run.get_node_or_null(^"Tutorial")).is_not_null()


func test_the_tattoo_row_adds_and_removes_placements() -> void:
	var creation := _stage(CREATION_SCENE.instantiate(), _slot("tattoo-row"))
	var tattoo_value := creation.get_node(^"Main/Right/Rows/RowTattoos/Value") as Label

	_press(creation.get_node(^"Main/Right/Rows/RowTattoos/Add") as Button)
	assert_str(tattoo_value.text).is_equal("1: LEFT ARM")
	_press(creation.get_node(^"Main/Right/Rows/RowTattoos/Add") as Button)
	assert_str(tattoo_value.text).is_equal("2: LEFT ARM, RIGHT ARM")
	_press(creation.get_node(^"Main/Right/Rows/RowTattoos/Remove") as Button)
	assert_str(tattoo_value.text).is_equal("1: LEFT ARM")
	assert_int(creation.appearance().tattoo_count()).is_equal(1)
	(
		assert_bool(
			creation.appearance().tattoo_placements.has(CharacterAppearance.TATTOO_LEFT_ARM)
		)
		. is_true()
	)
