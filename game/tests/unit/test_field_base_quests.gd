# ABOUTME: Unit tests for the pure rules of the field base side quests.
# ABOUTME: T091: gathered survivors give a small side quest, section 10.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/field_base_quest.tres")
const DEFINITION := preload("res://resources/quests/side/field_kitchen_stock.tres")
const HOUSE_BEANS := preload("res://resources/items/beans/house.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const MAIN_ROUTE := preload("res://resources/quests/main_route.tres")


func test_the_tres_pins_the_quest_content() -> void:
	# The shipped numbers and items of the round, section 10 and section 15.
	assert_int(BALANCE.min_gathered_survivors).is_equal(1)
	assert_int(BALANCE.beans_goal).is_equal(3)
	assert_int(BALANCE.reward_scrap_parts).is_equal(1)
	assert_str(BALANCE.bean_item.item_id).is_equal("house")
	assert_str(BALANCE.reward_item.item_id).is_equal("scrap_part")
	# The quest definition names no city and no site: the field base moves
	# with the van, so no marker draws anywhere.
	assert_str(DEFINITION.quest_id).is_equal("field_kitchen_stock")
	assert_str(DEFINITION.title).is_equal("The Field Kitchen Stock")
	assert_str(DEFINITION.city_id).is_empty()
	assert_str(DEFINITION.site_name).is_empty()


func test_register_adds_the_round_to_the_log_once() -> void:
	var board := _make_board()
	var log := QuestLog.new()

	assert_bool(board.register(log)).is_true()
	var quest := log.quest("field_kitchen_stock")
	assert_object(quest).is_not_null()
	assert_bool(quest.is_offered()).is_true()
	assert_bool(board.register(log)).is_false()
	assert_int(log.quest_count()).is_equal(1)


func test_no_ask_below_the_gathered_minimum() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)

	board.poll(log, BALANCE.min_gathered_survivors - 1, true)

	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.QUIET)
	assert_bool(board.is_asking()).is_false()


func test_no_ask_while_the_field_base_is_closed() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)

	board.poll(log, BALANCE.min_gathered_survivors, false)

	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.QUIET)


func test_the_survivors_ask_when_the_tables_fill() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	var phases: Array = []
	board.phase_changed.connect(func(new_phase: int) -> void: phases.append(new_phase))

	board.poll(log, BALANCE.min_gathered_survivors, true)

	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.ASKING)
	assert_bool(board.is_asking()).is_true()
	assert_int(phases.size()).is_equal(1)
	assert_int(phases[0]).is_equal(FieldBaseQuests.Phase.ASKING)


func test_packing_the_base_withdraws_the_ask() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)
	assert_bool(board.is_asking()).is_true()

	board.poll(log, 0, false)

	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.QUIET)
	# The quest log keeps the quest offered: only the ask at the tables
	# withdrew, and the next open base asks again.
	assert_bool(log.quest("field_kitchen_stock").is_offered()).is_true()


func test_accept_needs_the_ask() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)

	assert_bool(board.try_accept(log, BALANCE.min_gathered_survivors, false)).is_false()
	assert_bool(board.try_accept(log, BALANCE.min_gathered_survivors - 1, true)).is_false()
	assert_bool(log.quest("field_kitchen_stock").is_offered()).is_true()
	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.QUIET)


func test_accept_moves_the_quest_to_active() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)

	assert_bool(board.try_accept(log, BALANCE.min_gathered_survivors, true)).is_true()

	assert_bool(log.is_active("field_kitchen_stock")).is_true()
	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.ACTIVE)


func test_deliver_needs_the_open_base() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)
	board.try_accept(log, BALANCE.min_gathered_survivors, true)
	var bag := _bag_with_beans(BALANCE.beans_goal)

	assert_bool(board.try_deliver(log, bag, false)).is_false()

	assert_bool(log.is_active("field_kitchen_stock")).is_true()
	assert_int(bag.count("house")).is_equal(BALANCE.beans_goal)


func test_deliver_with_too_few_beans_refuses_and_burns_nothing() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)
	board.try_accept(log, BALANCE.min_gathered_survivors, true)
	var bag := _bag_with_beans(BALANCE.beans_goal - 1)

	assert_bool(board.try_deliver(log, bag, true)).is_false()

	assert_bool(log.is_active("field_kitchen_stock")).is_true()
	assert_int(bag.count("house")).is_equal(BALANCE.beans_goal - 1)
	assert_int(bag.count("scrap_part")).is_equal(0)


func test_deliver_trades_beans_for_scrap_and_completes() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)
	board.try_accept(log, BALANCE.min_gathered_survivors, true)
	var bag := _bag_with_beans(BALANCE.beans_goal)

	assert_bool(board.try_deliver(log, bag, true)).is_true()

	assert_int(bag.count("house")).is_equal(0)
	assert_int(bag.count("scrap_part")).is_equal(BALANCE.reward_scrap_parts)
	assert_bool(log.quest("field_kitchen_stock").is_complete()).is_true()
	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.DONE)


func test_deliver_answers_only_once() -> void:
	var board := _make_board()
	var log := _make_registered_log(board)
	board.poll(log, BALANCE.min_gathered_survivors, true)
	board.try_accept(log, BALANCE.min_gathered_survivors, true)
	var bag := _bag_with_beans(BALANCE.beans_goal * 2)
	board.try_deliver(log, bag, true)

	assert_bool(board.try_deliver(log, bag, true)).is_false()

	assert_int(bag.count("house")).is_equal(BALANCE.beans_goal)
	assert_int(bag.count("scrap_part")).is_equal(BALANCE.reward_scrap_parts)


func test_a_loaded_log_rebuilds_the_phase_without_a_new_ask() -> void:
	# The quest log save carries the state of the round. A fresh board reads
	# an active quest back as active, and never asks again.
	var first := _make_board()
	var first_log := _make_registered_log(first)
	first.poll(first_log, BALANCE.min_gathered_survivors, true)
	first.try_accept(first_log, BALANCE.min_gathered_survivors, true)
	var saved := first_log.save_state()

	var board := _make_board()
	var log := QuestLog.new()
	assert_bool(log.setup(MAIN_ROUTE, "san_coffesco")).is_true()
	board.register(log)
	log.load_state(saved)
	var phases: Array = []
	board.phase_changed.connect(func(new_phase: int) -> void: phases.append(new_phase))

	board.poll(log, BALANCE.min_gathered_survivors, true)

	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.ACTIVE)
	assert_int(phases.size()).is_equal(1)
	assert_int(phases[0]).is_equal(FieldBaseQuests.Phase.ACTIVE)


func test_a_duplicated_balance_drives_the_rules() -> void:
	# The rules read the balance, not the shipped numbers: a tuned copy with a
	# two-survivor minimum and a two-bean goal behaves by its own values.
	var tuned := FieldBaseQuestBalance.new()
	tuned.min_gathered_survivors = 2
	tuned.beans_goal = 2
	tuned.reward_scrap_parts = 5
	tuned.bean_item = HOUSE_BEANS
	tuned.reward_item = SCRAP_PART
	var board := FieldBaseQuests.new(tuned, DEFINITION)
	var log := _make_registered_log(board)

	board.poll(log, 1, true)
	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.QUIET)
	board.poll(log, 2, true)
	assert_int(board.phase()).is_equal(FieldBaseQuests.Phase.ASKING)
	board.try_accept(log, 2, true)
	var bag := _bag_with_beans(1)
	assert_bool(board.try_deliver(log, bag, true)).is_false()
	bag.add(HOUSE_BEANS, 1)
	assert_bool(board.try_deliver(log, bag, true)).is_true()
	assert_int(bag.count("scrap_part")).is_equal(5)


func _make_board() -> FieldBaseQuests:
	return FieldBaseQuests.new(BALANCE, DEFINITION)


func _make_registered_log(board: FieldBaseQuests) -> QuestLog:
	# The log of a live run: the shipped route plus the registered round.
	var log := QuestLog.new()
	log.setup(MAIN_ROUTE, "san_coffesco")
	board.register(log)
	return log


func _bag_with_beans(amount: int) -> Inventory:
	var bag := Inventory.new()
	bag.add(HOUSE_BEANS, amount)
	return bag
