# ABOUTME: BroadcastTowerBalance holds the tower switch tuning as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/broadcast_tower.tres, never in scripts.
class_name BroadcastTowerBalance
extends Resource

@export var silence_seconds: float
@export var fuses_needed: int
