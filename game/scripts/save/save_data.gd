# ABOUTME: SaveData is the auto-save document: one versioned dict of plain values.
# ABOUTME: This slice holds the tower phase per city; section 18 grows the rest.
class_name SaveData
extends RefCounted

# Bump when the document changes shape. A save from a newer version stays
# unreadable, so a read from the future returns no document.
const SAVE_VERSION := 1

# The saved broadcast tower phase per city id, GAME_DESIGN section 18. The
# tower owns the meaning of the numbers; the document stores them as they are.
var tower_phases: Dictionary = {}


static func from_dict(saved: Dictionary) -> SaveData:
	# A document without a known version is no save of this game.
	var version := int(saved.get("save_version", 0))
	if version < 1 or version > SAVE_VERSION:
		return null
	var data := SaveData.new()
	var phases: Dictionary = saved.get("tower_phases", {})
	for city_id: String in phases:
		data.tower_phases[city_id] = int(phases[city_id])
	return data


func to_dict() -> Dictionary:
	# The document hands out a copy, so a caller cannot change the save by
	# holding the dict.
	return {"save_version": SAVE_VERSION, "tower_phases": tower_phases.duplicate()}


func set_tower_phase(city_id: String, phase: int) -> void:
	tower_phases[city_id] = phase


func tower_phase(city_id: String, default_phase: int) -> int:
	# A city the save never saw starts at the caller's default phase.
	return int(tower_phases.get(city_id, default_phase))


func has_tower_state(city_id: String) -> bool:
	return tower_phases.has(city_id)
