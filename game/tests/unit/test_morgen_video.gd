# ABOUTME: Unit tests for the MorgenVideo director track, GAME_DESIGN section 22.
# ABOUTME: Pins the subtitle timing, the storyboard, and the small motions.
extends GdUnitTestSuite

var _video := MorgenVideo.new(20.0)


func test_the_script_is_the_section_22_dialogue_verbatim() -> void:
	assert_int(_video.SCRIPT_LINES.size()).is_equal(5)
	assert_str(_video.SCRIPT_LINES[0]).is_equal(
		"If you see this, you drink real coffee. Good. Listen."
	)
	assert_str(_video.SCRIPT_LINES[1]).is_equal(
		(
			"The extraction works. We removed the caffeine, and the body..."
			+ " the body keeps the count. Every missed hour."
		)
	)
	assert_str(_video.SCRIPT_LINES[2]).is_equal("We did not know. They did not listen.")
	assert_str(_video.SCRIPT_LINES[3]).is_equal(
		"It plays tonight. All channels. Do not watch it sleepy."
	)


func test_the_script_ends_on_the_thesis_line() -> void:
	assert_str(_video.SCRIPT_LINES[4]).is_equal(
		"I did a very bad thing. I leave it to you to correct it. Brew it strong."
	)
	assert_str(_video.subtitle_at(19.0)).is_equal(_video.SCRIPT_LINES[4])


func test_one_beat_per_script_line_at_the_pinned_length() -> void:
	assert_float(_video.video_seconds()).is_equal(20.0)
	assert_float(_video.beat_duration()).is_equal(4.0)


func test_the_first_subtitle_holds_until_the_first_boundary() -> void:
	assert_str(_video.subtitle_at(0.0)).is_equal(_video.SCRIPT_LINES[0])
	assert_str(_video.subtitle_at(2.0)).is_equal(_video.SCRIPT_LINES[0])
	assert_str(_video.subtitle_at(3.999)).is_equal(_video.SCRIPT_LINES[0])


func test_each_boundary_switches_the_subtitle() -> void:
	assert_str(_video.subtitle_at(4.0)).is_equal(_video.SCRIPT_LINES[1])
	assert_str(_video.subtitle_at(8.0)).is_equal(_video.SCRIPT_LINES[2])
	assert_str(_video.subtitle_at(12.0)).is_equal(_video.SCRIPT_LINES[3])
	assert_str(_video.subtitle_at(16.0)).is_equal(_video.SCRIPT_LINES[4])


func test_the_last_subtitle_holds_until_the_video_ends() -> void:
	assert_str(_video.subtitle_at(19.99)).is_equal(_video.SCRIPT_LINES[4])
	assert_bool(_video.is_over(19.99)).is_false()
	assert_bool(_video.is_over(20.0)).is_true()
	assert_str(_video.subtitle_at(20.0)).is_equal(_video.SCRIPT_LINES[4])


func test_the_camera_cuts_with_the_script() -> void:
	assert_int(_video.shot_at(0.0)).is_equal(MorgenVideo.Shot.WIDE)
	assert_int(_video.shot_at(4.0)).is_equal(MorgenVideo.Shot.MEDIUM)
	assert_int(_video.shot_at(8.0)).is_equal(MorgenVideo.Shot.CLOSE)
	assert_int(_video.shot_at(12.0)).is_equal(MorgenVideo.Shot.REHEARSAL)
	assert_int(_video.shot_at(16.0)).is_equal(MorgenVideo.Shot.LOOK_BACK)


func test_the_reach_begins_in_the_tail_of_the_last_beat() -> void:
	assert_int(_video.shot_at(18.0)).is_equal(MorgenVideo.Shot.LOOK_BACK)
	assert_float(_video.reach_progress(18.0)).is_equal(0.0)
	assert_int(_video.shot_at(18.25)).is_equal(MorgenVideo.Shot.REACH)
	assert_float(_video.reach_progress(18.25)).is_greater(0.0)


func test_the_reach_rises_smoothly_and_lands_full_at_the_cut() -> void:
	var last := 0.0
	for i: int in range(15):
		var share := _video.reach_progress(18.2 + float(i) * 0.1)
		assert_float(share).is_greater_equal(last)
		last = share
	assert_float(_video.reach_progress(19.7)).is_equal(1.0)


func test_the_video_stops_inside_the_reach() -> void:
	assert_bool(_video.is_cut(19.5)).is_false()
	assert_bool(_video.is_cut(19.7)).is_true()
	assert_bool(_video.is_cut(20.0)).is_true()


func test_she_looks_off_camera_only_at_the_rehearsal_screen() -> void:
	assert_vector(_video.gaze(11.0)).is_equal(Vector2.ZERO)
	assert_vector(_video.gaze(14.0)).is_equal(MorgenVideo.GAZE_AT_SCREEN)
	assert_vector(_video.gaze(17.0)).is_equal(Vector2.ZERO)


func test_the_phone_camera_sways_inside_its_bounds() -> void:
	for i: int in range(20):
		var elapsed := float(i) * 0.05
		var offset := _video.sway_offset(elapsed)
		assert_float(absf(offset.x)).is_less_equal(MorgenVideo.SWAY_PIXELS.x)
		assert_float(absf(offset.y)).is_less_equal(MorgenVideo.SWAY_PIXELS.y)
		assert_float(absf(_video.sway_angle(elapsed))).is_less_equal(MorgenVideo.SWAY_ANGLE)


func test_she_breathes_slowly_and_blinks() -> void:
	assert_float(_video.breath(0.0)).is_equal(0.0)
	assert_float(_video.breath(0.85)).is_equal_approx(1.0, 0.001)
	assert_float(_video.breath(1.7)).is_equal_approx(0.0, 0.001)
	assert_float(_video.breath(2.55)).is_equal_approx(-1.0, 0.001)
	assert_float(_video.lid_openness(0.0)).is_equal(0.0)
	assert_float(_video.lid_openness(1.0)).is_equal(MorgenVideo.TIRED_LID_OPENNESS)


func test_the_recording_light_blinks_each_second() -> void:
	assert_bool(_video.is_rec_on(0.0)).is_true()
	assert_bool(_video.is_rec_on(0.8)).is_false()
	assert_bool(_video.is_rec_on(1.0)).is_true()
	assert_bool(_video.is_rec_on(1.9)).is_false()


func test_the_rehearsal_screen_flickers_only_while_she_watches() -> void:
	assert_float(_video.rehearsal_glow(4.0)).is_equal(0.0)
	assert_float(_video.rehearsal_glow(17.0)).is_equal(0.0)
	assert_float(_video.rehearsal_glow(14.0)).is_between(0.55, 1.0)
	assert_float(_video.rehearsal_glow(14.1)).is_between(0.55, 1.0)
	assert_float(_video.rehearsal_glow(14.0)).is_not_equal(_video.rehearsal_glow(14.1))


func test_the_lab_light_never_holds_still() -> void:
	var changed := false
	var first := _video.light_flicker(0.0)
	for i: int in range(1, 20):
		var value := _video.light_flicker(float(i) * 0.05)
		assert_float(value).is_between(0.92, 1.0)
		if value != first:
			changed = true
	assert_bool(changed).is_true()


func test_a_retuned_length_rescales_every_beat() -> void:
	var short_video := MorgenVideo.new(10.0)
	assert_float(short_video.beat_duration()).is_equal(2.0)
	assert_str(short_video.subtitle_at(2.0)).is_equal(short_video.SCRIPT_LINES[1])
	assert_bool(short_video.is_over(9.99)).is_false()
	assert_bool(short_video.is_over(10.0)).is_true()
	# The cut owns the last tenth of the last beat: 9.8 to 10.0 seconds.
	assert_bool(short_video.is_cut(9.85)).is_true()
	assert_bool(short_video.is_cut(9.7)).is_false()
