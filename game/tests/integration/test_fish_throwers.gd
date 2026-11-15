# ABOUTME: Integration tests for the Fish Throwers boss fight of Steamtle, T029.
# ABOUTME: Proves the volley pattern and the head-first cure rule in the city.
extends GdUnitTestSuite

const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const FISH_SCENE := preload("res://scenes/projectiles/fish.tscn")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
# The rhythm spacing between two fish, in physics frames: the 1.2 second
# interval of the volley balance at 60 physics frames per second.
const BEAT_FRAMES := 72

var _city: CityRun
var _boss: FishThrowers
var _spoken_lines: Array[String] = []
# One dictionary per new fish, snapshotted at first sight: "frame", "position",
# and "direction". A fish drops after about 104 frames, so the sightings keep
# plain values, not freed instances.
var _sightings: Array[Dictionary] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the counters
	# reset here, not in the member declarations.
	_spoken_lines.clear()
	_sightings.clear()
	_city = STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_boss = _city.boss() as FishThrowers
	if _boss != null:
		_boss.spoke.connect(func(line: String) -> void: _spoken_lines.append(line))
	_wake_the_crowd()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_crew_sleeps_at_the_public_market() -> void:
	# The fish sellers of the public market: one head fishmonger in the apron
	# front, three crew behind the counter, all asleep in their pajama indigo.
	assert_object(_boss).is_not_null()
	var arena := _city.city_map().find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
	assert_vector(_boss.global_position).is_equal(arena.global_position + arena.size * 0.5)
	assert_bool(_boss.is_cured()).is_false()

	var members := _boss.members()
	assert_int(members.size()).is_equal(4)
	var heads := 0
	for member: FishSeller in members:
		assert_bool(member.is_awake()).is_false()
		if member.is_head:
			heads += 1
	assert_int(heads).is_equal(1)
	assert_object(_boss.head()).is_not_null()
	assert_bool(_boss.head().is_head).is_true()
	assert_int(_boss.crew_members().size()).is_equal(3)
	for member: FishSeller in members:
		var visual := member.get_node(^"Visual") as Polygon2D
		assert_bool(visual.color == FishThrowers.SLEEPING_COLOR).is_true()


func test_the_volley_waits_off_the_market() -> void:
	# The market plays for customers only: with the player at the cafe, three
	# seconds of market time throw no fish at all.
	for _frame: int in range(180):
		await get_tree().physics_frame
		assert_int(_boss.live_fish().size()).is_equal(0)
	assert_int(_boss.live_fish().size()).is_equal(0)


func test_the_volley_throws_one_fish_per_beat_in_seller_order() -> void:
	# The acceptance case for the volley pattern: inside the market, one fish
	# closes every beat, the sellers throw in fixed order, and every fish flies
	# the perfect line to the player spot.
	_city.player.global_position = _boss.global_position + Vector2(0.0, 200.0)
	await get_tree().physics_frame

	await _await_new_fish(4)
	assert_int(_sightings.size()).is_equal(4)

	# The seller order: the crew first, the head fishmonger last.
	var expected_throwers: Array[FishSeller] = []
	expected_throwers.append(_boss.crew_members()[0])
	expected_throwers.append(_boss.crew_members()[1])
	expected_throwers.append(_boss.crew_members()[2])
	expected_throwers.append(_boss.head())
	for i: int in range(_sightings.size()):
		var thrower: FishSeller = expected_throwers[i]
		var position: Vector2 = _sightings[i]["position"]
		assert_float(position.distance_to(thrower.global_position)).is_less(12.0)

	# Perfect aim, section 6: every fish flies the exact line from its seller
	# to the spot where the player stands.
	for i: int in range(_sightings.size()):
		var thrower: FishSeller = expected_throwers[i]
		var expected := (_city.player.global_position - thrower.global_position).normalized()
		var direction: Vector2 = _sightings[i]["direction"]
		assert_float(direction.distance_to(expected)).is_less(0.01)

	# The steady rhythm: the space between two fish is one beat, plus or minus
	# the lead-in frame of the sense area.
	for i: int in range(1, _sightings.size()):
		var space: int = _sightings[i]["frame"] - _sightings[i - 1]["frame"]
		assert_int(space).is_between(BEAT_FRAMES - 3, BEAT_FRAMES + 3)


func test_the_volley_stops_when_the_cure_lands() -> void:
	# The fight ends with the wake: the market that sleeps no more throws no
	# more fish at the player, and the celebration fish drop on their own.
	assert_bool(_boss.head().try_wake(_market_cure())).is_true()
	_city.player.global_position = _boss.global_position + Vector2(0.0, 200.0)
	for _frame: int in range(200):
		await get_tree().physics_frame
	assert_int(_boss.live_fish().size()).is_equal(0)


func test_a_fish_landing_dazzles_the_player() -> void:
	# A fish that lands on the player staggers them for a moment, like the
	# drone bump of the Tech Bro.
	var player := _city.player
	player.global_position = _boss.global_position + Vector2(400.0, 0.0)
	await get_tree().physics_frame
	assert_bool(player.is_stunned()).is_false()

	var fish := FISH_SCENE.instantiate() as Fish
	fish.direction = Vector2.RIGHT
	add_child(auto_free(fish))
	fish.global_position = player.global_position + Vector2(-120.0, 0.0)

	var frames := 0
	while not player.is_stunned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(player.is_stunned()).is_true()


func test_a_dodging_player_slips_the_fish() -> void:
	# The dodge roll of section 14 slips the volley: a rolling player takes no
	# dazzle from a fish that lands on them mid-roll.
	var player := _city.player
	player.global_position = _boss.global_position + Vector2(400.0, 0.0)
	await get_tree().physics_frame

	var fish := FISH_SCENE.instantiate() as Fish
	fish.direction = Vector2.RIGHT
	add_child(auto_free(fish))
	fish.global_position = player.global_position + Vector2(-80.0, 0.0)
	# The roll runs INTO the incoming fish, so the contact lands deep inside
	# the 0.4 second roll instead of behind its end.
	assert_bool(player.begin_dodge(Vector2.LEFT)).is_true()

	var frames := 0
	while is_instance_valid(fish) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(fish)).is_false()
	# The fish died on the player, long before its range end at frame 104.
	assert_int(frames).is_less(60)
	# A dazzle would still hold here: 0.35 seconds of stun against the few
	# frames to the contact.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(player.is_stunned()).is_false()


func test_the_crew_cannot_be_woken_before_the_head() -> void:
	# The head-first cure rule, section 6: a cure cup that lands on a crew
	# member wakes nobody, and a wrong cup wakes nobody at all. The head
	# fishmonger must wake first.
	for member: FishSeller in _boss.crew_members():
		assert_bool(member.try_wake(_market_cure())).is_false()
	assert_bool(_boss.is_cured()).is_false()

	assert_bool(_boss.head().try_wake(_standard_cup())).is_false()
	assert_bool(_boss.is_cured()).is_false()
	for member: FishSeller in _boss.members():
		assert_bool(member.is_awake()).is_false()
	assert_int(_boss.live_fish().size()).is_equal(0)


func test_the_cure_cup_wakes_the_head_first_then_the_crew() -> void:
	# The acceptance case for the cure: one tall cup of the market dark roast
	# into the apron of the head fishmonger wakes him first, and the crew
	# follows him awake.
	assert_bool(_boss.head().try_wake(_market_cure())).is_true()
	assert_bool(_boss.head().is_awake()).is_true()
	for member: FishSeller in _boss.crew_members():
		assert_bool(member.is_awake()).is_true()
	assert_bool(_boss.is_cured()).is_true()
	for member: FishSeller in _boss.members():
		var visual := member.get_node(^"Visual") as Polygon2D
		assert_bool(visual.color == FishThrowers.AWAKE_COLOR).is_true()

	# A second cup changes nothing, wherever it lands.
	assert_bool(_boss.head().try_wake(_market_cure())).is_false()
	assert_bool(_boss.crew_members()[0].try_wake(_market_cure())).is_false()
	assert_int(_spoken_lines.size()).is_equal(1)


func test_the_crew_throws_the_fish_one_last_time_and_cheers() -> void:
	# Section 6: on the wake, the whole market throws the fish one last time,
	# all together, straight up where it hits nobody, and cheers. The fish
	# spawn on the deferred queue, so the first physics frame carries them.
	assert_bool(_boss.head().try_wake(_market_cure())).is_true()
	assert_bool(_boss.is_cured()).is_true()
	await get_tree().physics_frame
	var fish := _boss.live_fish()
	assert_int(fish.size()).is_equal(_boss.members().size())
	var members := _boss.members()
	for i: int in range(fish.size()):
		assert_bool(fish[i].harmless).is_true()
		assert_vector(fish[i].direction).is_equal(Vector2.UP)
		assert_float(fish[i].global_position.distance_to(members[i].global_position)).is_less(8.0)
	assert_int(_spoken_lines.size()).is_equal(1)
	assert_str(_spoken_lines[0]).is_equal(_boss.balance.cheer_line)


func test_a_thrown_cure_cup_wakes_the_head_through_the_apron() -> void:
	# The throw is the delivery verb of the game: a cure cup that lands on the
	# apron of the head fishmonger cures the market through the same path.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = _boss.head().global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _market_cure()
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(_boss.is_cured()).is_true()


func test_a_thrown_plain_cup_wakes_nobody() -> void:
	# The cafe-standard cup splashes on the apron: the market sleeps on.
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = _boss.head().global_position + Vector2(-160.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _standard_cup()
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(_boss.is_cured()).is_false()


func test_a_thrown_cure_cup_on_a_crew_member_wakes_nobody() -> void:
	# The head-first rule holds through the real delivery: a cure cup that
	# lands on a crew member dies on the apron of the wrong seller.
	var crew := _boss.crew_members()[0]
	var cup: CoffeeCup = CUP_SCENE.instantiate()
	cup.position = crew.global_position + Vector2(-120.0, 0.0)
	cup.direction = Vector2.RIGHT
	cup.brewed = _market_cure()
	add_child(auto_free(cup))

	var frames := 0
	while is_instance_valid(cup) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(cup)).is_false()
	assert_bool(_boss.is_cured()).is_false()
	assert_bool(crew.is_awake()).is_false()


func test_the_market_cure_completes_the_city_after_the_tower() -> void:
	# Section 7: the city completes when the tower is off and the boss is
	# cured, in either order. The wake toast carries the cheer.
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(_city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	assert_bool(_city.is_city_complete()).is_false()

	assert_bool(_boss.head().try_wake(_market_cure())).is_true()
	assert_bool(_city.progress.is_boss_cured()).is_true()
	assert_bool(_city.is_city_complete()).is_true()
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(FishThrowers.WAKE_TOAST)
	assert_int(_city.quest_log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)
	# The road-east trigger arms through a deferred set, so it listens one
	# physics frame after the completion.
	await get_tree().physics_frame
	assert_bool(_city.road_east_active()).is_true()


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the fight tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _await_new_fish(count: int) -> void:
	# Watches the flights of the market and snapshots every new fish at first
	# sight: the frame, the position, and the locked direction.
	var seen: Array[int] = []
	var frames := 0
	while _sightings.size() < count and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
		for one: Fish in _boss.live_fish():
			if not seen.has(one.get_instance_id()):
				seen.append(one.get_instance_id())
				(
					_sightings
					. append(
						{
							"frame": frames,
							"position": one.global_position,
							"direction": one.direction,
						}
					)
				)


func _market_cure() -> BrewedCup:
	# The cure of the market, section 6: one tall cup of the market dark
	# roast, from the beans of the Steamtle region.
	return _brew("golden_coast_arabica", "dark", "filter", "tall_size", 85.0)


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
