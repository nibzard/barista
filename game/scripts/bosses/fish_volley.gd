# ABOUTME: FishVolley is the pure clock of the Fish Throwers volley, no nodes.
# ABOUTME: One fish per beat, in a steady rhythm, cycling the sellers in order.
class_name FishVolley
extends RefCounted

var _thrower_count: int
var _interval_seconds: float
var _time_to_beat := 0.0
var _beats_passed := 0


func _init(thrower_count: int, interval_seconds: float) -> void:
	_thrower_count = maxi(1, thrower_count)
	_interval_seconds = maxf(0.01, interval_seconds)
	_time_to_beat = _interval_seconds


func tick(delta: float) -> int:
	# Advances the rhythm by one frame. Each beat lasts the whole interval, and
	# the throw fires on the tick that closes the beat. The return value is the
	# index of the seller that throws on this tick, or -1 inside a beat. A tick
	# that spans a whole beat or more fires one fish and the beat restarts, so
	# the rhythm never bursts after a stall.
	_time_to_beat -= maxf(0.0, delta)
	if _time_to_beat > 0.0:
		return -1
	_beats_passed += 1
	_time_to_beat = _interval_seconds
	return thrower_for_beat(_beats_passed, _thrower_count)


func beats_passed() -> int:
	return _beats_passed


static func thrower_for_beat(beat: int, thrower_count: int) -> int:
	# The round-robin order of the crew: beat 1 fires seller 0, beat 2 fires
	# seller 1, and so on, back to seller 0 after the full crew.
	return (beat - 1) % maxi(1, thrower_count)


static func aim(from_position: Vector2, target_position: Vector2) -> Vector2:
	# Perfect aim, section 6: the fish flies the exact line to the spot where
	# the player stands at the throw. The throwers never lead the target and
	# never drop a fish. A seller that stands on its target holds the fish.
	var to_target := target_position - from_position
	if to_target == Vector2.ZERO:
		return Vector2.ZERO
	return to_target.normalized()
