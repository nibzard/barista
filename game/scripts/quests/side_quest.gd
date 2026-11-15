# ABOUTME: SideQuest is the state machine of one side quest: offered, active,
# ABOUTME: complete. Pure logic; the quest data sits in a SideQuestDefinition.
class_name SideQuest
extends RefCounted

signal state_changed(quest: SideQuest, old_state: State, new_state: State)

enum State { OFFERED, ACTIVE, COMPLETE }

var definition: SideQuestDefinition

var _state: State = State.OFFERED


func _init(quest_definition: SideQuestDefinition = null) -> void:
	definition = quest_definition


func quest_id() -> String:
	if definition == null:
		return ""
	return definition.quest_id


func title() -> String:
	if definition == null:
		return ""
	return definition.title


func site_name() -> String:
	if definition == null:
		return ""
	return definition.site_name


func state() -> State:
	return _state


func is_offered() -> bool:
	return _state == State.OFFERED


func is_active() -> bool:
	return _state == State.ACTIVE


func is_complete() -> bool:
	return _state == State.COMPLETE


func accept() -> bool:
	# A survivor offered the quest; the player says yes. Only an offered quest
	# becomes active.
	if definition == null or _state != State.OFFERED:
		return false
	return _set_state(State.ACTIVE)


func complete() -> bool:
	# The goal of the quest is met. Only an active quest completes.
	if _state != State.ACTIVE:
		return false
	return _set_state(State.COMPLETE)


func save_state() -> int:
	# The save system stores the state as one plain number.
	return _state


func load_state(saved: int) -> void:
	# A loaded quest never replays its state change. An unknown number keeps
	# the quest offered.
	match saved:
		State.OFFERED, State.ACTIVE, State.COMPLETE:
			_state = saved
		_:
			_state = State.OFFERED


func _set_state(next: State) -> bool:
	var old := _state
	_state = next
	state_changed.emit(self, old, next)
	return true
