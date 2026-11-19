# ABOUTME: SideRoomLoot is the authored content of one locked side room.
# ABOUTME: The kit composes the room; the finds wait inside behind the door.
class_name SideRoomLoot
extends Resource

# Section 15 beans table: the finds of the room, like the Geisha Vault beans
# of the city. Authored as city data, never kit literals (T086).
@export var drops: Array[ScavengeDrop] = []
# Section 15: the item the locked door consumes on unlock. The city validator
# reports a room whose key no city crate stocks, so the door can never lock
# the finds away for good.
@export var key: ItemType
