# ABOUTME: Integration tests for the Moonwalker haunt in Pourtland, section 24.
# ABOUTME: The spawn gate, the hidden SleepyDex rule, and the dance-off
# ABOUTME: that teaches the Moonwalk dodge.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/pourtland.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const BALANCE := preload("res://resources/balance/moonwalker.tres")

# The spawn poll needs settled area overlaps: the fresh city runs three or
# more physics frames before its zones report bodies, like every city suite.
const SETTLE_FRAMES := 6
const MAX_FRAMES_TO_WAIT := 900

var _city: CityRun
var _mystery: MoonwalkerMystery


func before_test() -> void:
	MoveHandoff.reset()
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	for _frame: int in range(SETTLE_FRAMES):
		await get_tree().physics_frame
	_mystery = _city.get_tree().get_first_node_in_group(&"moonwalker_mystery") as MoonwalkerMystery
	assert_object(_mystery).is_not_null()


func after_test() -> void:
	MoveHandoff.reset()


func test_no_figure_while_the_tower_still_plays() -> void:
	# The gate rule, part one: dawn alone, and a silent stand in a pole
	# zone alone, spawn nothing while the address still runs.
	_silence_the_tower(false)
	_stand_in_a_pole_zone()
	_force_dawn()
	await _frames(30)
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.WAITING)
	assert_object(_mystery.figure()).is_null()


func test_no_figure_outside_the_dawn_window() -> void:
	_silence_the_tower(true)
	_stand_in_a_pole_zone()
	await _frames(30)
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.WAITING)
	assert_object(_mystery.figure()).is_null()


func test_no_figure_outside_a_silent_zone() -> void:
	_silence_the_tower(true)
	_city.player.global_position = _city.city_map().cafe_spawn().global_position
	_force_dawn()
	await _frames(30)
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.WAITING)
	assert_object(_mystery.figure()).is_null()


func test_the_figure_spawns_at_dawn_in_the_silent_zone() -> void:
	_silence_the_tower(true)
	_stand_in_a_pole_zone()
	_force_dawn()
	await _frames(MAX_FRAMES_TO_WAIT, _figure_live)
	assert_object(_mystery.figure()).is_not_null()
	assert_str(_mystery.figure().enemy_type.type_id).is_equal("moonwalker")
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.FIGHT)


func test_the_hidden_entry_opens_only_on_the_wake() -> void:
	# The hidden-dex rule, section 9 and section 24: the fight itself opens
	# no entry, and the wake opens the only smooth row.
	_silence_the_tower(true)
	_stand_in_a_pole_zone()
	_force_dawn()
	await _frames(MAX_FRAMES_TO_WAIT, _figure_live)
	# He spots the player like any sleepwalker: the meeting alone opens no
	# entry, because the hidden row waits for the wake.
	var figure := _mystery.figure()
	_city.player.global_position = figure.global_position + Vector2(60, 0)
	await _frames(SETTLE_FRAMES)
	assert_object(figure.player).is_not_null()
	assert_bool(_city.sleepy_dex().is_found("moonwalker")).is_false()
	assert_bool(figure.try_wake(_ristretto())).is_true()
	await _frames(
		MAX_FRAMES_TO_WAIT, func() -> bool: return _mystery.phase() == MoonwalkerMystery.Phase.OFFER
	)
	assert_bool(_city.sleepy_dex().is_found("moonwalker")).is_true()
	# The row reads the smooth line of the hidden entry, section 24.
	var row := _dex_row_index("The Moonwalker")
	assert_int(row).is_greater_equal(0)
	assert_str(_city.hud.dex_app.row_status(row)).is_equal("Status: smooth")


func test_the_dance_off_teaches_the_moonwalk_dodge() -> void:
	await _wake_the_figure()
	_city.player.global_position = _mystery.figure().global_position
	await _frames(
		MAX_FRAMES_TO_WAIT, func() -> bool: return _mystery.phase() == MoonwalkerMystery.Phase.OFFER
	)
	assert_bool(_mystery.try_begin_dance_off()).is_true()
	assert_bool(_mystery.owns_screen()).is_true()
	assert_bool(_city.player.is_input_locked()).is_true()
	var view := _mystery.dance_off_view()
	assert_object(view).is_not_null()
	# Tap every beat on its mark: the perfect taps win the dance.
	for i: int in range(view.model.beats_total()):
		await _frames(
			MAX_FRAMES_TO_WAIT, func() -> bool: return view.model.is_over() or _near_next_beat(view)
		)
		if view.model.is_over():
			break
		view.request_tap()
	await _frames(
		MAX_FRAMES_TO_WAIT, func() -> bool: return _mystery.phase() == MoonwalkerMystery.Phase.DONE
	)
	assert_int(_city.player.dodge_style).is_equal(Player.DodgeStyle.MOONWALK)
	assert_bool(_mystery.owns_screen()).is_false()
	assert_bool(_city.player.is_input_locked()).is_false()
	# The dance stands the player still in a plaza for its whole length, and a
	# wandering sleeper of the plain crowd walks up and grabs them before the
	# roll lands: the city, not the mystery. The crowd stands down, because a
	# grabbed player cannot roll.
	_wake_the_crowd()
	await _frames(SETTLE_FRAMES)
	# Section 24: the Moonwalk dodge is a roll variant with no power. The
	# dodge keeps the plain speed, window, and invulnerability, and it leans.
	assert_bool(_city.player.begin_dodge(Vector2.RIGHT)).is_true()
	var dodge_speed := _city.player.balance.dodge_speed
	await _frames(1)
	assert_float(_city.player.velocity.length()).is_equal_approx(dodge_speed, 1.0)
	assert_bool(_city.player.is_invulnerable()).is_true()
	assert_float(_city.player.visual.rotation).is_equal_approx(Player.MOONWALK_LEAN, 0.01)


func test_a_lost_dance_off_sends_him_back_to_the_dawn() -> void:
	await _wake_the_figure()
	_city.player.global_position = _mystery.figure().global_position
	await _frames(
		MAX_FRAMES_TO_WAIT, func() -> bool: return _mystery.phase() == MoonwalkerMystery.Phase.OFFER
	)
	assert_bool(_mystery.try_begin_dance_off()).is_true()
	var view := _mystery.dance_off_view()
	# No tap at all: every beat misses, the dance is lost, and no dodge is
	# taught.
	await _frames(
		MAX_FRAMES_TO_WAIT,
		func() -> bool: return _mystery.phase() != MoonwalkerMystery.Phase.DANCE_OFF
	)
	assert_int(_city.player.dodge_style).is_equal(Player.DodgeStyle.ROLL)
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.DEPARTING)
	await _frames(
		MAX_FRAMES_TO_WAIT,
		func() -> bool: return _mystery.phase() == MoonwalkerMystery.Phase.WAITING
	)


func test_he_returns_with_the_next_dawn_for_the_dance() -> void:
	# The wake opened the entry, but the dance-off loss left the mystery
	# open: he returns awake, straight to the offer.
	await test_a_lost_dance_off_sends_him_back_to_the_dawn()
	_stand_in_a_pole_zone()
	_force_dawn()
	await _frames(MAX_FRAMES_TO_WAIT, _figure_live)
	assert_bool(_mystery.figure().is_awake()).is_true()
	assert_int(_mystery.phase()).is_equal(MoonwalkerMystery.Phase.OFFER)


func _wake_the_figure() -> void:
	_silence_the_tower(true)
	_stand_in_a_pole_zone()
	_force_dawn()
	await _frames(MAX_FRAMES_TO_WAIT, _figure_live)
	var figure := _mystery.figure()
	assert_bool(figure.try_wake(_ristretto())).is_true()


func _figure_live() -> bool:
	return _mystery.figure() != null


func _near_next_beat(view: DanceOffView) -> bool:
	var model := view.model
	if model.next_beat() >= model.beats_total():
		return false
	return absf(model.elapsed() - model.beat_time(model.next_beat())) <= 0.033


func _frames(count: int, until: Callable = Callable()) -> void:
	# Physics frames, with an early out once the condition holds: the wait
	# runs at least one frame so a same-frame condition never races the poll.
	var spent := 0
	while spent < count:
		await get_tree().physics_frame
		spent += 1
		if until.is_valid() and until.call():
			return


func _silence_the_tower(silence: bool) -> void:
	if not silence:
		return
	var tower := _city.city_map().broadcast_tower()
	_city.player.pickup_item(FUSE_ITEM, tower.balance.fuses_needed)
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()


func _stand_in_a_pole_zone() -> void:
	var map := _city.city_map()
	var indices := CityRules.pole_block_indices(map.block_count(), map.balance)
	var zone := map.block_view(indices[0]).pole_zone()
	_city.player.global_position = zone.global_position
	await _frames(SETTLE_FRAMES)


func _force_dawn() -> void:
	# Jump the clock to the middle of the dawn window: the jump lands clear
	# of the wrap point, so no float wobble at the cycle edge can skip it,
	# and the wait still holds half a window of dawn.
	var now := _mystery.dawn_clock().time_of_day()
	var target := BALANCE.dawn_length_seconds * 0.5
	_mystery.dawn_clock().advance(BALANCE.day_cycle_seconds + target - now)


func _dex_row_index(name: String) -> int:
	for i: int in range(_city.hud.dex_app.row_count()):
		if _city.hud.dex_app.row_name(i) == name:
			return i
	return -1


func _wake_the_crowd() -> void:
	# Every sleeper of the run wakes, the grabber first: a grab clears through
	# the walker that holds it, and the roll asserts need the player free.
	for node: Node in _city.get_tree().get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var walker := node as Sleepwalker
		if walker != null and not walker.is_awake():
			walker.wake_up()


func _ristretto() -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("light"),
		LIBRARY.find_method("espresso"),
		"short_pull",
		85.0
	)
