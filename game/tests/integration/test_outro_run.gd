# ABOUTME: Integration tests for the version ending of section 16, T048.
# ABOUTME: Drives the Pourtland outro end to end: the Karen blocks the road
# ABOUTME: east, demands the manager, and the credits catch her mid-sentence.
extends GdUnitTestSuite

const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const OUTRO_BALANCE := preload("res://resources/balance/outro.tres")
const OUTRO_KAREN_SCENE := preload("res://scenes/ending/outro_karen.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
# The credits roll ends on their own: march and demand first, then the roll.
const CREDITS_END_FRAMES := 900
# The demand line of section 6 and the mid-sentence catch of section 16.
const DEMAND_LINE := "Manager! I want to see the manager!"
const CAUGHT_LINE := "Manager! I want to see the ma—"

var _city: CityRun
var _outro: OutroDirector


func before_test() -> void:
	_city = POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_outro = _city.get_node(^"Outro") as OutroDirector
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_outro_balance_values_pin_the_section_16_numbers() -> void:
	assert_bool(OUTRO_BALANCE is OutroBalance).is_true()
	# The march, the demand hold, and the credit roll carry the beat order.
	assert_float(OUTRO_BALANCE.karen_march_seconds).is_equal(1.4)
	assert_float(OUTRO_BALANCE.demand_hold_seconds).is_equal(2.6)
	assert_float(OUTRO_BALANCE.credits_roll_seconds).is_equal(9.0)
	# The director of the run reads the tuned balance.
	assert_object(_outro.balance).is_same(OUTRO_BALANCE)


func test_the_karen_body_is_the_wall_of_the_version() -> void:
	# Her barrier spans the whole deck corridor of 720 pixels, so nobody walks
	# around her.
	var karen := auto_free(OUTRO_KAREN_SCENE.instantiate()) as OutroKaren
	var barrier := karen.get_node(^"Barrier") as CollisionShape2D
	var shape := barrier.shape as RectangleShape2D
	assert_vector(shape.size).is_equal(OutroKaren.BARRIER_SIZE)
	assert_float(shape.size.y).is_greater_equal(720.0)


func test_the_outro_waits_dormant_until_the_city_completes() -> void:
	assert_object(_outro).is_not_null()
	assert_int(_outro.flow.current_step()).is_equal(OutroFlow.Step.WAITING)
	assert_object(_outro.karen()).is_null()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.cinematic_camera).is_false()


func test_only_the_last_city_carries_the_outro() -> void:
	# Steamtle is a middle city: its completion opens the road east, and the
	# version does not end there.
	assert_object(_outro).is_not_null()
	var steamtle := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(steamtle))
	await get_tree().physics_frame
	assert_object(steamtle.get_node_or_null(^"Outro")).is_null()


func test_the_completion_begins_the_outro_and_locks_the_player() -> void:
	_complete_city()
	assert_int(_outro.flow.current_step()).is_equal(OutroFlow.Step.ARRIVAL)
	assert_bool(_city.player.is_input_locked()).is_true()
	assert_bool(_city.cinematic_camera).is_true()
	# The outro replaces the completion screen of the middle cities.
	var overlay := _city.get_node(^"UI/Overlay") as ColorRect
	assert_bool(overlay.visible).is_false()
	# The Karen blocks the road east, so the travel trigger never arms.
	assert_bool(_city.road_east_active()).is_false()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_object(_outro.karen()).is_not_null()


func test_the_karen_marches_in_and_blocks_the_road_east() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.DEMAND, MAX_FRAMES_TO_WAIT)
	var karen := _outro.karen()
	assert_bool(karen.is_in_place()).is_true()
	# She stands on the bridge deck, west of the paywall gate: she is the wall
	# of the version.
	var bounds := _city.city_map().city_size()
	assert_float(karen.global_position.x).is_between(bounds.x, bounds.x + CityRun.BRIDGE_DECK_WIDTH)
	assert_float(karen.global_position.y).is_equal(bounds.y * 0.5)
	assert_float(karen.global_position.x).is_less(bounds.x + CityRun.BRIDGE_DECK_WIDTH * 0.5)


func test_she_demands_the_manager() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.DEMAND, MAX_FRAMES_TO_WAIT)
	assert_str(_outro.demand_text()).is_equal(DEMAND_LINE)
	# The demand holds: the credits have not started yet.
	assert_bool(_outro.credits_view.visible).is_false()


func test_the_credits_catch_her_mid_sentence() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.CREDITS, MAX_FRAMES_TO_WAIT)
	assert_bool(_outro.credits_view.visible).is_true()
	assert_bool(_outro.credits_view.is_rolling()).is_true()
	# The frozen line at the top of the roll is her demand, cut mid-sentence.
	assert_str(_outro.credits_view.caught_line()).is_equal(CAUGHT_LINE)
	assert_str(_outro.flow.caught_line()).is_equal(CAUGHT_LINE)
	# The world label is gone: the credits own her line now.
	assert_str(_outro.demand_text()).is_equal("")


func test_a_press_skips_the_credits_into_the_post_game() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.CREDITS, MAX_FRAMES_TO_WAIT)
	var press := InputEventKey.new()
	press.pressed = true
	_outro._unhandled_input(press)
	assert_bool(_outro.credits_view.is_done()).is_true()
	assert_int(_outro.flow.current_step()).is_equal(OutroFlow.Step.POST_GAME)
	# The world returns: the player acts again and the credits are gone.
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.cinematic_camera).is_false()
	assert_bool(_outro.credits_view.visible).is_false()
	# The post-game beat names the open cities and their activities.
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(OutroDirector.POST_GAME_TEXT)
	assert_bool(OutroDirector.POST_GAME_TEXT.contains("FINISH THE SIDE QUESTS")).is_true()
	assert_bool(OutroDirector.POST_GAME_TEXT.contains("COMPLETE THE SLEEPYDEX")).is_true()
	assert_bool(OutroDirector.POST_GAME_TEXT.contains("FIND EVERY HIDDEN GLOVE")).is_true()
	# The Karen stays: she blocks the road east forever.
	assert_object(_outro.karen()).is_not_null()
	assert_bool(_outro.karen().is_in_place()).is_true()


func test_the_credits_end_on_their_own() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.POST_GAME, CREDITS_END_FRAMES)
	assert_bool(_outro.credits_view.is_done()).is_true()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.hud.is_toast_visible()).is_true()


func test_the_post_game_karen_still_blocks_the_road_east() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.CREDITS, MAX_FRAMES_TO_WAIT)
	var press := InputEventKey.new()
	press.pressed = true
	_outro._unhandled_input(press)
	await _await_step(OutroFlow.Step.POST_GAME, MAX_FRAMES_TO_WAIT)
	# The player walks east on the deck and stops at her body: no road east
	# past the Karen in version 1.
	var karen := _outro.karen()
	var player := _city.player
	player.global_position = karen.global_position + Vector2(-60.0, 0.0)
	Input.action_press(&"move_right")
	for _i: int in range(50):
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	assert_float(player.global_position.x).is_less(karen.global_position.x - 20.0)


func test_the_outro_plays_once_per_run() -> void:
	_complete_city()
	await _await_step(OutroFlow.Step.POST_GAME, CREDITS_END_FRAMES)
	_outro.begin()
	assert_int(_outro.flow.current_step()).is_equal(OutroFlow.Step.POST_GAME)
	assert_bool(_city.player.is_input_locked()).is_false()


func test_a_loaded_post_game_world_finds_the_karen_blocking() -> void:
	# A saved ending never replays: the world resumes with the Karen standing
	# on the road, silent, and the player free to play.
	_outro.flow.load_state({"step": OutroFlow.Step.POST_GAME})
	_outro._enter_step(OutroFlow.Step.POST_GAME, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var karen := _outro.karen()
	assert_object(karen).is_not_null()
	assert_bool(karen.is_in_place()).is_true()
	var bounds := _city.city_map().city_size()
	assert_float(karen.global_position.x).is_between(bounds.x, bounds.x + CityRun.BRIDGE_DECK_WIDTH)
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_bool(_city.hud.is_toast_visible()).is_false()


func _complete_city() -> void:
	# The real beats: one fuse at the foot, the tower switch, then the boss.
	var player := _city.player
	player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	_city.notify_boss_cured()


func _await_step(step: OutroFlow.Step, max_frames: int) -> void:
	# This helper awaits physics frames, so every caller must await it too.
	var frames := 0
	while _outro.flow.current_step() != step and frames < max_frames:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(max_frames)


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or sprint, so the outro tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()
