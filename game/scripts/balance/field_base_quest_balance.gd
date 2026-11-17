# ABOUTME: FieldBaseQuestBalance holds the tuning of the small side quest that
# ABOUTME: gathered survivors give at the level 3 field base, section 10.
class_name FieldBaseQuestBalance
extends Resource

# How many survivors must sit at the tables before one of them asks.
@export var min_gathered_survivors: int = 1
# The small ask of the round: house beans for the field kitchen.
@export var beans_goal: int = 3
# The thank-you of the survivors: scrap parts for the van, section 15.
@export var reward_scrap_parts: int = 1
@export var bean_item: ItemType
@export var reward_item: ItemType
