# ABOUTME: SaveSystem drives the auto-save slot for one game session.
# ABOUTME: This slice records the tower switch and answers the tower state.
class_name SaveSystem
extends RefCounted

var _store: SaveStore
var _data: SaveData = null


func _init(save_file_path: String = SaveStore.DEFAULT_SAVE_FILE) -> void:
	_store = SaveStore.new(save_file_path)


func record_tower_switch(city_id: String, phase: int) -> Error:
	# Save point of section 18: the tower switch. The run reads the phase
	# from its tower and the system writes the slot at once, so the player
	# can close the app the moment the beat lands.
	_ensure_loaded()
	_data.set_tower_phase(city_id, phase)
	return _store.write(_data)


func saved_tower_phase(city_id: String, default_phase: int) -> int:
	_ensure_loaded()
	return _data.tower_phase(city_id, default_phase)


func has_tower_state(city_id: String) -> bool:
	_ensure_loaded()
	return _data.has_tower_state(city_id)


func has_save() -> bool:
	return _store.exists()


func delete_save() -> bool:
	# Death in hardcore mode deletes the slot, section 18. The in-memory
	# document goes with it, so the next record starts a fresh save.
	var deleted := _store.delete_save()
	_data = null
	return deleted


func _ensure_loaded() -> void:
	# One system holds the slot for its whole run. The document loads from
	# disk once, then every save point writes the full slot back.
	if _data == null:
		_data = _store.read()
	if _data == null:
		_data = SaveData.new()
