# ABOUTME: SleepyDex is the phone app state: which sleepwalker types are found.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name SleepyDex
extends RefCounted

signal entry_opened(type_id: String)
signal keychain_awarded

# Section 9: a completed dex gives one troll doll keychain, and the game says
# one line about it. The line is the whole reward.
const KEYCHAIN_LINE := "It is just a keychain."

var catalog: SleepyDexCatalog

var _found: Dictionary = {}
var _keychain_given := false


func _init(dex_catalog: SleepyDexCatalog = null) -> void:
	catalog = dex_catalog


func meet(type_id: String) -> bool:
	# A new entry opens on the first meeting with a type, section 9. A second
	# meeting changes nothing, and a type outside the catalog never opens one.
	if catalog == null or catalog.find_entry(type_id) == null:
		return false
	if _found.has(type_id):
		return false
	_found[type_id] = true
	entry_opened.emit(type_id)
	if is_complete() and not _keychain_given:
		_keychain_given = true
		keychain_awarded.emit()
	return true


func listed_entries() -> Array[SleepyDexEntry]:
	# The rows the phone shows: every common type, found or not, plus every
	# found rare type. An unfound rare type is completely absent, section 9:
	# no placeholder row, no count, no hint that it exists.
	var listed: Array[SleepyDexEntry] = []
	if catalog == null:
		return listed
	for entry: SleepyDexEntry in catalog.entries:
		if entry.is_rare() and not _found.has(entry.type_id()):
			continue
		listed.append(entry)
	return listed


func entry_count() -> int:
	return listed_entries().size()


func found_count() -> int:
	var found := 0
	for entry: SleepyDexEntry in listed_entries():
		if _found.has(entry.type_id()):
			found += 1
	return found


func is_found(type_id: String) -> bool:
	return _found.has(type_id)


func is_complete() -> bool:
	# Complete means every type in the catalog, the rare ones included. A dex
	# that found only the common types stays open, and it says nothing about why.
	if catalog == null:
		return false
	for entry: SleepyDexEntry in catalog.entries:
		if not _found.has(entry.type_id()):
			return false
	return true


func has_keychain() -> bool:
	# The troll doll keychain hangs on the mobile cafe mirror, section 9. It
	# gives no stats, no skill, and no secret: this flag is the whole effect.
	return _keychain_given


func save_state() -> Dictionary:
	# The save system stores the dex as the found ids plus the keychain flag,
	# section 18.
	return {"found_ids": _found.keys(), "keychain": _keychain_given}


func load_state(state: Dictionary) -> void:
	# A loaded dex never replays the entry or the keychain beats. Ids that the
	# catalog does not know, like types from a newer save, stay out.
	_found.clear()
	for saved_id: Variant in state.get("found_ids", []):
		if saved_id is String and catalog != null and catalog.find_entry(saved_id) != null:
			_found[saved_id] = true
	_keychain_given = bool(state.get("keychain", false)) or is_complete()
