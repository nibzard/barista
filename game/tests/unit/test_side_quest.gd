# ABOUTME: Unit tests for the side-quest state machine: offered, active,
# ABOUTME: complete. Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite


func _quest() -> SideQuest:
	var definition := SideQuestDefinition.new()
	definition.quest_id = "robotaxi_depot"
	definition.title = "The Robotaxi Depot"
	definition.site_name = ""
	return SideQuest.new(definition)


func _changes(quest: SideQuest) -> Array[int]:
	var counts: Array[int] = []
	quest.state_changed.connect(
		func(_changed: SideQuest, old_state: int, new_state: int) -> void:
			counts.append(old_state * 10 + new_state)
	)
	return counts


func test_a_registered_quest_starts_offered() -> void:
	var quest := _quest()
	assert_int(quest.state()).is_equal(SideQuest.State.OFFERED)
	assert_bool(quest.is_offered()).is_true()
	assert_bool(quest.is_active()).is_false()
	assert_bool(quest.is_complete()).is_false()


func test_the_definition_answers_id_title_and_site() -> void:
	var quest := _quest()
	assert_str(quest.quest_id()).is_equal("robotaxi_depot")
	assert_str(quest.title()).is_equal("The Robotaxi Depot")
	assert_str(quest.site_name()).is_equal("")


func test_accept_moves_the_quest_to_active() -> void:
	var quest := _quest()
	var changes := _changes(quest)

	assert_bool(quest.accept()).is_true()
	assert_int(quest.state()).is_equal(SideQuest.State.ACTIVE)
	assert_bool(quest.is_active()).is_true()
	assert_int(changes.size()).is_equal(1)
	assert_int(changes[0]).is_equal(SideQuest.State.OFFERED * 10 + SideQuest.State.ACTIVE)


func test_a_second_accept_stays_silent() -> void:
	var quest := _quest()
	quest.accept()
	var changes := _changes(quest)

	assert_bool(quest.accept()).is_false()
	assert_int(quest.state()).is_equal(SideQuest.State.ACTIVE)
	assert_int(changes.size()).is_equal(0)


func test_complete_needs_an_active_quest() -> void:
	var quest := _quest()
	var changes := _changes(quest)

	assert_bool(quest.complete()).is_false()
	assert_int(quest.state()).is_equal(SideQuest.State.OFFERED)
	assert_int(changes.size()).is_equal(0)


func test_complete_finishes_an_active_quest() -> void:
	var quest := _quest()
	quest.accept()
	var changes := _changes(quest)

	assert_bool(quest.complete()).is_true()
	assert_int(quest.state()).is_equal(SideQuest.State.COMPLETE)
	assert_bool(quest.is_complete()).is_true()
	assert_int(changes.size()).is_equal(1)
	assert_int(changes[0]).is_equal(SideQuest.State.ACTIVE * 10 + SideQuest.State.COMPLETE)


func test_a_second_complete_stays_silent() -> void:
	var quest := _quest()
	quest.accept()
	quest.complete()
	var changes := _changes(quest)

	assert_bool(quest.complete()).is_false()
	assert_int(quest.state()).is_equal(SideQuest.State.COMPLETE)
	assert_int(changes.size()).is_equal(0)


func test_accept_after_complete_is_refused() -> void:
	var quest := _quest()
	quest.accept()
	quest.complete()

	assert_bool(quest.accept()).is_false()
	assert_int(quest.state()).is_equal(SideQuest.State.COMPLETE)


func test_save_round_trip_carries_each_state() -> void:
	var states := [SideQuest.State.OFFERED, SideQuest.State.ACTIVE, SideQuest.State.COMPLETE]
	for expected: int in states:
		var quest := _quest()
		if expected != SideQuest.State.OFFERED:
			quest.accept()
		if expected == SideQuest.State.COMPLETE:
			quest.complete()

		var loaded := _quest()
		var changes := _changes(loaded)
		loaded.load_state(quest.save_state())

		assert_int(loaded.state()).is_equal(expected)
		assert_int(changes.size()).is_equal(0)


func test_load_rejects_an_unknown_state_number() -> void:
	var quest := _quest()
	quest.load_state(99)
	assert_int(quest.state()).is_equal(SideQuest.State.OFFERED)


func test_a_loaded_quest_still_moves_on() -> void:
	var quest := _quest()
	quest.accept()

	var loaded := _quest()
	loaded.load_state(quest.save_state())
	assert_bool(loaded.complete()).is_true()
	assert_int(loaded.state()).is_equal(SideQuest.State.COMPLETE)
