# ABOUTME: MainQuest tracks the main chain: the current city, the tower and
# ABOUTME: boss beats per city, and the unlock of the next city. Pure logic.
class_name MainQuest
extends RefCounted

signal city_entered(city_id: String)
signal city_completed(city_id: String)
signal next_city_unlocked(city_id: String)
signal objective_changed(objective: Objective)

enum Objective { TOWER, BOSS, ROAD_EAST }

var _route: Array[String] = []
var _current_index := -1
# The beats per city id, stored as plain values for the save system.
var _tower_off := {}
var _boss_cured := {}
var _completion_announced := {}
var _last_objective := Objective.TOWER


func setup(route: Array[String], start_city := "") -> bool:
	# The route is the city row from west to east. The start city defaults to
	# the first city. A route fails when it is empty, repeats a city, or names
	# an unknown start city.
	_route.clear()
	_tower_off.clear()
	_boss_cured.clear()
	_completion_announced.clear()
	if route.is_empty():
		_current_index = -1
		return false
	for city_id: String in route:
		if _route.has(city_id):
			_current_index = -1
			return false
		_route.append(city_id)
	_current_index = 0
	if not start_city.is_empty():
		var start_index := _route.find(start_city)
		if start_index < 0:
			_current_index = -1
			return false
		_current_index = start_index
	_last_objective = current_objective()
	return true


func current_city() -> String:
	if _current_index < 0 or _current_index >= _route.size():
		return ""
	return _route[_current_index]


func route_size() -> int:
	return _route.size()


func is_on_route(city_id: String) -> bool:
	return _route.has(city_id)


func current_objective() -> Objective:
	# The marker order per city: first the tower, then the boss, then the open
	# road east. A city is complete only when both beats landed.
	var city := current_city()
	if not _tower_off.get(city, false):
		return Objective.TOWER
	if not _boss_cured.get(city, false):
		return Objective.BOSS
	return Objective.ROAD_EAST


func mark_tower_off(city_id := "") -> bool:
	# Records the tower beat, section 7 step 7. The empty id means the current
	# city. Returns true only for a city on the route.
	return _mark(_tower_off, city_id)


func mark_boss_cured(city_id := "") -> bool:
	# Records the boss cure beat. The empty id means the current city.
	return _mark(_boss_cured, city_id)


func is_tower_off(city_id: String) -> bool:
	return bool(_tower_off.get(city_id, false))


func is_boss_cured(city_id: String) -> bool:
	return bool(_boss_cured.get(city_id, false))


func is_city_complete(city_id: String) -> bool:
	return is_tower_off(city_id) and is_boss_cured(city_id)


func next_city() -> String:
	# The city east of the current one. Empty at the end of the route.
	if _current_index < 0 or _current_index + 1 >= _route.size():
		return ""
	return _route[_current_index + 1]


func is_city_unlocked(city_id: String) -> bool:
	# The first city stands open. Every later city opens when the city before
	# it completes, section 7 step 8.
	var index := _route.find(city_id)
	if index < 0:
		return false
	if index == 0:
		return true
	return is_city_complete(_route[index - 1])


func travel_east() -> bool:
	# The completed city hands the road to the next city. The chain moves one
	# city east and the objective resets to the tower of the new city.
	var destination := next_city()
	if destination.is_empty() or not is_city_unlocked(destination):
		return false
	_current_index += 1
	city_entered.emit(current_city())
	_refresh_objective()
	return true


func save_state() -> Dictionary:
	# The save system stores the route position and both beat maps as plain
	# values.
	return {
		"current": _current_index,
		"tower_off": _tower_off.duplicate(),
		"boss_cured": _boss_cured.duplicate(),
	}


func load_state(saved: Dictionary) -> void:
	# A loaded chain never replays a beat: the completion announcements are
	# rebuilt from the saved beats, and no signal fires on the load path.
	_current_index = int(saved.get("current", 0))
	if _current_index < 0 or _current_index >= _route.size():
		_current_index = 0
	_tower_off = _as_bool_dict(saved.get("tower_off", {}))
	_boss_cured = _as_bool_dict(saved.get("boss_cured", {}))
	_completion_announced.clear()
	for city_id: String in _route:
		if is_city_complete(city_id):
			_completion_announced[city_id] = true
	_last_objective = current_objective()


func _mark(beats: Dictionary, city_id: String) -> bool:
	var target := city_id
	if target.is_empty():
		target = current_city()
	if not _route.has(target):
		return false
	beats[target] = true
	_check_city_complete(target)
	_refresh_objective()
	return true


func _check_city_complete(city_id: String) -> void:
	if not is_city_complete(city_id) or _completion_announced.has(city_id):
		return
	_completion_announced[city_id] = true
	city_completed.emit(city_id)
	var follower := _city_after(city_id)
	if not follower.is_empty():
		next_city_unlocked.emit(follower)


func _city_after(city_id: String) -> String:
	var index := _route.find(city_id)
	if index < 0 or index + 1 >= _route.size():
		return ""
	return _route[index + 1]


func _refresh_objective() -> void:
	var objective := current_objective()
	if objective == _last_objective:
		return
	_last_objective = objective
	objective_changed.emit(objective)


func _as_bool_dict(saved: Variant) -> Dictionary:
	var result := {}
	var source := saved as Dictionary
	for key: String in source:
		result[key] = bool(source[key])
	return result
