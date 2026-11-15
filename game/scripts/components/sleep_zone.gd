# ABOUTME: SleepZone is a reusable area that changes the meter drain of the player inside it.
# ABOUTME: Loudspeaker poles and street sleep zones use SLEEP; the cafe interior
# ABOUTME: uses SAFE; boss auras like the Sleep Jam lullaby use BORING.
class_name SleepZone
extends Area2D

enum Kind { SLEEP, SAFE, BORING }

# Placeholder tints until the art pass brings the purple haze and the lamps.
const SLEEP_ZONE_TINT := Color(0.55, 0.25, 0.75, 0.22)
const SAFE_ZONE_TINT := Color(0.45, 0.85, 0.55, 0.12)
const LULLABY_TINT := Color(0.4, 0.35, 0.8, 0.16)
const POLE_TINT := Color(0.3, 0.1, 0.45, 0.9)
const POLE_MARKER_RADIUS := 10.0

@export var kind: Kind = Kind.SLEEP

var _broadcast_silenced := false
var _active := true


func set_active(active: bool) -> void:
	# The owner of the zone can end its pull, like the endless song of the band
	# on the wake: the zone stops draining and stops drawing.
	if _active == active:
		return
	_active = active
	queue_redraw()


func is_active() -> bool:
	return _active


func silence_broadcast() -> void:
	# The tower of the city is off: the address no longer plays through this
	# pole, so the zone stops pulling the player down.
	_broadcast_silenced = true


func is_broadcast_silenced() -> bool:
	return _broadcast_silenced


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the sleepwalker sensors do:
	# signal delivery order between siblings is not guaranteed, and the drain
	# tier must stay set for every frame of the stay inside the area.
	if not _active:
		return
	var player := _player_inside()
	if player == null:
		return
	if kind == Kind.SAFE:
		player.sleep_meter.suppress_environmental_drain()
	elif kind == Kind.BORING:
		# A boring attack, section 14: the lullaby of the band or the slides of
		# a keynote boss drain at the boring rate. The song is the boss's own,
		# so a silent broadcast tower does not stop it.
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.BORING_ATTACK)
	elif not _broadcast_silenced:
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)


func has_player_inside() -> bool:
	# A live overlap check for callers outside the drain tick, like the free
	# cafe refill that flows only inside the cafe safe zone.
	return _player_inside() != null


func _player_inside() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _draw() -> void:
	# Placeholder zone marker: the circle always matches the area radius.
	if not _active:
		return
	var radius := _circle_radius()
	if radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, radius, _zone_tint())
	if kind == Kind.SLEEP:
		draw_circle(Vector2.ZERO, POLE_MARKER_RADIUS, POLE_TINT)


func _circle_radius() -> float:
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return 0.0
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		return 0.0
	return circle.radius


func _zone_tint() -> Color:
	match kind:
		Kind.SAFE:
			return SAFE_ZONE_TINT
		Kind.BORING:
			return LULLABY_TINT
		_:
			return SLEEP_ZONE_TINT
