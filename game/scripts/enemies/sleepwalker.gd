# ABOUTME: Sleepwalker is the shared enemy engine: wander, chase, hug, wake.
# ABOUTME: The EnemyType resource defines the type, its cure, and its behavior.
class_name Sleepwalker
extends CharacterBody2D

signal woke_up
signal first_met(type_id: String)

enum State { WANDER, CHASE, HUG, AWAKE }

const SLEEPWALKER_GROUP := &"sleepwalkers"

@export var balance: SleepwalkerBalance
@export var enemy_type: EnemyType
@export var library: BrewingLibrary
@export var brewing_balance: BrewingBalance

var state := State.WANDER
var player: Player = null

var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
var _met_announced := false
var _rng := RandomNumberGenerator.new()

@onready var sense_area: Area2D = $SenseArea
@onready var hug_area: Area2D = $HugArea
@onready var visual: Polygon2D = $Visual
@onready var nightcap: Polygon2D = $Visual/Nightcap


func _ready() -> void:
	add_to_group(SLEEPWALKER_GROUP)
	_rng.randomize()
	_pick_wander_direction()
	visual.color = enemy_type.pajama_color
	nightcap.color = enemy_type.pajama_color


func _physics_process(delta: float) -> void:
	match state:
		State.WANDER:
			_process_wander(delta)
			_try_spot_player()
		State.CHASE, State.HUG:
			_process_engage()
		State.AWAKE:
			velocity = Vector2.ZERO
	move_and_slide()


func wake_up() -> void:
	if state == State.AWAKE:
		return
	if state == State.HUG and player != null:
		player.clear_grab(self)
	state = State.AWAKE
	velocity = Vector2.ZERO
	visual.modulate = Color(0.45, 0.85, 0.5)
	woke_up.emit()


func is_awake() -> bool:
	return state == State.AWAKE


func try_wake(cup: BrewedCup) -> bool:
	if state == State.AWAKE:
		return false
	if not CureMatcher.can_wake(cup, enemy_type.cure, library, brewing_balance):
		return false
	wake_up()
	return true


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
	velocity = _wander_direction * balance.walk_speed


func _process_engage() -> void:
	match enemy_type.special_behavior:
		EnemyType.SpecialBehavior.SIMPLE_HUG:
			_engage_simple_hug()


func _engage_simple_hug() -> void:
	# Poll the sensor areas instead of body_entered/exited signals: the signal
	# delivery order between sibling areas is not guaranteed and can misorder
	# the WANDER/CHASE/HUG transitions. A rolling or freshly-freed player
	# cannot be grabbed: the hug slides off.
	if _is_player_in_area(hug_area) and player != null and not player.is_invulnerable():
		state = State.HUG
		velocity = Vector2.ZERO
		player.set_grabbed_by(self)
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.HUG)
		return
	if state == State.HUG and player != null:
		player.clear_grab(self)
	state = State.CHASE
	if player == null:
		state = State.WANDER
		return
	velocity = (player.global_position - global_position).normalized() * balance.chase_speed


func _try_spot_player() -> void:
	if _is_player_in_area(sense_area):
		state = State.CHASE
		if not _met_announced:
			_met_announced = true
			first_met.emit(enemy_type.type_id)


func _is_player_in_area(area: Area2D) -> bool:
	for body: Node2D in area.get_overlapping_bodies():
		if body is Player:
			player = body
			return true
	return false


func _pick_wander_direction() -> void:
	_wander_timer = _rng.randf_range(
		balance.wander_change_min_seconds, balance.wander_change_max_seconds
	)
	if _rng.randf() < balance.idle_chance:
		_wander_direction = Vector2.ZERO
	else:
		_wander_direction = Vector2.from_angle(_rng.randf() * TAU).normalized()
