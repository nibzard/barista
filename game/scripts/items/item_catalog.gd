# ABOUTME: ItemCatalog lists every ItemType of the game, section 15.
# ABOUTME: The save system resolves saved bag ids back to items through it.
class_name ItemCatalog
extends Resource

@export var items: Array[ItemType] = []


func find_item(item_id: String) -> ItemType:
	for item: ItemType in items:
		if item.item_id == item_id:
			return item
	return null
