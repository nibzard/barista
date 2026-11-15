# ABOUTME: Drone is the Tech Bro's drone: it circles him and dives at the player.
# ABOUTME: The dive is a committed straight pass at the player's locked position.
class_name Drone
extends Area2D

enum State { ORBIT, DIVE, REGROUP, LANDED }

@export var balance: TechBroBalance
@export var anchor_path: NodePath = ^".."

var state := State.ORBIT
var anchor: Node2D = null
var target: Player = null

var _orbit_angle := 0.0
var _dive_cooldown := 0.0
var _dive_direction := Vector2.ZERO
var _dive_distance_left := 0.0


func _ready() -> void:
	# The drone follows the sleepwalker it was spawned with. When its master
	# wakes up, the pitch ends and the drone lands for good.
	var node := get_node_or_null(anchor_path) as Node2D
	if node == null:
		return
	anchor = node
	var sleeper := node as Sleepwalker
	if sleeper != null:
		sleeper.woke_up.connect(_land)


func _physics_process(delta: float) -> void:
	if state == State.LANDED or anchor == null:
		return
	_dive_cooldown = maxf(0.0, _dive_cooldown - delta)
	match state:
		State.ORBIT:
			_orbit(delta)
		State.DIVE:
			_dive(delta)
		State.REGROUP:
			_regroup(delta)


func _orbit(delta: float) -> void:
	_orbit_angle = fmod(
		_orbit_angle + deg_to_rad(balance.orbit_angular_speed_degrees_per_second) * delta, TAU
	)
	global_position = _orbit_point()
	if _dive_cooldown > 0.0:
		return
	var player := _sense_player()
	if player != null:
		target = player
		var to_player := player.global_position - global_position
		_dive_direction = to_player.normalized()
		_dive_distance_left = to_player.length()
		state = State.DIVE


func _dive(delta: float) -> void:
	# The run commits to the spot where the player stood at the lock. A player
	# that moves away makes the pass miss and fly into empty air.
	var step := balance.dive_speed * delta
	_dive_distance_left -= step
	global_position += _dive_direction * step
	if target != null and is_instance_valid(target) and not target.is_asleep():
		if global_position.distance_to(target.global_position) <= balance.bump_radius:
			_bump()
	if _dive_distance_left <= 0.0:
		_begin_regroup()


func _regroup(delta: float) -> void:
	# Fly back to the moving ring point. The orbit resumes on arrival.
	var ring := _orbit_point()
	var step := balance.dive_speed * delta
	var to_ring := ring - global_position
	if to_ring.length() <= step:
		global_position = ring
		state = State.ORBIT
	else:
		global_position += to_ring.normalized() * step


func _orbit_point() -> Vector2:
	return anchor.global_position + Vector2.from_angle(_orbit_angle) * balance.orbit_radius


func _sense_player() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _bump() -> void:
	# The drone makes its pass. A rolling or freshly-freed player cannot be
	# hit: the bump slides off. A sleeping player is left alone.
	if not target.is_invulnerable() and not target.is_asleep():
		target.apply_stun(balance.bump_stun_seconds)


func _begin_regroup() -> void:
	target = null
	_dive_cooldown = balance.dive_cooldown_seconds
	state = State.REGROUP


func _land() -> void:
	# The cure wakes the pitcher. The drone lands and stays down.
	state = State.LANDED
	target = null
