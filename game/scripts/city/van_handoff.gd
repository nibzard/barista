# ABOUTME: VanHandoff carries the van level across the move east, section 10.
# ABOUTME: The leaving city parks the level; the arriving city takes it once.
class_name VanHandoff
extends RefCounted

# The parked level of the van that just left the city west. It waits here
# through the scene change, because the two city runs never share a tree.
static var _parked_level: int = MobileCafe.Level.NONE


static func park(level: int) -> void:
	# The leaving city parks its van level for the arrival, section 10: the
	# van comes along on the move east, upgrades and all.
	_parked_level = level


static func take_arriving_level(fallback_level: int) -> int:
	# The arriving city takes the parked level once. A move without a parked
	# van, like a fresh run that never traveled, falls back to the caller's
	# default, so the gift rule of the first city stays whole.
	var arriving := _parked_level
	_parked_level = MobileCafe.Level.NONE
	if arriving < MobileCafe.Level.VAN:
		return fallback_level
	return arriving


static func reset() -> void:
	# A fresh session starts with an empty handoff. The test suites call this
	# so a parked level never leaks into an unrelated run.
	_parked_level = MobileCafe.Level.NONE
