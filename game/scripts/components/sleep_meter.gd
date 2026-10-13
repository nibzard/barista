# ABOUTME: SleepMeter tracks how awake the player is: full means awake, zero means asleep.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name SleepMeter
extends RefCounted

# Drain tiers in rising strength, per GAME_DESIGN section 14.
# The strongest active tier sets the drain rate for the frame.
# A safe zone, the cafe, stops the two environmental tiers for the frame.
enum DrainTier { PASSIVE, SLEEP_ZONE, BORING_ATTACK, HUG }

var balance: SleepMeterBalance
var value := 0.0

var _escalated_tier := DrainTier.PASSIVE
var _environmental_drain_suppressed := false
var _drink_time_left := 0.0


func _init(meter_balance: SleepMeterBalance) -> void:
	balance = meter_balance
	value = balance.max_value


func escalate_drain(tier: DrainTier) -> void:
	if tier > _escalated_tier:
		_escalated_tier = tier


func suppress_environmental_drain() -> void:
	_environmental_drain_suppressed = true


func begin_drinking() -> void:
	if _drink_time_left <= 0.0:
		_drink_time_left = balance.drink_duration_seconds


func is_drinking() -> bool:
	return _drink_time_left > 0.0


func tick(delta: float) -> void:
	var gain := 0.0
	if _drink_time_left > 0.0:
		var drink_delta := minf(delta, _drink_time_left)
		gain = balance.cup_gain * drink_delta / balance.drink_duration_seconds
		_drink_time_left -= drink_delta
	var drain := 0.0
	if not (_environmental_drain_suppressed and _is_environmental_tier(_escalated_tier)):
		drain = _rate_for_tier(_escalated_tier) * delta
	_environmental_drain_suppressed = false
	_escalated_tier = DrainTier.PASSIVE
	value = clampf(value + gain - drain, 0.0, balance.max_value)


func reset() -> void:
	# Waking in the cafe starts a new day: the meter fills, no drink carries over.
	value = balance.max_value
	_drink_time_left = 0.0


func drain(amount: float) -> void:
	value = clampf(value - amount, 0.0, balance.max_value)


func gain(amount: float) -> void:
	value = clampf(value + amount, 0.0, balance.max_value)


func is_asleep() -> bool:
	return value <= 0.0


func _is_environmental_tier(tier: DrainTier) -> bool:
	# A safe zone stops the pull of the address: the passive and the sleep-zone
	# tiers. Direct attacks, boring talks and hugs, still drain inside it.
	return tier == DrainTier.PASSIVE or tier == DrainTier.SLEEP_ZONE


func _rate_for_tier(tier: DrainTier) -> float:
	match tier:
		DrainTier.SLEEP_ZONE:
			return balance.sleep_zone_drain_per_second
		DrainTier.BORING_ATTACK:
			return balance.boring_attack_drain_per_second
		DrainTier.HUG:
			return balance.hug_drain_per_second
		_:
			return balance.passive_drain_per_second
