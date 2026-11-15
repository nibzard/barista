# ABOUTME: SideQuestDefinition is the data of one side quest: id, title, and
# ABOUTME: the named site that carries its marker. Content lives in .tres files.
class_name SideQuestDefinition
extends Resource

@export var quest_id: String
@export var title: String
# The city that offers this quest. Markers draw only in the city of the quest.
@export var city_id: String
# The named place of the quest goal, like "The Garage". Empty means the
# signature quest landmark of the city, like The Robotaxi Depot.
@export var site_name := ""
