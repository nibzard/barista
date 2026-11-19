# ABOUTME: Integration tests for the first ten minutes, GAME_DESIGN section 19.
# ABOUTME: Drives the intro run of San Coffesco through every tutorial beat.
extends GdUnitTestSuite

const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const PLAIN_CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const TUTORIAL_BALANCE := preload("res://resources/balance/tutorial.tres")

const MAX_FRAMES_TO_WAIT := 900
const FINALE_FRAMES_TO_WAIT := 1500
const FILTER_METHOD_ID := "filter"

var _city: CityRun
var _tutorial: TutorialDirector


func before_test() -> void:
	_city = INTRO_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready, so the areas report from the
	# second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame
	_tutorial = _city.get_node(^"Tutorial") as TutorialDirector


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_tutorial_balance_values_pin_the_section_19_numbers() -> void:
	assert_bool(TUTORIAL_BALANCE is TutorialBalance).is_true()
	# The video of Dr. Morgen plays 20 seconds, section 19 step 1.
	assert_float(TUTORIAL_BALANCE.video_seconds).is_equal(20.0)
	assert_float(TUTORIAL_BALANCE.wake_meter_value).is_equal(60.0)
	assert_float(TUTORIAL_BALANCE.move_min_distance).is_equal(24.0)
	assert_float(TUTORIAL_BALANCE.pole_zone_radius).is_equal(120.0)
	assert_float(TUTORIAL_BALANCE.pole_min_seconds).is_equal(2.0)
	assert_float(TUTORIAL_BALANCE.survivor_notice_radius).is_equal(90.0)
	assert_float(TUTORIAL_BALANCE.survivor_door_gap).is_equal(48.0)
	assert_vector(TUTORIAL_BALANCE.window_neighbor_fraction).is_equal(Vector2(0.12, 0.82))
	assert_float(TUTORIAL_BALANCE.line_hold_seconds).is_equal(4.5)
	assert_float(TUTORIAL_BALANCE.finale_pan_seconds).is_equal(2.5)
	assert_float(TUTORIAL_BALANCE.finale_map_hold_seconds).is_equal(1.25)
	assert_float(TUTORIAL_BALANCE.title_hold_seconds).is_equal(3.0)
	assert_float(TUTORIAL_BALANCE.finale_fade_seconds).is_equal(1.0)
	assert_float(TUTORIAL_BALANCE.finale_zoom_margin).is_equal(0.95)
	assert_object(_tutorial.balance).is_same(TUTORIAL_BALANCE)


func test_the_intro_starts_with_the_video_on_a_black_screen() -> void:
	assert_object(_tutorial).is_not_null()
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.VIDEO)
	assert_bool(_tutorial.video_view.visible).is_true()
	assert_str(_tutorial.video_view.current_line()).is_equal(
		"If you see this, you drink real coffee. Good. Listen."
	)
	# The produced video opens on its wide shot of the night lab, section 22.
	assert_int(_tutorial.video_view.shot()).is_equal(MorgenVideo.Shot.WIDE)
	assert_bool(_city.player.is_input_locked()).is_true()
	assert_bool(_tutorial.prompt_label.visible).is_false()
	# The tower marker waits for the survivor, section 19 step 7.
	assert_bool(_city.quest_markers().is_suppressed()).is_true()
	assert_bool(_city.quest_markers().has_objective_marker()).is_false()
	# The director rides after the player in the tree: the drink lesson
	# watches the meter channel close, and that close happens inside the
	# player's physics tick. A director that ticks before the player never
	# sees the close, because this suite's poll re-opens the channel first
	# (T090).
	assert_int(_tutorial.get_index()).is_greater(_city.player.get_index())


func test_the_video_plays_over_a_blind_crowd() -> void:
	# The cafe-block crowd stands close enough to sense the player, and its
	# wander direction is random per run. A Neighbor pressed onto the
	# input-locked player during the 20 second video still sees nothing: no
	# chase, no SleepyDex entry, no hug, and no drain, so the video cannot
	# end in a wake-up loss.
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.VIDEO)
	assert_bool(_city.player.is_input_locked()).is_true()
	# The plain Neighbors of the cafe block are the crowd of the finding:
	# they stand next to the player start. Later blocks cycle Tourists, whose
	# photo cadence changes state on its own, without any player.
	var cafe_crowd_size := _city.city_map().block_view(0).crowd_spawn_markers().size()
	for i: int in range(cafe_crowd_size):
		_city.crowd_enemy(i).global_position = _city.player.global_position
	var meter_at_start := _city.player.sleep_meter.value
	for i: int in range(60):
		await get_tree().physics_frame

	for i: int in range(cafe_crowd_size):
		assert_int(_city.crowd_enemy(i).state).is_equal(Sleepwalker.State.WANDER)
	assert_bool(_city.sleepy_dex().is_found("neighbor")).is_false()
	assert_bool(_city.player.is_grabbed()).is_false()
	assert_float(_city.player.sleep_meter.value).is_equal(meter_at_start)


func test_any_press_skips_the_video() -> void:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	_tutorial._unhandled_input(key)

	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.MOVE)
	assert_bool(_tutorial.video_view.visible).is_false()


func test_the_video_end_wakes_the_player_groggy() -> void:
	_tutorial.flow.end_video()
	await get_tree().physics_frame

	assert_bool(_city.player.is_input_locked()).is_false()
	# The player watched the address rehearsal: the meter starts low, so the
	# first drink visibly fills it, section 19 step 3. The area sync of the
	# safe zone can leak one passive-drain frame after the unlock.
	assert_float(_city.player.sleep_meter.value).is_equal_approx(
		_tutorial.balance.wake_meter_value, 1.0
	)
	assert_str(_tutorial.prompt_label.text).is_equal("MOVE.")
	assert_bool(_tutorial.prompt_label.visible).is_true()


func test_the_move_prompt_lands_when_the_player_walks() -> void:
	_tutorial.flow.end_video()
	var start := _city.player.global_position
	_city.player.global_position = start + Vector2(120.0, 0.0)
	await get_tree().physics_frame

	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.DRINK)


func test_the_first_drink_fills_the_meter() -> void:
	await _skip_to(TutorialFlow.Step.DRINK)
	var meter := _city.player.sleep_meter
	assert_float(meter.value).is_equal_approx(_tutorial.balance.wake_meter_value, 0.1)

	assert_bool(_city.player.drink_cup()).is_true()
	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.DOOR and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.DOOR)
	assert_float(meter.value).is_equal_approx(meter.balance.max_value, 1.0)


func test_a_neighbor_walks_past_and_the_door_opens_on_leaving() -> void:
	await _skip_to(TutorialFlow.Step.DOOR)
	var walker := _tutorial.window_neighbor()
	assert_object(walker).is_not_null()
	assert_bool(walker.is_awake()).is_false()
	# T128: the scripted walker carries the shared wake-line presenter at
	# spawn, like every crowd sleeper, and stays silent until he wakes.
	var presenter := walker.get_node(^"WakeLine") as WakeLinePresenter
	assert_object(presenter).is_not_null()
	assert_bool(presenter.is_speaking()).is_false()
	assert_str(presenter.spoken_line()).is_equal("")

	_city.player.global_position = _outside_cafe_position()
	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.THROW and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.THROW)


func test_the_window_neighbor_meeting_feeds_the_sleepy_dex() -> void:
	# The window neighbor is a real Neighbor of the crowd, section 19 step 4,
	# so his one first meeting feeds the SleepyDex, section 9. A crowd
	# Neighbor by the cafe start can meet the player first on a lucky wander,
	# so the wiring pin carries the acceptance: the tutorial binds this
	# walker's signal to the city dex.
	await _skip_to(TutorialFlow.Step.DOOR)
	var walker := _tutorial.window_neighbor()
	assert_object(walker).is_not_null()
	var dex := _city.sleepy_dex()

	var wired := false
	for connection: Dictionary in walker.first_met.get_connections():
		var callable: Callable = connection["callable"]
		if callable.get_object() == dex and callable.get_method() == &"meet":
			wired = true
	assert_bool(wired).is_true()

	# The meeting opens the phone entry: this walker or a crowd Neighbor
	# met the player by now, and the entry reads found either way.
	walker.global_position = _city.player.global_position + Vector2(60.0, 0.0)
	var frames := 0
	while not dex.is_found("neighbor") and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(dex.is_found("neighbor")).is_true()
	_city.hud.open_dex()
	assert_str(_city.hud.dex_app.row_status(0)).is_equal("Status: found")


func test_the_first_throw_wakes_him_and_he_shuffles_away() -> void:
	await _skip_to(TutorialFlow.Step.DOOR)
	_city.player.global_position = _outside_cafe_position()
	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.THROW and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	_park_the_crowd_west()

	var walker := _tutorial.window_neighbor()
	assert_object(walker).is_not_null()
	# Stand him still in front of the player so the thrown cup cannot miss.
	# A frozen body keeps its last velocity, and the aim assist would lead
	# that stale velocity, so zero it with the movement.
	walker.set_physics_process(false)
	walker.velocity = Vector2.ZERO
	walker.global_position = _city.player.global_position + Vector2(150.0, 0.0)
	var cup := _city.player.throw_cup(Vector2.RIGHT)
	assert_object(cup).is_not_null()
	frames = 0
	while not walker.is_awake() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	walker.set_physics_process(true)

	assert_bool(walker.is_awake()).is_true()
	assert_bool(walker.is_gathering()).is_true()
	# The thanks rides the shared presenter, so the scripted beat plays through
	# the same view as every crowd wake, and the line follows the shuffler.
	var presenter := walker.get_node(^"WakeLine") as WakeLinePresenter
	assert_bool(presenter.is_speaking()).is_true()
	assert_str(presenter.spoken_line()).is_equal("Thanks... coffee...")
	assert_str(_tutorial.thanks_line()).is_equal("Thanks... coffee...")
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.POLE)


func test_the_speaker_pole_drains_and_the_safe_zone_ends_it() -> void:
	await _skip_to(TutorialFlow.Step.POLE)
	# The pole enters the tree one frame after the step change, outside the
	# physics flush of the first wake.
	var pole := _tutorial.pole_zone()
	var spawn_frames := 0
	while pole == null and spawn_frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		pole = _tutorial.pole_zone()
		spawn_frames += 1
	assert_object(pole).is_not_null()
	assert_bool(pole.is_active()).is_true()

	# The pole droned at the door the player just used: the drain runs.
	var meter := _city.player.sleep_meter
	var before := meter.value
	var frames := 0
	while frames < 75:
		await get_tree().physics_frame
		frames += 1
	assert_float(meter.value).is_less(before)

	_city.player.global_position = _inside_cafe_position()
	frames = 0
	while (
		_tutorial.flow.current_step() != TutorialFlow.Step.SURVIVOR and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1

	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.SURVIVOR)
	assert_str(_city.hud.toast_message()).is_equal("SAFE ZONE. THE CAFE KEEPS YOU AWAKE.")


func test_the_survivor_names_the_tower_and_the_marker_appears() -> void:
	await _skip_to(TutorialFlow.Step.SURVIVOR)
	var survivor := _tutorial.survivor_npc()
	assert_object(survivor).is_not_null()
	assert_bool(survivor.has_spoken()).is_false()
	assert_bool(_city.quest_markers().has_objective_marker()).is_false()

	_city.player.global_position = survivor.global_position + Vector2(0.0, -30.0)
	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.ROAD and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(survivor.has_spoken()).is_true()
	assert_str(survivor.spoken_line()).is_equal("The tower. Kill the speaker.")
	assert_bool(_city.quest_markers().is_suppressed()).is_false()
	assert_bool(_city.quest_markers().has_objective_marker()).is_true()
	assert_vector(_city.quest_markers().objective_marker_position()).is_equal(
		_city.city_map().broadcast_tower().global_position
	)


func test_the_road_lessons_land_brew_dodge_and_hug() -> void:
	await _skip_to(TutorialFlow.Step.ROAD)
	assert_str(_tutorial.flow.prompt_text()).is_equal(
		"ON THE WAY: BREAK A HUG - DODGE - BREW AT THE POT"
	)

	# The brew: the dial opens at the pot, the cup lands, the skill trains.
	var cups_before := _city.player.coffee_supply.cups
	var skill_before := _city.player.brewing_skills.skill(FILTER_METHOD_ID)
	await _brew_at_the_pot()
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before + 1)
	assert_int(_city.player.brewing_skills.skill(FILTER_METHOD_ID)).is_greater(skill_before)
	# The lesson brews a real payload: the cafe-standard cup with the score
	# the grind earned, so the next throw carries it.
	var payload := _city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal(FILTER_METHOD_ID)
	assert_str(payload.bean.bean_id).is_equal("house")
	assert_float(payload.score).is_equal(85.0)
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_str(_tutorial.flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG - DODGE")

	# The dodge roll.
	_city.player.begin_dodge(Vector2.RIGHT)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_str(_tutorial.flow.prompt_text()).is_equal("ON THE WAY: BREAK A HUG")

	# The hug: one crowd Neighbor grabs, the mash breaks it.
	await _break_a_hug()
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.TOWER)


func test_the_tower_beat_ends_in_silence_then_the_finale() -> void:
	await _skip_to(TutorialFlow.Step.TOWER)
	assert_str(_tutorial.flow.prompt_text()).is_equal("THE TOWER. FIND A FUSE. SWITCH IT OFF.")

	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()

	# One second of silence, then birdsong: the finale follows, section 19
	# step 9 and 10.
	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.FINALE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.FINALE)
	assert_str(_city.hud.toast_message()).is_equal("WAKE-UP RESTORED")
	assert_bool(_city.cinematic_camera).is_true()

	for i: int in range(30):
		await get_tree().physics_frame
	assert_float(_city.camera.zoom.x).is_less(1.0)


func test_the_finale_pans_out_lands_the_title_and_returns() -> void:
	await _skip_to(TutorialFlow.Step.TOWER)
	_switch_the_tower_off()

	var frames := 0
	while not _tutorial.flow.is_done() and frames < FINALE_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(_tutorial.flow.is_done()).is_true()
	assert_bool(_tutorial.finale_view.visible).is_false()
	assert_bool(_city.cinematic_camera).is_false()
	assert_vector(_city.camera.zoom).is_equal(Vector2.ONE)
	assert_bool(_city.player.is_input_locked()).is_false()
	# The city run plays on after the tutorial: the road east still waits.
	assert_bool(_city.is_city_complete()).is_false()


func test_a_rushed_tower_beat_still_lands_the_finale() -> void:
	await _skip_to(TutorialFlow.Step.ROAD)
	_switch_the_tower_off()

	var frames := 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.FINALE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_tutorial.flow.current_step()).is_equal(TutorialFlow.Step.FINALE)


func test_a_locked_player_is_out_of_play() -> void:
	_tutorial.flow.end_video()
	await get_tree().physics_frame
	var start := _city.player.global_position

	_city.player.set_input_locked(true)
	Input.action_press(&"move_right")
	var meter_value := _city.player.sleep_meter.value
	for i: int in range(10):
		await get_tree().physics_frame
	Input.action_release(&"move_right")

	assert_bool(_city.player.is_input_locked()).is_true()
	assert_bool(_city.player.is_invulnerable()).is_true()
	assert_float(_city.player.global_position.distance_to(start)).is_less(
		_tutorial.balance.move_min_distance
	)
	assert_float(_city.player.sleep_meter.value).is_equal(meter_value)

	_city.player.set_input_locked(false)
	Input.action_press(&"move_right")
	for i: int in range(10):
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	assert_float(_city.player.global_position.distance_to(start)).is_greater(
		_tutorial.balance.move_min_distance
	)


func test_only_the_intro_scene_runs_the_tutorial() -> void:
	var plain := PLAIN_CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(plain))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_object(plain.get_node_or_null(^"Tutorial")).is_null()
	assert_bool(plain.quest_markers().is_suppressed()).is_false()
	assert_bool(plain.quest_markers().has_objective_marker()).is_true()


func _skip_to(target: TutorialFlow.Step) -> void:
	# Drive the world through the real polling of the director, one beat at a
	# time, until the flow reaches the target step. The crowd parks far west
	# first: the cafe block spawns wanderers whose hugs would flatten the
	# meter asserts; the hug lesson pulls its own Neighbor in by hand.
	_park_the_crowd_west()
	var frames := 0
	while _tutorial.flow.current_step() != target and frames < MAX_FRAMES_TO_WAIT:
		match _tutorial.flow.current_step():
			TutorialFlow.Step.VIDEO:
				_tutorial.flow.end_video()
			TutorialFlow.Step.MOVE:
				_city.player.global_position += Vector2(120.0, 0.0)
			TutorialFlow.Step.DRINK:
				# One channel only: a second drink_cup call spends another cup.
				if not _city.player.sleep_meter.is_drinking():
					_city.player.drink_cup()
			TutorialFlow.Step.DOOR:
				_city.player.global_position = _outside_cafe_position()
			TutorialFlow.Step.THROW:
				_throw_at_the_window_neighbor()
			TutorialFlow.Step.POLE:
				_city.player.global_position = _inside_cafe_position()
			TutorialFlow.Step.SURVIVOR:
				_city.player.global_position = (
					_tutorial.survivor_npc().global_position + Vector2(0.0, -30.0)
				)
			TutorialFlow.Step.ROAD:
				await _finish_the_road()
		await get_tree().physics_frame
		frames += 1
	assert_int(_tutorial.flow.current_step()).is_equal(target)


func _throw_at_the_window_neighbor() -> void:
	# Park the crowd far west, stand the scripted Neighbor still in front of
	# the player, and throw: the cup cannot miss and the step always lands.
	_park_the_crowd_west()
	var walker := _tutorial.window_neighbor()
	walker.set_physics_process(false)
	walker.velocity = Vector2.ZERO
	walker.global_position = _city.player.global_position + Vector2(150.0, 0.0)
	_city.player.throw_cup(Vector2.RIGHT)


func _park_the_crowd_west() -> void:
	# The wandering crowd would race the scripted Neighbor for the aim cone.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).global_position = Vector2(-500.0, 360.0)


func _brew_at_the_pot() -> void:
	# The pot stands inside the cafe: the brew needs the safe zone. The dial
	# stops the moment the marker enters the filter zone, so the cup scores.
	# The stand of the masters shares the cafe, so the probe stands at one:
	# the dial must own the interact key while it plays. The press rides the
	# real input pipeline, because the director consumes it there.
	var master := _city.masters()[0]
	_city.player.global_position = master.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	_tutorial.begin_brew()
	var dial := _tutorial.grind_dial_view()
	assert_object(dial).is_not_null()
	assert_bool(_city.player.is_input_locked()).is_true()
	_fire_interact_action()
	await get_tree().process_frame
	assert_int(_city.master_lessons.lessons_taken(master.master.master_id)).is_equal(0)
	var frames := 0
	while dial.model.position < dial.model.zone_start() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	dial.request_stop()
	await get_tree().physics_frame
	await get_tree().process_frame
	# The dial closed, so the same press at the master takes the lesson.
	_city._unhandled_input(_interact_event())
	assert_int(_city.master_lessons.lessons_taken(master.master.master_id)).is_equal(1)


func _fire_interact_action() -> void:
	# One interact press as an action event, so the dial does not read it as
	# its own stop key and the press still walks the whole pipeline. The flush
	# pushes the buffered pair out at once: under load, the headless input
	# transport drops events that wait for the next frame.
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _interact_event() -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	return key


func _finish_the_road() -> void:
	await _brew_at_the_pot()
	_city.player.begin_dodge(Vector2.RIGHT)
	await get_tree().physics_frame
	await _break_a_hug()


func _break_a_hug() -> void:
	# One crowd Neighbor grabs the player, and the mash presses break free.
	var enemy := _city.crowd_enemy(0)
	enemy.global_position = _city.player.global_position + Vector2(14.0, 0.0)
	var frames := 0
	while not _city.player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_city.player.is_grabbed()).is_true()
	await get_tree().physics_frame
	assert_str(_tutorial.prompt_label.text).is_equal("A HUG! MASH TO BREAK FREE.")

	while _city.player.is_grabbed():
		_city.player.struggle()
		await get_tree().physics_frame
	frames = 0
	while _tutorial.flow.current_step() != TutorialFlow.Step.TOWER and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1


func _switch_the_tower_off() -> void:
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	tower.insert_fuse(_city.player)
	tower.switch_off()


func _inside_cafe_position() -> Vector2:
	return _city.city_map().cafe_spawn().global_position


func _outside_cafe_position() -> Vector2:
	# Straight south of the cafe center, outside the safe zone circle.
	var cafe_block := _city.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	var center := cafe_block.global_position + cafe_block.size * 0.5
	return center + Vector2(0.0, cafe_block.cafe_zone_radius() + 80.0)
