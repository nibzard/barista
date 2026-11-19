# ABOUTME: CoffeeCup is the thrown projectile: it arcs to its landing point in one flight.
# ABOUTME: The payload wakes the hit sleeper per its cure; a perfect cup splashes a radius.
class_name CoffeeCup
extends Area2D

# The burst point sits a touch back along the flown line. The cup dies when
# its shape first touches a wall, so its center can already sit inside that
# wall. Pulled back, the burst still reaches the space in front of the wall.
const SPLASH_ORIGIN_MARGIN := 12.0

@export var balance: CoffeeCupBalance
@export var brewing_balance: BrewingBalance

var direction := Vector2.RIGHT
var brewed: BrewedCup = null
var landing := Vector2.INF

var _start := Vector2.ZERO
var _flight_time_left := 0.0
var _splash_pending := false

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual.rotation = direction.angle()


func launch(landing_position: Vector2) -> void:
	landing = landing_position
	_start = global_position
	_flight_time_left = balance.flight_time_seconds


func _physics_process(delta: float) -> void:
	if _splash_pending:
		# The cup met a body in the last physics flush and stands still at
		# the impact point. The burst runs here, outside the flush, where a
		# line-of-sight cast against walls is legal.
		_burst_and_free()
		return
	if _flight_time_left <= 0.0 and landing == Vector2.INF:
		launch(global_position + direction.normalized() * balance.throw_range)
	_flight_time_left -= delta
	if _flight_time_left <= 0.0:
		global_position = landing
		_burst_and_free()
		return
	var progress := 1.0 - _flight_time_left / balance.flight_time_seconds
	global_position = _start.lerp(landing, progress)
	visual.position = Vector2(0.0, -arc_height(progress, balance.arc_peak_height))


static func arc_height(progress: float, peak: float) -> float:
	# A parabola over the flight: ground level at both ends, the peak half-way.
	return 4.0 * peak * progress * (1.0 - progress)


func _on_body_entered(body: Node2D) -> void:
	if _splash_pending:
		return
	if body.has_method(&"try_wake"):
		# Every wakeable body takes the payload: the sleepwalkers of
		# section 6, the band stage, the fish sellers of the market, the
		# band members of Sleepvana, the husband of aisle 7. The cup asks
		# the body, never its class, so no boss or quest script joins the
		# cup compile (T112).
		if not _hat_stops_the_throw(body):
			body.try_wake(brewed)
		_splash_and_free()
	else:
		# Every other body is environment geometry: a wall, a gate, a stage
		# block. The cup breaks on it, so no coffee flies through walls and
		# no sleeper behind one wakes from the flight.
		_splash_and_free()


func _hat_stops_the_throw(body: Node2D) -> bool:
	# The Tinfoil Man's hat stops thrown coffee, section 6: the cup
	# splashes on the tinfoil and dies there. No payload gets through
	# while it flies, so the cure check never runs for him.
	return body.has_method(&"hat_stops_thrown_coffee") and body.hat_stops_thrown_coffee()


func _splash_and_free() -> void:
	# body_entered fires inside the physics flush, and space casts are
	# refused there. The burst waits one physics frame and runs from
	# _physics_process, where the splash can ask the walls for line of sight.
	_splash_pending = true


func _burst_and_free() -> void:
	# The cup dies here and its payload bursts, section 15: a perfect cup
	# wakes every sleepwalker in a small radius around the splash point.
	# The tinfoil hat keeps the splash off its wearer, section 6, and walls
	# keep it off every sleeper the geometry hides. Every splash weapon of
	# section 11 wakes through the same shared math, CureDelivery.
	monitoring = false
	_splash_pending = false
	if brewed == null or brewing_balance == null:
		queue_free()
		return
	CureDelivery.splash_wake(
		_splash_origin(),
		CureMatcher.wake_radius(brewed, brewing_balance),
		brewed,
		get_tree(),
		get_world_2d()
	)
	queue_free()


func _splash_origin() -> Vector2:
	# The burst point sits a touch back along the flown line, clear of the
	# wall face the cup died on.
	var offset := global_position - _start
	if offset.length() <= SPLASH_ORIGIN_MARGIN:
		return global_position
	return global_position - offset.normalized() * SPLASH_ORIGIN_MARGIN
