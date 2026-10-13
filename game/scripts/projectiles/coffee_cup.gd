# ABOUTME: CoffeeCup is the thrown projectile that wakes sleepwalkers on contact.
# ABOUTME: It flies straight for a limited distance, then frees itself.
class_name CoffeeCup
extends Area2D

@export var speed := 360.0
@export var max_travel_distance := 500.0

var direction := Vector2.RIGHT

var _travelled := 0.0

@onready var visual: Polygon2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	visual.rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_travel_distance:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body is Sleepwalker:
		body.wake_up()
		queue_free()
