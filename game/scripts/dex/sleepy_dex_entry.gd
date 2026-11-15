# ABOUTME: SleepyDexEntry is one SleepyDex row: the sleepwalker type and rarity.
# ABOUTME: Rarity drives the hidden rule: a rare type stays absent until found.
class_name SleepyDexEntry
extends Resource

enum Rarity { COMMON, RARE }

@export var enemy_type: EnemyType
@export var rarity: Rarity = Rarity.COMMON


func type_id() -> String:
	return enemy_type.type_id if enemy_type != null else ""


func display_name() -> String:
	return enemy_type.display_name if enemy_type != null else ""


func portrait_color() -> Color:
	# Placeholder picture until the art pass: the pajama color of the type.
	return enemy_type.pajama_color if enemy_type != null else Color.BLACK


func is_rare() -> bool:
	return rarity == Rarity.RARE
