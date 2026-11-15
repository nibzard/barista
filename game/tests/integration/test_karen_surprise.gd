# ABOUTME: Integration tests for The Karen: the speed switch and the cure rule.
# ABOUTME: Owns her wake line; the shared wake suites stay lean.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const KAREN_SCENE := preload("res://scenes/enemies/karen.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600
# The pair spawns out of sense range (150) but inside throw range (500).
const PLAYER_START_OFFSET := Vector2(400, 0)

var _karen: Sleepwalker
var _player: Player
var _met_types: Array[String] = []
var _spoken_lines: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_met_types.clear()
	_spoken_lines.clear()
	_karen = KAREN_SCENE.instantiate() as Sleepwalker
	# No idle stands while creeping: every lull frame carries a real direction.
	var calm := _karen.balance.duplicate() as SleepwalkerBalance
	calm.idle_chance = 0.0
	_karen.balance = calm
	_karen.position = Vector2(400, 200)
	add_child(auto_free(_karen))
	_karen.first_met.connect(func(type_id: String) -> void: _met_types.append(type_id))
	_karen.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))

	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = _karen.position + PLAYER_START_OFFSET
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_the_karen_creeps_far_slower_than_the_neighbor() -> void:
	# The player stays far away: this is the lull alone. She looks slow, much
	# slower than the neighbor's walk of 40, and never stands and never sprints.
	for _frame: int in range(120):
		_keep_player_far_away()
		await get_tree().physics_frame
		assert_int(_karen.state).is_equal(Sleepwalker.State.WANDER)
		var speed := _karen.velocity.length()
		assert_float(speed).is_between(11.0, 13.0)


func test_the_speed_switch_is_instant_with_no_telegraph() -> void:
	# The acceptance case for the surprise: the frame she spots the player she
	# still creeps, and one frame later she is at full sprint. No ramp-up
	# between the two speeds, no standing telegraph, no warning tint.
	_player.global_position = _karen.global_position + Vector2(0, 140)

	var chase_frames_after_spot := 0
	var slow_chase_frames := 0
	while chase_frames_after_spot < 40:
		await get_tree().physics_frame
		if _karen.state == Sleepwalker.State.HUG:
			break
		if _karen.state == Sleepwalker.State.WANDER:
			# Before the spot: the lull holds.
			assert_float(_karen.velocity.length()).is_between(11.0, 13.0)
			continue
		chase_frames_after_spot += 1
		var speed := _karen.velocity.length()
		if speed < 20.0:
			slow_chase_frames += 1
		else:
			# Full sprint already: 240 from karen.tres, not one pixel less.
			assert_float(speed).is_between(235.0, 245.0)
			assert_bool(_karen.visual.modulate == Color.WHITE).is_true()

	# Exactly one slow chase frame exists: the spot frame itself.
	assert_int(slow_chase_frames).is_equal(1)


func test_the_surprise_sprint_closes_in_and_ends_in_a_hug() -> void:
	_player.global_position = _karen.global_position + Vector2(0, 140)
	var frames := 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_true()
	assert_int(_karen.state).is_equal(Sleepwalker.State.HUG)
	# 140 pixels minus the hug range at sprint speed 240 is about 31 frames.
	# A steady 70-speed chase, like the neighbor's, needs more than 100.
	assert_int(frames).is_less(60)

	# Mashing breaks the hug, and the sprint chase resumes at full speed.
	for _press: int in range(5):
		_player.struggle()
	await get_tree().physics_frame
	assert_bool(_player.is_grabbed()).is_false()
	_player.global_position = _karen.global_position + Vector2(0, 100)
	var sprint_frames := 0
	var frames_after_break := 0
	while sprint_frames < 1 and frames_after_break < 10:
		await get_tree().physics_frame
		frames_after_break += 1
		if _karen.state == Sleepwalker.State.CHASE:
			assert_float(_karen.velocity.length()).is_between(235.0, 245.0)
			sprint_frames += 1
	assert_int(sprint_frames).is_equal(1)


func test_a_dodge_roll_slips_the_sprint_grab() -> void:
	# The sprint outruns the player walk, so the roll is the counterplay: a
	# rolling player cannot be grabbed, and the hug slides off.
	_player.global_position = _karen.global_position + Vector2(0, 100)
	var frames := 0
	while _karen.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_karen.state).is_equal(Sleepwalker.State.CHASE)

	assert_bool(_player.begin_dodge(Vector2(1, 0))).is_true()
	for _roll_frame: int in range(24):
		await get_tree().physics_frame
		assert_bool(_player.is_grabbed()).is_false()


func test_normal_coffee_does_not_wake_the_karen() -> void:
	# Section 6: normal coffee does not wake her. The cafe-standard cup is a
	# plain filter brew with no tall size, and she refuses it.
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(_karen.try_wake(standard_cup)).is_false()
	assert_int(_karen.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_a_dark_roast_tall_filter_does_not_wake_her() -> void:
	# The cure pins the medium roast: the tall size alone is not enough.
	var dark_tall := _brew("house", "dark", "filter", "tall_size", 85.0)
	assert_bool(_karen.try_wake(dark_tall)).is_false()
	assert_int(_karen.state).is_not_equal(Sleepwalker.State.AWAKE)


func test_the_super_tall_american_wakes_her() -> void:
	# The acceptance case for the cure: the super tall American wakes her, and
	# a second serve changes nothing.
	var super_tall := _brew("house", "medium", "filter", "tall_size", 85.0)
	assert_bool(_karen.try_wake(super_tall)).is_true()
	assert_int(_karen.state).is_equal(Sleepwalker.State.AWAKE)
	assert_bool(_karen.try_wake(super_tall)).is_false()


func test_house_or_better_beans_wake_her() -> void:
	# Section 15: the recipe asks for house beans or better, so a good single
	# origin works as well as the house beans.
	var good_bean := _brew("golden_coast_arabica", "medium", "filter", "tall_size", 85.0)
	assert_bool(_karen.try_wake(good_bean)).is_true()
	assert_int(_karen.state).is_equal(Sleepwalker.State.AWAKE)


func test_a_thrown_super_tall_american_wakes_her() -> void:
	# She wears no hat: a thrown cure cup lands the payload and wakes her.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = Vector2(100, 200)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("house", "medium", "filter", "tall_size", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(is_instance_valid(cup)).is_false()
	assert_int(frames).is_less(50)
	assert_int(_karen.state).is_equal(Sleepwalker.State.AWAKE)


func test_when_she_wakes_she_asks_for_the_manager() -> void:
	# Section 6: when she wakes up, she asks for the manager. The line speaks
	# once, on the wake itself.
	var super_tall := _brew("house", "medium", "filter", "tall_size", 85.0)
	assert_bool(_karen.try_wake(super_tall)).is_true()
	assert_int(_spoken_lines.size()).is_equal(1)
	assert_str(_spoken_lines[0]).is_equal("Manager! I want to see the manager!")

	assert_bool(_karen.try_wake(super_tall)).is_false()
	assert_int(_spoken_lines.size()).is_equal(1)


func test_waking_the_karen_stops_the_sprint() -> void:
	assert_bool(_karen.try_wake(_brew("house", "medium", "filter", "tall_size", 85.0))).is_true()

	var resting_spot := _karen.global_position
	for _frame: int in range(120):
		await get_tree().physics_frame
		assert_vector(_karen.velocity).is_equal(Vector2.ZERO)
	assert_vector(_karen.global_position).is_equal(resting_spot)


func test_karen_emits_first_met_for_the_sleepydex() -> void:
	_player.global_position = _karen.global_position + Vector2(0, 120)
	var frames := 0
	while _met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(_met_types.size()).is_equal(1)
	assert_str(_met_types[0]).is_equal("karen")
	for _frame: int in range(30):
		await get_tree().physics_frame
	assert_int(_met_types.size()).is_equal(1)


func _keep_player_far_away() -> void:
	# Hold the player outside the sense circle so the lull stays in WANDER.
	_player.global_position = _karen.global_position + PLAYER_START_OFFSET


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
