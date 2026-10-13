# ABOUTME: Integration tests for the cafe level flow: throwing, hugging, losing, winning.
# ABOUTME: Drives the real cafe scene with physics frames, no input devices needed.
extends GdUnitTestSuite

const CAFE_SCENE := preload("res://scenes/cafe/cafe.tscn")

const MAX_FRAMES_TO_WAIT := 600

var _cafe: Cafe


func before_test() -> void:
	_cafe = CAFE_SCENE.instantiate()
	add_child(auto_free(_cafe))
	await get_tree().physics_frame


func test_player_throws_cup_in_direction() -> void:
	var cup := _cafe.player.throw_cup(Vector2.RIGHT) as CoffeeCup
	assert_object(cup).is_not_null()
	assert_vector(cup.direction).is_equal(Vector2.RIGHT)
	cup.queue_free()


func test_throwing_costs_one_cup_per_throw() -> void:
	var supply := _cafe.player.coffee_supply
	var start_cups: int = supply.cups
	for index: int in range(start_cups):
		var cup := _cafe.player.throw_cup(Vector2.RIGHT) as CoffeeCup
		assert_object(cup).is_not_null()
		if cup != null:
			cup.queue_free()
	assert_int(supply.cups).is_equal(0)
	assert_bool(supply.is_empty()).is_true()
	assert_object(_cafe.player.throw_cup(Vector2.RIGHT)).is_null()


func test_drinking_without_cups_does_not_start_the_drink() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	var player := _cafe.player
	var meter := player.sleep_meter
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	meter.drain(80.0)

	assert_bool(player.drink_cup()).is_false()
	assert_bool(meter.is_drinking()).is_false()
	assert_float(meter.value).is_equal_approx(20.0, 0.0001)


func test_cafe_refills_the_supply_for_free() -> void:
	var player := _cafe.player
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	assert_int(_cafe.refill_player_supply()).is_equal(player.supply_balance.base_carry_limit)
	assert_int(player.coffee_supply.cups).is_equal(player.supply_balance.base_carry_limit)
	assert_int(_cafe.refill_player_supply()).is_equal(0)


func test_sustained_hug_sleeps_the_player_who_wakes_in_the_cafe() -> void:
	var woken := _cafe.get_sleepwalker(0)
	woken.wake_up()
	var hugger := _cafe.get_sleepwalker(1)
	_cafe.player.position = hugger.position

	var start_wake_ups: int = _cafe.player.wake_ups.remaining
	var frames := 0
	while _cafe.player.wake_ups.remaining == start_wake_ups and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(_cafe.player.wake_ups.remaining).is_equal(start_wake_ups - 1)
	# The player wakes in the cafe: back at the spawn point with a full meter.
	assert_vector(_cafe.player.global_position).is_equal(_cafe.cafe_spawn.global_position)
	assert_float(_cafe.player.sleep_meter.value).is_equal_approx(100.0, 0.05)
	assert_bool(_cafe.player.is_asleep()).is_false()
	assert_bool(_cafe.is_game_over()).is_false()
	# The world stays as it is: the woken neighbor did not sleep again.
	assert_int(woken.state).is_equal(Sleepwalker.State.AWAKE)


func test_sleep_at_zero_wake_ups_is_full_death() -> void:
	_cafe.player.wake_ups.remaining = 0
	_cafe.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame

	assert_bool(_cafe.player.is_asleep()).is_true()
	assert_bool(_cafe.is_game_over()).is_true()
	assert_bool(_cafe.is_game_won()).is_false()
	assert_str(_cafe.status_label.text).is_equal(Cafe.DEATH_TEXT)


func test_sleeping_player_cannot_throw_or_drink() -> void:
	_cafe.player.wake_ups.remaining = 0
	_cafe.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame

	var player := _cafe.player
	var cups_before: int = player.coffee_supply.cups
	var children_before: int = _cafe.get_child_count()
	assert_object(player.throw_cup(Vector2.RIGHT)).is_null()
	assert_bool(player.drink_cup()).is_false()
	assert_int(player.coffee_supply.cups).is_equal(cups_before)
	assert_int(_cafe.get_child_count()).is_equal(children_before)
	assert_bool(player.sleep_meter.is_drinking()).is_false()


func test_drinking_a_cup_fills_the_meter() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	var meter := _cafe.player.sleep_meter
	meter.drain(80.0)
	_cafe.player.drink_cup()

	var frames := 0
	while meter.is_drinking() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_bool(meter.is_drinking()).is_false()
	# Start 20, cup gain 40; the player drinks inside the cafe safe zone,
	# so no passive drain runs while the cup fills the meter.
	assert_float(meter.value).is_equal_approx(60.0, 0.05)


func test_speaker_pole_zone_drains_the_meter_faster() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	var pole := _cafe.get_node("Zones/SpeakerPole") as SleepZone
	_cafe.player.position = pole.position
	await get_tree().physics_frame

	var meter := _cafe.player.sleep_meter
	var value_before := meter.value
	var frames := 0
	while frames < 60:
		await get_tree().physics_frame
		frames += 1
	# 60 physics frames are one second; the pole zone drains 1.5 in that
	# time, three times the passive rate of 0.5.
	var drained := value_before - meter.value
	assert_float(drained).is_between(1.3, 1.7)


func test_cafe_safe_zone_stops_the_meter_drain() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	var safe_zone := _cafe.get_node("Zones/CafeSafeZone") as SleepZone
	_cafe.player.position = safe_zone.position
	_cafe.player.sleep_meter.drain(30.0)
	await get_tree().physics_frame

	var meter := _cafe.player.sleep_meter
	var value_before := meter.value
	var frames := 0
	while frames < 120:
		await get_tree().physics_frame
		frames += 1
	# Inside the cafe safe zone the meter keeps its value: no drain at all.
	assert_float(meter.value).is_equal_approx(value_before, 0.001)


func test_waking_all_sleepwalkers_wins() -> void:
	for index: int in _cafe.sleepwalkers.get_child_count():
		_cafe.get_sleepwalker(index).wake_up()

	assert_bool(_cafe.is_game_won()).is_true()
	assert_bool(_cafe.is_game_over()).is_false()
	assert_str(_cafe.status_label.text).is_equal(Cafe.WIN_TEXT)


func test_neighbor_emits_first_met_for_the_sleepydex() -> void:
	var met_types: Array[String] = []
	var neighbor := _cafe.get_sleepwalker(0)
	neighbor.first_met.connect(func(type_id: String) -> void: met_types.append(type_id))

	_cafe.player.position = neighbor.position
	var frames := 0
	while met_types.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	assert_int(met_types.size()).is_equal(1)
	assert_str(met_types[0]).is_equal("neighbor")
	for extra_frame: int in range(30):
		await get_tree().physics_frame
	assert_int(met_types.size()).is_equal(1)
