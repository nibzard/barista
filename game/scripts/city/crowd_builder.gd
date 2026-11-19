# ABOUTME: CrowdBuilder spawns the city crowd from the block kit markers.
# ABOUTME: Every block holds its budgeted sleepwalkers, section 17.
class_name CrowdBuilder
extends RefCounted


static func spawn(parent: Node, map: CityMap, definition: CityDefinition, dex: SleepyDex) -> Node2D:
	# Every block holds its budgeted sleepwalkers. The cafe block teaches the
	# basic throw, so it spawns only the first roster entry, the basic type.
	# Every later block cycles the full roster in order.
	var crowd := Node2D.new()
	crowd.name = "Crowd"
	parent.add_child(crowd)
	var roster := definition.roster
	if roster.is_empty():
		return crowd
	var global_marker := 0
	for i: int in range(map.block_count()):
		var view := map.block_view(i)
		for marker: Marker2D in view.crowd_spawn_markers():
			var entry := roster[0]
			if view.kind() != CityBlock.Kind.CAFE:
				entry = roster[global_marker % roster.size()]
			var enemy := entry.scene.instantiate() as Sleepwalker
			crowd.add_child(enemy)
			enemy.global_position = marker.global_position
			# The first meeting with a type opens its SleepyDex entry,
			# section 9. The dex itself keeps the second meeting silent.
			enemy.first_met.connect(dex.meet)
			# The wake of section 6 speaks once: the presenter floats the wake
			# line above the body, so the beat plays in live play.
			WakeLinePresenter.attach(enemy, enemy.spoke)
			global_marker += 1
	return crowd
