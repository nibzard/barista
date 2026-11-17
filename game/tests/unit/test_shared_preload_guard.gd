# ABOUTME: Guards the T102 fix: a resource that two scripts const-preload can
# ABOUTME: bind an empty scene or item, because one compile order loads the
# ABOUTME: resource while the other script's load of it is still running.
extends GdUnitTestSuite

const SCRIPTS_ROOT := "res://scripts"
# The scanner must see the whole script tree; a silent empty walk would pass.
const MINIMUM_SCRIPT_COUNT := 100


func test_every_preloaded_resource_has_one_script_owner() -> void:
	# Two const preloads of one resource form a compile-order hazard: the
	# second script to compile can bind an empty resource while the first
	# load is still in flight. The fix rule: keep one preload and load the
	# other copy at use time.
	var owners: Dictionary = {}
	var script_count := _collect_preload_owners(SCRIPTS_ROOT, owners)
	assert_int(script_count).is_greater_equal(MINIMUM_SCRIPT_COUNT)

	var shared: Array[String] = []
	for resource_path: String in owners:
		if (owners[resource_path] as Array).size() > 1:
			shared.append(resource_path)
	shared.sort()
	for resource_path: String in shared:
		var holder_names: Array[String] = []
		for holder: String in owners[resource_path]:
			holder_names.append(holder)
		(
			assert_bool(false)
			. override_failure_message(
				(
					"%s is const-preloaded by %d scripts (%s); load one at use time instead"
					% [resource_path, holder_names.size(), ", ".join(holder_names)]
				)
			)
			. is_true()
		)


func _collect_preload_owners(dir_path: String, owners: Dictionary) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var script_count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := dir_path + "/" + entry
		if dir.current_is_dir():
			script_count += _collect_preload_owners(child_path, owners)
		elif entry.ends_with(".gd"):
			script_count += 1
			_scan_script(child_path, owners)
		entry = dir.get_next()
	dir.list_dir_end()
	return script_count


func _scan_script(script_path: String, owners: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(script_path)
	var pattern := RegEx.create_from_string('preload\\("(res://[^"]+)"\\)')
	for match: RegExMatch in pattern.search_all(source):
		var resource_path := match.get_string(1)
		if not owners.has(resource_path):
			owners[resource_path] = []
		var holders := owners[resource_path] as Array
		if not holders.has(script_path):
			holders.append(script_path)
