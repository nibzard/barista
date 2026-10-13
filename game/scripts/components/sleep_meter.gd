# ABOUTME: SleepMeter tracks how close the player is to falling asleep.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name SleepMeter
extends RefCounted

const MAX_VALUE := 1.0

var value := 0.0


func add(amount: float) -> void:
	value = clampf(value + amount, 0.0, MAX_VALUE)


func recover(amount: float) -> void:
	value = clampf(value - amount, 0.0, MAX_VALUE)


func is_asleep() -> bool:
	return value >= MAX_VALUE
