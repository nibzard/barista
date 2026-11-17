# ABOUTME: FieldBaseQuests is the pure rule set of the small side quests that
# ABOUTME: gathered survivors give at the level 3 field base, section 10.
class_name FieldBaseQuests
extends RefCounted

signal phase_changed(new_phase: Phase)

enum Phase { QUIET, ASKING, ACTIVE, DONE }

var balance: FieldBaseQuestBalance
var definition: SideQuestDefinition

var _phase: Phase = Phase.QUIET


func _init(
	quest_balance: FieldBaseQuestBalance = null, quest_definition: SideQuestDefinition = null
) -> void:
	balance = quest_balance
	definition = quest_definition


func quest_id() -> String:
	if definition == null:
		return ""
	return definition.quest_id


func beans_goal() -> int:
	if balance == null or balance.bean_item == null:
		return 0
	return balance.beans_goal


func reward_scrap_parts() -> int:
	if balance == null or balance.reward_item == null:
		return 0
	return balance.reward_scrap_parts


func register(log: QuestLog) -> bool:
	# The round joins the run's quest log beside the signature quests. The log
	# starts it offered, section 12: a survivor gives the quest to the player.
	if log == null or definition == null:
		return false
	return log.register(definition)


func phase() -> Phase:
	return _phase


func is_asking() -> bool:
	return _phase == Phase.ASKING


func poll(log: QuestLog, gathered_count: int, field_base_open: bool) -> void:
	# The phase reads the live play: the quest log owns the quest state, and
	# the ask stands only while survivors sit at the tables of an open base.
	# The quest log save carries the state, so a loaded run rebuilds the phase
	# from the log with no new ask.
	var next := _phase_for(log, gathered_count, field_base_open)
	if next == _phase:
		return
	_phase = next
	phase_changed.emit(next)


func try_accept(log: QuestLog, gathered_count: int, field_base_open: bool) -> bool:
	# The player says yes to the survivor at the table. The accept lands only
	# while the ask stands, and the quest log moves the quest to active.
	if not _ask_stands(log, gathered_count, field_base_open):
		return false
	if not log.accept(quest_id()):
		return false
	_set_phase(Phase.ACTIVE)
	return true


func try_deliver(log: QuestLog, inventory: Inventory, field_base_open: bool) -> bool:
	# The goal of the round: house beans for the field kitchen. The beans
	# leave the bag at the open base, and the survivors answer with scrap
	# parts for the van.
	if _phase != Phase.ACTIVE or not field_base_open:
		return false
	if balance == null or balance.bean_item == null or balance.reward_item == null:
		return false
	if inventory.count(balance.bean_item.item_id) < balance.beans_goal:
		return false
	if not inventory.remove(balance.bean_item.item_id, balance.beans_goal):
		return false
	inventory.add(balance.reward_item, balance.reward_scrap_parts)
	if not log.complete(quest_id()):
		return false
	_set_phase(Phase.DONE)
	return true


func _ask_stands(log: QuestLog, gathered_count: int, field_base_open: bool) -> bool:
	if log == null or balance == null:
		return false
	var quest := log.quest(quest_id())
	if quest == null or not quest.is_offered():
		return false
	return field_base_open and gathered_count >= balance.min_gathered_survivors


func _phase_for(log: QuestLog, gathered_count: int, field_base_open: bool) -> Phase:
	if log != null:
		var quest := log.quest(quest_id())
		if quest != null:
			if quest.is_complete():
				return Phase.DONE
			if quest.is_active():
				return Phase.ACTIVE
	if _ask_stands(log, gathered_count, field_base_open):
		return Phase.ASKING
	return Phase.QUIET


func _set_phase(next: Phase) -> void:
	if next == _phase:
		return
	_phase = next
	phase_changed.emit(next)
