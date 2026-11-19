# ABOUTME: MoonwalkerSpawnRule is the spawn gate of the Moonwalker, section 24.
# ABOUTME: Pure logic with no nodes: dawn, a silent zone, and a dead tower.
class_name MoonwalkerSpawnRule
extends RefCounted


static func should_spawn(
	is_dawn: bool, tower_off: bool, player_in_silent_zone: bool, figure_live: bool
) -> bool:
	# Section 24: at dawn, in any silent zone with the tower already off, a
	# figure slides backwards across the plaza. Every condition must hold at
	# once, and only one figure walks one city: a live figure blocks the next
	# spawn until it departs.
	if figure_live:
		return false
	return is_dawn and tower_off and player_in_silent_zone


static func zone_is_silent(zone: SleepZone) -> bool:
	# A silent zone is a speaker pole zone whose broadcast died with the
	# tower, section 24: the busker names the place, "where the speakers
	# die", and the figure honors the hint.
	return zone != null and zone.is_broadcast_silenced() and zone.has_player_inside()
