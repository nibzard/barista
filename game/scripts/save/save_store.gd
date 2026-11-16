# ABOUTME: SaveStore writes and reads one auto-save slot as JSON on disk.
# ABOUTME: The document itself is SaveData; this class only moves the bytes.
class_name SaveStore
extends RefCounted

# Section 18: auto-save only, one slot. The slot lives under user://, so the
# app data of the device owns it and the repository never sees it.
const DEFAULT_SAVE_FILE := "user://saves/slot.json"

var _path: String


func _init(save_file_path: String = DEFAULT_SAVE_FILE) -> void:
	_path = save_file_path


func save_file_path() -> String:
	return _path


func write(data: SaveData) -> Error:
	# The store builds the save folder on demand, so a fresh install or a
	# cleared app data directory saves without extra setup.
	var make_dir_error := DirAccess.make_dir_recursive_absolute(_path.get_base_dir())
	if make_dir_error != OK:
		return make_dir_error
	var file := FileAccess.open(_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data.to_dict(), "\t"))
	var write_error := file.get_error()
	file.close()
	return write_error


func read() -> SaveData:
	# A missing, unreadable, or foreign slot reads as no save at all. The
	# caller cannot tell a corrupt slot from an empty one: both mean no save
	# point yet, and the game starts fresh.
	if not FileAccess.file_exists(_path):
		return null
	var file := FileAccess.open(_path, FileAccess.READ)
	if file == null:
		return null
	# The instance parser reports its error as a return value only, so a
	# corrupt slot stays silent instead of printing engine noise.
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return null
	var parsed: Variant = parser.data
	if parsed is Dictionary:
		return SaveData.from_dict(parsed as Dictionary)
	return null


func exists() -> bool:
	return FileAccess.file_exists(_path)


func delete_save() -> bool:
	# Section 18, hardcore mode: death deletes the slot. A missing file
	# already counts as deleted.
	if not exists():
		return true
	return DirAccess.remove_absolute(_path) == OK
