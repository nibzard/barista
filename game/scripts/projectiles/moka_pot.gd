# ABOUTME: MokaPot is the pressurized pot of the Moka Launcher, section 11: it
# ABOUTME: flies a high arc, the coffee brews during the flight, and it bursts in
# ABOUTME: a large area where it lands.
class_name MokaPot
extends Area2D

# The burst point sits a touch back along the flown line, clear of a wall face
# the pot died on, so the splash still reaches the space in front of the wall.
const SPLASH_ORIGIN_MARGIN := 12.0

@export var balance: CureWeaponsBalance

var direction := Vector2.RIGHT
var brewed: BrewedCup = null
var landing := Vector2.INF

var _start := Vector2.ZERO
var _flight_time_left := 0.0
var _burst_pending := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual.rotation = direction.angle()


func launch(landing_position: Vector2) -> void:
	landing = landing_position
	_start = global_position
	_flight_time_left = balance.moka_flight_time_seconds


func _physics_process(delta: float) -> void:
	if _burst_pending:
		# The pot met a body in the last physics flush and stands still at the
		# impact point. The burst runs here, outside the flush, where a
		# line-of-sight cast against walls is legal.
		_burst_and_free()
		return
	if _flight_time_left <= 0.0 and landing == Vector2.INF:
		launch(global_position + direction.normalized() * balance.moka_throw_range)
	_flight_time_left -= delta
	if _flight_time_left <= 0.0:
		global_position = landing
		_burst_and_free()
		return
	var progress := 1.0 - _flight_time_left / balance.moka_flight_time_seconds
	global_position = _start.lerp(landing, progress)
	visual.position = Vector2(0.0, -CoffeeCup.arc_height(progress, balance.moka_arc_peak_height))


func _on_body_entered(body: Node2D) -> void:
	if _burst_pending:
		return
	if body.has_method(&"try_wake"):
		if body.has_method(&"is_awake") and body.is_awake():
			return
		var blocked: bool = (
			body.has_method(&"hat_stops_thrown_coffee") and body.hat_stops_thrown_coffee()
		)
		if not blocked:
			body.try_wake(brewed)
	# The pot bursts on the first sleeping body or solid obstacle it meets,
	# then runs its area splash on the next physics frame.
	_burst_pending = true


func _burst_and_free() -> void:
	# The pot dies here and its brew bursts, section 11: the coffee that
	# brewed during the flight wakes every sleeping walker in a large area.
	monitoring = false
	_burst_pending = false
	CureDelivery.splash_wake(
		_splash_origin(), balance.moka_splash_radius, brewed, get_tree(), get_world_2d()
	)
	queue_free()


func _splash_origin() -> Vector2:
	# The burst point sits a touch back along the flown line, clear of the
	# wall face the pot died on.
	var offset := global_position - _start
	if offset.length() <= SPLASH_ORIGIN_MARGIN:
		return global_position
	return global_position - offset.normalized() * SPLASH_ORIGIN_MARGIN
