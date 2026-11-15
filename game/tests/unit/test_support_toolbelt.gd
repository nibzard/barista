# ABOUTME: Unit tests for the SupportToolbelt: unlock, cycle, cooldowns, parry window.
# ABOUTME: Pure logic: the clocks tick by hand, so no scene tree is needed.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/support_tools.tres")


func _belt() -> SupportToolbelt:
	return SupportToolbelt.new(BALANCE)


func test_the_balance_pins_the_section_11_and_14_numbers() -> void:
	# The parry rules come from section 14; the rest are the working numbers
	# of the prototype, pinned like every other balance resource.
	assert_bool(BALANCE is SupportToolsBalance).is_true()
	assert_float(BALANCE.tamper_reach).is_equal(60.0)
	assert_float(BALANCE.tamper_stagger_seconds).is_equal(1.2)
	assert_float(BALANCE.tamper_push_speed).is_equal(260.0)
	assert_float(BALANCE.tamper_push_seconds).is_equal(0.18)
	assert_float(BALANCE.tamper_cooldown_seconds).is_equal(0.5)
	assert_float(BALANCE.steam_wand_reach).is_equal(90.0)
	assert_float(BALANCE.steam_wand_half_angle_degrees).is_equal(45.0)
	assert_float(BALANCE.steam_wand_stagger_seconds).is_equal(0.8)
	assert_float(BALANCE.steam_wand_cooldown_seconds).is_equal(0.6)
	assert_float(BALANCE.parry_window_seconds).is_equal(0.3)
	assert_float(BALANCE.parry_stagger_seconds).is_equal(3.0)
	assert_float(BALANCE.portafilter_block_stagger_seconds).is_equal(0.5)
	assert_float(BALANCE.portafilter_block_push_speed).is_equal(180.0)
	assert_float(BALANCE.portafilter_block_push_seconds).is_equal(0.15)
	assert_float(BALANCE.portafilter_bash_reach).is_equal(70.0)
	assert_float(BALANCE.portafilter_bash_half_angle_degrees).is_equal(60.0)
	assert_float(BALANCE.portafilter_bash_stagger_seconds).is_equal(1.5)
	assert_float(BALANCE.portafilter_bash_push_speed).is_equal(300.0)
	assert_float(BALANCE.portafilter_bash_push_seconds).is_equal(0.2)
	assert_float(BALANCE.portafilter_bash_cooldown_seconds).is_equal(0.7)
	assert_float(BALANCE.sprayer_reach).is_equal(130.0)
	assert_float(BALANCE.sprayer_half_angle_degrees).is_equal(35.0)
	assert_float(BALANCE.brain_freeze_seconds).is_equal(2.5)
	assert_float(BALANCE.brain_freeze_speed_factor).is_equal(0.45)
	assert_float(BALANCE.sprayer_cooldown_seconds).is_equal(0.4)
	assert_float(BALANCE.bean_slick_radius).is_equal(34.0)
	assert_float(BALANCE.bean_slick_lifetime_seconds).is_equal(8.0)
	assert_float(BALANCE.bean_slick_cooldown_seconds).is_equal(1.2)
	assert_float(BALANCE.slip_slide_speed).is_equal(220.0)
	assert_float(BALANCE.slip_slide_seconds).is_equal(0.25)
	assert_float(BALANCE.slip_down_seconds).is_equal(1.0)
	# The parried hug stagger lasts far longer than the wand's plain hit.
	assert_float(BALANCE.parry_stagger_seconds).is_greater(BALANCE.steam_wand_stagger_seconds)
	# Brain freeze slows: the factor sits clearly below full speed.
	assert_float(BALANCE.brain_freeze_speed_factor).is_between(0.0, 1.0)


func test_a_fresh_belt_is_empty() -> void:
	var belt := _belt()
	assert_bool(belt.has_any()).is_false()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.NO_TOOL)
	assert_bool(belt.cycle()).is_false()
	assert_bool(belt.equip(SupportToolbelt.Tool.TAMPER)).is_false()


func test_the_first_find_equips_itself() -> void:
	var belt := _belt()
	belt.unlock(SupportToolbelt.Tool.ICED_SPRAYER)
	assert_bool(belt.has_any()).is_true()
	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.ICED_SPRAYER)).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.ICED_SPRAYER)


func test_unlocking_the_same_tool_twice_changes_nothing() -> void:
	var belt := _belt()
	belt.unlock(SupportToolbelt.Tool.TAMPER)
	belt.unlock(SupportToolbelt.Tool.TAMPER)
	assert_int(belt.unlocked_tools().size()).is_equal(1)
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)


func test_the_cycle_walks_the_found_tools_in_order() -> void:
	var belt := _belt()
	belt.unlock(SupportToolbelt.Tool.TAMPER)
	belt.unlock(SupportToolbelt.Tool.PORTAFILTER)
	belt.unlock(SupportToolbelt.Tool.BEAN_SLICK)

	assert_bool(belt.cycle()).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.PORTAFILTER)
	assert_bool(belt.cycle()).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.BEAN_SLICK)
	# The swap wraps around to the first found tool.
	assert_bool(belt.cycle()).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)


func test_equip_swaps_to_any_found_tool() -> void:
	var belt := _belt()
	belt.unlock_all()
	assert_bool(belt.equip(SupportToolbelt.Tool.ICED_SPRAYER)).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.ICED_SPRAYER)


func test_a_cooldown_blocks_the_tool_until_it_ticks_away() -> void:
	var belt := _belt()
	belt.unlock(SupportToolbelt.Tool.TAMPER)
	belt.start_cooldown(SupportToolbelt.Tool.TAMPER)
	assert_bool(belt.is_on_cooldown(SupportToolbelt.Tool.TAMPER)).is_true()

	belt.tick(BALANCE.tamper_cooldown_seconds * 0.9)
	assert_bool(belt.is_on_cooldown(SupportToolbelt.Tool.TAMPER)).is_true()
	belt.tick(BALANCE.tamper_cooldown_seconds * 0.2)
	assert_bool(belt.is_on_cooldown(SupportToolbelt.Tool.TAMPER)).is_false()
	# The clock clamps at zero, never below.
	assert_float(belt.cooldown_time_left(SupportToolbelt.Tool.TAMPER)).is_equal(0.0)


func test_each_tool_carries_its_own_cooldown() -> void:
	var belt := _belt()
	belt.unlock_all()
	belt.start_cooldown(SupportToolbelt.Tool.TAMPER)
	assert_bool(belt.is_on_cooldown(SupportToolbelt.Tool.STEAM_WAND)).is_false()
	assert_bool(belt.is_on_cooldown(SupportToolbelt.Tool.BEAN_SLICK)).is_false()


func test_the_parry_window_lasts_the_balanced_time() -> void:
	var belt := _belt()
	assert_bool(belt.is_parrying()).is_false()
	belt.open_parry_window()
	assert_bool(belt.is_parrying()).is_true()
	assert_float(belt.parry_time_left()).is_equal(BALANCE.parry_window_seconds)

	# Section 14 pins the window at 0.3 seconds.
	belt.tick(0.29)
	assert_bool(belt.is_parrying()).is_true()
	belt.tick(0.02)
	assert_bool(belt.is_parrying()).is_false()


func test_the_parry_window_closes_in_one_tick_at_the_limit() -> void:
	var belt := _belt()
	belt.open_parry_window()
	belt.tick(BALANCE.parry_window_seconds)
	assert_bool(belt.is_parrying()).is_false()


func test_a_parry_spends_the_window() -> void:
	var belt := _belt()
	belt.open_parry_window()
	assert_bool(belt.consume_parry()).is_true()
	assert_bool(belt.is_parrying()).is_false()
	# One swing stops one hug: the second call has no window left.
	assert_bool(belt.consume_parry()).is_false()


func test_consume_parry_fails_while_the_window_is_shut() -> void:
	var belt := _belt()
	assert_bool(belt.consume_parry()).is_false()


func test_a_new_parry_window_reopens_after_a_spend() -> void:
	var belt := _belt()
	belt.open_parry_window()
	assert_bool(belt.consume_parry()).is_true()
	belt.open_parry_window()
	assert_bool(belt.is_parrying()).is_true()
