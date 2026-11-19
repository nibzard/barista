# ABOUTME: Integration tests for the brewing masters in the city runs: the
# ABOUTME: walk-up lesson flow, the skill grants, and the recipe gifts.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const MASTER_NPC_SCENE := preload("res://scenes/masters/master_npc.tscn")

var _city: CityRun


func before_test() -> void:
	_city = SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready. Settle three frames so the
	# area overlaps report before the first case reads them.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak a pressed key.
	Input.action_release(&"move_right")


func test_the_scene_pins_its_parts() -> void:
	var npc := MASTER_NPC_SCENE.instantiate() as MasterNpc
	add_child(auto_free(npc))

	var notice := npc.get_node(^"NoticeArea") as Area2D
	assert_object(notice).is_not_null()
	assert_int(notice.collision_mask).is_equal(2)
	assert_object(npc.get_node(^"LineLabel")).is_not_null()
	assert_bool(npc.is_speaking()).is_false()


func test_the_run_builds_the_city_master_at_the_cafe() -> void:
	_wake_the_crowd()
	var masters := _city.master_school.masters()
	assert_int(masters.size()).is_equal(1)
	var master_npc := masters[0]
	assert_str(master_npc.master.master_id).is_equal("offmug")
	assert_str(master_npc.master.city_id).is_equal("san_coffesco")

	var cafe_block := _city.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	assert_vector(master_npc.global_position).is_equal(cafe_block.master_spot().global_position)
	var safe_zone := cafe_block.safe_zone()
	var offset := master_npc.global_position - safe_zone.global_position
	assert_float(offset.length()).is_less(cafe_block.cafe_zone_radius())


func test_offmug_says_ultimately_when_he_teaches() -> void:
	_wake_the_crowd()
	var master_npc := _city.master_school.masters()[0]
	await _stand_at_master(master_npc)

	assert_bool(_city.master_school.interact()).is_true()
	assert_str(master_npc.spoken_line()).is_equal(
		"Ultimately... Pour in a slow circle. Let the bloom lead. Patience makes the cup."
	)
	assert_int(_city.player.brewing_skills.skill("v60")).is_equal(2)
	assert_bool(_city.master_lessons.is_recipe_known("single_origin_v60")).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		"JAMES OFFMUG, LESSON 1 OF 3. +2 SKILL. NEW RECIPE: SINGLE-ORIGIN V60."
	)


func test_three_lessons_complete_the_school() -> void:
	_wake_the_crowd()
	var master_npc := _city.master_school.masters()[0]
	await _stand_at_master(master_npc)

	for lesson: int in range(3):
		assert_bool(_city.master_school.interact()).is_true()
	assert_int(_city.player.brewing_skills.skill("v60")).is_equal(6)
	assert_bool(_city.master_lessons.is_school_complete("offmug")).is_true()
	assert_str(_city.hud.toast_message()).is_equal(
		"JAMES OFFMUG, LESSON 3 OF 3. +2 SKILL. JAMES OFFMUG HAS TAUGHT EVERY LESSON."
	)

	# The fourth visit teaches nothing: the master only says the catchphrase.
	assert_bool(_city.master_school.interact()).is_true()
	assert_str(master_npc.spoken_line()).is_equal("Ultimately...")
	assert_str(_city.hud.toast_message()).is_equal("JAMES OFFMUG HAS TAUGHT EVERY LESSON.")
	assert_int(_city.player.brewing_skills.skill("v60")).is_equal(6)
	assert_int(_city.master_lessons.lessons_taken("offmug")).is_equal(3)


func test_hedrip_teaches_both_methods_in_steamtle() -> void:
	var steamtle := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(steamtle))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var master_npc := steamtle.master_school.masters()[0]
	assert_str(master_npc.master.master_id).is_equal("hedrip")
	steamtle.player.global_position = master_npc.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(steamtle.master_school.interact()).is_true()
	assert_int(steamtle.player.brewing_skills.skill("aeropress")).is_equal(2)
	assert_int(steamtle.player.brewing_skills.skill("cold_brew")).is_equal(2)
	assert_bool(steamtle.master_lessons.is_recipe_known("triple_shot")).is_true()
	assert_str(master_npc.spoken_line()).is_equal(
		"Measured to the gram! Weigh the beans. Watch the heat. The numbers make the cup."
	)


func test_raoast_grants_three_recipes_in_pourtland() -> void:
	var pourtland := POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(pourtland))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	var master_npc := pourtland.master_school.masters()[0]
	assert_str(master_npc.master.master_id).is_equal("raoast")
	pourtland.player.global_position = master_npc.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	for lesson: int in range(3):
		assert_bool(pourtland.master_school.interact()).is_true()
	assert_array(pourtland.master_lessons.known_recipes()).is_equal(
		["super_tall_american", "ristretto", "bulletproof"]
	)
	assert_int(pourtland.player.brewing_skills.skill("espresso")).is_equal(6)
	assert_int(pourtland.player.brewing_skills.skill("filter")).is_equal(6)


func test_interact_away_from_the_master_returns_false() -> void:
	_wake_the_crowd()
	_city.player.global_position = _city.city_map().broadcast_tower().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.master_school.interact()).is_false()
	assert_int(_city.player.brewing_skills.skill("v60")).is_equal(0)
	assert_int(_city.master_lessons.lessons_taken("offmug")).is_equal(0)


func test_the_van_keeps_the_interact_key_at_its_own_spot() -> void:
	# The van stands outside the cafe safe zone, far from the master, so the
	# interact key still reaches it there.
	_wake_the_crowd()
	assert_object(_city.van()).is_not_null()
	_city.player.global_position = _city.van().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.master_school.interact()).is_false()
	assert_int(_city.player.brewing_skills.skill("v60")).is_equal(0)


func _stand_at_master(master_npc: MasterNpc) -> void:
	_city.player.global_position = master_npc.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug, so the flow tests stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()
