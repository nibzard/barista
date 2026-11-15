# ABOUTME: CityProgress tracks the two beats that complete a city per section 7.
# ABOUTME: Pure logic: the tower switch and the boss cure, no scene nodes.
class_name CityProgress
extends RefCounted

signal city_completed

var _tower_off := false
var _boss_cured := false
var _announced := false


func mark_tower_off() -> void:
	# Core loop step 7: the broadcast tower is off, the woken stay awake.
	_tower_off = true
	_check_complete()


func mark_boss_cured() -> void:
	# The city boss drank the cure and woke up.
	_boss_cured = true
	_check_complete()


func is_tower_off() -> bool:
	return _tower_off


func is_boss_cured() -> bool:
	return _boss_cured


func is_complete() -> bool:
	return _tower_off and _boss_cured


func save_state() -> Dictionary:
	# The save system stores both beats as plain values and reads them back.
	return {"tower_off": _tower_off, "boss_cured": _boss_cured}


func load_state(saved: Dictionary) -> void:
	# A loaded city never replays the completion beat.
	_tower_off = bool(saved.get("tower_off", false))
	_boss_cured = bool(saved.get("boss_cured", false))
	_announced = is_complete()


func _check_complete() -> void:
	if is_complete() and not _announced:
		_announced = true
		city_completed.emit()
