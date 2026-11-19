# ABOUTME: SignatureQuest is the base of a city's signature side quest scene,
# ABOUTME: section 13. The city run builds it from CityDefinition.quest_scene.
class_name SignatureQuest
extends Node2D


func setup(_run: Node) -> void:
	# The quest binds itself to the run: the map, the player, the van, and the
	# quest log. The signature quests of the cities override this. The run
	# arrives as a plain Node: naming the run class here would tie every quest
	# stage's compile back into the city script (T112).
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


func owns_screen() -> bool:
	# True while the quest drives an overlay that owns the whole screen, like
	# the ride board of the Robotaxi Depot. The run then stands its touch
	# buttons down behind it, like behind the brew stand.
	return false
