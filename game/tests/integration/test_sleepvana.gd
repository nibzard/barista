# ABOUTME: Integration tests for the Sleepvana side quest of Steamtle, T035.
# ABOUTME: Proves the band orders, the crowd-gather condition, the encore,
# ABOUTME: and the concert wake event radius of section 13.
extends GdUnitTestSuite

const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")

const MAX_FRAMES_TO_WAIT := 600
# The van parks north-east of the garage, clear of every crowd marker so the
# field base invites only the fans the test places on the tables.
const VAN_PARK_OFFSET := Vector2(430.0, -130.0)

var _city: CityRun
var _stage: SleepvanaStage
var _spoken_lines: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declaration.
	_spoken_lines.clear()
	_city = STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_stage = _city.signature_quest as SleepvanaStage
	_stage.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_band_sleeps_at_the_three_sites() -> void:
	# Section 13: the retired band sleeps in three places. The garage holds
	# the guitarist and the frontman, because the garage is the stage.
	assert_object(_stage).is_not_null()
	var map := _city.city_map()
	var members := _stage.members()
	assert_int(members.size()).is_equal(3)
	var anchors := [
		map.find_quest_site("Greenhouse").quest_site_marker().global_position,
		map.find_quest_site("The Sofa").quest_site_marker().global_position,
		map.find_quest_site("The Garage").quest_site_marker().global_position,
	]
	for i: int in range(members.size()):
		assert_bool(members[i].is_awake()).is_false()
		(
			assert_float(members[i].global_position.distance_to(anchors[i] + Vector2(56.0, 0.0)))
			. is_less(2.0)
		)
		var visual := members[i].get_node(^"Visual") as Polygon2D
		assert_bool(visual.color == BandMember.SLEEPING_COLOR).is_true()
	var frontman := _stage.frontman()
	assert_object(frontman).is_not_null()
	assert_bool(frontman.is_frontman).is_true()
	assert_bool(frontman.is_awake()).is_false()
	assert_float(frontman.global_position.distance_to(anchors[2] + Vector2(-56.0, 0.0))).is_less(
		2.0
	)
	assert_vector(_stage.garage_position()).is_equal(anchors[2])


func test_the_band_orders_pin_the_quest_data() -> void:
	# The three simple orders are distinct recipes, and the frontman order
	# asks for the beans of the Steamtle region, good or better.
	assert_object(_stage.order_bassist).is_equal(LIBRARY.find_recipe("sleepvana_order_bassist"))
	assert_object(_stage.order_drummer).is_equal(LIBRARY.find_recipe("sleepvana_order_drummer"))
	assert_object(_stage.order_guitarist).is_equal(LIBRARY.find_recipe("sleepvana_order_guitarist"))
	assert_object(_stage.order_frontman).is_equal(LIBRARY.find_recipe("sleepvana_order_frontman"))
	assert_int(_stage.order_frontman.min_bean_quality).is_equal(BeanType.Quality.GOOD)
	var ids := [
		_stage.order_bassist.recipe_id,
		_stage.order_drummer.recipe_id,
		_stage.order_guitarist.recipe_id,
		_stage.order_frontman.recipe_id,
	]
	for i: int in range(ids.size()):
		assert_int(ids.count(ids[i])).is_equal(1)


func test_a_standard_cup_wakes_no_member() -> void:
	# The cafe-standard cup matches no band order: the members keep their
	# own simple orders, section 13.
	for member: BandMember in _stage.members():
		assert_bool(member.try_wake(_standard_cup())).is_false()
		assert_bool(member.is_awake()).is_false()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)


func test_the_wrong_order_wakes_no_member() -> void:
	# Every member wakes to his own order only: the drummer's moka pot means
	# nothing to the bassist in the greenhouse.
	var bassist := _stage.members()[0]
	assert_bool(bassist.try_wake(_order_cup(_stage.order_drummer))).is_false()
	assert_bool(bassist.try_wake(_order_cup(_stage.order_guitarist))).is_false()
	assert_bool(bassist.try_wake(_order_cup(_stage.order_bassist))).is_true()
	assert_bool(bassist.is_awake()).is_true()


func test_the_orders_wake_the_band_and_accept_the_quest() -> void:
	# The three simple orders wake the three members, and the first wake
	# accepts the side quest, section 12: the woken member asks for the show.
	var quest := _city.quest_log.quest("sleepvana")
	assert_object(quest).is_not_null()
	assert_bool(quest.is_offered()).is_true()

	assert_bool(_stage.members()[1].try_wake(_order_cup(_stage.order_drummer))).is_true()
	assert_bool(quest.is_active()).is_true()
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(SleepvanaStage.QUEST_ACCEPT_TOAST)

	# A perfect cup wakes any member, like every sleeper: the guitarist.
	assert_bool(_stage.members()[2].try_wake(_perfect_cup())).is_true()
	assert_bool(_stage.members()[0].try_wake(_order_cup(_stage.order_bassist))).is_true()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)
	assert_str(_city.hud.toast_message()).is_equal(
		SleepvanaStage.CROWD_STAGE_TOAST % _stage.balance.crowd_size
	)


func test_a_thrown_order_cup_wakes_the_member() -> void:
	# The throw is the delivery verb: the bassist order that lands on the
	# sleeping bassist wakes him through the same rule.
	var bassist := _stage.members()[0]
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = bassist.global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _order_cup(_stage.order_bassist)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(bassist.is_awake()).is_true()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)


func test_the_frontman_refuses_his_order_without_a_crowd() -> void:
	# The crowd-gather condition, part one: even the right order bounces off
	# the frontman while no full crowd stands at the garage.
	_wake_the_band()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)
	assert_bool(_stage.frontman().try_wake(_order_cup(_stage.order_frontman))).is_false()
	assert_bool(_stage.frontman().is_awake()).is_false()
	# A perfect cup bounces too: the crowd rule stands above the tiers.
	assert_bool(_stage.frontman().try_wake(_perfect_cup())).is_false()
	assert_bool(_stage.frontman().is_awake()).is_false()


func test_the_crowd_recruit_needs_a_full_field_cafe() -> void:
	# The crowd-gather condition, part two: the field cafe of the level 3 van
	# gathers the fans, and one fan short of the full crowd recruits nobody.
	_wake_the_band()
	_open_field_cafe()
	_place_gathered_fans(_stage.balance.crowd_size - 1)
	await _await_gathered(_stage.balance.crowd_size - 1)

	assert_bool(_stage.try_interact()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		SleepvanaStage.NOT_ENOUGH_FANS_TOAST % _stage.balance.crowd_size
	)
	for fan: Sleepwalker in _city.van().gathered_survivors():
		assert_bool(fan.is_following()).is_false()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)


func test_the_full_crowd_follows_the_player_to_the_garage() -> void:
	# The crowd-gather condition, part three: the full crowd at the field
	# cafe joins the walk, follows the player, and the arrival at the garage
	# opens the encore.
	_wake_the_band()
	_open_field_cafe()
	var fans := _place_gathered_fans(_stage.balance.crowd_size)
	await _await_gathered(_stage.balance.crowd_size)

	assert_bool(_stage.try_interact()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(SleepvanaStage.RECRUIT_TOAST)
	for fan: Sleepwalker in fans:
		assert_bool(fan.is_following()).is_true()
	# The van lets the followers go: no table takes a fan back.
	for _frame: int in range(20):
		await get_tree().physics_frame
	assert_int(_city.van().gathered_survivors().size()).is_equal(0)
	for fan: Sleepwalker in fans:
		assert_bool(fan.is_following()).is_true()

	# The lead: the player walks to the garage, the fans trail along, and
	# their arrival opens the encore.
	_city.player.global_position = _stage.garage_position()
	var frames := 0
	while _stage.quest.phase() != SleepvanaQuest.Phase.ENCORE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(_city.hud.toast_message()).is_equal(SleepvanaStage.ENCORE_TOAST)
	# The frontman mumbles his order at last, so the player knows the brew.
	assert_str(_stage.frontman().get_node(^"LineLabel").text).is_equal(
		"THE FRONTMAN\nORDER: THE BEAN SPIRIT."
	)


func test_the_frontman_order_wakes_him_during_the_encore() -> void:
	# The encore rule: the frontman order lands only inside the window, and
	# the wake completes the side quest.
	_wake_the_band()
	_play_encore()
	assert_bool(_stage.frontman().try_wake(_order_cup(_stage.order_frontman))).is_true()
	assert_bool(_stage.frontman().is_awake()).is_true()
	assert_bool(_stage.quest.is_concert_done()).is_true()
	assert_bool(_city.quest_log.quest("sleepvana").is_complete()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(SleepvanaStage.CONCERT_TOAST)
	assert_int(_spoken_lines.size()).is_equal(1)
	assert_str(_spoken_lines[0]).is_equal(SleepvanaStage.SONG_LINE)


func test_the_concert_wakes_every_sleepwalker_in_hearing_range() -> void:
	# The wake event radius, the acceptance case: one last concert, and every
	# sleepwalker inside the hearing range of the garage wakes. One step
	# outside the range, a sleeper sleeps on.
	_wake_the_band()
	var garage := _stage.garage_position()
	var near := _spawn_sleeper_at(garage + Vector2(-600.0, 0.0))
	var at_edge := _spawn_sleeper_at(garage + Vector2(_stage.balance.concert_wake_radius, 0.0))
	var far := _spawn_sleeper_at(garage + Vector2(_stage.balance.concert_wake_radius + 100.0, 0.0))

	_play_encore()
	assert_bool(_stage.frontman().try_wake(_order_cup(_stage.order_frontman))).is_true()

	assert_bool(near.is_awake()).is_true()
	assert_bool(at_edge.is_awake()).is_true()
	assert_bool(far.is_awake()).is_false()


func test_a_thrown_frontman_cup_wakes_him_during_the_encore() -> void:
	_wake_the_band()
	_play_encore()
	var frontman := _stage.frontman()
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = frontman.global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _order_cup(_stage.order_frontman)
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(frontman.is_awake()).is_true()
	assert_bool(_stage.quest.is_concert_done()).is_true()


func test_the_missed_encore_releases_the_crowd_and_re_arms() -> void:
	# The encore window ends without the order: the fans drift apart, and the
	# next full crowd at the garage opens the next encore.
	_wake_the_band()
	_play_encore()
	_stage.quest.tick(_stage.balance.encore_seconds)
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)
	assert_bool(_stage.quest.accepts_frontman_cup()).is_false()
	assert_bool(_stage.frontman().is_awake()).is_false()
	assert_str(_city.hud.toast_message()).is_equal(SleepvanaStage.ENCORE_MISSED_TOAST)

	assert_bool(_stage.quest.recruit_crowd(_stage.balance.crowd_size)).is_true()
	assert_bool(_stage.quest.crowd_arrived(_stage.balance.crowd_size)).is_true()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)


func _wake_the_band() -> void:
	# Wakes the three members on their own orders, so the quest enters the
	# crowd stage like in live play.
	var orders := [_stage.order_bassist, _stage.order_drummer, _stage.order_guitarist]
	for i: int in range(_stage.members().size()):
		assert_bool(_stage.members()[i].try_wake(_order_cup(orders[i]))).is_true()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _open_field_cafe() -> void:
	# The van arrives at level 3 and parks south of the garage, outside the
	# arrival radius, section 10.
	_city.van_state.load_state(MobileCafe.Level.FIELD_CAFE)
	_city.player.global_position = _stage.garage_position() + VAN_PARK_OFFSET
	assert_bool(_city.call_van()).is_true()
	assert_bool(_city.van().is_field_base_open()).is_true()


func _place_gathered_fans(count: int) -> Array[Sleepwalker]:
	# Awakened survivors placed on the field base tables count as gathered.
	var fans: Array[Sleepwalker] = []
	for i: int in range(count):
		var fan := _city.crowd_enemy(i)
		fan.wake_up()
		var angle := TAU * float(i) / 6.0
		fan.global_position = (_city.van().global_position + Vector2.from_angle(angle) * 78.0)
		fans.append(fan)
	return fans


func _await_gathered(count: int) -> void:
	# The van invites the fans inside its reach on its own physics beat, and
	# the notice overlap needs its own frames to report the player at the van.
	var frames := 0
	while (
		(not _city.van().is_player_at_van() or _city.van().gathered_survivors().size() < count)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1
	assert_bool(_city.van().is_player_at_van()).is_true()
	assert_int(_city.van().gathered_survivors().size()).is_greater_equal(count)


func _play_encore() -> void:
	# Drives the pure quest into the encore for the world-level beats, the
	# same state the fan walk reaches in live play.
	assert_bool(_stage.quest.recruit_crowd(_stage.balance.crowd_size)).is_true()
	assert_bool(_stage.quest.crowd_arrived(_stage.balance.crowd_size)).is_true()
	assert_int(_stage.quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)


func _spawn_sleeper_at(position: Vector2) -> Sleepwalker:
	var sleeper := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	add_child(auto_free(sleeper))
	sleeper.global_position = position
	assert_bool(sleeper.is_awake()).is_false()
	return sleeper


func _standard_cup() -> BrewedCup:
	# The cafe-standard cup: a plain filter brew that wakes basic types only.
	return _brew("house", "medium", "filter", "", 85.0)


func _order_cup(order: Recipe) -> BrewedCup:
	# A good-tier brew of the order recipe: the cheapest bean and the pinned
	# roast that still satisfy the order's own match rules.
	var bean_id := "house"
	if order.bean_match == Recipe.Match.EXACT:
		bean_id = order.bean_id
	elif order.min_bean_quality > BeanType.Quality.BASIC:
		bean_id = "golden_coast_arabica"
	var roast_id := "light"
	if order.roast_match == Recipe.Match.EXACT:
		roast_id = ["light", "medium", "dark"][order.roast]
	return _brew(bean_id, roast_id, order.method_id, order.extra_id, 85.0)


func _perfect_cup() -> BrewedCup:
	return _brew("house", "medium", "filter", "", 99.0)


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
