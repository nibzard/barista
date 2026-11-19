# ABOUTME: Guards the T102/T112 fix classes: a resource two scripts
# const-preload can bind empty when one load runs inside the other script's
# compile, and so can a resource a script const-preloads while a scene or
# .tres file also references it.
extends GdUnitTestSuite

const SCRIPTS_ROOT := "res://scripts"
const CONTENT_ROOTS: Array[String] = ["res://scenes", "res://resources"]
# Each scan must see the whole tree; a silent empty walk would pass.
const MINIMUM_SCRIPT_COUNT := 100
const MINIMUM_CONTENT_FILE_COUNT := 100


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


func test_no_preloaded_resource_is_also_referenced_by_content() -> void:
	# A script const preload runs inside the script compile; a scene or
	# .tres reference loads the same resource at instantiate time. When both
	# name one resource, one channel can bind an empty resource while the
	# other load is still in flight. The T102 failure observed the
	# script-script variant; this widened class has no observed failure, so
	# the rule stays preventive: the script loads such a resource at use
	# time (T112).
	var owners: Dictionary = {}
	var script_count := _collect_preload_owners(SCRIPTS_ROOT, owners)
	assert_int(script_count).is_greater_equal(MINIMUM_SCRIPT_COUNT)

	var referrers: Dictionary = {}
	var content_file_count := _collect_content_references(CONTENT_ROOTS, referrers)
	assert_int(content_file_count).is_greater_equal(MINIMUM_CONTENT_FILE_COUNT)

	var colliding: Array[String] = []
	for resource_path: String in owners:
		if referrers.has(resource_path):
			colliding.append(resource_path)
	colliding.sort()
	for resource_path: String in colliding:
		var holder_names: Array[String] = []
		for holder: String in owners[resource_path]:
			holder_names.append(holder)
		var referrer_names: Array[String] = []
		for referrer: String in referrers[resource_path]:
			referrer_names.append(referrer)
		(
			assert_bool(false)
			. override_failure_message(
				(
					"%s is const-preloaded by %s and referenced by %s; load it at use time in the script"
					% [resource_path, ", ".join(holder_names), ", ".join(referrer_names)]
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


func _collect_content_references(dir_paths: Array[String], referrers: Dictionary) -> int:
	var file_count := 0
	for dir_path: String in dir_paths:
		file_count += _collect_content_references_in(dir_path, referrers)
	return file_count


func _collect_content_references_in(dir_path: String, referrers: Dictionary) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var file_count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := dir_path + "/" + entry
		if dir.current_is_dir():
			file_count += _collect_content_references_in(child_path, referrers)
		elif entry.ends_with(".tscn") or entry.ends_with(".tres"):
			file_count += 1
			_scan_content_file(child_path, referrers)
		entry = dir.get_next()
	dir.list_dir_end()
	return file_count


func _scan_content_file(file_path: String, referrers: Dictionary) -> void:
	var source := FileAccess.get_file_as_string(file_path)
	var pattern := RegEx.create_from_string('path="(res://[^"]+)"')
	for match: RegExMatch in pattern.search_all(source):
		var resource_path := match.get_string(1)
		if not referrers.has(resource_path):
			referrers[resource_path] = []
		var holders := referrers[resource_path] as Array
		if not holders.has(file_path):
			holders.append(file_path)
