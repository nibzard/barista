# ABOUTME: RobotaxiDepotQuest is the pure state machine of the Robotaxi Depot
# ABOUTME: side quest, section 13 of GAME_DESIGN.md: the sleeping routing
# ABOUTME: engineer, his code-like order, and the fast travel reward.
class_name RobotaxiDepotQuest
extends RefCounted

signal engineer_woke

enum Phase { DEPOT_ASLEEP, FLEET_ROUTED }

# The order of the routing engineer: a triple shot oat cortado with milk at
# exactly 31 degrees, section 13. The recipe data holds the match rule.
var order: Recipe
var brewing_balance: BrewingBalance

var _phase: int = Phase.DEPOT_ASLEEP


func _init(quest_order: Recipe = null, brew_balance: BrewingBalance = null) -> void:
	order = quest_order
	brewing_balance = brew_balance


func phase() -> int:
	return _phase


func fleet_delivers_sleepwalkers() -> bool:
	# The routing of the sleeping fleet, section 13: the taxis pick up
	# sleepwalkers and deliver them to the player.
	return _phase == Phase.DEPOT_ASLEEP


func is_fast_travel_unlocked() -> bool:
	# The reward of the quest: the fleet re-routes and the taxis work as fast
	# travel inside the city.
	return _phase == Phase.FLEET_ROUTED


func receive_cup(cup: BrewedCup) -> bool:
	# One cup asks the order, and the tier-led rule of the bosses decides: a
	# perfect cup wakes him from any brew, a weak cup wakes nobody, and between
	# the tiers only the order itself works.
	if _phase != Phase.DEPOT_ASLEEP:
		return false
	if not BossCure.accepted(cup, order, brewing_balance):
		return false
	_phase = Phase.FLEET_ROUTED
	engineer_woke.emit()
	return true


func save_state() -> Dictionary:
	# The save system stores the quest as one plain number, section 18.
	return {"phase": _phase}


func load_state(saved: Dictionary) -> void:
	# A loaded quest never replays a beat. An unknown number keeps the depot
	# asleep.
	var saved_phase := int(saved.get("phase", Phase.DEPOT_ASLEEP))
	match saved_phase:
		Phase.DEPOT_ASLEEP, Phase.FLEET_ROUTED:
			_phase = saved_phase
		_:
			_phase = Phase.DEPOT_ASLEEP
