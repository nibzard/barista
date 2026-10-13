# ABOUTME: ItemType defines one inventory item: a bean, gear, a material, or an appliance.
# ABOUTME: The V1 items live in game/resources/items/, one .tres per item.
class_name ItemType
extends Resource

enum Category {
	BEAN,
	GEAR,
	MATERIAL,
	APPLIANCE,
}

@export var item_id: String
@export var display_name: String
@export var category: Category
@export var max_stack: int = 1
@export var bean: BeanType
