# ABOUTME: MovingDay is the state of the move between two city cafes, section 10.
# ABOUTME: Pure logic: the unload beat fires once, no scene nodes.
class_name MovingDay
extends RefCounted

signal finished

var _done := false


func is_done() -> bool:
	return _done


func unload() -> bool:
	# The belongings come off the van into the new cafe. The call returns true
	# only on the first unload, so the beat never replays.
	if _done:
		return false
	_done = true
	finished.emit()
	return true


func save_state() -> bool:
	# The save system stores the move as one plain flag, section 18.
	return _done


func load_state(saved: bool) -> void:
	# A loaded move never replays the unload beat.
	_done = saved
