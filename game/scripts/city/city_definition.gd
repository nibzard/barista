# ABOUTME: CityDefinition holds one city as an ordered row of shared kit blocks.
# ABOUTME: The first block is the cafe edge; the last block is the tower edge.
class_name CityDefinition
extends Resource

@export var city_id: String
@export var display_name: String
@export var accent_color := Color.WHITE
# Section 15 beans table: the region bean the scavenge buildings of the city
# yield. Golden Coast arabica in Steamtle, Moss Hollow organic in Pourtland.
# Null in San Coffesco: house beans are the common bean of every city.
@export var region_bean: ItemType
# Section 10: each new city has a cafe one tier bigger and better than the old
# one. City 1 on the route holds tier 1.
@export var cafe_tier: int = 1
@export var boss_name: String
# The boss fight of the city, played on the boss arena block by the run. Null
# until the boss fight of the city ships.
@export var boss_scene: PackedScene
@export var quest_name: String
# The signature quest flow of the city, played at its named sites by the run.
# Null until the quest of the city ships, like the boss scene.
@export var quest_scene: PackedScene
@export var blocks: Array[CityBlock] = []
# The city roster in spawn order: the first entry is the basic type that
# teaches the throw. Later cities fill their roster when their types ship.
@export var roster: Array[EnemySpawn] = []
# The side quests that this city offers, section 13: one signature quest per
# version 1 city.
@export var side_quests: Array[SideQuestDefinition] = []
# The brewing masters that live in this city, section 8. Each V1 city hosts
# exactly one master, who teaches at the city cafe.
@export var masters: Array[BrewingMaster] = []
