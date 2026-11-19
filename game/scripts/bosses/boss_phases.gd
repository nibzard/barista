# ABOUTME: BossPhases is the shared phase clock of the boss fights: a fixed
# ABOUTME: row of advancing phase durations whose last phase holds forever.
class_name BossPhases
extends RefCounted

var _durations: Array[float] = []
var _index := 0
var _elapsed := 0.0


func _init(phase_durations: Array[float] = []) -> void:
	_durations = phase_durations.duplicate()


func tick(delta: float) -> int:
	# Advances the clock by one step. Returns the new phase index when this
	# tick crossed a boundary, else -1. One large step can cross several
	# boundaries at once and lands on the last one it reached.
	if is_holding() or delta <= 0.0:
		return -1
	_elapsed += delta
	var crossed := -1
	while _index < _durations.size() and _elapsed >= _durations[_index]:
		_elapsed -= _durations[_index]
		_index += 1
		crossed = _index
	return crossed


func current() -> int:
	return _index


func phase_count() -> int:
	# The advancing phases plus the endless one the show ends on.
	return _durations.size() + 1


func elapsed_in_phase() -> float:
	return _elapsed


func is_holding() -> bool:
	# True inside the last phase, or with no advancing phases at all: the
	# clock stands still and only the cure ends the fight.
	return _index >= _durations.size()
