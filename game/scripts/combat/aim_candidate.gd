# ABOUTME: AimCandidate pairs a sleepwalker's position with its velocity, so
# ABOUTME: the aim cone can lead a mover to its impact-time position.
class_name AimCandidate
extends RefCounted

var position: Vector2
var velocity: Vector2


func _init(start_position: Vector2 = Vector2.ZERO, start_velocity: Vector2 = Vector2.ZERO) -> void:
	position = start_position
	velocity = start_velocity
