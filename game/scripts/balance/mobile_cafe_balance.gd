# ABOUTME: MobileCafeBalance holds the van upgrade tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/mobile_cafe.tres, never in scripts.
class_name MobileCafeBalance
extends Resource

@export var max_level: int = 3
@export var kitchen_scrap_cost: int = 5
@export var field_cafe_scrap_cost: int = 12
@export var field_base_radius: float = 300.0
@export var scrap_item: ItemType
