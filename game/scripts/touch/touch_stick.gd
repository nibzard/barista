# ABOUTME: TouchStick is the pure model of the virtual stick: it turns thumb
# ABOUTME: offsets into a direction with a dead zone and a clamp. No nodes.
class_name TouchStick
extends RefCounted

# The balance carries the dead zone and the full-tilt distance.
var balance: TouchControlsBalance

var _offset := Vector2.ZERO
var _held := false


func press() -> void:
	# The thumb lands: the stick wakes with no tilt until the thumb drags.
	_held = true
	_offset = Vector2.ZERO


func drag(thumb_offset: Vector2) -> void:
	# The thumb moved. The offset clamps at the full-tilt distance, so a thumb
	# beyond the rim still reads as full tilt in the same direction.
	if balance == null:
		return
	var distance := thumb_offset.length()
	if distance <= balance.stick_max_distance_pixels:
		_offset = thumb_offset
	else:
		_offset = thumb_offset / distance * balance.stick_max_distance_pixels


func release() -> void:
	# The thumb lifts: the stick centers and the move stops.
	_held = false
	_offset = Vector2.ZERO


func is_held() -> bool:
	return _held


func offset() -> Vector2:
	# The clamped raw offset, for the knob drawing.
	return _offset


func direction() -> Vector2:
	# The play direction: unit direction scaled by how far the thumb pulled
	# past the dead zone, so a light touch walks slowly. Zero tilts inside the
	# dead zone read as a rest.
	if balance == null:
		return Vector2.ZERO
	var distance := _offset.length()
	var dead_zone := balance.stick_dead_zone_pixels
	if distance <= dead_zone:
		return Vector2.ZERO
	var span := maxf(balance.stick_max_distance_pixels - dead_zone, 0.0001)
	var tilt := clampf((distance - dead_zone) / span, 0.0, 1.0)
	return _offset / distance * tilt
