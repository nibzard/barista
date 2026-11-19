# ABOUTME: Unit tests for the section 18 run-state round-trip of the auto-save.
# ABOUTME: Every save field travels through the slot and comes back unchanged.
extends GdUnitTestSuite

const TEST_SAVE_ROOT := "user://test-save-run-state"
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")


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


func _full_run_state() -> Dictionary:
	# Every section 18 field with its own distinct value, so one lost field
	# fails the round-trip by value: position, meter value, wake-ups, beans
	# and gear (the bag), cups, skill levels, SleepyDex, van level, quest
	# state, tower state, and the run identity.
	return {
		"city_id": "steamtle",
		"scene_path": "res://scenes/city/steamtle.tscn",
		"position": Vector2(1234.5, -67.25),
		"meter_value": 42.5,
		"wake_ups": 3,
		"bag": {"house": 12, "fuse": 2, "thermos_belt": 1, "turkish_pot": 1},
		"cups": 7,
		"thermos_belt": true,
		"brew_hand":
		{
			"bean_id": "geisha_vault",
			"roast_id": "dark",
			"method_id": "espresso",
			"extra_id": "double_shot",
			"score": 92.5,
			"cups_left": 2,
		},
		"skills": {"filter": 4, "espresso": 10},
		"dex": {"found_ids": ["neighbor", "gamer"], "keychain": false},
		"cold_brew":
		{"recipe_id": "cold_brew_concentrate", "bean_id": "geisha_vault", "elapsed": 123.5},
		"van_level": 2,
		"quests":
		{
			"main": {"current": 1, "tower_off": {"san_coffesco": true}, "boss_cured": {}},
			"side": {"sleepvana": 1},
		},
		"progress": {"tower_off": true, "boss_cured": false},
		"boss": {"cured": false},
		"crowd_awake": [false, true, false, true],
		"moving_day": true,
		"tutorial": {"step": 10, "hug": true, "dodge": true, "brew": false},
		"outro": {"step": 4},
		"unlock": true,
		"game_mode": "hardcore",
		"tower_phase": 3,
		"vault_open": true,
	}


func test_every_run_state_field_round_trips_through_the_slot() -> void:
	var system := SaveSystem.new(_slot("round-trip"))
	assert_int(system.record_save_point(SaveData.POINT_BOSS_CURED, _full_run_state())).is_equal(OK)

	# A second system on the same slot sees the write: the record went to
	# disk, and the JSON parse in between touched every value.
	var reopened := SaveSystem.new(_slot("round-trip"))
	assert_bool(reopened.has_run_state()).is_true()
	assert_str(reopened.saved_save_point()).is_equal(SaveData.POINT_BOSS_CURED)
	var loaded := reopened.saved_run_state()
	assert_str(loaded.get("city_id", "")).is_equal("steamtle")
	assert_str(loaded.get("scene_path", "")).is_equal("res://scenes/city/steamtle.tscn")
	assert_vector(loaded.get("position", Vector2.ZERO) as Vector2).is_equal(Vector2(1234.5, -67.25))
	assert_float(loaded.get("meter_value", 0.0)).is_equal(42.5)
	assert_int(loaded.get("wake_ups", 0)).is_equal(3)
	var bag: Dictionary = loaded.get("bag", {})
	assert_int(bag.size()).is_equal(4)
	assert_int(bag.get("house", 0)).is_equal(12)
	assert_int(bag.get("fuse", 0)).is_equal(2)
	assert_int(bag.get("thermos_belt", 0)).is_equal(1)
	assert_int(bag.get("turkish_pot", 0)).is_equal(1)
	assert_int(loaded.get("cups", 0)).is_equal(7)
	assert_bool(loaded.get("thermos_belt", false)).is_true()
	var brew_hand: Dictionary = loaded.get("brew_hand", {})
	assert_str(brew_hand.get("bean_id", "")).is_equal("geisha_vault")
	assert_str(brew_hand.get("roast_id", "")).is_equal("dark")
	assert_str(brew_hand.get("method_id", "")).is_equal("espresso")
	assert_str(brew_hand.get("extra_id", "")).is_equal("double_shot")
	assert_float(brew_hand.get("score", 0.0)).is_equal(92.5)
	assert_int(brew_hand.get("cups_left", 0)).is_equal(2)
	var skills: Dictionary = loaded.get("skills", {})
	assert_int(skills.get("filter", 0)).is_equal(4)
	assert_int(skills.get("espresso", 0)).is_equal(10)
	var dex: Dictionary = loaded.get("dex", {})
	assert_int((dex.get("found_ids", []) as Array).size()).is_equal(2)
	assert_bool(dex.get("keychain", true)).is_false()
	var cold_brew: Dictionary = loaded.get("cold_brew", {})
	assert_str(cold_brew.get("recipe_id", "")).is_equal("cold_brew_concentrate")
	assert_str(cold_brew.get("bean_id", "")).is_equal("geisha_vault")
	assert_float(cold_brew.get("elapsed", 0.0)).is_equal(123.5)
	assert_int(loaded.get("van_level", 0)).is_equal(2)
	var quests: Dictionary = loaded.get("quests", {})
	var main: Dictionary = quests.get("main", {})
	assert_int(main.get("current", -1)).is_equal(1)
	assert_bool((main.get("tower_off", {}) as Dictionary).get("san_coffesco", false)).is_true()
	assert_int((quests.get("side", {}) as Dictionary).get("sleepvana", 0)).is_equal(1)
	var progress: Dictionary = loaded.get("progress", {})
	assert_bool(progress.get("tower_off", false)).is_true()
	assert_bool(progress.get("boss_cured", true)).is_false()
	var boss: Dictionary = loaded.get("boss", {})
	assert_bool(boss.get("cured", true)).is_false()
	assert_array(loaded.get("crowd_awake", [])).is_equal([false, true, false, true])
	assert_bool(loaded.get("moving_day", false)).is_true()
	var tutorial: Dictionary = loaded.get("tutorial", {})
	assert_int(tutorial.get("step", -1)).is_equal(10)
	assert_bool(tutorial.get("hug", false)).is_true()
	assert_bool(tutorial.get("dodge", false)).is_true()
	assert_bool(tutorial.get("brew", true)).is_false()
	var outro: Dictionary = loaded.get("outro", {})
	assert_int(outro.get("step", 0)).is_equal(4)
	assert_bool(loaded.get("unlock", false)).is_true()
	assert_str(loaded.get("game_mode", "")).is_equal("hardcore")
	assert_int(loaded.get("tower_phase", -1)).is_equal(3)
	assert_bool(loaded.get("vault_open", false)).is_true()


func test_the_brewed_batch_in_hand_round_trips_the_slot() -> void:
	# Section 18: a brewed special cup in hand at the save point reloads as the
	# same brew, not as plain cups. The payload travels by id and comes back
	# through the library.
	var hand := BrewHand.new()
	hand.receive(_special_cup(), 2)
	var run := _full_run_state()
	run["brew_hand"] = hand.save_state()
	var system := SaveSystem.new(_slot("brew-hand"))
	assert_int(system.record_save_point(SaveData.POINT_CAFE_ENTRY, run)).is_equal(OK)

	var reopened := SaveSystem.new(_slot("brew-hand"))
	var reloaded := BrewHand.new()
	reloaded.load_state(reopened.saved_run_state().get("brew_hand", {}), LIBRARY)
	assert_int(reloaded.cups_left()).is_equal(2)
	var payload := reloaded.active_payload()
	assert_object(payload).is_not_null()
	assert_str(payload.bean.bean_id).is_equal("geisha_vault")
	assert_str(payload.roast.roast_id).is_equal("dark")
	assert_str(payload.method.method_id).is_equal("espresso")
	assert_str(payload.extra_id).is_equal("double_shot")
	assert_float(payload.score).is_equal(92.5)
	# The reloaded payload still matches its recipe, so the reload wakes the
	# same sleepwalkers the brew would have.
	assert_str(payload.matched_recipe(LIBRARY).recipe_id).is_equal("double_espresso")


func test_a_brew_hand_with_unknown_ids_loads_plain() -> void:
	# A data change can retire a bean. The unknown id drops away, so the slot
	# never breaks: the cups stay in the supply as plain ones.
	var hand := BrewHand.new()
	hand.receive(_special_cup(), 2)
	var retired := hand.save_state()
	retired["bean_id"] = "ghost_bean"

	var reloaded := BrewHand.new()
	reloaded.load_state(retired, LIBRARY)
	assert_int(reloaded.cups_left()).is_equal(0)
	assert_object(reloaded.active_payload()).is_null()
	assert_dict(reloaded.save_state()).is_empty()


func test_a_plain_cup_hand_saves_nothing() -> void:
	# A hand of plain cups from the pot holds no brew, and the last spent cup
	# empties the batch: both save no payload.
	var hand := BrewHand.new()
	assert_dict(hand.save_state()).is_empty()
	hand.receive(_special_cup(), 1)
	hand.consume()
	assert_dict(hand.save_state()).is_empty()


func _special_cup() -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("geisha_vault"),
		LIBRARY.find_roast("dark"),
		LIBRARY.find_method("espresso"),
		"double_shot",
		92.5
	)


func test_a_later_save_point_overwrites_the_run_state() -> void:
	var system := SaveSystem.new(_slot("overwrite"))
	var first := _full_run_state()
	first["city_id"] = "san_coffesco"
	first["scene_path"] = "res://scenes/city/san_coffesco.tscn"
	first["wake_ups"] = 5
	first["tower_phase"] = 0
	system.record_save_point(SaveData.POINT_CAFE_ENTRY, first)

	var second := _full_run_state()
	second["wake_ups"] = 2
	second["tower_phase"] = 3
	assert_int(system.record_save_point(SaveData.POINT_TOWER_SWITCH, second)).is_equal(OK)

	var reopened := SaveSystem.new(_slot("overwrite"))
	assert_str(reopened.saved_save_point()).is_equal(SaveData.POINT_TOWER_SWITCH)
	assert_int(reopened.saved_run_state().get("wake_ups", 0)).is_equal(2)
	# The cross-city maps merge: the first city keeps its phase beside the new.
	assert_int(reopened.saved_tower_phase("san_coffesco", -1)).is_equal(0)
	assert_int(reopened.saved_tower_phase("steamtle", -1)).is_equal(3)


func test_a_slot_without_a_run_state_continues_nowhere() -> void:
	var system := SaveSystem.new(_slot("no-run-state"))
	assert_bool(system.has_run_state()).is_false()
	assert_str(system.continue_scene_path()).is_empty()
	assert_str(system.saved_save_point()).is_empty()
	assert_dict(system.saved_run_state()).is_empty()


func test_continue_scene_path_names_the_saved_scene() -> void:
	var system := SaveSystem.new(_slot("continue"))
	system.record_save_point(SaveData.POINT_CAFE_ENTRY, _full_run_state())

	var reopened := SaveSystem.new(_slot("continue"))
	assert_str(reopened.continue_scene_path()).is_equal("res://scenes/city/steamtle.tscn")
	assert_bool(reopened.is_vault_open("steamtle")).is_true()
	assert_bool(reopened.is_vault_open("pourtland")).is_false()


func test_a_save_from_an_older_version_reads_as_no_save() -> void:
	# A version 4 slot predates the boss cure state of the arena show. The
	# grown document reads it as no save at all, so the menu starts the fresh
	# tutorial, section 18.
	var path := _slot("old-version")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"save_version": 4, "tower_phases": {"san_coffesco": 3}}')
	file.close()

	var system := SaveSystem.new(path)
	assert_bool(system.has_save()).is_true()
	assert_bool(system.has_run_state()).is_false()
	assert_str(system.continue_scene_path()).is_empty()


func test_the_mode_round_trips_and_a_later_save_point_overwrites_it() -> void:
	var system := SaveSystem.new(_slot("mode-overwrite"))
	var run := _full_run_state()
	run["game_mode"] = SaveData.MODE_HARDCORE
	assert_int(system.record_save_point(SaveData.POINT_CAFE_ENTRY, run)).is_equal(OK)

	var reopened := SaveSystem.new(_slot("mode-overwrite"))
	assert_str(reopened.saved_game_mode()).is_equal(SaveData.MODE_HARDCORE)

	var normal_run := _full_run_state()
	normal_run["game_mode"] = SaveData.MODE_NORMAL
	assert_int(system.record_save_point(SaveData.POINT_TOWER_SWITCH, normal_run)).is_equal(OK)
	assert_str(SaveSystem.new(_slot("mode-overwrite")).saved_game_mode()).is_equal(
		SaveData.MODE_NORMAL
	)


func test_the_menu_writes_the_mode_before_any_run_state() -> void:
	# Section 9: the menu records the selection before the first run starts.
	# The mode alone is no run state: it continues nowhere by itself.
	var system := SaveSystem.new(_slot("mode-before-run"))
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)

	var reopened := SaveSystem.new(_slot("mode-before-run"))
	assert_str(reopened.saved_game_mode()).is_equal(SaveData.MODE_HARDCORE)
	assert_bool(reopened.has_run_state()).is_false()
	assert_str(reopened.continue_scene_path()).is_empty()


func test_a_foreign_mode_value_reads_as_normal() -> void:
	# A corrupt mode field must never break the run: the document reads the
	# specced default, the wake-up system of section 9.
	var system := SaveSystem.new(_slot("mode-foreign"))
	assert_int(system.record_game_mode(SaveData.MODE_HARDCORE)).is_equal(OK)
	var path := _slot("mode-foreign")
	var text := FileAccess.open(path, FileAccess.READ).get_as_text()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text.replace("hardcore", "nightmare"))
	file.close()

	assert_str(SaveSystem.new(path).saved_game_mode()).is_equal(SaveData.MODE_NORMAL)
