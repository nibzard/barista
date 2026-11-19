# ABOUTME: SaveSystem drives the auto-save slot for one game session.
# ABOUTME: Section 18: every save point writes the whole run state at once.
class_name SaveSystem
extends RefCounted

# The slot holder that waits through a scene change, like the van handoff of
# the move east: a run that reloads its save, and the menu that continues one,
# park the system so the arriving scene reads the same slot without building
# its own. The holder clears on the first take, so nothing leaks.
static var _scene_change_handoff: SaveSystem = null

var _store: SaveStore
var _data: SaveData = null


static func park_for_scene_change(system: SaveSystem) -> void:
	_scene_change_handoff = system


static func take_after_scene_change() -> SaveSystem:
	var arriving := _scene_change_handoff
	_scene_change_handoff = null
	return arriving


func _init(save_file_path: String = SaveStore.DEFAULT_SAVE_FILE) -> void:
	_store = SaveStore.new(save_file_path)


func record_appearance(new_appearance: CharacterAppearance) -> Error:
	# Section 5: the creation screen writes the cosmetic choices into the slot
	# before the first run starts. A later save point never touches them, so
	# the barista keeps the created look for the whole save.
	_ensure_loaded()
	_data.appearance = new_appearance.to_dict()
	return _store.write(_data)


func saved_appearance(catalog: AppearanceCatalog) -> CharacterAppearance:
	# The created look, or the catalog defaults when the slot holds none: a
	# fresh slot and a corrupt field both read as the default barista.
	_ensure_loaded()
	return CharacterAppearance.from_dict(_data.appearance, catalog)


func has_appearance() -> bool:
	# The menu asks before it sends the player back into the creation screen:
	# a slot that already holds a look goes straight to the first run.
	_ensure_loaded()
	return not _data.appearance.is_empty()


func record_game_mode(mode: String) -> Error:
	# Section 9: the menu writes the chosen mode into the slot before the
	# first run starts. Every save point of the run rewrites it from the live
	# game, so the mode travels with the whole run.
	_ensure_loaded()
	_data.game_mode = SaveData.mode_or_default(mode)
	return _store.write(_data)


func saved_game_mode() -> String:
	# The mode the next run plays, section 9: normal when the slot holds no
	# mode yet, hardcore when the menu or a save point wrote it.
	_ensure_loaded()
	return _data.game_mode


func record_save_point(point: String, run_state: Dictionary) -> Error:
	# One save point of section 18: the cafe entry, the tower switch, the
	# boss cured, or the ended version. The run hands its whole state, so the
	# player can close the app the moment the beat lands and lose nothing the
	# slot could hold.
	# The tower phase and the vault door of the saved city merge into the
	# cross-city maps, so a save in one city never erases another city's.
	_ensure_loaded()
	var city_id := run_state.get("city_id", "") as String
	# The street crowd awake flags of the saved city, T134: they ride the run
	# state and the stored city world, so a reload and the return west both
	# rebuild the woken street.
	var crowd_awake := SaveData.bool_array(run_state.get("crowd_awake", []))
	_data.save_point = point
	_data.city_id = city_id
	_data.scene_path = run_state.get("scene_path", "") as String
	var saved_position := run_state.get("position", Vector2.ZERO) as Vector2
	_data.position_x = saved_position.x
	_data.position_y = saved_position.y
	_data.meter_value = float(run_state.get("meter_value", 0.0))
	_data.wake_ups = int(run_state.get("wake_ups", 0))
	_data.bag_counts = SaveData.int_dict(run_state.get("bag", {}))
	_data.cups = int(run_state.get("cups", 0))
	_data.has_thermos_belt = bool(run_state.get("thermos_belt", false))
	_data.brew_hand_state = SaveData.dict_or_empty(run_state.get("brew_hand", {}))
	_data.skills = SaveData.int_dict(run_state.get("skills", {}))
	_data.dex_state = SaveData.dict_or_empty(run_state.get("dex", {}))
	_data.cold_brew_state = SaveData.dict_or_empty(run_state.get("cold_brew", {}))
	_data.van_level = int(run_state.get("van_level", 0))
	_data.quest_state = SaveData.dict_or_empty(run_state.get("quests", {}))
	_data.progress_state = SaveData.dict_or_empty(run_state.get("progress", {}))
	_data.boss_state = SaveData.dict_or_empty(run_state.get("boss", {}))
	_data.crowd_awake = crowd_awake
	_data.moving_day_done = bool(run_state.get("moving_day", false))
	_data.tutorial_state = SaveData.dict_or_empty(run_state.get("tutorial", {}))
	_data.outro_state = SaveData.dict_or_empty(run_state.get("outro", {}))
	_data.purchase_unlocked = bool(run_state.get("unlock", false))
	# A run state that names no mode, like a partial record, keeps the mode
	# the slot already holds: a hardcore run never softens by one save point.
	_data.game_mode = SaveData.mode_or_default(run_state.get("game_mode", _data.game_mode))
	# A run without a tower or a vault, like a dev room, keeps the cross-city
	# maps as they stand: a missing phase must never override a city default.
	if int(run_state.get("tower_phase", -1)) >= 0:
		_data.set_tower_phase(city_id, int(run_state.get("tower_phase", -1)))
	if city_id != "" and bool(run_state.get("vault_open", false)):
		_data.set_vault_open(city_id, true)
	if city_id != "":
		# The world of this city at its last save point, section 23: a save in
		# one city never erases the saved world of another.
		(
			_data
			. set_city_world(
				city_id,
				{
					"progress": SaveData.dict_or_empty(run_state.get("progress", {})),
					"boss": SaveData.dict_or_empty(run_state.get("boss", {})),
					"crowd_awake": crowd_awake,
					"outro": SaveData.dict_or_empty(run_state.get("outro", {})),
					"moving_day": bool(run_state.get("moving_day", false)),
					"tutorial": SaveData.dict_or_empty(run_state.get("tutorial", {})),
					"cold_brew": SaveData.dict_or_empty(run_state.get("cold_brew", {})),
					"tower_phase": int(run_state.get("tower_phase", -1)),
				}
			)
		)
	return _store.write(_data)


func saved_run_state() -> Dictionary:
	# The run state of the last save point as one plain dict, the same shape
	# record_save_point takes. Empty when the slot holds no run state, like a
	# missing slot or a document from another version.
	_ensure_loaded()
	if not _data.has_run_state():
		return {}
	return {
		"save_point": _data.save_point,
		"city_id": _data.city_id,
		"scene_path": _data.scene_path,
		"position": Vector2(_data.position_x, _data.position_y),
		"meter_value": _data.meter_value,
		"wake_ups": _data.wake_ups,
		"bag": _data.bag_counts.duplicate(),
		"cups": _data.cups,
		"thermos_belt": _data.has_thermos_belt,
		"brew_hand": _data.brew_hand_state.duplicate(),
		"skills": _data.skills.duplicate(),
		"dex": _data.dex_state.duplicate(),
		"cold_brew": _data.cold_brew_state.duplicate(),
		"van_level": _data.van_level,
		"quests": _data.quest_state.duplicate(),
		"progress": _data.progress_state.duplicate(),
		"boss": _data.boss_state.duplicate(),
		"crowd_awake": _data.crowd_awake.duplicate(),
		"moving_day": _data.moving_day_done,
		"tutorial": _data.tutorial_state.duplicate(),
		"outro": _data.outro_state.duplicate(),
		"unlock": _data.purchase_unlocked,
		"game_mode": _data.game_mode,
		"tower_phase": _data.tower_phase(_data.city_id, -1),
		"vault_open": _data.is_vault_open(_data.city_id),
	}


func has_run_state() -> bool:
	_ensure_loaded()
	return _data.has_run_state()


func saved_run_state_for(scene_path: String) -> Dictionary:
	# The run state only when this very scene wrote the slot: the intro
	# tutorial stays the fresh start of the game against any other slot, and a
	# save of another city never bleeds into this one.
	var saved := saved_run_state()
	if saved.get("scene_path", "") != scene_path:
		return {}
	return saved


func continue_scene_path() -> String:
	# The scene the game boots into to continue at the last save point,
	# section 18. Empty when the slot holds no run state: the menu starts the
	# fresh tutorial instead.
	_ensure_loaded()
	return _data.scene_path if _data.has_run_state() else ""


func saved_save_point() -> String:
	# Which save point wrote the slot: cafe entry, tower switch, or boss cured.
	_ensure_loaded()
	return _data.save_point


func saved_tower_phase(city_id: String, default_phase: int) -> int:
	_ensure_loaded()
	return _data.tower_phase(city_id, default_phase)


func city_world(city_id: String) -> Dictionary:
	# The saved world of one city, section 23: the road west reads it, so the
	# return finds the city as its last save point left it. Empty when the
	# route never saved in this city.
	_ensure_loaded()
	return _data.city_world(city_id)


func has_tower_state(city_id: String) -> bool:
	_ensure_loaded()
	return _data.has_tower_state(city_id)


func is_vault_open(city_id: String) -> bool:
	_ensure_loaded()
	return _data.is_vault_open(city_id)


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
