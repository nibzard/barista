# ABOUTME: CityDefinition holds one city as an ordered row of shared kit blocks.
# ABOUTME: The first block is the cafe edge; the last block is the tower edge.
class_name CityDefinition
extends Resource

@export var city_id: String
@export var display_name: String
@export var accent_color := Color.WHITE
@export var boss_name: String
@export var quest_name: String
@export var blocks: Array[CityBlock] = []
