# ABOUTME: Unit tests for the save document and its slot writer and reader.
# ABOUTME: Pure logic plus one throwaway slot under user://, no scene nodes.
extends GdUnitTestSuite

const TEST_SAVE_ROOT := "user://test-save-store"


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


func test_a_new_document_holds_no_tower_state() -> void:
	var data := SaveData.new()
	assert_bool(data.has_tower_state("san_coffesco")).is_false()
	assert_int(data.tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING)).is_equal(
		BroadcastTower.Phase.BROADCASTING
	)


func test_the_document_round_trips_through_a_dictionary() -> void:
	var data := SaveData.new()
	data.set_tower_phase("san_coffesco", BroadcastTower.Phase.SILENCE)
	data.set_tower_phase("pourtland", BroadcastTower.Phase.BIRDSONG)

	var loaded := SaveData.from_dict(data.to_dict())

	assert_int(loaded.tower_phase("san_coffesco", 0)).is_equal(BroadcastTower.Phase.SILENCE)
	assert_int(loaded.tower_phase("pourtland", 0)).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_bool(loaded.has_tower_state("san_coffesco")).is_true()
	assert_bool(loaded.has_tower_state("steamtle")).is_false()


func test_from_dict_rejects_a_document_from_a_future_version() -> void:
	assert_object(SaveData.from_dict({"save_version": 99, "tower_phases": {}})).is_null()
	assert_object(SaveData.from_dict({"tower_phases": {}})).is_null()


func test_from_dict_reads_plain_json_values() -> void:
	# A JSON number loads as a float, so the document stores every phase as
	# an int again, the plain number the tower contract pins.
	var loaded := SaveData.from_dict({"save_version": 1, "tower_phases": {"san_coffesco": 3.0}})
	assert_int(loaded.tower_phase("san_coffesco", 0)).is_equal(3)
	var bare := SaveData.from_dict({"save_version": 1})
	assert_bool(bare.has_tower_state("san_coffesco")).is_false()


func test_the_store_writes_and_reads_one_slot() -> void:
	var store := SaveStore.new(_slot("round-trip"))
	var data := SaveData.new()
	data.set_tower_phase("san_coffesco", BroadcastTower.Phase.SILENCE)

	assert_int(store.write(data)).is_equal(OK)
	assert_bool(store.exists()).is_true()

	var loaded := store.read()
	assert_object(loaded).is_not_null()
	assert_int(loaded.tower_phase("san_coffesco", 0)).is_equal(BroadcastTower.Phase.SILENCE)


func test_a_missing_slot_reads_as_no_save() -> void:
	var store := SaveStore.new(_slot("missing"))
	assert_bool(store.exists()).is_false()
	assert_object(store.read()).is_null()


func test_a_corrupt_slot_reads_as_no_save() -> void:
	var path := _slot("corrupt")
	var store := SaveStore.new(path)
	var data := SaveData.new()
	data.set_tower_phase("san_coffesco", BroadcastTower.Phase.SILENCE)
	store.write(data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("not a save document {")
	file.close()

	assert_bool(store.exists()).is_true()
	assert_object(store.read()).is_null()


func test_delete_save_removes_the_slot() -> void:
	var path := _slot("delete")
	var store := SaveStore.new(path)
	var data := SaveData.new()
	data.set_tower_phase("san_coffesco", BroadcastTower.Phase.FUSED)
	store.write(data)

	assert_bool(store.delete_save()).is_true()
	assert_bool(store.exists()).is_false()
	# A repeat delete counts as done: hardcore death asks twice at most.
	assert_bool(store.delete_save()).is_true()


func test_the_store_builds_the_save_folder_on_demand() -> void:
	var store := SaveStore.new(_slot("fresh-folder") + "/nested/slot.json")
	var data := SaveData.new()
	data.set_tower_phase("san_coffesco", BroadcastTower.Phase.FUSED)

	assert_int(store.write(data)).is_equal(OK)
	assert_bool(store.exists()).is_true()


func test_the_save_system_records_the_tower_switch() -> void:
	var path := _slot("system-record")
	var system := SaveSystem.new(path)

	assert_int(system.record_tower_switch("san_coffesco", BroadcastTower.Phase.SILENCE)).is_equal(
		OK
	)
	assert_bool(system.has_save()).is_true()
	assert_bool(system.has_tower_state("san_coffesco")).is_true()
	(
		assert_int(system.saved_tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING))
		. is_equal(BroadcastTower.Phase.SILENCE)
	)

	# A second system on the same slot sees the write: the record went to disk.
	var reopened := SaveSystem.new(path)
	(
		assert_int(reopened.saved_tower_phase("san_coffesco", BroadcastTower.Phase.BROADCASTING))
		. is_equal(BroadcastTower.Phase.SILENCE)
	)


func test_the_save_system_keeps_cities_apart() -> void:
	var system := SaveSystem.new(_slot("system-cities"))
	system.record_tower_switch("san_coffesco", BroadcastTower.Phase.SILENCE)
	system.record_tower_switch("steamtle", BroadcastTower.Phase.BIRDSONG)

	assert_int(system.saved_tower_phase("san_coffesco", 0)).is_equal(BroadcastTower.Phase.SILENCE)
	assert_int(system.saved_tower_phase("steamtle", 0)).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_int(system.saved_tower_phase("pourtland", BroadcastTower.Phase.BROADCASTING)).is_equal(
		BroadcastTower.Phase.BROADCASTING
	)


func test_delete_save_resets_the_document() -> void:
	var system := SaveSystem.new(_slot("system-reset"))
	system.record_tower_switch("san_coffesco", BroadcastTower.Phase.SILENCE)

	assert_bool(system.delete_save()).is_true()
	assert_bool(system.has_save()).is_false()
	assert_bool(system.has_tower_state("san_coffesco")).is_false()

	# The next record starts a fresh document, not the deleted one.
	system.record_tower_switch("steamtle", BroadcastTower.Phase.FUSED)
	assert_bool(system.has_tower_state("san_coffesco")).is_false()
	assert_bool(system.has_tower_state("steamtle")).is_true()
