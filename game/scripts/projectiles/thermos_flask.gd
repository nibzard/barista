# ABOUTME: ThermosFlask is the thrown thermos of section 11: it flies an arc,
# ABOUTME: breaks on the first thing it meets, and splashes coffee in a wide area.
class_name ThermosFlask
extends Area2D

# The burst point sits a touch back along the flown line. The flask dies when
# its shape first touches a wall or a sleeper, so its center can already sit
# inside that body. Pulled back, the splash still reaches the open space.
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
	_flight_time_left = balance.thermos_flight_time_seconds


func _physics_process(delta: float) -> void:
	if _burst_pending:
		# The flask met a body in the last physics flush and stands still at
		# the impact point. The burst runs here, outside the flush, where a
		# line-of-sight cast against walls is legal.
		_burst_and_free()
		return
	if _flight_time_left <= 0.0 and landing == Vector2.INF:
		launch(global_position + direction.normalized() * balance.thermos_throw_range)
	_flight_time_left -= delta
	if _flight_time_left <= 0.0:
		global_position = landing
		_burst_and_free()
		return
	var progress := 1.0 - _flight_time_left / balance.thermos_flight_time_seconds
	global_position = _start.lerp(landing, progress)
	visual.position = Vector2(0.0, -CoffeeCup.arc_height(progress, balance.thermos_arc_peak_height))


func _on_body_entered(_body: Node2D) -> void:
	# The flask breaks on the first body it meets: a sleeper, a wall, or a
	# stage block. The splash itself asks the tinfoil hat guard and the walls,
	# so nothing here needs the body.
	_burst_pending = true


func _burst_and_free() -> void:
	# The flask dies and its whole tank bursts, section 11: a wide splash of
	# coffee that wakes every sleeping walker it reaches.
	monitoring = false
	_burst_pending = false
	CureDelivery.splash_wake(
		_splash_origin(), balance.thermos_splash_radius, brewed, get_tree(), get_world_2d()
	)
	queue_free()


func _splash_origin() -> Vector2:
	# The burst point sits a touch back along the flown line, clear of the
	# wall face the flask died on.
	var offset := global_position - _start
	if offset.length() <= SPLASH_ORIGIN_MARGIN:
		return global_position
	return global_position - offset.normalized() * SPLASH_ORIGIN_MARGIN
