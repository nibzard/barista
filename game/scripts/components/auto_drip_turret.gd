# ABOUTME: AutoDripTurret is the deployable drip tower of section 11: it drips
# ABOUTME: coffee on every sleepwalker below it and works alone until the tank
# ABOUTME: runs dry.
class_name AutoDripTurret
extends Node2D

# Placeholder tower colors until the art pass brings real props.
const TOWER_FILL := Color(0.72, 0.7, 0.62, 0.95)
const TOWER_EDGE := Color(0.25, 0.24, 0.2, 1.0)
const TOWER_HALF_SIZE := Vector2(14.0, 26.0)
const DRIP_HEAD_RADIUS := 9.0

@export var balance: CureWeaponsBalance

# The tank payload, drawn from the player's hand at deploy: every drip of this
# tower carries it until the tank runs dry.
var payload: BrewedCup = null

var _tank_time_left := 0.0
var _drip_time_left := 0.0


func _ready() -> void:
	_tank_time_left = balance.turret_tank_seconds
	_drip_time_left = balance.turret_drip_interval_seconds


func _physics_process(delta: float) -> void:
	if _tank_time_left <= 0.0:
		return
	_tank_time_left = maxf(0.0, _tank_time_left - delta)
	_drip_time_left -= delta
	if _drip_time_left <= 0.0:
		_drip_time_left += balance.turret_drip_interval_seconds
		_drip()
	if _tank_time_left <= 0.0:
		queue_free()


func _drip() -> void:
	# One drip falls from the head onto every sleepwalker below the tower,
	# section 11. The player stands anywhere: the tower works alone.
	CureDelivery.drip_wake(global_position, balance.turret_drip_radius, payload, get_tree())


func _draw() -> void:
	# Placeholder drip tower: a thin tower with a wide shower head.
	var body := Rect2(-TOWER_HALF_SIZE, TOWER_HALF_SIZE * 2.0)
	draw_rect(body, TOWER_FILL)
	draw_rect(body, TOWER_EDGE, false, 2.0)
	draw_circle(Vector2(0.0, -TOWER_HALF_SIZE.y), DRIP_HEAD_RADIUS, TOWER_FILL)
	draw_arc(
		Vector2(0.0, -TOWER_HALF_SIZE.y), DRIP_HEAD_RADIUS - 1.0, 0.0, TAU, 24, TOWER_EDGE, 2.0
	)
