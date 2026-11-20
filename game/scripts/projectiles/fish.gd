# ABOUTME: Fish is one thrown fish of the Fish Throwers volley.
# ABOUTME: It flies the locked line of its perfect aim and dazzles on a hit.
class_name Fish
extends Area2D

@export var balance: FishThrowersBalance

# The locked flight line, set at the throw. The aim never follows the player.
var direction := Vector2.RIGHT
# The celebration fish of the wake fly up and hit nobody.
var harmless := false

var _distance_left := 0.0

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if direction != Vector2.ZERO:
		direction = direction.normalized()
	_distance_left = balance.fish_flight_range
	visual.rotation = direction.angle()


func _physics_process(delta: float) -> void:
	# A fish flies straight until it drops. It never curves after the throw.
	var step := balance.fish_speed * delta
	_distance_left -= step
	if _distance_left <= 0.0:
		queue_free()
		return
	global_position += direction * step


func _on_body_entered(body: Node2D) -> void:
	# A fish that lands on the player smarts: one short dazzle, like the drone
	# bump. A rolling player slips it, and the celebration fish hit nobody.
	if body is not Player or harmless:
		return
	if not body.is_invulnerable() and not body.is_asleep():
		body.apply_stun(balance.fish_stun_seconds)
	queue_free()
