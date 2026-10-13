# ABOUTME: Sleepwalker is the enemy of Apocalypse Barista: it can be woken, not killed.
# ABOUTME: It wanders, chases the player, and hugs until the player falls asleep.
class_name Sleepwalker
extends CharacterBody2D

signal woke_up

enum State { WANDER, CHASE, HUG, AWAKE }

const WANDER_CHANGE_MIN_SECONDS := 1.0
const WANDER_CHANGE_MAX_SECONDS := 3.0
const IDLE_CHANCE := 0.25

@export var walk_speed := 40.0
@export var chase_speed := 70.0
@export var hug_fill_time := 3.0

var state := State.WANDER
var player: Player = null

var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var sense_area: Area2D = $SenseArea
@onready var hug_area: Area2D = $HugArea
@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	_rng.randomize()
	_pick_wander_direction()


func _physics_process(delta: float) -> void:
	match state:
		State.WANDER:
			_process_wander(delta)
			_try_spot_player()
		State.CHASE, State.HUG:
			_process_engage(delta)
		State.AWAKE:
			velocity = Vector2.ZERO
	move_and_slide()


func wake_up() -> void:
	if state == State.AWAKE:
		return
	state = State.AWAKE
	velocity = Vector2.ZERO
	visual.modulate = Color(0.45, 0.85, 0.5)
	woke_up.emit()


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
	velocity = _wander_direction * walk_speed


func _process_engage(delta: float) -> void:
	# Poll the sensor areas instead of body_entered/exited signals: the signal
	# delivery order between sibling areas is not guaranteed and can misorder
	# the WANDER/CHASE/HUG transitions.
	if _is_player_in_area(hug_area):
		state = State.HUG
		velocity = Vector2.ZERO
		if player != null:
			player.sleep_meter.add(delta / hug_fill_time)
			if player.sleep_meter.is_asleep():
				player.fall_asleep()
		return
	state = State.CHASE
	if player == null:
		state = State.WANDER
		return
	velocity = (player.global_position - global_position).normalized() * chase_speed


func _try_spot_player() -> void:
	if _is_player_in_area(sense_area):
		state = State.CHASE


func _is_player_in_area(area: Area2D) -> bool:
	for body: Node2D in area.get_overlapping_bodies():
		if body is Player:
			player = body
			return true
	return false


func _pick_wander_direction() -> void:
	_wander_timer = _rng.randf_range(WANDER_CHANGE_MIN_SECONDS, WANDER_CHANGE_MAX_SECONDS)
	if _rng.randf() < IDLE_CHANCE:
		_wander_direction = Vector2.ZERO
	else:
		_wander_direction = Vector2.from_angle(_rng.randf() * TAU).normalized()
