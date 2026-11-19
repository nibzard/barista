# ABOUTME: BossSaveState moves the cure state of a boss fight to the save slot.
# ABOUTME: The V1 fights share no base class, so this helper owns the casts.
class_name BossSaveState
extends RefCounted


static func capture(boss: Node2D) -> Dictionary:
	# Section 18: the cure of the arena show rides the run slot as one plain
	# dict, whatever fight the city holds. A city without a boss saves empty
	# state, so its reload builds the fight fresh.
	var band := boss as SleepJamBand
	if band != null:
		return band.save_state()
	var throwers := boss as FishThrowers
	if throwers != null:
		return throwers.save_state()
	var keynote := boss as SamOatman
	if keynote != null:
		return keynote.save_state()
	return {}


static func apply_saved(boss: Node2D, saved: Dictionary) -> void:
	# A saved cure lands silent on the built fight, like the loaded tower
	# switch: the slot already recorded the beat, so the reload never replays
	# a show the save ended.
	if boss == null:
		return
	var band := boss as SleepJamBand
	if band != null:
		band.load_state(saved)
		return
	var throwers := boss as FishThrowers
	if throwers != null:
		throwers.load_state(saved)
		return
	var keynote := boss as SamOatman
	if keynote != null:
		keynote.load_state(saved)
