# ABOUTME: Player is the barista: moves, throws coffee cups, falls asleep when hugged too long.
# ABOUTME: Input handling stays here; the sleep meter is a separate testable component.
class_name Player
extends CharacterBody2D

signal fell_asleep

const SPEED := 220.0
const SLEEP_RECOVERY_PER_SECOND := 0.06

@export var cup_scene: PackedScene

var sleep_meter := SleepMeter.new()

var _announced_sleep := false

@onready var cup_spawn: Marker2D = $CupSpawn


func _physics_process(delta: float) -> void:
	if _announced_sleep:
		velocity = Vector2.ZERO
		return
	var input_direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = input_direction * SPEED
	move_and_slide()
	sleep_meter.recover(SLEEP_RECOVERY_PER_SECOND * delta)


func fall_asleep() -> void:
	if _announced_sleep:
		return
	_announced_sleep = true
	velocity = Vector2.ZERO
	fell_asleep.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"throw_coffee"):
		throw_cup(get_global_mouse_position() - global_position)


func throw_cup(direction: Vector2) -> CoffeeCup:
	var cup := cup_scene.instantiate() as CoffeeCup
	cup.direction = direction.normalized()
	get_parent().add_child(cup)
	cup.global_position = cup_spawn.global_position
	return cup
