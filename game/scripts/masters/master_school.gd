# ABOUTME: MasterSchool builds the brewing masters of one city at the cafe,
# ABOUTME: section 8, and answers the interact key at their side. A quest can
# ABOUTME: stand one more master later, like the Aisle 7 husband, so the school
# ABOUTME: finds its masters through the brewing-masters group.
class_name MasterSchool
extends Node

const MASTER_NPC_SCENE := preload("res://scenes/masters/master_npc.tscn")

# The run arrives as a plain Node: naming the run class here would tie this
# component's compile back into the city script (T112).
var _run: Node = null


func setup(run: Node) -> void:
	# The masters of the city stand side by side on the cafe master spot.
	_run = run
	var definition: CityDefinition = run.definition
	var lessons: MasterLessons = run.master_lessons
	var cafe_block: CityBlockView = (run.city_map() as CityMap).find_block_of_kind(
		CityBlock.Kind.CAFE
	)
	if cafe_block == null or cafe_block.master_spot() == null:
		return
	var spot: Vector2 = cafe_block.master_spot().global_position
	var count := definition.masters.size()
	for i: int in range(count):
		var master_data: BrewingMaster = definition.masters[i]
		var npc := MASTER_NPC_SCENE.instantiate() as MasterNpc
		npc.name = "Master" + master_data.master_id.capitalize()
		add_child(npc)
		npc.global_position = spot + Vector2(72.0 * float(i) - 36.0 * float(count - 1), 0.0)
		npc.bind_master(master_data, lessons)


func masters() -> Array[MasterNpc]:
	# The masters of the run, in tree order: the resident cafe masters first,
	# then any master a quest stood later.
	var found: Array[MasterNpc] = []
	if _run == null:
		return found
	for node: Node in get_tree().get_nodes_in_group(&"brewing_masters"):
		var npc := node as MasterNpc
		if npc != null and _run.is_ancestor_of(npc):
			found.append(npc)
	return found


func interact() -> bool:
	# One button at the master: a lesson while lessons remain, then only the
	# catchphrase. Returns false when no master stands at hand.
	var hud: Hud = _run.hud
	var player: Player = _run.player
	for npc: MasterNpc in masters():
		if not npc.is_player_at_master():
			continue
		var skills_before := _taught_skills(npc, player.brewing_skills)
		var outcome := npc.interact()
		if outcome == MasterNpc.Interaction.NOT_AT_MASTER:
			return false
		var gain := _measured_skill_gain(npc, player, skills_before)
		hud.show_toast(npc.announce_text(outcome, gain, player.brewing_library))
		return true
	return false


func _taught_skills(npc: MasterNpc, skills: BrewingSkills) -> Dictionary:
	var snapshot: Dictionary = {}
	if npc.master == null or skills == null:
		return snapshot
	for method_id: String in npc.master.taught_methods:
		snapshot[method_id] = skills.skill(method_id)
	return snapshot


func _measured_skill_gain(npc: MasterNpc, player: Player, before: Dictionary) -> int:
	# Report the actual clamped skill gain rather than the nominal gain when
	# the player is already near or at the method skill cap.
	if npc.master == null or npc.master.taught_methods.is_empty():
		return player.brewing_balance.master_lesson_skill_gain
	var max_gain := 0
	for method_id: String in npc.master.taught_methods:
		var delta := player.brewing_skills.skill(method_id) - int(before.get(method_id, 0))
		max_gain = maxi(max_gain, delta)
	return max_gain
