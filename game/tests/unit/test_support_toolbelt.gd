# ABOUTME: Unit tests for the SupportToolbelt: unlock, cycle, cooldowns, parry
# ABOUTME: window, the found-gear grant, and the route placement of section 11.
extends GdUnitTestSuite

const BALANCE := preload("res://resources/balance/support_tools.tres")
const ITEM_CATALOG := preload("res://resources/items/catalog.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")
const STEAMTLE := preload("res://resources/city/steamtle.tres")
const POURTLAND := preload("res://resources/city/pourtland.tres")

# Section 11, the route order: San Coffesco hands over the tamper and the
# steam wand, Steamtle the portafilter and the iced sprayer, Pourtland the
# bean slick.
const ROUTE_FINDS := {
	"san_coffesco": ["tamper", "steam_wand"],
	"steamtle": ["portafilter", "iced_sprayer"],
	"pourtland": ["bean_slick"],
}


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
	assert_str(TouchControls.tool_name_for(belt.equipped_tool())).is_equal("")
	assert_bool(belt.cycle()).is_false()
	assert_bool(belt.equip(SupportToolbelt.Tool.TAMPER)).is_false()


func test_the_first_find_equips_itself() -> void:
	var belt := _belt()
	belt.unlock(SupportToolbelt.Tool.ICED_SPRAYER)
	assert_bool(belt.has_any()).is_true()
	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.ICED_SPRAYER)).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.ICED_SPRAYER)
	assert_str(TouchControls.tool_name_for(belt.equipped_tool())).is_equal("Iced Sprayer")


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
	assert_str(TouchControls.tool_name_for(belt.equipped_tool())).is_equal("Portafilter")
	assert_bool(belt.cycle()).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.BEAN_SLICK)
	# The swap wraps around to the first found tool.
	assert_bool(belt.cycle()).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)
	assert_str(TouchControls.tool_name_for(belt.equipped_tool())).is_equal("Tamper")


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


func test_a_found_gear_item_unlocks_its_tool() -> void:
	# Section 11: a tool joins the belt through its gear item, like the cure
	# weapons. Gear that carries no tool changes nothing.
	var belt := _belt()
	assert_bool(belt.grant_item("tamper")).is_true()
	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.TAMPER)).is_true()
	# The first find equips itself.
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)
	# A later find unlocks without stealing the slot.
	assert_bool(belt.grant_item("bean_slick")).is_true()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)
	# A cure weapon and plain material carry no support tool.
	assert_bool(belt.grant_item("travel_mug")).is_false()
	assert_bool(belt.grant_item("scrap_part")).is_false()
	assert_int(belt.unlocked_tools().size()).is_equal(2)


func test_a_loaded_bag_restocks_the_belt() -> void:
	# Section 18: the tools ride the bag as gear, so a save or a move east
	# rebuilds the unlocked set from the loaded bag.
	var belt := _belt()
	var bag := Inventory.new()
	bag.add(ITEM_CATALOG.find_item("portafilter"), 1)
	bag.add(ITEM_CATALOG.find_item("iced_sprayer"), 1)
	bag.add(ITEM_CATALOG.find_item("fuse"), 3)

	belt.sync_unlocked_from_inventory(bag)

	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.PORTAFILTER)).is_true()
	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.ICED_SPRAYER)).is_true()
	assert_bool(belt.is_unlocked(SupportToolbelt.Tool.TAMPER)).is_false()
	assert_int(belt.equipped_tool()).is_equal(SupportToolbelt.Tool.PORTAFILTER)


func test_the_tool_gear_resolves_in_the_catalog() -> void:
	# The save resolves bag ids through the catalog, so a tool that misses
	# from it would vanish on reload. The interface name of a tool is the
	# display name of its gear item, so the readout and the bag row agree.
	for tool: SupportToolbelt.Tool in SupportToolbelt.CYCLE_ORDER:
		var item: ItemType = ITEM_CATALOG.find_item(SupportToolbelt.ITEM_IDS[tool])
		assert_object(item).is_not_null()
		assert_int(item.max_stack).is_equal(1)
		assert_int(item.category).is_equal(ItemType.Category.GEAR)
		assert_str(SupportToolbelt.TOOL_NAMES[tool]).is_equal(item.display_name)


func test_every_tool_waits_exactly_once_along_the_route() -> void:
	# Section 11: the player finds the support tools along the route. Every
	# tool of the belt waits as a find in one city, and no city hands the
	# same tool over twice.
	var found_cities: Dictionary = {}
	for city: CityDefinition in [SAN_COFFESCO, STEAMTLE, POURTLAND]:
		var expected: Array = ROUTE_FINDS[city.city_id]
		var finds := _city_tool_finds(city)
		assert_int(finds.size()).override_failure_message(city.city_id).is_equal(expected.size())
		for item_id: String in finds:
			assert_bool(expected.has(item_id)).is_true()
			assert_bool(found_cities.has(item_id)).is_false()
			found_cities[item_id] = city.city_id
	assert_int(found_cities.size()).is_equal(5)


func test_the_route_hands_the_tools_over_in_the_cycle_order() -> void:
	# The early cities arm the player gently: the push and the parry in San
	# Coffesco where hugs rule, the shield and the crowd slow in Steamtle,
	# the comedy slick in Pourtland at the end of the road.
	assert_str(_city_tool_finds(SAN_COFFESCO)[0]).is_equal("tamper")
	assert_str(_city_tool_finds(SAN_COFFESCO)[1]).is_equal("steam_wand")
	assert_str(_city_tool_finds(STEAMTLE)[0]).is_equal("portafilter")
	assert_str(_city_tool_finds(STEAMTLE)[1]).is_equal("iced_sprayer")
	assert_str(_city_tool_finds(POURTLAND)[0]).is_equal("bean_slick")


func _city_tool_finds(city: CityDefinition) -> Array[String]:
	# The tool gear ids of every authored find of the city, in block order.
	var tool_ids: Array = SupportToolbelt.ITEM_IDS.values()
	var finds: Array[String] = []
	for block: CityBlock in city.blocks:
		for drop: ScavengeDrop in block.finds:
			if tool_ids.has(drop.item.item_id):
				finds.append(drop.item.item_id)
	return finds
