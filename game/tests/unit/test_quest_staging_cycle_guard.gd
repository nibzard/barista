# ABOUTME: Guards the T112 quest-staging cut: the directors the city run
# ABOUTME: drives must not name the CityRun class, and a woken quest body
# ABOUTME: must not name its stage class, so their compiles stay out of the
# ABOUTME: run script's cycle.
extends GdUnitTestSuite

# The run hands every director a plain Node handle; a typed CityRun hint in
# any of these trees ties the whole quest staging back into city_run.gd.
const DIRECTOR_ROOTS: Array[String] = [
	"res://scripts/quests", "res://scripts/tutorial", "res://scripts/ending", "res://scripts/audio"
]
# The quest bodies the stages spawn. Each entry maps a body script to the
# stage class it must stay off; the stage hands the body a plain Node handle.
const QUEST_BODIES: Dictionary = {
	"res://scripts/quests/band_member.gd": "SleepvanaStage",
	"res://scripts/quests/aisle_7_husband.gd": "Aisle7Stage",
	"res://scripts/quests/aisle_7_wife.gd": "Aisle7Stage",
}
# Each scan must see the whole tree; a silent empty walk would pass.
const MINIMUM_DIRECTOR_SCRIPT_COUNT := 30


func test_directors_do_not_name_the_city_run_class() -> void:
	# The quest, tutorial, ending, and audio directors run inside the city
	# run and reach everything through its Node handle. The word CityRun in
	# any of them re-ties their compile to the city script (T112).
	var script_count := 0
	var offenders: Array[String] = []
	for root_path: String in DIRECTOR_ROOTS:
		script_count += _collect_class_name_offenders(root_path, "CityRun", offenders)
	assert_int(script_count).is_greater_equal(MINIMUM_DIRECTOR_SCRIPT_COUNT)

	for offender: String in offenders:
		(
			assert_bool(false)
			. override_failure_message(
				(
					"%s names the CityRun class; take the run as a Node and duck-call it (T112)"
					% offender
				)
			)
			. is_true()
		)


func test_quest_bodies_do_not_name_their_stage_class() -> void:
	# The stages hand their spawned bodies a plain Node stage handle, so the
	# body compiles without the staging graph. A typed stage hint in a body
	# rebuilds the stage-body-script cycle (T112).
	for body_path: String in QUEST_BODIES:
		var stage_class: String = QUEST_BODIES[body_path]
		if not assert_bool(FileAccess.file_exists(body_path)).is_true():
			continue
		var body_offenders: Array[String] = []
		_collect_class_name_offenders_in_file(body_path, stage_class, body_offenders)
		for offender: String in body_offenders:
			(
				assert_bool(false)
				. override_failure_message(
					(
						"%s names the %s class; take the stage as a Node and duck-call it (T112)"
						% [offender, stage_class]
					)
				)
				. is_true()
			)


func _collect_class_name_offenders(
	dir_path: String, class_name_word: String, offenders: Array
) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var script_count := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var child_path := dir_path + "/" + entry
		if dir.current_is_dir():
			script_count += _collect_class_name_offenders(child_path, class_name_word, offenders)
		elif entry.ends_with(".gd"):
			script_count += 1
			_collect_class_name_offenders_in_file(child_path, class_name_word, offenders)
		entry = dir.get_next()
	dir.list_dir_end()
	return script_count


func _collect_class_name_offenders_in_file(
	script_path: String, class_name_word: String, offenders: Array
) -> void:
	var source := FileAccess.get_file_as_string(script_path)
	if source.is_empty():
		return
	var pattern := RegEx.create_from_string("\\b%s\\b" % class_name_word)
	for match: RegExMatch in pattern.search_all(source):
		offenders.append("%s:%d" % [script_path, source.count("\n", 0, match.get_start()) + 1])
