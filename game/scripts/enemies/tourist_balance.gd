# ABOUTME: TouristBalance holds the camera-flash tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/tourist.tres, never in scripts.
class_name TouristBalance
extends Resource

@export var photo_interval_seconds: float
@export var flash_windup_seconds: float
@export var flash_stun_seconds: float
@export var flash_radius: float
@export var photo_recovery_seconds: float
