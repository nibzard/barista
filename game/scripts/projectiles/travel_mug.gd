# ABOUTME: TravelMug is the sealed steel mug of section 11: it bounces from one
# ABOUTME: sleepwalker to a second one, also around corners, then rolls back.
# ABOUTME: The lid keeps the coffee inside, so the throw costs no cups.
class_name TravelMug
extends Area2D

enum Phase { THROW, BOUNCE, RETURN }

# The mug lands in the hand again when it comes this close to the thrower.
const CATCH_DISTANCE := 26.0

@export var balance: CureWeaponsBalance

var direction := Vector2.RIGHT
var brewed: BrewedCup = null
var thrower: Player = null
var landing := Vector2.INF

var _phase := Phase.THROW
var _start := Vector2.ZERO
var _flight_time_left := 0.0
var _flight_seconds := 1.0
var _bounce_target := Vector2.INF
var _first_hit: Node2D = null

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual.rotation = direction.angle()


func launch(landing_position: Vector2) -> void:
	landing = landing_position
	_start = global_position
	_flight_seconds = balance.travel_mug_flight_time_seconds
	_flight_time_left = _flight_seconds


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.THROW, Phase.BOUNCE:
			_fly(delta)
		Phase.RETURN:
			_roll_home(delta)


func _fly(delta: float) -> void:
	_flight_time_left -= delta
	var target := landing if _phase == Phase.THROW else _bounce_target
	var progress := 1.0
	if _flight_time_left > 0.0:
		progress = 1.0 - _flight_time_left / _flight_seconds
	global_position = _start.lerp(target, clampf(progress, 0.0, 1.0))
	if _flight_time_left <= 0.0:
		_on_flight_end()


func _on_flight_end() -> void:
	# The mug reached its point without a body in the way. The throw seeks a
	# bounce target anyway, because a sleeper may stand just past the landing
	# spot; the bounce has nothing left to seek and rolls home.
	if _phase == Phase.THROW:
		_begin_bounce()
	else:
		_begin_return()


func _on_body_entered(body: Node2D) -> void:
	if _phase == Phase.RETURN:
		# The rolling mug wakes nobody on the way home. The lid is on.
		return
	if body.has_method(&"try_wake"):
		# Every wakeable body takes the payload: the sleepwalkers of section 6
		# and the wakeable quest bodies, like the cup does. The mug asks the
		# body, never its class, so no quest script joins this compile.
		if _phase == Phase.BOUNCE and body == _first_hit:
			# The bounce flies over its own first hit: the mug already rang
			# that body and passes by without a second splash.
			return
		_first_hit = body
		if not _hat_stops_the_throw(body):
			body.try_wake(brewed)
		if _phase == Phase.THROW:
			_begin_bounce()
		else:
			_begin_return()
		return
	# Every other body is environment geometry. A wall ends the throw and the
	# mug rolls home from the impact; a bounce in flight flies over walls on
	# purpose, section 11, so no wall can end it.
	if _phase == Phase.THROW:
		_begin_return()


func _hat_stops_the_throw(body: Node2D) -> bool:
	# The Tinfoil Man's hat stops thrown coffee, section 6. The steel mug
	# ricochets off the tinfoil and hunts the next sleeper, but no payload
	# gets through while it flies.
	return body.has_method(&"hat_stops_thrown_coffee") and body.hat_stops_thrown_coffee()


func _begin_bounce() -> void:
	# The ricochet: the nearest other sleeping walker inside the seek radius,
	# with no line-of-sight ask, because the mug also bounces around corners.
	var target := _bounce_candidate()
	if target == null:
		_begin_return()
		return
	_phase = Phase.BOUNCE
	_start = global_position
	_bounce_target = target.global_position
	# The bounce takes its authored time, but never crawls slower than the
	# roll-home speed, so a long ricochet still moves like a thrown mug.
	_flight_seconds = maxf(
		balance.travel_mug_bounce_flight_time_seconds,
		global_position.distance_to(_bounce_target) / balance.travel_mug_return_speed
	)
	_flight_time_left = _flight_seconds


func _bounce_candidate() -> Sleepwalker:
	var best: Sleepwalker = null
	var best_distance := balance.travel_mug_bounce_seek_radius
	for node: Node in get_tree().get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var sleeper := node as Sleepwalker
		if sleeper == null or sleeper.is_awake() or sleeper == _first_hit:
			continue
		var distance := sleeper.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = sleeper
			best_distance = distance
	return best


func _begin_return() -> void:
	_phase = Phase.RETURN


func _roll_home(delta: float) -> void:
	# The mug rolls back to the thrower's live position. A thrower who left
	# the tree leaves the mug nowhere to go, so it gives up on the spot.
	if thrower == null or not is_instance_valid(thrower):
		queue_free()
		return
	var home := thrower.global_position
	var step := balance.travel_mug_return_speed * delta
	var offset := home - global_position
	if offset.length() <= maxf(step, CATCH_DISTANCE):
		queue_free()
		return
	global_position += offset.normalized() * step
