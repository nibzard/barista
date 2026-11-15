# ABOUTME: EnemySpawn pairs one enemy type with the scene that plays it.
# ABOUTME: City rosters list these entries in spawn order, see CityDefinition.
class_name EnemySpawn
extends Resource

@export var enemy_type: EnemyType
@export var scene: PackedScene
