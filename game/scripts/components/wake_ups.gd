# ABOUTME: WakeUps counts the remaining wake-ups: the lives of the barista.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name WakeUps
extends RefCounted

enum SleepOutcome { WOKE_IN_CAFE, DIED }

var balance: WakeUpsBalance
var remaining: int


func _init(wake_balance: WakeUpsBalance) -> void:
	balance = wake_balance
	remaining = balance.start_wake_ups


func has_wake_ups() -> bool:
	return remaining > 0


func register_sleep() -> SleepOutcome:
	# An empty meter makes the player sleep on the spot. One wake-up pays for
	# the wake in the cafe. A sleep at zero wake-ups is full death instead.
	if remaining <= 0:
		return SleepOutcome.DIED
	remaining -= 1
	return SleepOutcome.WOKE_IN_CAFE


func restore_one() -> int:
	# Switching off a city tower restores 1 wake-up, up to the maximum.
	remaining = mini(remaining + 1, balance.max_wake_ups)
	return remaining
