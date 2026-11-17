# ABOUTME: Integration tests for the combat feel rules from GAME_DESIGN section 14.
# ABOUTME: Covers the dodge-roll invulnerability window, the cup arc flight, and the hug mash-break.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")

const MAX_FRAMES_TO_WAIT := 600
# The player body is 40 px tall, the hug circle has an 18 px radius, so the
# vertical grab reach is 38 px from center to center.
const OUTSIDE_GRAB_REACH := Vector2(0, -42)
const INSIDE_GRAB_REACH := Vector2(0, -30)

var _cafe: Cafe


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	await get_tree().physics_frame


func test_dodge_roll_is_invulnerable_for_its_duration() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	var player := _cafe.player
	var start_x := player.global_position.x
	assert_bool(player.begin_dodge(Vector2.RIGHT)).is_true()
	assert_bool(player.is_dodging()).is_true()
	assert_bool(player.is_invulnerable()).is_true()

	var frames := 0
	while player.is_dodging():
		assert_bool(player.is_invulnerable()).is_true()
		await get_tree().physics_frame
		frames += 1

	# 0.4 seconds at 60 physics frames per second.
	assert_int(frames).is_between(23, 25)
	assert_bool(player.is_invulnerable()).is_false()
	# The roll covers ground: 0.4 s at dodge speed.
	assert_float(player.global_position.x - start_x).is_between(160.0, 190.0)


func test_dodge_roll_uses_last_move_direction_when_standing_still() -> void:
	assert_bool(_cafe.player.begin_dodge(Vector2.ZERO)).is_true()
	await get_tree().physics_frame
	assert_vector(_cafe.player.velocity).is_equal(Vector2(440.0, 0.0))


func test_rolling_player_cannot_be_grabbed() -> void:
	var hugger := _prepare_hugger()
	var player := _cafe.player
	player.global_position = hugger.global_position
	assert_bool(player.begin_dodge(Vector2.RIGHT)).is_true()

	while player.is_dodging():
		# Pin the player inside the hug reach for the whole roll.
		player.global_position = hugger.global_position
		await get_tree().physics_frame
		if player.is_dodging():
			assert_bool(player.is_grabbed()).is_false()

	# After the roll ends, the hug can grab again.
	var frames := 0
	while not player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_grabbed()).is_true()


func test_dodge_is_locked_while_grabbed() -> void:
	_prepare_hugger()
	await _grab_the_player()

	assert_bool(_cafe.player.begin_dodge(Vector2.RIGHT)).is_false()
	assert_bool(_cafe.player.is_dodging()).is_false()


func test_hug_grab_range_is_short() -> void:
	var hugger := _prepare_hugger()
	var player := _cafe.player

	player.global_position = hugger.global_position + OUTSIDE_GRAB_REACH
	var frames := 0
	while frames < 10:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_grabbed()).is_false()
	assert_int(hugger.state).is_equal(Sleepwalker.State.CHASE)

	player.global_position = hugger.global_position + INSIDE_GRAB_REACH
	frames = 0
	while not player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_grabbed()).is_true()
	assert_int(hugger.state).is_equal(Sleepwalker.State.HUG)


func test_grabbed_player_mashes_to_break_free() -> void:
	var hugger := _prepare_hugger()
	await _grab_the_player()

	var player := _cafe.player
	# The held hug drains the meter while the player mashes.
	assert_float(player.sleep_meter.value).is_less(100.0)
	var presses: int = player.balance.hug_mash_presses_to_break
	for index: int in range(presses - 1):
		assert_bool(player.struggle()).is_false()
	assert_bool(player.is_grabbed()).is_true()

	assert_bool(player.struggle()).is_true()
	assert_bool(player.is_grabbed()).is_false()
	# The break buys a short grace window against an instant re-grab.
	assert_bool(player.is_invulnerable()).is_true()
	await get_tree().physics_frame
	assert_int(hugger.state).is_equal(Sleepwalker.State.CHASE)

	var frames := 0
	while player.is_invulnerable() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_invulnerable()).is_false()
	# The hug grabs again once the grace window closes.
	frames = 0
	while not player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_grabbed()).is_true()


func test_struggle_without_a_grab_does_nothing() -> void:
	assert_bool(_cafe.player.struggle()).is_false()
	assert_bool(_cafe.player.is_grabbed()).is_false()


func test_waking_the_hugger_releases_the_grabbed_player() -> void:
	var hugger := _prepare_hugger()
	await _grab_the_player()

	hugger.wake_up()

	assert_bool(_cafe.player.is_grabbed()).is_false()
	assert_int(hugger.state).is_equal(Sleepwalker.State.AWAKE)


func test_grabbed_player_cannot_throw_or_drink() -> void:
	_prepare_hugger()
	await _grab_the_player()

	var player := _cafe.player
	var cups_before: int = player.coffee_supply.cups
	var children_before: int = _cafe.get_child_count()
	assert_object(player.throw_cup(Vector2.RIGHT)).is_null()
	assert_bool(player.drink_cup()).is_false()
	assert_int(player.coffee_supply.cups).is_equal(cups_before)
	assert_int(_cafe.get_child_count()).is_equal(children_before)
	assert_bool(player.sleep_meter.is_drinking()).is_false()


func test_cup_flies_a_one_second_arc() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	# Throw east across the open room: walls stop the cup now, so a
	# full-range flight needs a lane clear of them.
	var cup := _cafe.player.throw_cup(Vector2.RIGHT) as CoffeeCup
	assert_object(cup).is_not_null()
	# No target stands right of the player: the cup lands at full throw range.
	assert_vector(cup.landing).is_equal(Vector2(722, 350))

	var frames := 0
	var peak_height := 0.0
	var peak_frame := 0
	var ground_x_at_peak := 0.0
	while is_instance_valid(cup):
		await get_tree().physics_frame
		frames += 1
		if is_instance_valid(cup):
			var height := -cup.visual.position.y
			if height > peak_height:
				peak_height = height
				peak_frame = frames
				ground_x_at_peak = cup.global_position.x

	# Flight time 1.0 s at 60 physics frames per second, plus the free frame.
	assert_int(frames).is_between(59, 63)
	# The parabola peaks near the balanced arc height, half-way through.
	assert_float(peak_height).is_between(35.0, 45.0)
	assert_int(peak_frame).is_between(26, 34)
	assert_float(ground_x_at_peak).is_between(439.0, 505.0)


func test_throw_snaps_to_a_sleepwalker_inside_the_aim_cone() -> void:
	var target := _cafe.get_sleepwalker(0)
	_wake_others(target)
	var frozen := target.balance.duplicate() as SleepwalkerBalance
	frozen.walk_speed = 0.0
	frozen.chase_speed = 0.0
	target.balance = frozen
	await get_tree().physics_frame
	target.global_position = Vector2(700, 220)

	# The target sits 15 degrees above the throw axis; a 30 degree half-cone snaps it.
	var aim := Vector2.from_angle(deg_to_rad(-40.0))
	var cup := _cafe.player.throw_cup(aim) as CoffeeCup

	assert_object(cup).is_not_null()
	assert_vector(cup.landing).is_equal(target.global_position)
	cup.queue_free()


func test_a_thrown_cup_leads_and_wakes_a_walking_sleepwalker() -> void:
	# The T071 playtest finding: a mover drifted past a landing locked to
	# its throw-time position, so an aimed throw at a plainly visible
	# wanderer missed. The assist now leads the walker by its velocity over
	# the flight time, and the throw connects.
	var target := _cafe.get_sleepwalker(0)
	_wake_others(target)
	var steady := target.balance.duplicate() as SleepwalkerBalance
	steady.walk_speed = 40.0
	steady.chase_speed = 40.0
	steady.idle_chance = 0.0
	steady.wander_change_min_seconds = 30.0
	steady.wander_change_max_seconds = 60.0
	target.balance = steady
	await get_tree().physics_frame
	target.global_position = Vector2(560, 350)

	var frames := 0
	while target.velocity == Vector2.ZERO and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_vector(target.velocity).is_not_equal(Vector2.ZERO)

	var flight := _cafe.player.cup_balance.flight_time_seconds
	var aim := target.global_position - _cafe.player.global_position
	var cup := _cafe.player.throw_cup(aim) as CoffeeCup
	assert_object(cup).is_not_null()
	assert_vector(cup.landing).is_equal_approx(
		target.global_position + target.velocity * flight, Vector2(0.1, 0.1)
	)

	frames = 0
	while not target.is_awake() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(target.is_awake()).is_true()


func test_dodge_roll_has_a_cooldown_before_the_next_roll() -> void:
	# The T071 playtest outcome: chain rolls made the player near
	# permanently untouchable, so each roll now buys a short cooldown.
	var player := _cafe.player
	assert_bool(player.begin_dodge(Vector2.RIGHT)).is_true()
	var frames := 0
	while player.is_dodging():
		await get_tree().physics_frame
		frames += 1

	assert_bool(player.begin_dodge(Vector2.RIGHT)).is_false()

	# The cooldown outlasts the roll by its margin: 0.8 s cycle less the
	# 0.4 s roll leaves about 24 frames of locked dodge after the roll.
	frames = 0
	while not player.begin_dodge(Vector2.RIGHT) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_between(18, 30)
	assert_bool(player.is_dodging()).is_true()


func test_dodge_spam_keeps_a_gap_between_rolls() -> void:
	# One roll press every physics frame still cannot chain rolls: the
	# invulnerability uptime stays near the roll share of the cycle.
	var player := _cafe.player
	var invulnerable_frames := 0
	const TOTAL_FRAMES := 240
	for index: int in range(TOTAL_FRAMES):
		player.begin_dodge(Vector2.RIGHT)
		await get_tree().physics_frame
		if player.is_invulnerable():
			invulnerable_frames += 1
	# 0.4 s of roll inside a 0.8 s cycle: about half of the frames, never
	# the near-total uptime chain rolls had before the cooldown.
	assert_int(invulnerable_frames).is_between(90, 150)


func _prepare_hugger() -> Sleepwalker:
	var hugger := _cafe.get_sleepwalker(1)
	_wake_others(hugger)
	var frozen := hugger.balance.duplicate() as SleepwalkerBalance
	frozen.walk_speed = 0.0
	frozen.chase_speed = 0.0
	hugger.balance = frozen
	return hugger


func _wake_others(keep: Sleepwalker) -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		var sleepwalker := _cafe.get_sleepwalker(index)
		if sleepwalker != keep:
			sleepwalker.wake_up()


func _grab_the_player() -> void:
	var hugger := _cafe.get_sleepwalker(1)
	_cafe.player.global_position = hugger.global_position + INSIDE_GRAB_REACH
	var frames := 0
	while not _cafe.player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_cafe.player.is_grabbed()).is_true()
