# ABOUTME: ColdBrewHandoff carries the cold brew steep across the move east.
# ABOUTME: The leaving city parks the steep; the arriving city takes it once.
class_name ColdBrewHandoff
extends RefCounted

# The parked steep of the fridge that just left the city west: the recipe id,
# the bean id, and the steeped seconds. It waits here through the scene
# change, because the two city runs never share a tree and the slot of the
# west city never bleeds into the east one.
static var _parked_state: Dictionary = {}


static func park(state: Dictionary) -> void:
	# The leaving city parks its live steep for the arrival: the cold brew
	# crosses the road east with the player, steeped seconds and all.
	_parked_state = state.duplicate()


static func take_arriving_state() -> Dictionary:
	# The arriving city takes the parked steep once. A move without a parked
	# steep, like a fresh run that never traveled, arrives at an empty fridge.
	var arriving := _parked_state
	_parked_state = {}
	return arriving


static func reset() -> void:
	# A fresh session starts with an empty handoff. The test suites call this
	# so a parked steep never leaks into an unrelated run.
	_parked_state = {}
