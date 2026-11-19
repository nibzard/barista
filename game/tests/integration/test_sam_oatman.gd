# ABOUTME: Integration tests for the Sam Oatman boss fight of San Coffesco.
# ABOUTME: Proves the phase progression, the slides aura, and the dripper cure.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const METER_BALANCE := preload("res://resources/balance/sleep_meter.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const DRIPPER_ITEM := preload("res://resources/items/gear/designer_dripper.tres")
const CURE_RECIPE := preload("res://resources/brewing/recipes/designer_dripper_cup.tres")

# One phase runs six seconds, 360 physics frames, so the wait holds a full
# phase plus the lead-in frames of the city build.
const MAX_FRAMES_TO_WAIT := 900
const PHYSICS_FRAMES_PER_SECOND := 60
# The tail of the finale: any window past a phase length proves the hold.
const HOLD_CHECK_FRAMES := 240

var _city: CityRun
var _boss: SamOatman
var _spoken_lines: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations. The spoke signal binds
	# before the first physics frame, so the opening line of the show lands
	# in the record too.
	_spoken_lines.clear()
	_city = SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	_boss = _city.boss() as SamOatman
	if _boss != null:
		_boss.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_guru_sleeps_at_the_keynote_hall() -> void:
	# The show stands at the arena center of the city: a guru in the gray
	# fleece vest on a stage, a hall of sleeping founders, a demo table, and
	# a screen lit with slides.
	assert_object(_boss).is_not_null()
	var arena := _city.city_map().find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
	assert_vector(_boss.global_position).is_equal(arena.global_position + arena.size * 0.5)
	assert_bool(_boss.is_cured()).is_false()
	assert_int(_boss.phase_kind()).is_equal(SamOatman.PhaseKind.SLIDES)
	var members := _boss.hall_members()
	assert_int(members.size()).is_equal(7)
	for member: Polygon2D in members:
		assert_bool(member.color == SamOatman.SLEEPING_COLOR).is_true()
	var screen := _boss.get_node(^"Screen") as Polygon2D
	assert_bool(screen.color == SamOatman.SCREEN_LIT_COLOR).is_true()
	assert_object(_boss.demo_table()).is_not_null()
	assert_int(_boss.live_drones().size()).is_equal(0)

	# The boring slides are the aura of the fight, section 14.
	var zone := _boss.slides_zone()
	assert_int(zone.kind).is_equal(SleepZone.Kind.BORING)
	assert_float(_circle_radius(zone)).is_equal(_boss.balance.slides_radius)
	assert_bool(zone.is_active()).is_true()


func test_every_phase_starts_with_one_more_thing() -> void:
	# The acceptance case for the phase progression: the show opens on the
	# words, every phase change speaks them again, the acts change their
	# attack, and the finale holds the words forever.
	assert_int(_phase_line_count()).is_equal(1)
	assert_int(_boss.live_drones().size()).is_equal(0)

	assert_bool(await _await_phase(1)).is_true()
	assert_int(_boss.phase_kind()).is_equal(SamOatman.PhaseKind.DEMO)
	assert_int(_phase_line_count()).is_equal(2)
	assert_int(_boss.live_drones().size()).is_equal(_boss.balance.demo_drones)
	assert_bool(_boss.slides_zone().is_active()).is_false()

	assert_bool(await _await_phase(2)).is_true()
	assert_int(_boss.phase_kind()).is_equal(SamOatman.PhaseKind.FINALE)
	assert_int(_phase_line_count()).is_equal(3)
	assert_int(_boss.live_drones().size()).is_equal(_boss.balance.finale_drones)
	assert_bool(_boss.slides_zone().is_active()).is_true()

	for _frame: int in range(HOLD_CHECK_FRAMES):
		await get_tree().physics_frame
	assert_int(_boss.phase_index()).is_equal(2)
	assert_int(_phase_line_count()).is_equal(3)
	assert_int(_boss.live_drones().size()).is_equal(_boss.balance.finale_drones)


func test_the_slides_drain_the_meter_at_the_boring_rate() -> void:
	# Section 14: the slides are a boring attack, so they drain 5 per second,
	# not the passive 0.5 and not the sleep-zone 1.5.
	var drop := await _meter_drop_inside_the_show(2.0)
	var expected := METER_BALANCE.boring_attack_drain_per_second * 2.0
	assert_float(drop).is_between(expected - 2.0, expected + 2.0)
	assert_bool(_boss.is_cured()).is_false()


func test_the_demo_phase_stops_the_slides_and_sends_drones() -> void:
	# The live demo replaces the slides: while it runs, a stay inside the old
	# slide reach costs only the passive drain, and the demo drone flies. The
	# arena block of the free city carries a speaker pole, so the tower dies
	# first: its address must not mask the quiet the demo brings.
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()

	assert_bool(await _await_phase(1)).is_true()
	assert_bool(_boss.slides_zone().is_active()).is_false()
	var screen := _boss.get_node(^"Screen") as Polygon2D
	assert_bool(screen.color == SamOatman.SCREEN_DARK_COLOR).is_true()
	assert_int(_boss.live_drones().size()).is_equal(_boss.balance.demo_drones)

	_city.player.global_position = _boss.global_position + Vector2(120.0, 40.0)
	await get_tree().physics_frame
	var drop := await _meter_drop_at_the_player(2.0)
	assert_float(drop).is_between(0.75, 1.25)


func test_the_designer_dripper_scavenges_in_the_arena() -> void:
	# Section 6: the cure starts as scavenge gear. The 700-dollar dripper
	# waits beside the demo table, and the bag holding it opens the recipe at
	# any brew stand.
	var dripper_point := _boss.dripper_point()
	assert_object(dripper_point).is_not_null()
	assert_int(dripper_point.remaining_amount(DRIPPER_ITEM)).is_equal(1)
	assert_bool(BrewFlow.appliance_owned(CURE_RECIPE, _city.player.inventory)).is_false()

	_city.player.global_position = dripper_point.global_position
	var frames := 0
	while not _city.player.inventory.has_item(DRIPPER_ITEM.item_id) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_city.player.inventory.has_item(DRIPPER_ITEM.item_id)).is_true()
	assert_bool(BrewFlow.appliance_owned(CURE_RECIPE, _city.player.inventory)).is_true()


func test_a_wrong_cup_on_the_demo_table_wakes_nobody() -> void:
	# Section 15: the tiers lead. A weak cup wakes nobody, and a good cup off
	# the wrong method or with an extra in it never matches the cure recipe.
	var lines_before := _phase_line_count()
	for cup: BrewedCup in [
		_standard_cup(),
		_brew("house", "medium", "v60", "", 42.0),
		_brew("house", "medium", "v60", "tall_size", 85.0),
	]:
		assert_bool(_boss.demo_table().try_wake(cup)).is_false()
	assert_bool(_boss.is_cured()).is_false()
	assert_int(_phase_line_count()).is_equal(lines_before)


func test_the_designer_cup_on_the_demo_table_wakes_the_guru() -> void:
	# The acceptance case for the cure: one designer dripper cup served on
	# the demo table wakes the guru, he presents the cup as his next product,
	# and the whole show stands down.
	assert_bool(await _await_phase(1)).is_true()
	assert_int(_boss.live_drones().size()).is_equal(_boss.balance.demo_drones)

	assert_bool(_boss.demo_table().try_wake(_designer_cup())).is_true()
	assert_bool(_boss.is_cured()).is_true()
	for member: Polygon2D in _boss.hall_members():
		assert_bool(member.color == SamOatman.AWAKE_COLOR).is_true()
	assert_bool(_boss.slides_zone().is_active()).is_false()
	for drone: Drone in _boss.live_drones():
		assert_int(drone.state).is_equal(Drone.State.LANDED)
	assert_str(_spoken_lines[_spoken_lines.size() - 1]).is_equal(_boss.balance.wake_line)

	# The show ended: no phase speaks again, and a second serve changes
	# nothing.
	var lines_after_wake := _phase_line_count()
	for _frame: int in range(HOLD_CHECK_FRAMES):
		await get_tree().physics_frame
	assert_int(_phase_line_count()).is_equal(lines_after_wake)
	assert_bool(_boss.demo_table().try_wake(_designer_cup())).is_false()


func test_a_thrown_designer_cup_wakes_him_through_the_demo_table() -> void:
	# The throw is the delivery verb of the game: a cure cup that lands on
	# the demo table cures the show through the same path as a serve.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = _boss.demo_table().global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _designer_cup()
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(_boss.is_cured()).is_true()


func test_the_keynote_cure_completes_the_city_after_the_tower() -> void:
	# Section 7: the city completes when the tower is off and the boss is
	# cured, in either order. The wake toast carries the product beat.
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_bool(_city.is_city_complete()).is_false()

	assert_bool(_boss.demo_table().try_wake(_designer_cup())).is_true()
	assert_bool(_city.progress.is_boss_cured()).is_true()
	assert_bool(_city.is_city_complete()).is_true()
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(SamOatman.WAKE_TOAST)
	assert_int(_city.quest_log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	# The road-east trigger arms through a deferred set, so it listens one
	# physics frame after the completion.
	await get_tree().physics_frame
	assert_bool(_city.road_east_active()).is_true()


func test_a_saved_cure_lands_silent_on_a_reloaded_show() -> void:
	# Section 18: the cure of the show rides the run slot as one plain flag.
	# A reloaded arena never replays the keynote: the hall stands awake from
	# the first frame, and no opening line, wake line, or signal fires.
	var sleeping := _boss.save_state()
	assert_bool(bool(sleeping.get("cured", true))).is_false()

	assert_bool(_boss.demo_table().try_wake(_designer_cup())).is_true()
	var reloaded := (
		(load("res://scenes/bosses/sam_oatman.tscn") as PackedScene).instantiate() as SamOatman
	)
	add_child(auto_free(reloaded))
	var lines: Array[String] = []
	var wakes := [0]
	reloaded.spoke.connect(func(line: String) -> void: lines.append(line))
	reloaded.boss_woke.connect(func() -> void: wakes[0] += 1)
	reloaded.load_state(_boss.save_state())
	await get_tree().physics_frame

	assert_bool(reloaded.is_cured()).is_true()
	assert_bool(reloaded.slides_zone().is_active()).is_false()
	var screen := reloaded.get_node(^"Screen") as Polygon2D
	assert_bool(screen.color == SamOatman.SCREEN_DARK_COLOR).is_true()
	for member: Polygon2D in reloaded.hall_members():
		assert_bool(member.color == SamOatman.AWAKE_COLOR).is_true()
	assert_int(reloaded.live_drones().size()).is_equal(0)
	assert_int(lines.size()).is_equal(0)
	assert_int(wakes[0]).is_equal(0)


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the fight tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _await_phase(phase: int) -> bool:
	# Waits until the show crosses into the given phase. False on timeout, so
	# the assert names the phase that never came.
	var frames := 0
	while _boss.phase_index() < phase and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	return _boss.phase_index() >= phase


func _phase_line_count() -> int:
	var count := 0
	for line: String in _spoken_lines:
		if line == _boss.balance.phase_line:
			count += 1
	return count


func _meter_drop_inside_the_show(seconds: float) -> float:
	# Stand the player in the hall, inside the slide reach, and read the
	# meter before and after the stay.
	_city.player.global_position = _boss.global_position + Vector2(120.0, 40.0)
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


func _designer_cup() -> BrewedCup:
	# The cure of the fight, section 6: one good V60 pour, any bean, any
	# roast, the brew the scavenge dripper unlocks.
	return _brew("house", "medium", "v60", "", 85.0)


func _standard_cup() -> BrewedCup:
	# The cafe-standard cup: a plain filter brew that wakes basic types only.
	return _brew("house", "medium", "filter", "", 85.0)


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
