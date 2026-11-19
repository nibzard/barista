# ABOUTME: WakeUps counts the remaining wake-ups: the lives of the barista.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name WakeUps
extends RefCounted

enum SleepOutcome { WOKE_IN_CAFE, DIED }

var balance: WakeUpsBalance
var remaining: int
# Section 9, hardcore mode: the player has no wake-ups at all. The first sleep
# ends the game, so no count ever pays for a wake in the cafe.
var hardcore := false


func _init(wake_balance: WakeUpsBalance) -> void:
	balance = wake_balance
	remaining = balance.start_wake_ups


func set_hardcore(enabled: bool) -> void:
	# The mode rides the save slot, section 9. A hardcore run starts at zero
	# wake-ups and never holds any again.
	hardcore = enabled
	if hardcore:
		remaining = 0


func has_wake_ups() -> bool:
	return not hardcore and remaining > 0


func register_sleep() -> SleepOutcome:
	# An empty meter makes the player sleep on the spot. One wake-up pays for
	# the wake in the cafe. A sleep at zero wake-ups is full death instead.
	# Hardcore mode holds no wake-ups: the first sleep is the full death.
	if hardcore or remaining <= 0:
		return SleepOutcome.DIED
	remaining -= 1
	return SleepOutcome.WOKE_IN_CAFE


func restore_one() -> int:
	# Switching off a city tower restores 1 wake-up, up to the maximum.
	# Hardcore mode holds no wake-ups, so the switch restores nothing there.
	if not hardcore:
		remaining = mini(remaining + 1, balance.max_wake_ups)
	return remaining


func save_state() -> int:
	# The save system stores the remaining wake-ups, section 18: a full death
	# reloads the last save with the wake-ups from that save.
	return remaining


func load_state(saved_remaining: int) -> void:
	# A loaded count lands silent: no death fires at zero, because the reload
	# always restores a save that held at least one wake-up. A hardcore slot
	# holds no wake-ups, whatever count it carried.
	remaining = clampi(saved_remaining, 0, balance.max_wake_ups)
	if hardcore:
		remaining = 0
