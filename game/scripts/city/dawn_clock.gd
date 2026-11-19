# ABOUTME: DawnClock keeps the in-city day of the Moonwalker mystery, section 24.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name DawnClock
extends RefCounted

var balance: MoonwalkerBalance

var _time := 0.0


func _init(moonwalker_balance: MoonwalkerBalance) -> void:
	balance = moonwalker_balance
	# The first day starts just past the dawn window: the figure needs the
	# player to earn the silence first, so dawn never opens at the city gate.
	_time = balance.dawn_length_seconds


func tick(delta: float) -> void:
	_time = fposmod(_time + delta, balance.day_cycle_seconds)


func advance(seconds: float) -> void:
	# One plain jump on the clock, for callers that step whole beats at once.
	tick(seconds)


func is_dawn() -> bool:
	return _time < balance.dawn_length_seconds


func time_of_day() -> float:
	return _time
