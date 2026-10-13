# ABOUTME: CoffeeSupplyBalance holds the coffee supply tuning values as a typed resource.
# ABOUTME: The numbers live in game/resources/balance/coffee_supply.tres, never in scripts.
class_name CoffeeSupplyBalance
extends Resource

@export var base_carry_limit: int
@export var mobile_cafe_level2_carry_limit: int
@export var thermos_belt_carry_bonus: int
@export var drink_cost: int
@export var support_tool_cost: int
@export var cup_throw_cost: int
@export var travel_mug_cost: int
@export var thermos_cost: int
@export var moka_launcher_cost: int
@export var minigun_cups_per_second: float
