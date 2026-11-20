# ABOUTME: QuestLog owns the whole quest state of one run: the main chain and
# ABOUTME: every side quest of the route. The save system reads it as one dict.
class_name QuestLog
extends RefCounted

signal objective_changed(objective: MainQuest.Objective)
signal side_quest_changed(quest_id: String, new_state: SideQuest.State)

var main_quest := MainQuest.new()

var _side_quests := {}
# Saved states for late-registered quests (such as the level-3 field base
# round) that are not part of the static city definition list.
var _pending_side_states := {}


func _init() -> void:
	# One relay point for the UI: the log re-emits the chain objective.
	main_quest.objective_changed.connect(objective_changed.emit)


func setup(route: MainRoute, start_city := "") -> bool:
	# Registers every side quest of every route city, so a save in a later
	# city still carries the finished quests of the cities before it.
	if route == null:
		return false
	if not main_quest.setup(route.city_ids(), start_city):
		return false
	_side_quests.clear()
	_pending_side_states.clear()
	for city: CityDefinition in route.cities:
		for quest: SideQuestDefinition in city.side_quests:
			register(quest)
	return true


func register(definition: SideQuestDefinition) -> bool:
	# A quest registers once and starts offered, section 12: survivors give
	# the side quests to the player.
	if definition == null or definition.quest_id.is_empty():
		return false
	if _side_quests.has(definition.quest_id):
		return false
	var quest := SideQuest.new(definition)
	if _pending_side_states.has(definition.quest_id):
		quest.load_state(int(_pending_side_states[definition.quest_id]))
		_pending_side_states.erase(definition.quest_id)
	quest.state_changed.connect(_on_quest_state_changed)
	_side_quests[definition.quest_id] = quest
	return true


func quest(quest_id: String) -> SideQuest:
	return _side_quests.get(quest_id) as SideQuest


func quest_count() -> int:
	return _side_quests.size()


func is_active(quest_id: String) -> bool:
	var quest := quest(quest_id)
	return quest != null and quest.is_active()


func accept(quest_id: String) -> bool:
	var target := quest(quest_id)
	if target == null:
		return false
	return target.accept()


func complete(quest_id: String) -> bool:
	var target := quest(quest_id)
	if target == null:
		return false
	return target.complete()


func active_side_quests() -> Array[SideQuest]:
	var active: Array[SideQuest] = []
	for quest_id: String in _side_quests:
		var target := _side_quests[quest_id] as SideQuest
		if target.is_active():
			active.append(target)
	return active


func current_objective() -> MainQuest.Objective:
	return main_quest.current_objective()


func mark_tower_off() -> bool:
	return main_quest.mark_tower_off()


func mark_boss_cured() -> bool:
	return main_quest.mark_boss_cured()


func travel_east() -> bool:
	return main_quest.travel_east()


func travel_west() -> bool:
	# The road back west of section 23: the chain moves with the traveler.
	return main_quest.travel_west()


func save_state() -> Dictionary:
	# The save system stores the chain and every quest state in one dict.
	var side := _pending_side_states.duplicate()
	for quest_id: String in _side_quests:
		side[quest_id] = (_side_quests[quest_id] as SideQuest).save_state()
	return {"main": main_quest.save_state(), "side": side}


func load_state(saved: Dictionary) -> void:
	# A loaded log never replays a beat or a state change. Quests that the
	# save does not know keep their offered state, and quests that register
	# later (like field base quests) receive their saved state on register.
	main_quest.load_state(saved.get("main", {}) as Dictionary)
	_pending_side_states.clear()
	var side := saved.get("side", {}) as Dictionary
	for quest_id: Variant in side:
		var id := str(quest_id)
		var state := int(side[quest_id])
		if _side_quests.has(id):
			(_side_quests[id] as SideQuest).load_state(state)
		else:
			_pending_side_states[id] = state


func _on_quest_state_changed(
	changed: SideQuest, _old_state: SideQuest.State, new_state: SideQuest.State
) -> void:
	side_quest_changed.emit(changed.quest_id(), new_state)
