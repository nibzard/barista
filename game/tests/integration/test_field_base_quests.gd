# ABOUTME: Integration tests for the field base side quests in the city run.
# ABOUTME: T091: gathered survivors offer a small side quest, section 10.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")

const QUEST_ID := "field_kitchen_stock"
const MAX_FRAMES_TO_WAIT := 600

var _city: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready. A cold-start suite reports area
	# overlaps from the third physics step onward, so settle before the cases.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func test_the_run_carries_the_field_base_round_quest() -> void:
	# The giver rides every city run, and the round sits in the quest log
	# beside the signature quests of the route.
	assert_object(_city.field_base_quests).is_not_null()
	assert_object(_city.field_base_quests.quests).is_not_null()
	var quest := _city.quest_log.quest(QUEST_ID)
	assert_object(quest).is_not_null()
	assert_bool(quest.is_offered()).is_true()
	assert_int(_city.field_base_quests.quests.phase()).is_equal(FieldBaseQuests.Phase.QUIET)
	assert_bool(_city.field_base_quests.is_ask_visible()).is_false()


func test_no_ask_while_the_field_base_is_closed() -> void:
	await _own_the_van(false)
	_city.player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)

	# An awakened survivor stands beside the parked van, but the field base
	# stays closed, so nobody takes a table and nobody asks.
	var survivor := _city.crowd_enemy(6)
	survivor.wake_up()
	survivor.global_position = _city.van().global_position + Vector2(60.0, 0.0)
	for _i: int in range(10):
		await get_tree().physics_frame

	assert_bool(_city.van().is_field_base_open()).is_false()
	assert_int(_city.field_base_quests.quests.phase()).is_equal(FieldBaseQuests.Phase.QUIET)


func test_no_ask_with_nobody_gathered() -> void:
	await _own_the_van(false)
	_city.player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()
	assert_bool(_city.call_van()).is_true()

	# The field base is open, but the whole crowd sleeps: no survivor gathers,
	# so no one asks, section 10.
	for _i: int in range(10):
		await get_tree().physics_frame

	assert_int(_city.van().gathered_survivors().size()).is_equal(0)
	assert_int(_city.field_base_quests.quests.phase()).is_equal(FieldBaseQuests.Phase.QUIET)


func test_gathered_survivors_ask_at_the_level_three_field_base() -> void:
	await _gathered_field_base_with_one_survivor()

	# The ask of section 10: an awakened survivor at the field base tables
	# offers a small side quest. The quest log keeps it offered until the
	# player answers.
	var giver := _city.field_base_quests
	assert_int(giver.quests.phase()).is_equal(FieldBaseQuests.Phase.ASKING)
	assert_bool(giver.is_ask_visible()).is_true()
	assert_str(giver.ask_line()).is_equal(FieldBaseQuestGiver.ASK_LINE)
	assert_str(_city.hud.toast_message()).is_equal(
		FieldBaseQuestGiver.OFFER_TOAST % giver.quests.beans_goal()
	)
	assert_bool(_city.quest_log.quest(QUEST_ID).is_offered()).is_true()


func test_the_interact_at_the_van_accepts_the_round() -> void:
	await _gathered_field_base_with_one_survivor()
	assert_bool(_city.van().is_player_at_van()).is_true()

	assert_bool(_city.field_base_quests.try_interact(_city.player)).is_true()

	assert_bool(_city.quest_log.is_active(QUEST_ID)).is_true()
	assert_int(_city.field_base_quests.quests.phase()).is_equal(FieldBaseQuests.Phase.ACTIVE)
	assert_str(_city.hud.toast_message()).is_equal(
		FieldBaseQuestGiver.ACCEPT_TOAST % _city.field_base_quests.quests.beans_goal()
	)
	assert_bool(_city.field_base_quests.is_ask_visible()).is_false()


func test_the_real_interact_action_routes_the_round_accept() -> void:
	# The shared interact key, and with it the touch USE button, answers the
	# survivor: the run routes the press to the giver before the van.
	await _gathered_field_base_with_one_survivor()
	assert_bool(_city.van().is_player_at_van()).is_true()

	_fire_interact_action()
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.quest_log.is_active(QUEST_ID)).is_true()
	assert_bool(_city.van().is_field_base_open()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		FieldBaseQuestGiver.ACCEPT_TOAST % _city.field_base_quests.quests.beans_goal()
	)


func test_the_round_trades_beans_for_scrap_at_the_van() -> void:
	await _gathered_field_base_with_one_survivor()
	_city.field_base_quests.try_interact(_city.player)
	assert_bool(_city.quest_log.is_active(QUEST_ID)).is_true()

	# The bag still holds the scrap left over from the upgrades, so the trade
	# proves itself as the change in the bag.
	var scrap_before := _city.player.inventory.count("scrap_part")
	_city.player.pickup_item(HOUSE_BEANS, _city.field_base_quests.quests.beans_goal())
	assert_bool(_city.field_base_quests.try_interact(_city.player)).is_true()

	assert_int(_city.player.inventory.count("house")).is_equal(0)
	assert_int(_city.player.inventory.count("scrap_part")).is_equal(
		scrap_before + _city.field_base_quests.quests.reward_scrap_parts()
	)
	assert_bool(_city.quest_log.quest(QUEST_ID).is_complete()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		FieldBaseQuestGiver.DELIVER_TOAST % _city.field_base_quests.quests.reward_scrap_parts()
	)


func test_short_beans_leave_the_key_with_the_van() -> void:
	# The round is on, the bag is short, so the giver does not consume the
	# press: the van keeps its key and packs the field base. The round stays
	# active and the next open base takes the beans.
	await _gathered_field_base_with_one_survivor()
	_city.field_base_quests.try_interact(_city.player)
	assert_bool(_city.quest_log.is_active(QUEST_ID)).is_true()

	assert_bool(_city.field_base_quests.try_interact(_city.player)).is_false()
	_fire_interact_action()
	await get_tree().physics_frame
	await get_tree().physics_frame

	# The press fell through to the van: the field base packed, and the round
	# stays active for the next open base.
	assert_bool(_city.van().is_field_base_open()).is_false()
	assert_bool(_city.quest_log.is_active(QUEST_ID)).is_true()


func test_packing_the_base_withdraws_the_ask_until_the_next_open() -> void:
	await _gathered_field_base_with_one_survivor()
	assert_bool(_city.field_base_quests.quests.is_asking()).is_true()

	assert_int(_city.interact_with_van()).is_equal(MobileCafeVan.Interaction.PACKED_FIELD_BASE)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(_city.field_base_quests.quests.phase()).is_equal(FieldBaseQuests.Phase.QUIET)
	assert_bool(_city.field_base_quests.is_ask_visible()).is_false()

	# The next open base asks again: the quest log still holds the quest
	# offered, and the survivor takes a table again.
	assert_bool(_city.call_van()).is_true()
	var frames := 0
	while not _city.field_base_quests.quests.is_asking() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_str(_city.hud.toast_message()).is_equal(
		FieldBaseQuestGiver.OFFER_TOAST % _city.field_base_quests.quests.beans_goal()
	)


func _own_the_van(wake_crowd := true) -> void:
	# Walk the player up to the van so the survivors hand it over, then let the
	# overlap report settle. The gathering tests keep the crowd asleep.
	if wake_crowd:
		for i: int in range(_city.crowd_count()):
			_city.crowd_enemy(i).wake_up()
	_city.player.global_position = _city.van().global_position
	var frames := 0
	while not _city.van_state.is_owned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_city.van_state.is_owned()).is_true()


func _gathered_field_base_with_one_survivor() -> void:
	# Drive the live flow to the promise of section 10: the van reaches level
	# 3, parks where the player stands, and one awakened survivor takes a
	# table at the open field base. The player stays at the van.
	await _own_the_van(false)
	_city.player.pickup_item(SCRAP_PART, 99)
	_city.interact_with_van()
	_city.interact_with_van()
	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)

	var survivor := _city.crowd_enemy(6)
	_city.player.global_position = survivor.global_position + Vector2(-120.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.call_van()).is_true()

	survivor.wake_up()
	var frames := 0
	while _city.van().gathered_survivors().is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	# One more frame lets the giver poll the arrival and ask.
	await get_tree().physics_frame


func _fire_interact_action() -> void:
	# One synthesized press through the normal input pipeline, the same event
	# the touch USE button fires.
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = &"interact"
	release.pressed = false
	Input.parse_input_event(release)
