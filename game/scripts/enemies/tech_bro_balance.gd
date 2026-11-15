# ABOUTME: TechBroBalance holds the pitch and drone tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/tech_bro.tres, never in scripts.
class_name TechBroBalance
extends Resource

@export var pitch_interval_seconds: float
@export var orbit_radius: float
@export var orbit_angular_speed_degrees_per_second: float
@export var dive_trigger_radius: float
@export var dive_speed: float
@export var bump_radius: float
@export var bump_stun_seconds: float
@export var dive_cooldown_seconds: float
