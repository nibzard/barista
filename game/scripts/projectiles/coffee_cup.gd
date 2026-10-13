# ABOUTME: CoffeeCup is the thrown projectile: it arcs to its landing point in one flight.
# ABOUTME: The hit sleepwalker checks the payload against its own cure.
class_name CoffeeCup
extends Area2D

@export var balance: CoffeeCupBalance

var direction := Vector2.RIGHT
var brewed: BrewedCup = null
var landing := Vector2.INF

var _start := Vector2.ZERO
var _flight_time_left := 0.0

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual.rotation = direction.angle()


func launch(landing_position: Vector2) -> void:
	landing = landing_position
	_start = global_position
	_flight_time_left = balance.flight_time_seconds


func _physics_process(delta: float) -> void:
	if _flight_time_left <= 0.0 and landing == Vector2.INF:
		launch(global_position + direction.normalized() * balance.throw_range)
	_flight_time_left -= delta
	if _flight_time_left <= 0.0:
		global_position = landing
		queue_free()
		return
	var progress := 1.0 - _flight_time_left / balance.flight_time_seconds
	global_position = _start.lerp(landing, progress)
	visual.position = Vector2(0.0, -arc_height(progress, balance.arc_peak_height))


static func arc_height(progress: float, peak: float) -> float:
	# A parabola over the flight: ground level at both ends, the peak half-way.
	return 4.0 * peak * progress * (1.0 - progress)


func _on_body_entered(body: Node2D) -> void:
	if body is Sleepwalker:
		body.try_wake(brewed)
		queue_free()
