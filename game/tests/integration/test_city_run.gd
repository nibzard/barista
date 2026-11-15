# ABOUTME: Integration tests for the playable San Coffesco city run.
# ABOUTME: Proves the landmark set, the roster, the gates, and the completion flow.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const CITY_RUN_SCENE := preload("res://scenes/city/city_run.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const CITY_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600

# The deterministic spawn rule: the cafe block holds only the basic type,
# every later block cycles the roster, so the counts follow the densities.
const EXPECTED_CROWD_TOTAL := 24
const EXPECTED_NEIGHBORS := 10
const EXPECTED_TOURISTS := 7
const EXPECTED_TECH_BROS := 7

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready, so the area overlaps report
	# from the second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_city_loads_with_the_full_landmark_set() -> void:
	var map := _city.city_map()
	assert_int(map.block_count()).is_equal(7)
	var landmarks: Array[CityBlock.Kind] = [
		CityBlock.Kind.CAFE,
		CityBlock.Kind.TOWER,
		CityBlock.Kind.BOSS_ARENA,
		CityBlock.Kind.QUEST,
	]
	for kind: CityBlock.Kind in landmarks:
		(
			assert_object(map.find_block_of_kind(kind))
			. override_failure_message(CityRules.kind_name(kind))
			. is_not_null()
		)
	assert_int(map.block_view(0).kind()).is_equal(CityBlock.Kind.CAFE)
	assert_int(map.block_view(map.block_count() - 1).kind()).is_equal(CityBlock.Kind.TOWER)


func test_the_crowd_spawns_the_roster_at_full_density() -> void:
	assert_int(_city.crowd_count()).is_equal(EXPECTED_CROWD_TOTAL)
	var counts := {"neighbor": 0, "tourist": 0, "tech_bro": 0}
	for i: int in range(_city.crowd_count()):
		var enemy := _city.crowd_enemy(i)
		assert_bool(enemy.is_awake()).is_false()
		counts[enemy.enemy_type.type_id] += 1
	assert_int(counts["neighbor"]).is_equal(EXPECTED_NEIGHBORS)
	assert_int(counts["tourist"]).is_equal(EXPECTED_TOURISTS)
	assert_int(counts["tech_bro"]).is_equal(EXPECTED_TECH_BROS)
	# The cafe block teaches the basic throw: only neighbors stand there.
	for i: int in range(3):
		assert_str(_city.crowd_enemy(i).enemy_type.type_id).is_equal("neighbor")


func test_the_player_starts_inside_the_cafe_safe_zone() -> void:
	var map := _city.city_map()
	assert_vector(_city.player.global_position).is_equal(map.cafe_spawn().global_position)
	var safe_zone := map.find_block_of_kind(CityBlock.Kind.CAFE).safe_zone()
	assert_object(safe_zone).is_not_null()
	assert_bool(safe_zone.has_player_inside()).is_true()


func test_the_hud_binds_to_the_city_player() -> void:
	assert_object(_city.hud.player).is_equal(_city.player)
	assert_str(_city.hud.awake_value.text).is_equal("100/100")


func test_the_free_refill_flows_inside_the_cafe_safe_zone() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	player.global_position = _city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(_city.refill_player_supply()).is_equal(player.supply_balance.base_carry_limit)
	assert_int(player.coffee_supply.cups).is_equal(player.supply_balance.base_carry_limit)


func test_the_refill_stays_a_cafe_privilege() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	player.global_position = _tower().global_position
	# The area overlap report follows the move one step behind.
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(_city.refill_player_supply()).is_equal(0)
	assert_int(player.coffee_supply.cups).is_equal(0)


func test_one_fuse_waits_at_the_foot_of_the_tower() -> void:
	var tower_block := _city.city_map().find_block_of_kind(CityBlock.Kind.TOWER)
	assert_object(tower_block.tower_fuse_point()).is_not_null()
	assert_int(tower_block.tower_fuse_point().remaining_amount(FUSE_ITEM)).is_equal(1)


func test_the_tower_switch_beat_runs_without_completing_the_city() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.wake_ups.register_sleep()
	assert_int(player.wake_ups.remaining).is_equal(4)

	player.pickup_item(FUSE_ITEM, 1)
	var tower := _tower()
	assert_bool(tower.insert_fuse(player)).is_true()
	assert_bool(tower.switch_off()).is_true()

	assert_bool(_city.progress.is_tower_off()).is_true()
	assert_bool(_city.is_city_complete()).is_false()
	# Section 14: the switch restores 1 wake-up, up to the maximum.
	assert_int(player.wake_ups.remaining).is_equal(5)

	var frames := 0
	while not _city.hud.is_toast_visible() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_str(_city.hud.toast_message()).is_equal(CityRun.WAKE_UP_RESTORED_TEXT)


func test_the_boss_cure_after_the_tower_completes_the_city() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.pickup_item(FUSE_ITEM, 1)
	var tower := _tower()
	tower.insert_fuse(player)
	tower.switch_off()

	var completions: Array[int] = []
	_city.city_completed.connect(func() -> void: completions.append(1))
	_city.notify_boss_cured()

	assert_bool(_city.is_city_complete()).is_true()
	assert_int(completions.size()).is_equal(1)
	assert_str(_city.status_label.text).is_equal(
		CityRun.CITY_COMPLETE_TEXT % ["San Coffesco", "Sam Oatman"]
	)
	assert_bool(_city.status_label.visible).is_true()
	# The city stays open after the completion: no restart, the road goes on.
	assert_bool(_city.restart_button.visible).is_false()


func test_waking_every_sleepwalker_no_longer_wins_the_city() -> void:
	_wake_the_crowd()
	assert_bool(_city.is_city_complete()).is_false()
	assert_bool(_city.status_label.visible).is_false()


func test_a_sleep_returns_the_player_to_the_cafe_spawn() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.global_position = _tower().global_position
	var start_wake_ups: int = player.wake_ups.remaining

	player.sleep_meter.drain(200.0)
	await get_tree().physics_frame

	assert_int(player.wake_ups.remaining).is_equal(start_wake_ups - 1)
	assert_vector(player.global_position).is_equal(_city.city_map().cafe_spawn().global_position)
	assert_bool(player.is_asleep()).is_false()


func test_full_death_shows_the_end_screen() -> void:
	_wake_the_crowd()
	_city.player.wake_ups.remaining = 0
	_city.player.sleep_meter.drain(200.0)
	await get_tree().physics_frame

	assert_bool(_city.player.is_asleep()).is_true()
	assert_str(_city.status_label.text).is_equal(CityRun.DEATH_TEXT)
	assert_bool(_city.restart_button.visible).is_true()


func test_the_locked_bridge_blocks_the_road_east() -> void:
	_wake_the_crowd()
	var player := _city.player
	var map := _city.city_map()
	var gate := _city.bridge_gate()
	assert_bool(gate.is_open()).is_false()

	player.global_position = Vector2(map.city_size().x - 60.0, map.city_size().y * 0.5)
	await get_tree().physics_frame
	Input.action_press(&"move_right")
	var frames := 0
	while frames < 120:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_right")

	# The barrier stopped the walk west of the gate and spoke its one line.
	assert_float(player.global_position.x).is_less(gate.global_position.x - 10.0)
	assert_bool(_city.hud.is_toast_visible()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(CityRun.PAYWALL_TEXT)


func test_one_unlock_opens_the_bridge_and_the_road_east() -> void:
	_wake_the_crowd()
	var player := _city.player
	var map := _city.city_map()
	var gate := _city.bridge_gate()

	player.global_position = Vector2(map.city_size().x - 60.0, map.city_size().y * 0.5)
	await get_tree().physics_frame

	assert_bool(_city.unlock_state.unlock()).is_true()
	await get_tree().physics_frame
	assert_bool(gate.is_open()).is_true()

	Input.action_press(&"move_right")
	var frames := 0
	while player.global_position.x < gate.global_position.x + 40.0 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_right")

	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_float(player.global_position.x).is_greater(gate.global_position.x)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.ROAD_OPEN_TEXT)


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _tower() -> BroadcastTower:
	return _city.city_map().broadcast_tower()


func _build_raw_run() -> CityRun:
	# A run without an east scene: the road-east signal stays observable and
	# no scene change fires during the test.
	var run := CITY_RUN_SCENE.instantiate() as CityRun
	run.definition = CITY_DEFINITION
	run.balance = CITY_BALANCE
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame
	return run


func _complete_the_city(run: CityRun) -> void:
	run.player.pickup_item(FUSE_ITEM, 1)
	var tower := run.city_map().broadcast_tower()
	tower.insert_fuse(run.player)
	tower.switch_off()
	run.notify_boss_cured()


func test_san_coffesco_names_steamtle_as_the_city_east() -> void:
	# T028: San Coffesco completes and the road east travels to Steamtle. The
	# wired scene is a Steamtle run: city 2 on the route, arrived with the van.
	assert_object(_city.east_city_scene).is_not_null()
	var east := auto_free(_city.east_city_scene.instantiate()) as CityRun
	assert_object(east).is_not_null()
	assert_str(east.definition.city_id).is_equal("steamtle")
	assert_int(east.city_index).is_equal(2)


func test_the_road_east_stays_closed_before_completion() -> void:
	var run := await _build_raw_run()
	var arrivals: Array[int] = []
	run.east_road_taken.connect(func() -> void: arrivals.append(1))
	var road := run.road_east()
	assert_object(road).is_not_null()
	assert_bool(run.road_east_active()).is_false()

	# The player stands on the deck end with the gate open; nothing travels.
	run.unlock_state.unlock()
	run.player.global_position = road.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(arrivals.size()).is_equal(0)
	assert_bool(run.road_east_active()).is_false()


func test_the_completed_city_opens_the_road_east() -> void:
	var run := await _build_raw_run()
	assert_bool(run.road_east_active()).is_false()
	_complete_the_city(run)
	# The monitoring flip is deferred to the end of the completion frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(run.is_city_complete()).is_true()
	assert_bool(run.road_east_active()).is_true()


func test_the_road_east_carries_the_player_to_the_next_city() -> void:
	var run := await _build_raw_run()
	var arrivals: Array[int] = []
	run.east_road_taken.connect(func() -> void: arrivals.append(1))
	_complete_the_city(run)
	await get_tree().physics_frame
	await get_tree().physics_frame

	run.player.global_position = run.road_east().global_position
	var frames := 0
	while arrivals.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(arrivals.size()).is_equal(1)
