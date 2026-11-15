# ABOUTME: OutroKaren is the Karen of the version ending, section 16: she blocks
# ABOUTME: the road east and demands the manager. She is a stage actor, not an
# ABOUTME: enemy: no cure, no wake, and her body is the wall of the version.
class_name OutroKaren
extends StaticBody2D

signal in_place

# The barrier spans the whole deck corridor, so nobody walks around her.
const BARRIER_SIZE := Vector2(52.0, 720.0)

var _progress := 0.0
var _start := Vector2.ZERO
var _spot := Vector2.ZERO
var _arrived := false


func place(at_spot: Vector2, from: Vector2) -> void:
	# She marches in from the east edge to her blocking spot on the road.
	_spot = at_spot
	_start = from
	_progress = 0.0
	_arrived = false
	global_position = from


func march(delta: float, seconds: float) -> void:
	# Slide toward the spot. The first landing there blocks the road and fires
	# in_place exactly once.
	if _arrived or seconds <= 0.0:
		return
	_progress = minf(1.0, _progress + delta / seconds)
	global_position = _start.lerp(_spot, _progress)
	if _progress >= 1.0:
		_arrived = true
		in_place.emit()


func stand_at(at_spot: Vector2) -> void:
	# A loaded post-game world finds her already blocking the road, with no
	# march and no signal.
	place(at_spot, at_spot)
	_progress = 1.0
	_arrived = true


func is_in_place() -> bool:
	return _arrived
