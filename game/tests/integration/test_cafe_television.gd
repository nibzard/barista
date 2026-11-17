# ABOUTME: Integration tests for the cafe television, GAME_DESIGN section 22.
# ABOUTME: The produced Dr. Morgen video replays there after the opening.
extends GdUnitTestSuite

const PLAIN_CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const TUTORIAL_BALANCE := preload("res://resources/balance/tutorial.tres")

var _city: CityRun


func before_test() -> void:
	_city = PLAIN_CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready, so the areas report from the
	# second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_every_city_cafe_carries_a_television_in_its_safe_zone() -> void:
	var cafe_block := _city.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	var television := cafe_block.television()
	assert_object(television).is_not_null()
	var zone := cafe_block.safe_zone()
	assert_float(television.global_position.distance_to(zone.global_position)).is_less_equal(
		cafe_block.cafe_zone_radius()
	)
	# The set stands clear of the brewing master, so one interact press never
	# answers two lessons at once.
	(
		assert_float(
			television.global_position.distance_to(cafe_block.master_spot().global_position)
		)
		. is_greater_equal(150.0)
	)


func test_a_press_away_from_the_television_starts_no_replay() -> void:
	# The player starts at the cafe spawn, far off the set.
	_city._unhandled_input(_interact_event())

	assert_object(_city.get_node_or_null(^"MorgenReplay")).is_null()


func test_one_press_at_the_television_replays_the_video() -> void:
	await _stand_at_television()
	_city._unhandled_input(_interact_event())
	var replay := _replay()

	assert_bool(replay.is_playing()).is_true()
	assert_bool(_city.player.is_input_locked()).is_true()
	assert_bool(replay.video_view.visible).is_true()
	assert_str(replay.video_view.current_line()).is_equal(MorgenVideo.SCRIPT_LINES[0])
	assert_int(replay.video_view.shot()).is_equal(MorgenVideo.Shot.WIDE)


func test_any_press_skips_the_replay_and_frees_the_player() -> void:
	await _stand_at_television()
	_city._unhandled_input(_interact_event())

	_replay()._unhandled_input(_key_event(KEY_W))

	assert_bool(_replay().is_playing()).is_false()
	assert_bool(_replay().video_view.visible).is_false()
	assert_bool(_city.player.is_input_locked()).is_false()


func test_the_replay_runs_the_full_pinned_length() -> void:
	await _stand_at_television()
	_city._unhandled_input(_interact_event())
	var finished: Array[int] = []
	_replay().finished.connect(func() -> void: finished.append(1))

	# The clock rides the physics step, so a poke one frame short of the end
	# proves the replay ends by its timer, not by the press.
	_replay()._time = TUTORIAL_BALANCE.video_seconds - 0.001
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_replay().is_playing()).is_false()
	assert_bool(_replay().video_view.visible).is_false()
	assert_bool(_city.player.is_input_locked()).is_false()
	assert_float(_replay().elapsed()).is_greater_equal(TUTORIAL_BALANCE.video_seconds)
	assert_int(finished.size()).is_equal(1)


func test_the_video_replays_again_after_it_ends() -> void:
	await _stand_at_television()
	_city._unhandled_input(_interact_event())
	_replay()._unhandled_input(_key_event(KEY_W))
	assert_bool(_replay().is_playing()).is_false()

	_city._unhandled_input(_interact_event())

	assert_bool(_replay().is_playing()).is_true()
	assert_str(_replay().video_view.current_line()).is_equal(MorgenVideo.SCRIPT_LINES[0])


func test_a_locked_player_gets_no_replay() -> void:
	await _stand_at_television()
	_city.player.set_input_locked(true)
	_city._unhandled_input(_interact_event())
	assert_object(_city.get_node_or_null(^"MorgenReplay")).is_null()
	_city.player.set_input_locked(false)


func test_the_replay_view_is_the_produced_morgen_video() -> void:
	await _stand_at_television()
	_city._unhandled_input(_interact_event())
	var view := _replay().video_view

	view.set_progress(0.99)
	assert_bool(view.is_cut()).is_true()
	view.set_progress(0.5)
	assert_str(view.current_line()).is_equal(MorgenVideo.SCRIPT_LINES[2])
	assert_int(view.shot()).is_equal(MorgenVideo.Shot.CLOSE)


func _stand_at_television() -> void:
	# The area needs one physics flush to see the moved player.
	var television := _city.city_map().find_block_of_kind(CityBlock.Kind.CAFE).television()
	_city.player.global_position = television.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame


func _replay() -> MorgenReplayPlayer:
	return _city.get_node(^"MorgenReplay") as MorgenReplayPlayer


func _interact_event() -> InputEventKey:
	return _key_event(KEY_E)


func _key_event(code: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key
