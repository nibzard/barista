# ABOUTME: CityBlock is the data of one block in the shared city block kit.
# ABOUTME: The kind marks the landmark; density and speaker poles follow section 17.
class_name CityBlock
extends Resource

enum Kind { CAFE, TOWER, BOSS_ARENA, QUEST, SCAVENGE, QUEST_SITE }

@export var kind: Kind = Kind.SCAVENGE
@export var sleepwalker_count: int = 3
@export var has_speaker_pole := false
# The named place on the block when the landmark has one, like the greenhouse
# of the Sleepvana quest. Empty on plain kit blocks.
@export var site_name := ""
# Section 15: the one-time finds of the block, authored scavenge loot like the
# thermos belt and the cafe appliances. Empty on plain kit blocks.
@export var finds: Array[ScavengeDrop] = []
# Section 15 beans table: the locked side room of the city. The excellent
# Geisha Vault beans wait inside, behind a door the vault key opens. Null on
# blocks without a room; the validator caps a city at one.
@export var locked_side_room: SideRoomLoot
