# ABOUTME: Unit tests for the TutorialFlow step machine of section 19.
# ABOUTME: Pure logic: no scene nodes, so the tests run without a tree.
extends GdUnitTestSuite


func test_a_new_tutorial_starts_at_the_video() -> void:
	var flow := TutorialFlow.new()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.VIDEO)
	assert_bool(flow.is_done()).is_false()
	assert_str(flow.prompt_text()).is_equal("")


func test_the_step_order_pins_every_beat_of_section_19() -> void:
	assert_int(TutorialFlow.Step.VIDEO).is_equal(0)
	assert_int(TutorialFlow.Step.MOVE).is_equal(1)
	assert_int(TutorialFlow.Step.DRINK).is_equal(2)
	assert_int(TutorialFlow.Step.DOOR).is_equal(3)
	assert_int(TutorialFlow.Step.THROW).is_equal(4)
	assert_int(TutorialFlow.Step.POLE).is_equal(5)
	assert_int(TutorialFlow.Step.SURVIVOR).is_equal(6)
	assert_int(TutorialFlow.Step.ROAD).is_equal(7)
	assert_int(TutorialFlow.Step.TOWER).is_equal(8)
	assert_int(TutorialFlow.Step.FINALE).is_equal(9)
	assert_int(TutorialFlow.Step.DONE).is_equal(10)


func test_the_video_ends_by_skip_or_by_timeout() -> void:
	var skipped := TutorialFlow.new()
	assert_bool(skipped.end_video()).is_true()
	assert_int(skipped.current_step()).is_equal(TutorialFlow.Step.MOVE)

	var timed_out := TutorialFlow.new()
	timed_out.end_video()
	assert_int(timed_out.current_step()).is_equal(TutorialFlow.Step.MOVE)


func test_events_before_their_step_are_ignored() -> void:
	var flow := TutorialFlow.new()
	assert_bool(flow.notify_moved()).is_false()
	assert_bool(flow.notify_drank()).is_false()
	assert_bool(flow.notify_left_cafe()).is_false()
	assert_bool(flow.notify_sleepwalker_woke()).is_false()
	assert_bool(flow.notify_back_in_cafe()).is_false()
	assert_bool(flow.notify_survivor_spoke()).is_false()
	assert_bool(flow.notify_hug_broken()).is_false()
	assert_bool(flow.notify_dodged()).is_false()
	assert_bool(flow.notify_brewed()).is_false()
	assert_bool(flow.notify_tower_off()).is_false()
	assert_bool(flow.notify_finale_ended()).is_false()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.VIDEO)


func test_the_prompts_pin_the_words_of_section_19() -> void:
	var flow := TutorialFlow.new()
	flow.end_video()
	assert_str(flow.prompt_text()).is_equal("MOVE.")
	flow.notify_moved()
	assert_str(flow.prompt_text()).is_equal("DRINK ONE CUP.")
	flow.notify_drank()
	assert_str(flow.prompt_text()).is_equal("A NEIGHBOR WALKS PAST. OPEN THE DOOR.")
	flow.notify_left_cafe()
	assert_str(flow.prompt_text()).is_equal("THROW YOUR CUP.")
	flow.notify_sleepwalker_woke()
	assert_str(flow.prompt_text()).is_equal("THE SPEAKER DRAINS YOU. STEP BACK INSIDE.")
	flow.notify_back_in_cafe()
	assert_str(flow.prompt_text()).is_equal("SOMEONE WAITS AT THE DOOR.")
	flow.notify_survivor_spoke()
	assert_str(flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG - DODGE - BREW AT THE POT")
	_complete_the_road(flow)
	assert_str(flow.prompt_text()).is_equal("THE TOWER. FIND A FUSE. SWITCH IT OFF.")
	flow.notify_tower_off()
	assert_str(flow.prompt_text()).is_equal("")


func test_the_happy_path_walks_every_step_in_order() -> void:
	var flow := TutorialFlow.new()
	var steps: Array[int] = []
	var finished: Array[int] = []
	flow.step_changed.connect(func(_from: int, to: int) -> void: steps.append(to))
	flow.finished.connect(func() -> void: finished.append(1))

	flow.end_video()
	flow.notify_moved()
	flow.notify_drank()
	flow.notify_left_cafe()
	flow.notify_sleepwalker_woke()
	flow.notify_back_in_cafe()
	flow.notify_survivor_spoke()
	flow.notify_hug_broken()
	flow.notify_dodged()
	flow.notify_brewed()
	flow.notify_tower_off()
	flow.notify_finale_ended()

	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.DONE)
	assert_bool(flow.is_done()).is_true()
	(
		assert_array(steps)
		. is_equal(
			[
				TutorialFlow.Step.MOVE,
				TutorialFlow.Step.DRINK,
				TutorialFlow.Step.DOOR,
				TutorialFlow.Step.THROW,
				TutorialFlow.Step.POLE,
				TutorialFlow.Step.SURVIVOR,
				TutorialFlow.Step.ROAD,
				TutorialFlow.Step.TOWER,
				TutorialFlow.Step.FINALE,
				TutorialFlow.Step.DONE,
			]
		)
	)
	assert_int(finished.size()).is_equal(1)


func test_the_road_needs_all_three_lessons_in_any_order() -> void:
	var flow := _flow_at_road()
	flow.notify_brewed()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.ROAD)
	flow.notify_hug_broken()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.ROAD)
	flow.notify_dodged()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.TOWER)


func test_repeated_road_events_stay_silent() -> void:
	var flow := _flow_at_road()
	assert_bool(flow.notify_dodged()).is_true()
	assert_bool(flow.notify_dodged()).is_false()
	assert_array(flow.road_lessons_remaining()).is_equal(
		[TutorialFlow.LESSON_HUG, TutorialFlow.LESSON_BREW]
	)


func test_road_lessons_outside_the_road_are_ignored() -> void:
	var flow := TutorialFlow.new()
	flow.end_video()
	assert_bool(flow.notify_dodged()).is_false()
	var road := _flow_at_road()
	assert_bool(road.notify_dodged()).is_true()
	assert_array(road.road_lessons_remaining()).is_equal(
		[TutorialFlow.LESSON_HUG, TutorialFlow.LESSON_BREW]
	)


func test_the_road_prompt_shrinks_as_lessons_complete() -> void:
	var flow := _flow_at_road()
	assert_str(flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG - DODGE - BREW AT THE POT")
	flow.notify_dodged()
	assert_str(flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG - BREW AT THE POT")
	flow.notify_brewed()
	assert_str(flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG")


func test_the_tower_beat_lands_from_the_tower_step() -> void:
	var flow := _flow_at_road()
	_complete_the_road(flow)
	assert_bool(flow.notify_tower_off()).is_true()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.FINALE)


func test_a_rushed_tower_beat_lands_from_the_road() -> void:
	# A player who runs past the road lessons still gets the finale: the tower
	# never waits, section 19 step 9.
	var flow := _flow_at_road()
	assert_bool(flow.notify_tower_off()).is_true()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.FINALE)


func test_the_tower_beat_is_ignored_before_the_road() -> void:
	var flow := TutorialFlow.new()
	flow.end_video()
	flow.notify_moved()
	flow.notify_drank()
	flow.notify_left_cafe()
	assert_bool(flow.notify_tower_off()).is_false()
	assert_int(flow.current_step()).is_equal(TutorialFlow.Step.THROW)


func test_the_done_tutorial_stays_silent() -> void:
	var flow := _completed_flow()
	var finished: Array[int] = []
	flow.finished.connect(func() -> void: finished.append(1))

	assert_bool(flow.notify_moved()).is_false()
	assert_bool(flow.notify_tower_off()).is_false()
	assert_bool(flow.notify_finale_ended()).is_false()
	assert_bool(flow.is_done()).is_true()
	assert_int(finished.size()).is_equal(0)


func test_save_round_trip_mid_road() -> void:
	var flow := _flow_at_road()
	flow.notify_dodged()
	var saved := flow.save_state()

	var loaded := TutorialFlow.new()
	var moves: Array[int] = []
	loaded.step_changed.connect(func(_from: int, _to: int) -> void: moves.append(1))
	loaded.load_state(saved)

	assert_int(loaded.current_step()).is_equal(TutorialFlow.Step.ROAD)
	assert_array(loaded.road_lessons_remaining()).is_equal(
		[TutorialFlow.LESSON_HUG, TutorialFlow.LESSON_BREW]
	)
	assert_int(moves.size()).is_equal(0)

	loaded.notify_hug_broken()
	loaded.notify_brewed()
	assert_int(loaded.current_step()).is_equal(TutorialFlow.Step.TOWER)


func test_load_of_a_done_tutorial_stays_done() -> void:
	var saved := _completed_flow().save_state()
	var loaded := TutorialFlow.new()
	loaded.load_state(saved)
	assert_bool(loaded.is_done()).is_true()
	assert_str(loaded.prompt_text()).is_equal("")


func test_load_without_state_starts_at_the_video() -> void:
	var loaded := TutorialFlow.new()
	loaded.load_state({})
	assert_int(loaded.current_step()).is_equal(TutorialFlow.Step.VIDEO)


func _flow_at_road() -> TutorialFlow:
	var flow := TutorialFlow.new()
	flow.end_video()
	flow.notify_moved()
	flow.notify_drank()
	flow.notify_left_cafe()
	flow.notify_sleepwalker_woke()
	flow.notify_back_in_cafe()
	flow.notify_survivor_spoke()
	return flow


func _complete_the_road(flow: TutorialFlow) -> void:
	flow.notify_hug_broken()
	flow.notify_dodged()
	flow.notify_brewed()


func _completed_flow() -> TutorialFlow:
	var flow := _flow_at_road()
	_complete_the_road(flow)
	flow.notify_tower_off()
	flow.notify_finale_ended()
	return flow
