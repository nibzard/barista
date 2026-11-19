# ABOUTME: Integration tests for The Moonwalker fight, section 24: the
# ABOUTME: backwards gait, the reverse telegraph, the graze under the guard.
# ABOUTME: Drives the real moonwalker and player scenes with physics frames.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MOONWALKER_SCENE := preload("res://scenes/enemies/moonwalker.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/balance/moonwalker.tres")

const MAX_FRAMES_TO_WAIT := 600

var _figure: Sleepwalker
var _player: Player


func before_test() -> void:
	_figure = MOONWALKER_SCENE.instantiate() as Sleepwalker
	# No idle stands while wandering: every slide carries a real direction,
	# like the gamer suite pins for its bursts.
	var calm := _figure.balance.duplicate() as SleepwalkerBalance
	calm.idle_chance = 0.0
	_figure.balance = calm
	_figure.position = Vector2(400, 200)
	add_child(auto_free(_figure))
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = Vector2(400, 80)
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_he_never_walks_forward() -> void:
	# Section 6: every approach happens backwards. Whenever he closes in on
	# the player, he faces away from her: he looks like he goes away, but he
	# comes closer.
	_place_player_near(Vector2(0, 120))
	await _figure_engages()
	var approaching_frames := 0
	for _frame: int in range(240):
		await get_tree().physics_frame
		var to_player := _player.global_position - _figure.global_position
		var moving_to_player := _figure.velocity.dot(to_player) > 0.0
		if not moving_to_player:
			continue
		approaching_frames += 1
		assert_float(_figure.moonwalk_gait.facing.dot(to_player)).is_less(0.0)
	assert_int(approaching_frames).is_greater(20)


func test_the_telegraph_runs_in_reverse() -> void:
	# Section 24: the slide comes first, the warning after it. The first
	# phase out of the dawn is the slide itself, the telegraph never
	# precedes a slide, and the red signal marks a standstill.
	var seen_phases: Array[int] = []
	var telegraph_moved := false
	for _frame: int in range(200):
		await get_tree().physics_frame
		var phase := _figure.moonwalk_gait.phase()
		if seen_phases.is_empty() or seen_phases.back() != phase:
			seen_phases.append(phase)
		if _figure.moonwalk_gait.is_telegraphing() and _figure.velocity.length() > 1.0:
			telegraph_moved = true
	# The slide opens the cycle: no warning ever comes first.
	assert_int(seen_phases.front()).is_equal(MoonwalkGait.Phase.SLIDE)
	# The cycle holds slide, telegraph, rest, in that order.
	assert_int(seen_phases[1]).is_equal(MoonwalkGait.Phase.TELEGRAPH)
	assert_int(seen_phases[2]).is_equal(MoonwalkGait.Phase.REST)
	# The telegraph never hands into a slide: the rest always stands between.
	for i: int in range(seen_phases.size() - 1):
		if seen_phases[i] != MoonwalkGait.Phase.TELEGRAPH:
			continue
		assert_int(seen_phases[i + 1]).is_equal(MoonwalkGait.Phase.REST)
	assert_bool(telegraph_moved).is_false()


func test_the_slide_is_fast_and_backwards() -> void:
	# Section 6: he only slides backwards, and that is fast. The slide speed
	# pins above the fastest walker of the roster, and the facing always
	# opposes the move.
	var slide_frames := 0
	for _frame: int in range(60):
		await get_tree().physics_frame
		if not _figure.moonwalk_gait.is_sliding():
			continue
		slide_frames += 1
		assert_float(_figure.velocity.length()).is_equal_approx(BALANCE.slide_speed, 1.0)
		# The facing always opposes the move: their dot product is minus one.
		var facing_dot := _figure.moonwalk_gait.facing.dot(_figure.velocity.normalized())
		assert_float(facing_dot).is_equal_approx(-1.0, 0.01)
	assert_int(slide_frames).is_greater(8)


func test_he_does_not_hug_the_graze_slides_under_the_guard() -> void:
	# Section 6: no hug, ever. The player stands inside his arms for a long
	# beat and never gets grabbed, no parry and no block stops the pass, and
	# the brush of the slide costs the meter its price.
	_place_player_near(Vector2.ZERO)
	await _figure_engages()
	for _frame: int in range(120):
		await get_tree().physics_frame
		assert_bool(_player.is_grabbed()).is_false()
		assert_int(_figure.state).is_not_equal(Sleepwalker.State.HUG)
	assert_float(_player.sleep_meter.value).is_less(100.0 - BALANCE.graze_meter_cost + 1.0)


func test_the_graze_pays_at_most_once_per_cooldown() -> void:
	_place_player_near(Vector2.ZERO)
	await _figure_engages()
	var grazes := 0
	var last_value := _player.sleep_meter.value
	for _frame: int in range(180):
		await get_tree().physics_frame
		if last_value - _player.sleep_meter.value >= BALANCE.graze_meter_cost * 0.5:
			grazes += 1
		last_value = _player.sleep_meter.value
	# Three seconds inside his arms: the passive drip never reaches half the
	# price, so every counted drop is a graze, and the cooldown caps them.
	assert_int(grazes).is_between(1, 3)


func test_a_rolling_player_slides_over_the_graze() -> void:
	_place_player_near(Vector2.ZERO)
	await _figure_engages()
	await get_tree().physics_frame
	var value_before_roll := _player.sleep_meter.value
	assert_bool(_player.begin_dodge(Vector2.RIGHT)).is_true()
	for _frame: int in range(10):
		await get_tree().physics_frame
		assert_bool(_player.is_invulnerable()).is_true()
	assert_float(_player.sleep_meter.value).is_greater_equal(value_before_roll - 1.0)


func test_one_ristretto_wakes_him_and_nothing_else_does() -> void:
	var standard := _cup("medium", "filter", "")
	assert_bool(_figure.try_wake(standard)).is_false()
	assert_bool(_figure.is_awake()).is_false()
	var ristretto := _cup("light", "espresso", "short_pull")
	assert_bool(_figure.try_wake(ristretto)).is_true()
	assert_bool(_figure.is_awake()).is_true()


func _place_player_near(offset: Vector2) -> void:
	_player.global_position = _figure.global_position + offset


func _figure_engages() -> void:
	# Wait until the figure spots the player and the chase runs.
	var frames := 0
	while _figure.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_figure.state).is_equal(Sleepwalker.State.CHASE)


func _cup(roast_id: String, method_id: String, extra_id: String) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		85.0
	)
