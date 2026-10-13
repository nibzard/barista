# ABOUTME: SleepMeterBalance holds the sleepy-meter tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/sleep_meter.tres, never in scripts.
class_name SleepMeterBalance
extends Resource

@export var max_value: float
@export var passive_drain_per_second: float
@export var sleep_zone_drain_per_second: float
@export var boring_attack_drain_per_second: float
@export var hug_drain_per_second: float
@export var cup_gain: float
@export var drink_duration_seconds: float
