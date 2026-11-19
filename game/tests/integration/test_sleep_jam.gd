# ABOUTME: Integration tests for the Sleep Jam boss fight of Pourtland, T031.
# ABOUTME: Proves the lullaby aura drain and the Geisha Vault cure condition.
extends GdUnitTestSuite

const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
const PHYSICS_FRAMES_PER_SECOND := 60
# The band plays on the arena stage, north of the arena center.
const STAGE_LOCAL_OFFSET := Vector2(0.0, -140.0)

var _city: CityRun
var _band: SleepJamBand
var _spoken_lines: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counter
	# resets here, not in the member declaration.
	_spoken_lines.clear()
	_city = POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_band = _city.boss() as SleepJamBand
	if _band != null:
		_band.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_band_performs_on_the_beanroom_stage() -> void:
	# The Sleep Jam stands at the arena center of the city and plays one
	# endless song from a stage off the crowd lane.
	assert_object(_band).is_not_null()
	var arena := _city.city_map().find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
	assert_vector(_band.global_position).is_equal(arena.global_position + arena.size * 0.5)
	assert_bool(_band.is_performing()).is_true()
	assert_bool(_band.is_awake()).is_false()
	# Three members sleep-perform in their pajama indigo.
	var members := _band.band_members()
	assert_int(members.size()).is_equal(3)
	for member: Polygon2D in members:
		assert_bool(member.color == SleepJamBand.SLEEPING_COLOR).is_true()


func test_the_lullaby_covers_the_arena_at_the_boring_rate() -> void:
	# Section 14: the endless song is a boring attack, so it drains 5 per
	# second, not the passive 0.5 and not the sleep-zone 1.5.
	var zone := _band.lullaby_zone()
	assert_int(zone.kind).is_equal(SleepZone.Kind.BORING)
	assert_float(_circle_radius(zone)).is_equal(_band.balance.lullaby_radius)
	assert_bool(zone.is_active()).is_true()

	var drop := await _meter_drop_inside_the_song(3.0)
	var expected := METER_BALANCE.boring_attack_drain_per_second * 3.0
	assert_float(drop).is_between(expected - 2.0, expected + 2.0)
	# The song never ends on its own: the band still performs after the stay.
	assert_bool(_band.is_performing()).is_true()


func test_outside_the_song_the_meter_drains_passively() -> void:
	# The aura ends at its radius: on a plain block one block west of the
	# arena, only the passive drain of the address pulls the player down.
	var plain_block := _city.city_map().block_view(1)
	_city.player.global_position = plain_block.global_position + plain_block.size * 0.5
	await get_tree().physics_frame
	var drop := await _meter_drop_at_the_player(1.0)
	assert_float(drop).is_between(0.25, 0.75)


func test_the_dead_tower_does_not_stop_the_song() -> void:
	# The band plays its own song, not the address: switching the city tower
	# off silences the pole zones but leaves the lullaby untouched.
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_bool(_city.progress.is_tower_off()).is_true()

	var drop := await _meter_drop_inside_the_song(1.0)
	var expected := METER_BALANCE.boring_attack_drain_per_second
	assert_float(drop).is_between(expected - 1.0, expected + 1.0)


func test_normal_coffee_does_not_wake_the_band() -> void:
	# Section 6: only the obscure single-origin beans work. The cafe-standard
	# cup splashes on the stage and the song plays on.
	var standard_cup := _brew("house", "medium", "filter", "", 85.0)
	assert_bool(_band.try_wake(standard_cup)).is_false()
	assert_bool(_band.is_performing()).is_true()

	# One more refused serve from the good-tier beans: still no wake.
	var good_origin := _brew("moss_hollow_organic", "medium", "filter", "", 85.0)
	assert_bool(_band.try_wake(good_origin)).is_false()
	assert_bool(_band.is_performing()).is_true()
	assert_int(_spoken_lines.size()).is_equal(0)


func test_the_geisha_cup_wakes_the_whole_band_and_ends_the_song() -> void:
	# The acceptance case for the cure: a cup from the Geisha Vault tier
	# recipe wakes every member, the song stops, and the aura goes quiet.
	var geisha_cup := _brew("geisha_vault", "medium", "filter", "", 85.0)
	assert_bool(_band.try_wake(geisha_cup)).is_true()
	assert_bool(_band.is_awake()).is_true()
	for member: Polygon2D in _band.band_members():
		assert_bool(member.color == SleepJamBand.AWAKE_COLOR).is_true()
	assert_bool(_band.lullaby_zone().is_active()).is_false()
	assert_int(_spoken_lines.size()).is_equal(1)
	assert_str(_spoken_lines[0]).is_equal(_band.balance.wake_line)
	# A second serve changes nothing.
	assert_bool(_band.try_wake(geisha_cup)).is_false()
	assert_int(_spoken_lines.size()).is_equal(1)


func test_the_ended_song_stops_the_aura_drain() -> void:
	# With the band awake, a stay in the arena costs only the passive drain.
	assert_bool(_band.try_wake(_brew("geisha_vault", "light", "v60", "", 85.0))).is_true()
	var drop := await _meter_drop_inside_the_song(1.0)
	assert_float(drop).is_between(0.25, 0.75)


func test_the_band_cure_completes_the_city_after_the_tower() -> void:
	# Section 7: the city completes when the tower is off and the boss is
	# cured, in either order. The wake toast carries the beat.
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_bool(_city.is_city_complete()).is_false()

	assert_bool(_band.try_wake(_brew("geisha_vault", "medium", "filter", "", 85.0))).is_true()
	assert_bool(_city.progress.is_boss_cured()).is_true()
	assert_bool(_city.is_city_complete()).is_true()
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(SleepJamBand.WAKE_TOAST)
	assert_int(_city.quest_log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	# Section 16: the version ends in Pourtland. The outro replaces the
	# completion screen and the Karen blocks the road east, so the travel
	# trigger never arms in the last city. The outro sequencing itself is
	# covered by test_outro_run.gd.
	var outro := _city.get_node_or_null(^"Outro") as OutroDirector
	assert_object(outro).is_not_null()
	assert_int(outro.flow.current_step()).is_equal(OutroFlow.Step.ARRIVAL)
	assert_bool(_city.roads.east_active()).is_false()


func test_a_thrown_geisha_cup_wakes_the_band() -> void:
	# The throw is the delivery verb of the game: a cure cup that lands on
	# the stage wakes the band through the same path as a serve.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = _band.global_position + STAGE_LOCAL_OFFSET + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _brew("geisha_vault", "medium", "filter", "", 85.0)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(_band.is_awake()).is_true()


func test_a_saved_cure_lands_silent_on_a_reloaded_stage() -> void:
	# Section 18: the cure of the song rides the run slot as one plain flag.
	# A reloaded stage never replays the endless song: the band stands awake,
	# the lullaby stays off, and no wake line or signal fires.
	var sleeping := _band.save_state()
	assert_bool(bool(sleeping.get("cured", true))).is_false()

	assert_bool(_band.try_wake(_brew("geisha_vault", "medium", "filter", "", 85.0))).is_true()
	var reloaded := (
		(load("res://scenes/bosses/sleep_jam_band.tscn") as PackedScene).instantiate()
		as SleepJamBand
	)
	add_child(auto_free(reloaded))
	var lines: Array[String] = []
	var wakes := [0]
	reloaded.spoke.connect(func(line: String) -> void: lines.append(line))
	reloaded.band_woke.connect(func() -> void: wakes[0] += 1)
	reloaded.load_state(_band.save_state())
	await get_tree().physics_frame

	assert_bool(reloaded.is_awake()).is_true()
	assert_bool(reloaded.is_performing()).is_false()
	assert_bool(reloaded.lullaby_zone().is_active()).is_false()
	for member: Polygon2D in reloaded.band_members():
		assert_bool(member.color == SleepJamBand.AWAKE_COLOR).is_true()
	assert_int(lines.size()).is_equal(0)
	assert_int(wakes[0]).is_equal(0)


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the meter tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _meter_drop_inside_the_song(seconds: float) -> float:
	# Stand the player next to the stage, inside the lullaby reach, and read
	# the meter before and after the stay.
	_city.player.global_position = _band.global_position + Vector2(120.0, 40.0)
	await get_tree().physics_frame
	return await _meter_drop_at_the_player(seconds)


func _meter_drop_at_the_player(seconds: float) -> float:
	var meter := _city.player.sleep_meter
	var start := meter.value
	for _frame: int in range(int(seconds * PHYSICS_FRAMES_PER_SECOND)):
		await get_tree().physics_frame
	return start - meter.value


func _circle_radius(zone: SleepZone) -> float:
	var shape_node := zone.get_node(^"CollisionShape2D") as CollisionShape2D
	return (shape_node.shape as CircleShape2D).radius


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
