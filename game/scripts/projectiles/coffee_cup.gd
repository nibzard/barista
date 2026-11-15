# ABOUTME: CoffeeCup is the thrown projectile: it arcs to its landing point in one flight.
# ABOUTME: The payload wakes the hit sleeper per its cure; a perfect cup splashes a radius.
class_name CoffeeCup
extends Area2D

@export var balance: CoffeeCupBalance
@export var brewing_balance: BrewingBalance

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
		_splash_and_free()
		return
	var progress := 1.0 - _flight_time_left / balance.flight_time_seconds
	global_position = _start.lerp(landing, progress)
	visual.position = Vector2(0.0, -arc_height(progress, balance.arc_peak_height))


static func arc_height(progress: float, peak: float) -> float:
	# A parabola over the flight: ground level at both ends, the peak half-way.
	return 4.0 * peak * progress * (1.0 - progress)


func _on_body_entered(body: Node2D) -> void:
	if body is Sleepwalker:
		# The Tinfoil Man's hat stops thrown coffee, section 6: the cup
		# splashes on the tinfoil and dies there. No payload gets through
		# while it flies, so the cure check never runs for him.
		if not body.hat_stops_thrown_coffee():
			body.try_wake(brewed)
		_splash_and_free()
	elif body is SleepJamBand:
		# The band stage takes a thrown cure cup like any sleepwalker,
		# section 6: the payload lands on the stage.
		body.try_wake(brewed)
		_splash_and_free()
	elif body is FishSeller:
		# The fish sellers of the market take a thrown cure cup the same way,
		# section 6: the head-first rule inside the market decides its worth.
		body.try_wake(brewed)
		_splash_and_free()
	elif body is BandMember:
		# The band members of Sleepvana take a thrown order cup the same way,
		# section 13: the member's own order and the encore rule decide.
		body.try_wake(brewed)
		_splash_and_free()
	elif body is Aisle7Husband:
		# The husband of aisle 7 takes a thrown Turkish cup the same way,
		# section 13: the photo gate and the quest rule decide inside the stage.
		body.try_wake(brewed)
		_splash_and_free()


func _splash_and_free() -> void:
	# The cup dies here and its payload bursts, section 15: a perfect cup
	# wakes every sleepwalker in a small radius around the splash point.
	# The tinfoil hat keeps the splash off its wearer too, section 6, so
	# the same guard runs for every sleeper the radius reaches.
	if brewed == null or brewing_balance == null:
		queue_free()
		return
	var radius := CureMatcher.wake_radius(brewed, brewing_balance)
	if radius > 0.0:
		for node: Node in get_tree().get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
			var sleeper := node as Sleepwalker
			if sleeper == null or sleeper.hat_stops_thrown_coffee():
				continue
			if sleeper.global_position.distance_to(global_position) <= radius:
				sleeper.try_wake(brewed)
	queue_free()
