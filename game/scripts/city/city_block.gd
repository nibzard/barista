# ABOUTME: CityBlock is the data of one block in the shared city block kit.
# ABOUTME: The kind marks the landmark; density and speaker poles follow section 17.
class_name CityBlock
extends Resource

enum Kind { CAFE, TOWER, BOSS_ARENA, QUEST, SCAVENGE }

@export var kind: Kind = Kind.SCAVENGE
@export var sleepwalker_count: int = 3
@export var has_speaker_pole := false
