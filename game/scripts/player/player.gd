# ABOUTME: Player is the barista: moves, dodges, throws cups, drinks coffee to stay awake.
# ABOUTME: Input handling stays here; the meter, the supply, and the wake-ups are components.
class_name Player
extends CharacterBody2D

signal woke_in_cafe
signal died

const STANDARD_BEAN_ID := "house"
const STANDARD_ROAST_ID := "medium"
const STANDARD_METHOD_ID := "filter"
const THERMOS_BELT_ID := "thermos_belt"

@export var balance: PlayerBalance
@export var meter_balance: SleepMeterBalance
@export var supply_balance: CoffeeSupplyBalance
@export var wake_ups_balance: WakeUpsBalance
@export var cup_balance: CoffeeCupBalance
@export var brewing_library: BrewingLibrary
@export var brewing_balance: BrewingBalance
@export var cup_scene: PackedScene

var _asleep := false
var _grabber: Sleepwalker = null
var _mash_presses := 0
var _dodge_time_left := 0.0
var _grace_time_left := 0.0
var _dodge_direction := Vector2.RIGHT
var _last_move_direction := Vector2.RIGHT

@onready var sleep_meter := SleepMeter.new(meter_balance)
@onready var coffee_supply := CoffeeSupply.new(supply_balance)
@onready var wake_ups := WakeUps.new(wake_ups_balance)
@onready var inventory := Inventory.new()
@onready var cup_spawn: Marker2D = $CupSpawn
@onready var visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	if _asleep:
		velocity = Vector2.ZERO
		return
	_tick_combat_timers(delta)
	if _grabber != null:
		velocity = Vector2.ZERO
	elif is_dodging():
		velocity = _dodge_direction * balance.dodge_speed
	else:
		var input_direction := Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
		if input_direction != Vector2.ZERO:
			_last_move_direction = input_direction
		var speed := balance.move_speed
		if sleep_meter.is_drinking():
			speed *= balance.drink_slow_walk_factor
		velocity = input_direction * speed
	move_and_slide()
	sleep_meter.tick(delta)
	if sleep_meter.is_asleep():
		fall_asleep()


func _tick_combat_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = maxf(0.0, _dodge_time_left - delta)
	if _grace_time_left > 0.0:
		_grace_time_left = maxf(0.0, _grace_time_left - delta)
	visual.modulate.a = 0.5 if is_invulnerable() else 1.0


func fall_asleep() -> void:
	# The meter is empty: the player sleeps on the spot. One wake-up pays for
	# the wake in the cafe, and the world stays as it is. A sleep at zero
	# wake-ups is full death instead.
	if _asleep:
		return
	_asleep = true
	velocity = Vector2.ZERO
	if wake_ups.register_sleep() == WakeUps.SleepOutcome.DIED:
		died.emit()
		return
	woke_in_cafe.emit()
	wake_in_cafe()


func wake_in_cafe() -> void:
	# The player wakes in the cafe: a new day starts with a full meter.
	sleep_meter.reset()
	_grabber = null
	_mash_presses = 0
	_asleep = false


func is_asleep() -> bool:
	return _asleep


func begin_dodge(direction: Vector2) -> bool:
	# The dodge roll: a short burst of speed with invulnerability for the
	# whole roll. A grabbed player cannot roll; mashing is the only way out.
	if _asleep or _grabber != null or is_dodging():
		return false
	_dodge_direction = (
		direction.normalized() if direction != Vector2.ZERO else _last_move_direction
	)
	_dodge_time_left = balance.dodge_duration_seconds
	return true


func is_dodging() -> bool:
	return _dodge_time_left > 0.0


func is_invulnerable() -> bool:
	return is_dodging() or _grace_time_left > 0.0


func is_grabbed() -> bool:
	return _grabber != null


func set_grabbed_by(sleepwalker: Sleepwalker) -> void:
	if _grabber == null:
		_grabber = sleepwalker
		_mash_presses = 0


func clear_grab(sleepwalker: Sleepwalker) -> void:
	if _grabber == sleepwalker:
		_grabber = null
		_mash_presses = 0


func struggle() -> bool:
	# A grabbed player mashes presses to break the hug. The breaking press
	# frees the player and buys a grace window against an instant re-grab.
	if _grabber == null:
		return false
	_mash_presses += 1
	if _mash_presses >= balance.hug_mash_presses_to_break:
		_grabber = null
		_mash_presses = 0
		_grace_time_left = balance.hug_break_grace_seconds
		return true
	return false


func drink_cup() -> bool:
	if _asleep or _grabber != null:
		return false
	# The same cup heals the meter or wakes a sleepwalker, never both.
	if not coffee_supply.spend_cups(supply_balance.drink_cost):
		return false
	sleep_meter.begin_drinking()
	return true


func refill_supply() -> int:
	return coffee_supply.refill_at_cafe()


func pickup_item(item: ItemType, amount: int) -> int:
	# Scavenged goods enter the bag; a sleeping player picks nothing up.
	# The thermos belt raises the coffee carry limit as soon as it is worn.
	if _asleep:
		return 0
	var added: int = inventory.add(item, amount)
	if added > 0 and item.item_id == THERMOS_BELT_ID:
		coffee_supply.equip_thermos_belt()
	return added


func _unhandled_input(event: InputEvent) -> void:
	if is_grabbed():
		if _is_mash_press(event):
			struggle()
		return
	if event.is_action_pressed(&"throw_coffee"):
		throw_cup(get_global_mouse_position() - global_position)
	elif event.is_action_pressed(&"drink_coffee"):
		drink_cup()
	elif event.is_action_pressed(&"dodge"):
		begin_dodge(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"))


func _is_mash_press(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"throw_coffee")
		or event.is_action_pressed(&"drink_coffee")
		or event.is_action_pressed(&"dodge")
	)


func throw_cup(direction: Vector2) -> CoffeeCup:
	if _asleep or _grabber != null:
		return null
	if not coffee_supply.fire(CoffeeSupply.Weapon.CUP_THROW):
		return null
	var aim := direction.normalized() if direction != Vector2.ZERO else _last_move_direction
	var start := cup_spawn.global_position
	var landing := AimCone.landing_point(
		start,
		aim,
		_sleepwalker_positions(),
		cup_balance.aim_cone_half_angle_degrees,
		cup_balance.throw_range
	)
	var cup := cup_scene.instantiate() as CoffeeCup
	cup.direction = aim
	cup.brewed = _standard_cup()
	get_parent().add_child(cup)
	cup.global_position = start
	cup.launch(landing)
	return cup


func _sleepwalker_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var sleepwalker := node as Sleepwalker
		if sleepwalker != null and not sleepwalker.is_awake():
			positions.append(sleepwalker.global_position)
	return positions


func _standard_cup() -> BrewedCup:
	# The cafe-standard cup: a plain filter brew that wakes basic types only.
	return BrewedCup.new(
		brewing_library.find_bean(STANDARD_BEAN_ID),
		brewing_library.find_roast(STANDARD_ROAST_ID),
		brewing_library.find_method(STANDARD_METHOD_ID),
		"",
		brewing_balance.standard_cup_score
	)
