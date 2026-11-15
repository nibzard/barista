# ABOUTME: SleepyDexCatalog ships every SleepyDex entry as one ordered list.
# ABOUTME: The catalog holds the rare types too; the SleepyDex state hides them.
class_name SleepyDexCatalog
extends Resource

@export var entries: Array[SleepyDexEntry] = []


func size() -> int:
	return entries.size()


func find_entry(type_id: String) -> SleepyDexEntry:
	for entry: SleepyDexEntry in entries:
		if entry.type_id() == type_id:
			return entry
	return null
