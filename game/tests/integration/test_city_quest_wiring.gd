# ABOUTME: Integration tests for the quest wiring inside a live city run.
# ABOUTME: T032: the run feeds its beats to the quest log and the markers.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const CITY_RUN_SCENE := preload("res://scenes/city/city_run.tscn")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const CITY_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready, so the areas report from the
	# second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_run_carries_the_quest_chain_and_its_marker() -> void:
	# The run builds the quest log from the shipped route, and the marker
	# layer already points at the tower, section 19 step 7.
	assert_object(_city.quest_log).is_not_null()
	assert_str(_city.quest_log.main_quest.current_city()).is_equal("san_coffesco")
	# The three signature quests of the route plus the field base round that
	# the gathered survivors give, section 10.
	assert_int(_city.quest_log.quest_count()).is_equal(4)
	assert_bool(_city.quest_log.quest("field_kitchen_stock").is_offered()).is_true()
	var markers := _city.quest_markers()
	assert_object(markers).is_not_null()
	assert_bool(markers.has_objective_marker()).is_true()
	assert_vector(markers.objective_marker_position()).is_equal(
		_city.city_map().broadcast_tower().global_position
	)
	assert_str(markers.objective_marker_label()).is_equal("THE TOWER")


func test_the_tower_beat_moves_the_run_quest_objective() -> void:
	_wake_the_crowd()
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	tower.insert_fuse(_city.player)
	tower.switch_off()

	assert_int(_city.quest_log.current_objective()).is_equal(MainQuest.Objective.BOSS)
	var arena := _city.city_map().find_block_of_kind(CityBlock.Kind.BOSS_ARENA)
	assert_vector(_city.quest_markers().objective_marker_position()).is_equal(
		arena.global_position + arena.size * 0.5
	)


func test_the_completed_city_unlocks_the_next_one_in_the_log() -> void:
	var run := await _build_raw_run()
	assert_bool(run.quest_log.main_quest.is_city_unlocked("steamtle")).is_false()

	_complete_the_city(run)
	assert_bool(run.quest_log.main_quest.is_city_complete("san_coffesco")).is_true()
	assert_bool(run.quest_log.main_quest.is_city_unlocked("steamtle")).is_true()
	assert_int(run.quest_log.current_objective()).is_equal(MainQuest.Objective.ROAD_EAST)

	# The road-east beat hands the chain to the next city. The monitoring flip
	# is deferred to the end of the completion frame, so the player steps on
	# the trigger only after it lands.
	await get_tree().physics_frame
	await get_tree().physics_frame
	run.player.global_position = run.road_east().global_position
	var frames := 0
	while run.quest_log.main_quest.current_city() != "steamtle" and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(run.quest_log.main_quest.current_city()).is_equal("steamtle")


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


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
