# ABOUTME: MoonwalkGait is the Moonwalker's gait, section 6 and section 24.
# ABOUTME: Pure logic with no nodes: every move is one backwards slide, and
# ABOUTME: the telegraph runs in reverse, after the move it should announce.
class_name MoonwalkGait
extends RefCounted

enum Phase { SLIDE, TELEGRAPH, REST }

var balance: MoonwalkerBalance

# The way the figure faces: always opposite the slide, so he looks like he
# goes away while he comes closer, section 6.
var facing := Vector2.LEFT

var _phase: Phase = Phase.SLIDE
var _timer := 0.0
var _direction := Vector2.ZERO


func _init(moonwalker_balance: MoonwalkerBalance) -> void:
	balance = moonwalker_balance
	_timer = balance.slide_duration_seconds


func step(delta: float, steer: Vector2) -> Vector2:
	# One frame of the gait. The cycle runs slide, telegraph, rest: the red
	# telegraph lands after the slide, a warning for a move that already
	# happened, so a player who answers it answers a lie. The slide
	# direction locks when the slide fires, like the Gamer dash.
	_timer -= delta
	match _phase:
		Phase.SLIDE:
			if _timer <= 0.0:
				_phase = Phase.TELEGRAPH
				_timer = balance.telegraph_seconds
				return Vector2.ZERO
			if _direction != Vector2.ZERO:
				facing = -_direction
			return _direction * balance.slide_speed
		Phase.TELEGRAPH:
			if _timer <= 0.0:
				_phase = Phase.REST
				_timer = balance.rest_seconds
			return Vector2.ZERO
		Phase.REST:
			if _timer <= 0.0:
				_phase = Phase.SLIDE
				_timer = balance.slide_duration_seconds
				_direction = steer.normalized()
			return Vector2.ZERO
	return Vector2.ZERO


func aim(direction: Vector2) -> void:
	# The haunt aims the entry slide, section 24: the figure crosses the
	# plaza from edge to edge, backwards, right out of the dawn. Only a live
	# slide takes the order.
	if _phase != Phase.SLIDE or direction == Vector2.ZERO:
		return
	_direction = direction.normalized()
	facing = -_direction


func phase() -> Phase:
	return _phase


func is_telegraphing() -> bool:
	return _phase == Phase.TELEGRAPH


func is_sliding() -> bool:
	return _phase == Phase.SLIDE and _direction != Vector2.ZERO
