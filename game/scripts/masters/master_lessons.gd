# ABOUTME: MasterLessons is the school of the brewing masters, section 8.
# ABOUTME: Pure logic with no nodes: one master, one lesson, three deliveries.
class_name MasterLessons
extends RefCounted

signal lesson_taken(master_id: String, lesson_number: int)
signal recipe_granted(recipe_id: String)
signal school_complete(master_id: String)

var _masters: Array[BrewingMaster] = []
var _skills: BrewingSkills = null
var _lessons: Dictionary = {}
var _known_recipes: Array[String] = []


func _init(masters: Array[BrewingMaster] = [], skills: BrewingSkills = null) -> void:
	_masters = masters.duplicate()
	_skills = skills


func lessons_per_master() -> int:
	# Section 14: every master teaches three lessons. The number lives in the
	# brewing balance, not in this class.
	if _skills == null or _skills.balance == null:
		return 0
	return _skills.balance.lessons_per_master


func find_master(master_id: String) -> BrewingMaster:
	for master: BrewingMaster in _masters:
		if master.master_id == master_id:
			return master
	return null


func register_master(master: BrewingMaster) -> bool:
	# A quest can open its master mid-run, like the Turkish husband of the
	# Aisle 7, section 13: the sleeper becomes the teacher. A master joins the
	# school once; a second registration changes nothing.
	if master == null or master.master_id.is_empty():
		return false
	if find_master(master.master_id) != null:
		return false
	_masters.append(master)
	return true


func master_for_city(city_id: String) -> BrewingMaster:
	for master: BrewingMaster in _masters:
		if master.city_id == city_id:
			return master
	return null


func masters() -> Array[BrewingMaster]:
	return _masters.duplicate()


func lessons_taken(master_id: String) -> int:
	return int(_lessons.get(master_id, 0))


func lessons_remaining(master_id: String) -> int:
	return maxi(0, lessons_per_master() - lessons_taken(master_id))


func can_take_lesson(master_id: String) -> bool:
	return find_master(master_id) != null and _skills != null and lessons_remaining(master_id) > 0


func take_lesson(master_id: String) -> Array[String]:
	# One lesson: the master's craft trains by the master lesson gain, faster
	# than solo practice, and the recipe of the lesson joins the known set.
	var master := find_master(master_id)
	if not can_take_lesson(master_id) or master == null:
		return []
	_lessons[master_id] = lessons_taken(master_id) + 1
	var lesson_number: int = _lessons[master_id]
	for method_id: String in master.taught_methods:
		_skills.record_master_lesson(method_id)
	var granted: Array[String] = []
	if lesson_number <= master.lesson_recipes.size():
		var recipe_id: String = master.lesson_recipes[lesson_number - 1]
		if not recipe_id.is_empty() and not _known_recipes.has(recipe_id):
			_known_recipes.append(recipe_id)
			granted.append(recipe_id)
			recipe_granted.emit(recipe_id)
	lesson_taken.emit(master_id, lesson_number)
	if is_school_complete(master_id):
		school_complete.emit(master_id)
	return granted


func is_school_complete(master_id: String) -> bool:
	return lessons_per_master() > 0 and lessons_taken(master_id) >= lessons_per_master()


func is_recipe_known(recipe_id: String) -> bool:
	return _known_recipes.has(recipe_id)


func known_recipes() -> Array[String]:
	return _known_recipes.duplicate()


func save_state() -> Dictionary:
	# The save system stores the lesson table per master, section 18. The
	# known recipes follow from the table and the master data.
	return {"lessons": _lessons.duplicate()}


func load_state(saved: Dictionary) -> void:
	# A loaded game never replays a lesson beat or a recipe grant. Unknown
	# master ids drop away; impossible lesson counts clamp to the school size.
	var saved_lessons: Dictionary = saved.get("lessons", {})
	_lessons.clear()
	for master: BrewingMaster in _masters:
		if not saved_lessons.has(master.master_id):
			continue
		_lessons[master.master_id] = clampi(
			int(saved_lessons[master.master_id]), 0, lessons_per_master()
		)
	_rebuild_known_recipes()


func _rebuild_known_recipes() -> void:
	# The known recipes follow from the lessons taken, so the data and the
	# school state can never disagree.
	_known_recipes.clear()
	for master: BrewingMaster in _masters:
		for lesson_number: int in range(1, lessons_taken(master.master_id) + 1):
			if lesson_number > master.lesson_recipes.size():
				break
			var recipe_id: String = master.lesson_recipes[lesson_number - 1]
			if not recipe_id.is_empty() and not _known_recipes.has(recipe_id):
				_known_recipes.append(recipe_id)
