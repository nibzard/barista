# ABOUTME: SleepvanaBalance holds the Sleepvana quest tuning values as a typed
# ABOUTME: resource. The numbers live in game/resources/balance/sleepvana.tres.
class_name SleepvanaBalance
extends Resource

# A full crowd holds this many fans at the field cafe and at the garage.
@export var crowd_size: int
# Fans inside this radius of the garage count as the arrived crowd.
@export var garage_arrival_radius: float
# The encore window in which the frontman order works.
@export var encore_seconds: float
# The concert wake event wakes every sleepwalker inside this hearing range.
@export var concert_wake_radius: float
