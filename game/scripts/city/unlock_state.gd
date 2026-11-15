# ABOUTME: UnlockState is the paywall flag: the first city is free, one payment
# ABOUTME: unlocks the full game. The real purchase is external, see backlog T053.
class_name UnlockState
extends RefCounted

signal unlocked

var _unlocked := false


func is_unlocked() -> bool:
	return _unlocked


func unlock() -> bool:
	# The stub purchase hook. The store flow calls this later; the gate opens
	# the same frame no matter who pays. Returns true only on the first call.
	if _unlocked:
		return false
	_unlocked = true
	unlocked.emit()
	return true


func save_state() -> bool:
	# The save system stores the purchase as one plain flag.
	return _unlocked


func load_state(saved: bool) -> void:
	# A loaded purchase never replays the unlock beat.
	_unlocked = saved
