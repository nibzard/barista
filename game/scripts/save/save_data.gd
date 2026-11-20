# ABOUTME: SaveData is the auto-save document: one versioned dict of plain values.
# ABOUTME: It holds the full section 18 run state plus the cross-city world state.
class_name SaveData
extends RefCounted

# Bump when the document changes shape. A save from a newer version stays
# unreadable, so a read from the future returns no document.
const SAVE_VERSION := 8

# The save point kinds of section 18. The document stores the kind that wrote
# the slot, so a reload can say where the player stands. The purchase of
# section 4 writes its own point, so the paid bridge outlives any app close.
const POINT_CAFE_ENTRY := "cafe_entry"
const POINT_TOWER_SWITCH := "tower_switch"
const POINT_BOSS_CURED := "boss_cured"
const POINT_PURCHASE := "purchase"
const POINT_POST_GAME := "post_game"

# The game modes of section 9. The mode rides the slot: it outlives every save
# point and exists before the first run writes one.
const MODE_NORMAL := "normal"
const MODE_HARDCORE := "hardcore"

# --- The run state at the last save point, section 18 ---

# Which save point wrote the slot: POINT_CAFE_ENTRY, POINT_TOWER_SWITCH,
# POINT_BOSS_CURED, POINT_PURCHASE, or POINT_POST_GAME.
var save_point := ""
# The city the save point stands in, and the scene that replays it. An empty
# scene path means the slot holds no run state, like a tower-only record.
var city_id := ""
var scene_path := ""
# Where the player stands at the save point, stored as plain numbers because
# JSON carries no vectors.
var position_x := 0.0
var position_y := 0.0
# The sleepy meter value at the save point.
var meter_value := 0.0
# The remaining wake-ups at the save point.
var wake_ups := 0
# The bag: item id to held units. Beans, gear, materials, and appliances ride
# this one table.
var bag_counts: Dictionary = {}
# The brewed cups in hand and the worn thermos belt.
var cups := 0
var has_thermos_belt := false
# The brewed batch in hand: the payload ids of the last brew, its score, and
# how many brewed cups remain. Empty when the hand holds plain cups only.
var brew_hand_state: Dictionary = {}
# The brewing skill levels: method id to skill.
var skills: Dictionary = {}
# The SleepyDex state: found type ids plus the keychain flag.
var dex_state: Dictionary = {}
# The cold brew steep of the run: recipe id, bean id, and steeped seconds.
# Empty when no steep runs.
var cold_brew_state: Dictionary = {}
# The mobile cafe van level.
var van_level := 0
# The quest state: the main chain and every side quest.
var quest_state: Dictionary = {}
# The run progress of the saved city: the tower and boss beats.
var progress_state: Dictionary = {}
# The boss fight state of the saved city, like the cure flag of the arena
# show. Empty when the saved city holds no boss.
var boss_state: Dictionary = {}
# The street crowd of the saved city, T134: one awake flag per sleepwalker
# in spawn order, so a reload and the return west rebuild the woken street.
# Empty when the run state predates the crowd snapshot.
var crowd_awake: Array = []
# The moving-day unload of the saved city.
var moving_day_done := false
# The tutorial flow state of the intro run.
var tutorial_state: Dictionary = {}
# The outro flow state of the last city.
var outro_state: Dictionary = {}
# The paywall purchase flag.
var purchase_unlocked := false
# The taught Moonwalk dodge variant of section 24.
var moonwalk_dodge := false
# The master school lesson counts and known recipes, section 8.
var master_lessons: Dictionary = {}
# The cosmetic choices of character creation, section 5, as one plain dict.
# It rides the slot beside the run state: the look outlives every save point
# and exists before the first run writes one.
var appearance: Dictionary = {}
# The game mode of the run, section 9: MODE_NORMAL or MODE_HARDCORE. It rides
# the slot the same way, so a hardcore run never softens into a normal one.
var game_mode := MODE_NORMAL

# --- The cross-city world state ---

# The saved broadcast tower phase per city id. The tower owns the meaning of
# the numbers; the document stores them as they are.
var tower_phases: Dictionary = {}
# The unlocked vault doors per city id: a reload never re-locks a door.
var vaults_open: Dictionary = {}
# The world state per city id, section 23: the beats of a city stay saved when
# the road west returns the player to it. One plain dict per city: the run
# progress, the boss state, the street crowd awake flags, the outro step, the
# moving-day unload, the tutorial flow, the cold brew steep, and the tower
# phase at the city's last save point.
var city_worlds: Dictionary = {}


static func from_dict(saved: Dictionary) -> SaveData:
	# A document without a known version is no save of this game.
	var version := int(saved.get("save_version", 0))
	if version != SAVE_VERSION:
		return null
	var data := SaveData.new()
	var plain := _plain_numbers(saved) as Dictionary
	data.save_point = string_or_default(plain.get("save_point", ""), "")
	data.city_id = string_or_default(plain.get("city_id", ""), "")
	data.scene_path = string_or_default(plain.get("scene_path", ""), "")
	data.position_x = float(plain.get("position_x", 0.0))
	data.position_y = float(plain.get("position_y", 0.0))
	data.meter_value = float(plain.get("meter_value", 0.0))
	data.wake_ups = int(plain.get("wake_ups", 0))
	data.bag_counts = int_dict(plain.get("bag_counts", {}))
	data.cups = int(plain.get("cups", 0))
	data.has_thermos_belt = bool(plain.get("has_thermos_belt", false))
	data.brew_hand_state = dict_or_empty(plain.get("brew_hand_state", {}))
	data.skills = int_dict(plain.get("skills", {}))
	data.dex_state = dict_or_empty(plain.get("dex_state", {}))
	data.cold_brew_state = dict_or_empty(plain.get("cold_brew_state", {}))
	data.van_level = int(plain.get("van_level", 0))
	data.quest_state = dict_or_empty(plain.get("quest_state", {}))
	data.progress_state = dict_or_empty(plain.get("progress_state", {}))
	data.boss_state = dict_or_empty(plain.get("boss_state", {}))
	data.crowd_awake = bool_array(plain.get("crowd_awake", []))
	data.moving_day_done = bool(plain.get("moving_day_done", false))
	data.tutorial_state = dict_or_empty(plain.get("tutorial_state", {}))
	data.outro_state = dict_or_empty(plain.get("outro_state", {}))
	data.purchase_unlocked = bool(plain.get("purchase_unlocked", false))
	data.moonwalk_dodge = bool(plain.get("moonwalk_dodge", false))
	data.master_lessons = dict_or_empty(plain.get("master_lessons", {}))
	data.appearance = dict_or_empty(plain.get("appearance", {}))
	data.game_mode = mode_or_default(plain.get("game_mode", MODE_NORMAL))
	var phases := dict_or_empty(plain.get("tower_phases", {}))
	for city_id: String in phases:
		data.tower_phases[city_id] = int(phases[city_id])
	var vaults := dict_or_empty(plain.get("vaults_open", {}))
	for city_id: String in vaults:
		data.vaults_open[city_id] = bool(vaults[city_id])
	var worlds := dict_or_empty(plain.get("city_worlds", {}))
	for city_id: String in worlds:
		data.city_worlds[city_id] = dict_or_empty(worlds[city_id])
	return data


func to_dict() -> Dictionary:
	# The document hands out a copy, so a caller cannot change the save by
	# holding the dict.
	return {
		"save_version": SAVE_VERSION,
		"save_point": save_point,
		"city_id": city_id,
		"scene_path": scene_path,
		"position_x": position_x,
		"position_y": position_y,
		"meter_value": meter_value,
		"wake_ups": wake_ups,
		"bag_counts": bag_counts.duplicate(),
		"cups": cups,
		"has_thermos_belt": has_thermos_belt,
		"brew_hand_state": brew_hand_state.duplicate(),
		"skills": skills.duplicate(),
		"dex_state": dex_state.duplicate(),
		"cold_brew_state": cold_brew_state.duplicate(),
		"van_level": van_level,
		"quest_state": quest_state.duplicate(),
		"progress_state": progress_state.duplicate(),
		"boss_state": boss_state.duplicate(),
		"crowd_awake": crowd_awake.duplicate(),
		"moving_day_done": moving_day_done,
		"tutorial_state": tutorial_state.duplicate(),
		"outro_state": outro_state.duplicate(),
		"purchase_unlocked": purchase_unlocked,
		"moonwalk_dodge": moonwalk_dodge,
		"master_lessons": master_lessons.duplicate(true),
		"appearance": appearance.duplicate(),
		"game_mode": game_mode,
		"tower_phases": tower_phases.duplicate(),
		"vaults_open": vaults_open.duplicate(),
		"city_worlds": city_worlds.duplicate(true),
	}


func has_run_state() -> bool:
	# A run state exists once a save point wrote the slot from a live run.
	return not scene_path.is_empty()


func set_tower_phase(city_id: String, phase: int) -> void:
	tower_phases[city_id] = phase


func tower_phase(city_id: String, default_phase: int) -> int:
	# A city the save never saw starts at the caller's default phase.
	return int(tower_phases.get(city_id, default_phase))


func has_tower_state(city_id: String) -> bool:
	return tower_phases.has(city_id)


func set_vault_open(city_id: String, is_open: bool) -> void:
	vaults_open[city_id] = is_open


func is_vault_open(city_id: String) -> bool:
	return bool(vaults_open.get(city_id, false))


func set_city_world(city_id: String, world: Dictionary) -> void:
	# Every save point of a city refreshes its own world, so the map holds the
	# last save point of every city on the route.
	city_worlds[city_id] = world.duplicate(true)


func city_world(city_id: String) -> Dictionary:
	# The saved world of one city. A city the save never saw reads as no world,
	# so a first visit builds fresh.
	return dict_or_empty(city_worlds.get(city_id, {}))


static func string_or_default(saved: Variant, default_value: String) -> String:
	# A JSON string loads as a String only when the field was one.
	if saved is String:
		return saved
	return default_value


static func mode_or_default(mode: Variant) -> String:
	# A foreign value, like a corrupt string, reads as the specced default:
	# normal mode with the wake-up system of section 9.
	if mode == MODE_HARDCORE:
		return MODE_HARDCORE
	return MODE_NORMAL


static func dict_or_empty(saved: Variant) -> Dictionary:
	# Nested state rides the document as plain dicts. A foreign value, like a
	# list, reads as no state at all.
	if saved is Dictionary:
		return saved as Dictionary
	return {}


static func array_or_empty(saved: Variant) -> Array:
	# List state rides the document as plain arrays. A foreign value, like a
	# dict, reads as no list at all.
	if saved is Array:
		return saved as Array
	return []


static func bool_array(saved: Variant) -> Array:
	# Flag lists ride the document as plain arrays of booleans. A foreign
	# entry, like a string, reads as false, so a corrupt slot wakes nobody.
	var result: Array = []
	for entry in array_or_empty(saved):
		result.append(entry is bool and bool(entry))
	return result


static func int_dict(saved: Variant) -> Dictionary:
	# A JSON number loads as a float, so count tables store ints again.
	var result: Dictionary = {}
	var source := dict_or_empty(saved)
	for key: String in source:
		result[key] = int(source[key])
	return result


static func _plain_numbers(value: Variant) -> Variant:
	# A JSON number loads as a float, even when the save wrote an int, and
	# the nested flow states read their steps and counts back by type. The
	# walk stores every whole number as an int again, deeply, so a saved
	# quest step of 10 never comes back as 10.0.
	if value is float:
		var number := value as float
		if is_equal_approx(number, roundf(number)):
			return int(number)
		return value
	if value is Dictionary:
		var plain: Dictionary = {}
		for key: String in value:
			plain[key] = _plain_numbers((value as Dictionary)[key])
		return plain
	if value is Array:
		var plain_items: Array = []
		for item: Variant in value:
			plain_items.append(_plain_numbers(item))
		return plain_items
	return value
