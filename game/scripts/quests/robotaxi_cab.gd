# ABOUTME: RobotaxiCab is one driverless taxi of the fleet, section 13: while
# ABOUTME: the routing engineer sleeps, the taxis pick up sleepwalkers and
# ABOUTME: deliver them to the player. It drives without a driver and without
# ABOUTME: collisions, like the placeholder-era world it rides through.
class_name RobotaxiCab
extends Node2D

signal passenger_delivered(passenger: Sleepwalker)

enum CabState { PARKED, PICKUP, DELIVER }

# Placeholder look until the art pass: a yellow cab with a windshield and the
# roof light that burns while the cab serves a ride.
const BODY_COLOR := Color(0.99, 0.83, 0.25, 1.0)
const WINDOW_COLOR := Color(0.55, 0.72, 0.75, 1.0)
const LIGHT_ON_COLOR := Color(0.55, 0.98, 0.6, 1.0)
const LIGHT_OFF_COLOR := Color(0.45, 0.45, 0.5, 1.0)
const BODY_SIZE := Vector2(84.0, 44.0)
const WINDOW_SIZE := Vector2(30.0, 26.0)
const LIGHT_SIZE := Vector2(22.0, 10.0)
# The passenger rides beside the driver seat, in the cab's local space.
const SEAT_OFFSET := Vector2(-20.0, 6.0)

var balance: RobotaxiDepotBalance = null

var _state: int = CabState.PARKED
var _retired := false
var _wait_left := 0.0
var _passenger: Sleepwalker = null
# The sleeper of the ride that just ended, kept for the delivered signal.
var _last_passenger: Sleepwalker = null


func setup(park_position: Vector2, cab_balance: RobotaxiDepotBalance) -> void:
	global_position = park_position
	balance = cab_balance
	_wait_left = cab_balance.first_ride_delay


func state() -> int:
	return _state


func passenger() -> Sleepwalker:
	return _passenger


func is_retired() -> bool:
	# The fleet re-routes: a retired cab parks for good and hauls nobody.
	return _retired


func tick(delta: float, player: Player, candidate: Sleepwalker, may_deliver: bool) -> void:
	# One physics step of the ride loop. The stage supplies the rule answers:
	# the eligible sleeper to fetch, and whether a ride may run at all.
	if _retired or balance == null or player == null:
		return
	if _passenger != null and not _passenger_rides_still():
		# The passenger woke mid-ride, or left the world: the cab lets him out
		# where he stands and parks.
		_release_passenger()
	match _state:
		CabState.PARKED:
			_tick_parked(delta, player, candidate, may_deliver)
		CabState.PICKUP:
			_tick_pickup(delta, may_deliver)
		CabState.DELIVER:
			_tick_deliver(delta, player, may_deliver)


func retire() -> void:
	# The reward beat lands: the fleet re-routes into fast travel, so this cab
	# drops any rider and parks for good.
	if _passenger != null:
		_release_passenger()
	_retired = true
	_state = CabState.PARKED
	queue_redraw()


func _tick_parked(delta: float, player: Player, candidate: Sleepwalker, may_deliver: bool) -> void:
	# The parked cab waits out its cooldown, then takes the next hail: the
	# stage's eligible sleeper, fetched for the player.
	_wait_left = maxf(0.0, _wait_left - delta)
	if _wait_left > 0.0 or not may_deliver or candidate == null:
		return
	if (
		player.global_position.distance_to(candidate.global_position)
		< (balance.pickup_min_player_distance)
	):
		return
	_passenger = candidate
	_state = CabState.PICKUP
	queue_redraw()


func _tick_pickup(delta: float, may_deliver: bool) -> void:
	# The cab drives to its hailed sleeper and takes him aboard on arrival.
	# If the player enters the cafe safe zone or the sleeper leaves wander,
	# the cab aborts the hail instead of delivering into a safe zone or mid-hug.
	if not may_deliver or _passenger == null or _passenger.state != Sleepwalker.State.WANDER:
		_release_passenger()
		return
	var distance_left := _step_toward(_passenger.global_position, delta)
	if distance_left <= balance.pickup_radius:
		_passenger.set_physics_process(false)
		_state = CabState.DELIVER
		queue_redraw()


func _tick_deliver(delta: float, player: Player, may_deliver: bool) -> void:
	# The cab carries its sleeper to the player and lets him out at the curb,
	# still asleep, so the player can wake him.
	if not may_deliver or _passenger == null:
		_release_passenger()
		return
	_passenger.global_position = global_position + SEAT_OFFSET.rotated(rotation)
	var distance_left := _step_toward(player.global_position, delta)
	if distance_left <= balance.delivery_radius:
		_release_passenger()
		passenger_delivered.emit(_last_passenger)


func _release_passenger() -> void:
	# The ride ends: the sleeper steps out where the cab stands, asleep, and
	# the cab parks for its cooldown.
	if _passenger != null and is_instance_valid(_passenger):
		_passenger.set_physics_process(true)
	_last_passenger = _passenger
	_passenger = null
	_state = CabState.PARKED
	_wait_left = balance.delivery_cooldown if balance != null else 0.0
	queue_redraw()


func _passenger_rides_still() -> bool:
	# A ride holds while its sleeper still sleeps in the world: an awake
	# passenger walks off on his own, and a freed one is gone.
	return _passenger != null and is_instance_valid(_passenger) and not _passenger.is_awake()


func _step_toward(target: Vector2, delta: float) -> float:
	# One straight drive step at the tuned speed. Returns the distance left.
	var to_target := target - global_position
	var step := balance.cab_speed * delta
	if to_target.length() > step:
		var heading := to_target.normalized()
		global_position += heading * step
		rotation = heading.angle()
		return to_target.length() - step
	global_position = target
	return 0.0


func _draw() -> void:
	# The placeholder cab: a body, a windshield, and the roof light that burns
	# while a ride runs and dims when the fleet retires.
	var body := Rect2(-BODY_SIZE * 0.5, BODY_SIZE)
	draw_rect(body, BODY_COLOR)
	draw_rect(body, Color(0.2, 0.15, 0.1, 1.0), false, 3.0)
	draw_rect(Rect2(WINDOW_SIZE * Vector2(-0.5, -0.5), WINDOW_SIZE), WINDOW_COLOR)
	var light_rect := Rect2(
		Vector2(-LIGHT_SIZE.x * 0.5, -BODY_SIZE.y * 0.5 - LIGHT_SIZE.y - 4.0), LIGHT_SIZE
	)
	var light_color := LIGHT_OFF_COLOR
	if not _retired and _state != CabState.PARKED:
		light_color = LIGHT_ON_COLOR
	draw_rect(light_rect, light_color)
