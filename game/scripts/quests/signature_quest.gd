# ABOUTME: SignatureQuest is the base of a city's signature side quest scene,
# ABOUTME: section 13. CityRun builds it from CityDefinition.quest_scene.
class_name SignatureQuest
extends Node2D


func setup(_run: CityRun) -> void:
	# The quest binds itself to the run: the map, the player, the van, and the
	# quest log. The signature quests of the cities override this.
	pass


func try_interact() -> bool:
	# One button in the quest world. Returns true when the press was consumed,
	# so the van keeps its own interact otherwise.
	return false


func holds_interact() -> bool:
	# True while the quest drives an overlay that owns the interact key, like
	# the Foam Watch brew of the Aisle 7. The run then drops the press instead
	# of routing it to the masters or the van.
	return false
