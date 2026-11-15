# ABOUTME: Unit tests for the pure SleepvanaQuest state machine, section 13.
# ABOUTME: Proves the member wakes, the crowd condition, the encore window,
# ABOUTME: the frontman rule, and the save round trip.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/sleepvana.tres")

var _signals: Array[String] = []


func before_test() -> void:
	# GdUnit reuses one suite instance for every test case, so the recorder
	# resets here, not in the member declaration.
	_signals.clear()


func test_the_balance_pins_the_show_values() -> void:
	# Section 13: a full crowd of five fans, a short encore window, and a wake
	# event that reaches past the garage block into the hearing range.
	assert_int(BALANCE.crowd_size).is_equal(5)
	assert_float(BALANCE.garage_arrival_radius).is_equal(180.0)
	assert_float(BALANCE.encore_seconds).is_equal(12.0)
	assert_float(BALANCE.concert_wake_radius).is_equal(1000.0)
	assert_float(BALANCE.concert_wake_radius).is_greater(BALANCE.garage_arrival_radius)


func test_the_quest_starts_with_the_band_asleep() -> void:
	var quest := SleepvanaQuest.new(BALANCE)
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)
	assert_int(quest.members_awake_count()).is_equal(0)
	assert_bool(quest.is_band_ready()).is_false()
	assert_bool(quest.accepts_frontman_cup()).is_false()
	assert_bool(quest.is_concert_done()).is_false()


func test_each_member_wakes_once_at_his_site() -> void:
	var quest := _recorder()
	assert_bool(quest.record_member_wake(0)).is_true()
	assert_bool(quest.record_member_wake(0)).is_false()
	assert_bool(quest.record_member_wake(-1)).is_false()
	assert_bool(quest.record_member_wake(SleepvanaQuest.MEMBER_COUNT)).is_false()
	assert_int(quest.members_awake_count()).is_equal(1)
	assert_str(_signals[0]).is_equal("member_woke:0")
	assert_int(_signals.size()).is_equal(1)


func test_the_third_member_arms_the_crowd_stage() -> void:
	# The three simple orders wake the three members, in any site order, and
	# the last wake arms the crowd stage exactly once.
	var quest := _recorder()
	quest.record_member_wake(2)
	quest.record_member_wake(0)
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)
	quest.record_member_wake(1)
	assert_bool(quest.is_band_ready()).is_true()
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)
	assert_str(_signals[3]).is_equal("band_ready")
	assert_int(_signals.count("band_ready")).is_equal(1)


func test_no_crowd_recruit_before_the_band_is_ready() -> void:
	var quest := SleepvanaQuest.new(BALANCE)
	assert_bool(quest.recruit_crowd(BALANCE.crowd_size)).is_false()
	assert_bool(quest.is_crowd_recruited()).is_false()


func test_the_crowd_recruit_needs_a_full_field_cafe() -> void:
	# The crowd-gather condition: one fan short of the crowd size is too
	# small, the full crowd joins the walk to the garage.
	var quest := _recorder()
	_wake_the_band(quest)
	assert_bool(quest.recruit_crowd(BALANCE.crowd_size - 1)).is_false()
	assert_bool(quest.is_crowd_recruited()).is_false()
	assert_bool(quest.recruit_crowd(BALANCE.crowd_size)).is_true()
	assert_bool(quest.is_crowd_recruited()).is_true()
	assert_str(_signals[4]).is_equal("crowd_recruited:%d" % BALANCE.crowd_size)


func test_the_crowd_arrives_only_after_the_recruit() -> void:
	var quest := _wake_the_band(SleepvanaQuest.new(BALANCE))
	assert_bool(quest.crowd_arrived(BALANCE.crowd_size + 3)).is_false()
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)


func test_the_crowd_arrival_needs_the_full_crowd_at_the_garage() -> void:
	var quest := _recruited_quest()
	assert_bool(quest.crowd_arrived(BALANCE.crowd_size - 1)).is_false()
	assert_bool(quest.crowd_arrived(BALANCE.crowd_size)).is_true()
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)
	assert_str(_signals[_signals.size() - 1]).is_equal("encore_began")


func test_the_encore_opens_its_window() -> void:
	var quest := _recruited_quest()
	quest.crowd_arrived(BALANCE.crowd_size)
	assert_float(quest.encore_time_left()).is_equal(BALANCE.encore_seconds)
	assert_bool(quest.accepts_frontman_cup()).is_true()


func test_the_encore_window_runs_out() -> void:
	# A missed encore sends the crowd home: the player gathers a new crowd at
	# the field cafe, and the next arrival re-arms the encore.
	var quest := _recruited_quest()
	quest.crowd_arrived(BALANCE.crowd_size)
	quest.tick(BALANCE.encore_seconds)
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)
	assert_bool(quest.is_crowd_recruited()).is_false()
	assert_bool(quest.accepts_frontman_cup()).is_false()
	assert_str(_signals[_signals.size() - 1]).is_equal("encore_missed")

	# The regather works: the crowd joins again and the encore re-arms.
	assert_bool(quest.recruit_crowd(BALANCE.crowd_size)).is_true()
	assert_bool(quest.crowd_arrived(BALANCE.crowd_size)).is_true()
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)


func test_the_encore_window_ticks_down() -> void:
	var quest := _recruited_quest()
	quest.crowd_arrived(BALANCE.crowd_size)
	quest.tick(BALANCE.encore_seconds - 1.0)
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)
	assert_float(quest.encore_time_left()).is_equal(1.0)
	quest.tick(2.0)
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)


func test_the_frontman_wakes_only_during_the_encore() -> void:
	# The frontman rule, section 13: no wake before the band, no wake in the
	# crowd stage without the encore, and no second wake after the concert.
	var quest := _recruited_quest()
	assert_bool(quest.wake_the_frontman()).is_false()
	quest.crowd_arrived(BALANCE.crowd_size)
	assert_bool(quest.wake_the_frontman()).is_true()
	assert_bool(quest.is_concert_done()).is_true()
	assert_bool(quest.wake_the_frontman()).is_false()
	assert_bool(quest.accepts_frontman_cup()).is_false()


func test_a_woken_member_stays_woken_after_the_concert() -> void:
	# The concert ends the quest, but a late member wake record changes
	# nothing anymore.
	var quest := _recruited_quest()
	quest.crowd_arrived(BALANCE.crowd_size)
	quest.wake_the_frontman()
	assert_bool(quest.record_member_wake(0)).is_false()


func test_save_round_trip_mid_quest() -> void:
	var quest := _recorder()
	quest.record_member_wake(1)
	quest.record_member_wake(2)

	var loaded := SleepvanaQuest.new(BALANCE)
	loaded.load_state(quest.save_state())
	assert_int(loaded.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)
	assert_int(loaded.members_awake_count()).is_equal(2)
	# A loaded quest never replays a beat.
	assert_int(_signals.size()).is_equal(2)


func test_load_rejects_unknown_values() -> void:
	var quest := SleepvanaQuest.new(BALANCE)
	quest.load_state({"phase": 99, "woke_sites": [0, 0, 7, -2]})
	assert_int(quest.phase()).is_equal(SleepvanaQuest.Phase.BAND_ASLEEP)
	assert_int(quest.members_awake_count()).is_equal(1)


func test_load_keeps_a_finished_concert() -> void:
	var quest := _recruited_quest()
	quest.crowd_arrived(BALANCE.crowd_size)
	quest.wake_the_frontman()

	var loaded := SleepvanaQuest.new(BALANCE)
	loaded.load_state(quest.save_state())
	assert_bool(loaded.is_concert_done()).is_true()
	assert_bool(loaded.is_band_ready()).is_true()


func test_a_duplicated_balance_drives_the_rules() -> void:
	# The rules read the balance, never their own copy of the numbers.
	var small := SleepvanaBalance.new()
	small.crowd_size = 2
	small.garage_arrival_radius = 90.0
	small.encore_seconds = 3.0
	small.concert_wake_radius = 400.0
	var quest := SleepvanaQuest.new(small)
	_wake_the_band(quest)
	assert_bool(quest.recruit_crowd(1)).is_false()
	assert_bool(quest.recruit_crowd(2)).is_true()
	quest.crowd_arrived(2)
	assert_float(quest.encore_time_left()).is_equal(3.0)


func _recorder() -> SleepvanaQuest:
	# A quest that records every beat into _signals.
	var quest := SleepvanaQuest.new(BALANCE)
	quest.member_woke.connect(func(site: int) -> void: _signals.append("member_woke:%d" % site))
	quest.band_ready.connect(func() -> void: _signals.append("band_ready"))
	quest.crowd_recruited.connect(
		func(fans: int) -> void: _signals.append("crowd_recruited:%d" % fans)
	)
	quest.encore_began.connect(func() -> void: _signals.append("encore_began"))
	quest.encore_missed.connect(func() -> void: _signals.append("encore_missed"))
	quest.frontman_woke.connect(func() -> void: _signals.append("frontman_woke"))
	return quest


func _wake_the_band(quest: SleepvanaQuest) -> SleepvanaQuest:
	for site: int in range(SleepvanaQuest.MEMBER_COUNT):
		quest.record_member_wake(site)
	return quest


func _recruited_quest() -> SleepvanaQuest:
	var quest := _recorder()
	_wake_the_band(quest)
	quest.recruit_crowd(BALANCE.crowd_size)
	return quest
