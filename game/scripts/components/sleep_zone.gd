# ABOUTME: SleepZone is a reusable area that changes the meter drain of the player inside it.
# ABOUTME: Loudspeaker poles and street sleep zones use SLEEP; the cafe interior uses SAFE.
class_name SleepZone
extends Area2D

enum Kind { SLEEP, SAFE }

# Placeholder tints until the art pass brings the purple haze and the lamps.
const SLEEP_ZONE_TINT := Color(0.55, 0.25, 0.75, 0.22)
const SAFE_ZONE_TINT := Color(0.45, 0.85, 0.55, 0.12)
const POLE_TINT := Color(0.3, 0.1, 0.45, 0.9)
const POLE_MARKER_RADIUS := 10.0

@export var kind: Kind = Kind.SLEEP


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the sleepwalker sensors do:
	# signal delivery order between siblings is not guaranteed, and the drain
	# tier must stay set for every frame of the stay inside the area.
	var player := _player_inside()
	if player == null:
		return
	if kind == Kind.SAFE:
		player.sleep_meter.suppress_environmental_drain()
	else:
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.SLEEP_ZONE)


func _player_inside() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _draw() -> void:
	# Placeholder zone marker: the circle always matches the area radius.
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
	return SAFE_ZONE_TINT if kind == Kind.SAFE else SLEEP_ZONE_TINT
