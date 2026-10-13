# ABOUTME: ScavengeDrop is one loot entry of a scavenge point: an item and an amount.
# ABOUTME: Scavenge points build their loot tables from these small data resources.
class_name ScavengeDrop
extends Resource

@export var item: ItemType
@export var amount: int = 1
