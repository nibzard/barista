# ABOUTME: Integration tests for the V1 playthrough, west chapter, T055.
# ABOUTME: One save slot walks the boot, the tutorial, and the free city.
extends GdUnitTestSuite

const MENU_SCENE := preload("res://scenes/main/menu.tscn")
const TOUCH_BALANCE := preload("res://resources/balance/touch_controls.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const BLENDER_ITEM := preload("res://resources/items/appliances/blender.tres")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")
const GOLDEN_BEAN_ITEM := preload("res://resources/items/beans/golden_coast_arabica.tres")

const CREATION_SCENE_PATH := "res://scenes/main/character_creation.tscn"
const INTRO_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
const STEAMTLE_SCENE_PATH := "res://scenes/city/steamtle.tscn"
const TEST_SAVE_ROOT := "user://test-v1-west"
const MAX_FRAMES_TO_WAIT := 1200
const RIDE_FRAMES_TO_WAIT := 3000
const SETTLE_FRAMES := 6

var _scene_leftovers: Array[Node] = []


func before() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	_reset_session_statics()


func after() -> void:
	_reset_session_statics()
	_clear_current_scene()
	for node: Node in _scene_leftovers:
		if is_instance_valid(node):
			node.free()
	_scene_leftovers.clear()
	_remove_dir(TEST_SAVE_ROOT)


func before_test() -> void:
	_reset_session_statics()


func after_test() -> void:
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)
	var city := get_tree().current_scene as CityRun
	if city != null and is_instance_valid(city.touch_controls):
		city.touch_controls.stick().force_release()
	# One session ends like a closed app: the next case continues from the
	# slot alone, the same way the game reloads between play sessions.
	_clear_current_scene()


func test_the_boot_runs_menu_creation_and_the_first_ten_minutes() -> void:
	# Session one, section 19: the fresh slot boots through the menu and the
	# creation screen into the tutorial run, and the first ten minutes play
	# through the real polling of the director.
	var menu := _build_menu()
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)
	var creation := await _await_scene_change(menu, CREATION_SCENE_PATH)
	# The creation screen writes the look through its own slot holder, so it
	# needs the test root too: the default device slot stays untouched.
	creation.set(&"save_file_path", _slot_path())
	_press(creation.get_node(^"Main/Right/Bottom/StartButton") as Button)
	var city := await _await_scene_change(creation, INTRO_SCENE_PATH) as CityRun
	var tutorial := city.get_node(^"Tutorial") as TutorialDirector
	assert_object(tutorial).is_not_null()
	# The spawn inside the cafe writes the first save point of section 18.
	var entry := 0
	while not city.save_system.has_run_state() and entry < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		entry += 1
	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_CAFE_ENTRY)

	await _ride_the_tutorial(city, tutorial)
	assert_bool(tutorial.flow.is_done()).is_true()
	assert_bool(city.player.is_input_locked()).is_false()
	# The first throw fed the dex, and the tower switch wrote the slot.
	assert_bool(city.sleepy_dex().is_found("neighbor")).is_true()
	var system := _open_slot()
	assert_str(system.saved_save_point()).is_equal(SaveData.POINT_TOWER_SWITCH)
	assert_bool(system.has_tower_state("san_coffesco")).is_true()
	# The van gift beat: the survivors hand the van over on the walk up.
	city.player.global_position = city.van().global_position + Vector2(0.0, -60.0)
	var gift := 0
	while not city.van_state.is_owned() and gift < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		gift += 1
	assert_bool(city.van_state.is_owned()).is_true()


func test_the_continued_run_wakes_the_free_city_by_their_cures() -> void:
	# Session two continues from the tower save point through the menu, so
	# the reload is the real continue path. The three San Coffesco sleepers
	# wake from their own cures, section 16.
	var city := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(city)
	# The tower save point reloads silent: tower, poles, and address loop.
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.is_switched_off()).is_true()
	assert_bool(city.address_audio.is_address_cut()).is_true()
	assert_bool(city.progress.is_tower_off()).is_true()
	assert_vector(city.player.global_position).is_equal_approx(
		tower.global_position, Vector2(2.0, 2.0)
	)

	_park_the_crowd_west(city)
	# The Neighbor wakes from the cafe-standard cup the tutorial brewed.
	city.player.global_position = _inside_cafe_position(city)
	await _settle(SETTLE_FRAMES)
	var neighbor := await _park_sleeper_east(city, "neighbor")
	await _throw_east_by_touch_and_awake(city, neighbor)
	assert_bool(city.sleepy_dex().is_found("neighbor")).is_true()

	# The Tourist needs the Frappuccino of the scavenged blender.
	city.player.inventory.add(BLENDER_ITEM, 1)
	await _brew_at_stand(city, LIBRARY.find_recipe("frappuccino"))
	var tourist := await _park_sleeper_east(city, "tourist")
	await _throw_east_by_touch_and_awake(city, tourist)
	assert_bool(city.sleepy_dex().is_found("tourist")).is_true()

	# The Tech Bro needs the bulletproof espresso.
	await _brew_at_stand(city, LIBRARY.find_recipe("bulletproof"))
	var tech_bro := await _park_sleeper_east(city, "tech_bro")
	await _throw_east_by_touch_and_awake(city, tech_bro)
	assert_bool(city.sleepy_dex().is_found("tech_bro")).is_true()


func test_every_brewing_method_pours_once_at_the_stand() -> void:
	# Session three covers the eight methods of section 8 through the live
	# stand: the dial, then the minigame of each method group.
	var city := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(city)
	city.player.inventory.add(TURKISH_POT_ITEM, 1)
	# The good-tier region bean pays the brews that accept any bean, because
	# the stand prefers a held bean over the free house jar, and the cold
	# brew needs at least a good bean by its recipe pin.
	city.player.inventory.add(GOLDEN_BEAN_ITEM, 12)
	var expected_methods := [
		["super_tall_american", "filter"],
		["single_origin_v60", "v60"],
		["triple_shot", "aeropress"],
		["ristretto", "espresso"],
		["sleepvana_order_guitarist", "french_press"],
		["sleepvana_order_drummer", "moka_pot"],
		["turkish_cup", "turkish"],
	]
	for row: Array in expected_methods:
		var cup := await _brew_at_stand(city, LIBRARY.find_recipe(row[0]))
		assert_str(cup.method.method_id).is_equal(row[1])
		assert_float(cup.score).is_greater_equal(city.player.brewing_balance.good_tier_min_score)

	# The cold brew steep is the eighth method: start it, let the fridge run,
	# and collect the cup at the stand.
	_spend_one_cup(city)
	await _open_stand_by_touch(city)
	var stand := city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("cold_brew_concentrate"))
	assert_bool(stand.start_button.disabled).is_false()
	assert_bool(city.cold_fridge.is_empty()).is_true()
	stand.begin_selected_brew()
	assert_object(city.brew_pot.stand()).is_null()
	assert_bool(city.cold_fridge.is_steeping()).is_true()
	for _tick: int in range(301):
		city.cold_fridge.tick(1.0)
	assert_bool(city.cold_fridge.is_ready()).is_true()
	await _open_stand_by_touch(city)
	city.brew_pot.stand().collect_steep()
	var payload := city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("cold_brew")
	assert_float(payload.score).is_equal(LIBRARY.find_method("cold_brew").score_ceiling)


func test_the_robotaxi_depot_delivers_the_order_and_reroutes_the_fleet() -> void:
	# Session four plays the signature quest of San Coffesco, section 13: the
	# walk-in accepts the quest, the live espresso order wakes the engineer,
	# and the fleet re-routes.
	var city := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(city)
	var quest := city.get_node(^"SignatureQuest") as RobotaxiDepotStage
	assert_object(quest).is_not_null()
	city.player.global_position = quest.engineer().global_position
	await _settle(SETTLE_FRAMES)
	assert_bool(city.quest_log.quest("robotaxi_depot").is_active()).is_true()

	await _brew_at_stand(city, LIBRARY.find_recipe("robotaxi_engineer_order"))
	var engineer := quest.engineer()
	await _throw_east_by_touch_and_awake(city, null, engineer.global_position)
	assert_bool(engineer.is_awake()).is_true()
	assert_bool(city.quest_log.quest("robotaxi_depot").is_complete()).is_true()
	assert_bool(quest.quest.is_fast_travel_unlocked()).is_true()
	assert_int(quest.stands().size()).is_greater(0)


func test_sam_oatman_drinks_the_designer_cup_and_completes_the_city() -> void:
	# Session five plays the boss of the free city: the dripper scavenges in
	# the arena, the V60 brew of section 6 runs at the stand, and the thrown
	# cure ends the show. The boss-cured save point reloads a finished city.
	var city := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(city)
	var boss := city.boss() as SamOatman
	assert_object(boss).is_not_null()
	city.player.global_position = boss.dripper_point().global_position
	var scavenge := 0
	while not city.player.inventory.has_item("designer_dripper") and scavenge < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		scavenge += 1
	assert_bool(city.player.inventory.has_item("designer_dripper")).is_true()

	var cup := await _brew_at_stand(city, LIBRARY.find_recipe("designer_dripper_cup"))
	assert_str(cup.method.method_id).is_equal("v60")
	await _throw_east_by_touch_and_awake(city, null, boss.demo_table().global_position)
	assert_bool(boss.is_cured()).is_true()
	assert_bool(city.is_city_complete()).is_true()
	var system := _open_slot()
	assert_str(system.saved_save_point()).is_equal(SaveData.POINT_BOSS_CURED)

	# The completion screen stands down and the road east opens.
	assert_bool(city.road_east_active()).is_true()
	# A closed app after the cure reloads the finished city with the road
	# armed and no beat replayed.
	_clear_current_scene()
	await get_tree().physics_frame
	var reloaded := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(reloaded)
	assert_bool(reloaded.is_city_complete()).is_true()
	assert_bool((reloaded.boss() as SamOatman).is_cured()).is_true()
	assert_bool(reloaded.road_east_active()).is_true()


func test_one_payment_opens_the_bridge_and_the_road_east_travels() -> void:
	# Session six pays the one payment of section 4 at the gate and walks the
	# road east. The scene travel lands in Steamtle with the run carried over.
	var city := await _continue_from_menu(INTRO_SCENE_PATH)
	_city_checks(city)
	# The cold brew of the crossing needs a good-tier bean in this session:
	# the last save point predates the west chapter's bean finds.
	city.player.inventory.add(GOLDEN_BEAN_ITEM, 2)
	var gate := city.bridge_gate()
	assert_bool(gate.is_open()).is_false()
	city.player.global_position = gate.global_position + Vector2(-80.0, 0.0)
	await _settle(SETTLE_FRAMES)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_bool(gate.is_open()).is_true()
	assert_bool(city.unlock_state.is_unlocked()).is_true()
	assert_str(city.hud.toast_message()).is_equal(CityRun.ROAD_OPEN_TEXT)
	var payer := _open_slot()
	assert_bool(payer.saved_run_state().get("unlock", false)).is_true()

	# A live steep crosses the road east with the run.
	_spend_one_cup(city)
	await _open_stand_by_touch(city)
	var stand := city.brew_pot.stand()
	stand.select_recipe(LIBRARY.find_recipe("cold_brew_concentrate"))
	assert_bool(stand.start_button.disabled).is_false()
	stand.begin_selected_brew()
	assert_bool(city.cold_fridge.is_steeping()).is_true()
	for _tick: int in range(200):
		city.cold_fridge.tick(1.0)

	# The player steps on the travel trigger; the scene travels east. The
	# slot parks for the change like a player build hands it to the next run.
	SaveSystem.park_for_scene_change(SaveSystem.new(_slot_path()))
	city.player.global_position = city.road_east().global_position
	var east := await _await_scene_change(city, STEAMTLE_SCENE_PATH) as CityRun
	assert_object(east).is_not_null()
	assert_str(east.definition.city_id).is_equal("steamtle")
	# The van came along at its west level and the steep crossed the road.
	assert_bool(east.van_state.is_owned()).is_true()
	assert_bool(east.cold_fridge.is_steeping()).is_true()
	assert_str(east.cold_fridge.steeped_recipe().recipe_id).is_equal("cold_brew_concentrate")


func _city_checks(city: CityRun) -> void:
	assert_object(city).is_not_null()
	assert_object(city.save_system).is_not_null()
	assert_bool(city.save_system.has_run_state()).is_true()


func _reset_session_statics() -> void:
	SaveSystem.take_after_scene_change()
	VanHandoff.reset()
	ColdBrewHandoff.reset()
	MoveHandoff.reset()


func _clear_current_scene() -> void:
	var tree := get_tree()
	var current := tree.current_scene
	if current != null:
		tree.current_scene = null
		current.free()


func _slot_path() -> String:
	return TEST_SAVE_ROOT + "/slot.json"


func _open_slot() -> SaveSystem:
	return SaveSystem.new(_slot_path())


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var entries: Array[String] = []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	for child: String in entries:
		var child_path := path.path_join(child)
		if DirAccess.dir_exists_absolute(child_path):
			_remove_dir(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	DirAccess.remove_absolute(path)


func _build_menu() -> Node:
	var menu := MENU_SCENE.instantiate()
	menu.set(&"save_file_path", _slot_path())
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	_scene_leftovers.append(menu)
	return menu


func _press(button: Button) -> void:
	button.pressed.emit()


func _continue_from_menu(expected_path: String) -> CityRun:
	# The real continue path of section 18: the menu reads the slot, parks the
	# system, and the scene change lands the saved run.
	var menu := _build_menu()
	await get_tree().process_frame
	await get_tree().process_frame
	_press(menu.get_node(^"Center/VBox/PlayButton") as Button)
	var city := await _await_scene_change(menu, expected_path) as CityRun
	await _settle(SETTLE_FRAMES)
	await _await_tutorial_settled(city)
	return city


func _await_tutorial_settled(city: CityRun) -> void:
	# A save point written mid-tutorial reloads before its finale: the resumed
	# run replays the closing cinematic and unlocks the player after it, so a
	# session that continues from the slot waits the replay out.
	var tutorial := city.get_node_or_null(^"Tutorial") as TutorialDirector
	if tutorial == null or tutorial.flow.is_done():
		return
	var frames := 0
	while not tutorial.flow.is_done() and frames < RIDE_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(tutorial.flow.is_done()).is_true()
	assert_bool(city.player.is_input_locked()).is_false()
	await _settle(SETTLE_FRAMES)


func _await_scene_change(old_scene: Node, expected_path: String) -> Node:
	var frames := 0
	while (
		(get_tree().current_scene == null or get_tree().current_scene == old_scene)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	var current := get_tree().current_scene
	assert_object(current).is_not_null()
	assert_str(current.scene_file_path).is_equal(expected_path)
	return current


func _settle(frames: int) -> void:
	for _frame: int in range(frames):
		await get_tree().physics_frame


func _fire_action(action: StringName) -> void:
	# One action press through the input pipeline, like a touch button tap
	# synthesizes it. The flush pushes the buffered pair out at once.
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()


func _touch_event(pressed: bool, position: Vector2, index := 0) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	touch.position = position
	return touch


func _drag_event(position: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = position
	return drag


func _hold_stick(city: CityRun, direction: Vector2) -> void:
	var center := city.touch_controls.stick().get_global_rect().get_center()
	city.touch_controls._input(_touch_event(true, center))
	city.touch_controls._input(
		_drag_event(center + direction.normalized() * TOUCH_BALANCE.stick_max_distance_pixels)
	)


func _release_stick(city: CityRun) -> void:
	city.touch_controls._input(_touch_event(false, Vector2.ZERO))


func _tap(city: CityRun, kind: TouchControls.ButtonKind) -> void:
	var button := city.touch_controls.button(kind)
	var center := button.get_global_rect().get_center()
	city.touch_controls._input(_touch_event(true, center, 1))
	city.touch_controls._input(_touch_event(false, center, 1))
	Input.flush_buffered_events()


func _ride_the_tutorial(city: CityRun, tutorial: TutorialDirector) -> void:
	# The whole first ten minutes through the director's own polling. Each
	# beat uses the live verb where one exists: the stick moves, the touch
	# buttons drink, throw, and brew, and the tower answers the USE tap.
	# The helper awaits its steps, so every caller must await it too.
	_park_the_crowd_west(city)
	var frames := 0
	while not tutorial.flow.is_done() and frames < RIDE_FRAMES_TO_WAIT:
		match tutorial.flow.current_step():
			TutorialFlow.Step.VIDEO:
				tutorial.flow.end_video()
			TutorialFlow.Step.MOVE:
				await _ride_the_move_step(city, tutorial)
			TutorialFlow.Step.DRINK:
				# One channel only: a second drink press spends another cup.
				if not city.player.sleep_meter.is_drinking():
					_tap(city, TouchControls.ButtonKind.DRINK)
				await get_tree().physics_frame
			TutorialFlow.Step.DOOR:
				city.player.global_position = _outside_cafe_position(city)
			TutorialFlow.Step.THROW:
				await _ride_the_first_throw(city, tutorial)
			TutorialFlow.Step.POLE:
				city.player.global_position = _inside_cafe_position(city)
			TutorialFlow.Step.SURVIVOR:
				city.player.global_position = (
					tutorial.survivor_npc().global_position + Vector2(0.0, -30.0)
				)
			TutorialFlow.Step.ROAD:
				await _ride_the_road_lessons(city, tutorial)
			TutorialFlow.Step.TOWER:
				await _switch_the_tower_by_touch(city)
			TutorialFlow.Step.FINALE:
				await get_tree().physics_frame
		await get_tree().physics_frame
		frames += 1
	assert_int(frames).is_less(RIDE_FRAMES_TO_WAIT)


func _ride_the_move_step(city: CityRun, tutorial: TutorialDirector) -> void:
	_hold_stick(city, Vector2.RIGHT)
	var moved := 0
	while tutorial.flow.current_step() == TutorialFlow.Step.MOVE and moved < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		moved += 1
	_release_stick(city)


func _ride_the_first_throw(city: CityRun, tutorial: TutorialDirector) -> void:
	_park_the_crowd_west(city)
	var walker := tutorial.window_neighbor()
	walker.set_physics_process(false)
	walker.velocity = Vector2.ZERO
	walker.global_position = city.player.global_position + Vector2(150.0, 0.0)
	_hold_stick(city, Vector2.RIGHT)
	await get_tree().physics_frame
	_tap(city, TouchControls.ButtonKind.THROW)
	_release_stick(city)
	var thrown := 0
	while tutorial.flow.current_step() == TutorialFlow.Step.THROW and thrown < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		thrown += 1


func _ride_the_road_lessons(city: CityRun, tutorial: TutorialDirector) -> void:
	# The three lessons of the road in prompt order: brew, dodge, hug. The
	# BREW tap reaches the tutorial director, which owns the key while its
	# first-ten-minutes script runs.
	city.player.global_position = city.masters()[0].global_position
	await _settle(3)
	_tap(city, TouchControls.ButtonKind.BREW)
	var dial := tutorial.grind_dial_view()
	assert_object(dial).is_not_null()
	var dial_frames := 0
	while dial.model.position < dial.model.zone_start() and dial_frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		dial_frames += 1
	dial.request_stop()
	await _settle(3)
	city.player.begin_dodge(Vector2.RIGHT)
	await get_tree().physics_frame
	var enemy := city.crowd_enemy(0)
	enemy.global_position = city.player.global_position + Vector2(14.0, 0.0)
	var grabbed := 0
	while not city.player.is_grabbed() and grabbed < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		grabbed += 1
	assert_bool(city.player.is_grabbed()).is_true()
	while city.player.is_grabbed():
		city.player.struggle()
		await get_tree().physics_frame
	var tower := 0
	while tutorial.flow.current_step() != TutorialFlow.Step.TOWER and tower < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		tower += 1


func _switch_the_tower_by_touch(city: CityRun) -> void:
	# The real verbs of the tower: take a fuse, walk in, and let the interact
	# action run the insert and the switch, like the USE tap fires it. The
	# flow holds the TOWER step until the birdsong beat lands, so a repeat
	# call only waits.
	var tower := city.city_map().broadcast_tower()
	if tower.is_switched_off():
		await get_tree().physics_frame
		return
	city.player.pickup_item(FUSE_ITEM, 1)
	city.player.global_position = tower.global_position
	await _settle(SETTLE_FRAMES)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_bool(tower.is_switched_off()).is_false()
	_fire_action(&"interact")
	var switched := 0
	while not tower.is_switched_off() and switched < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		switched += 1
	assert_bool(tower.is_switched_off()).is_true()


func _inside_cafe_position(city: CityRun) -> Vector2:
	return city.city_map().cafe_spawn().global_position


func _outside_cafe_position(city: CityRun) -> Vector2:
	var cafe_block := city.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	var center := cafe_block.global_position + cafe_block.size * 0.5
	return center + Vector2(0.0, cafe_block.cafe_zone_radius() + 80.0)


func _park_the_crowd_west(city: CityRun) -> void:
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)


func _park_sleeper_east(city: CityRun, type_id: String) -> Sleepwalker:
	# The placement parks the walker inside its sense radius first, so the
	# meeting opens its SleepyDex row, then the freeze holds it still east
	# of the player for the touch throw.
	# The helper awaits its waits, so every caller must await it too.
	_park_the_crowd_west(city)
	for i: int in range(city.crowd_count()):
		var walker := city.crowd_enemy(i)
		if walker.enemy_type.type_id == type_id and not walker.is_awake():
			walker.global_position = city.player.global_position + Vector2(90.0, 0.0)
			var met := 0
			while not city.sleepy_dex().is_found(type_id) and met < MAX_FRAMES_TO_WAIT:
				await get_tree().physics_frame
				met += 1
			assert_bool(city.sleepy_dex().is_found(type_id)).is_true()
			walker.set_physics_process(false)
			walker.velocity = Vector2.ZERO
			walker.global_position = city.player.global_position + Vector2(150.0, 0.0)
			return walker
	return null


func _throw_east_by_touch(city: CityRun) -> void:
	# The stick aims east, the THROW tap fires the throw action.
	_hold_stick(city, Vector2.RIGHT)
	await get_tree().physics_frame
	_tap(city, TouchControls.ButtonKind.THROW)
	_release_stick(city)


func _throw_east_by_touch_and_awake(
	city: CityRun, sleeper: Sleepwalker, hit_position := Vector2.ZERO
) -> void:
	# The helper awaits its own waits, so every caller must await it too.
	# A tourist flash can stun the throwing hand for a beat, so the wake
	# retries the throw like a player would.
	if hit_position != Vector2.ZERO:
		city.player.global_position = hit_position + Vector2(-160.0, 0.0)
		await _settle(SETTLE_FRAMES)
	if sleeper == null:
		# The wide aim cone of the live throw can spray past a small target,
		# so a positioned shot retries like a player would.
		for attempt: int in range(3):
			await _throw_east_by_touch(city)
			await _settle(SETTLE_FRAMES)
		return
	for attempt: int in range(3):
		await _throw_east_by_touch(city)
		var frames := 0
		while sleeper.state != Sleepwalker.State.AWAKE and frames < 180:
			await get_tree().physics_frame
			frames += 1
		if sleeper.state == Sleepwalker.State.AWAKE:
			return
	assert_int(sleeper.state).is_equal(Sleepwalker.State.AWAKE)


func _spend_one_cup(city: CityRun) -> void:
	# The hand starts full: one throw west of the cafe makes room for the
	# brewed cup, and no sleeper stands there to catch it.
	_park_the_crowd_west(city)
	city.player.throw_cup(Vector2.LEFT)


func _open_stand_by_touch(city: CityRun) -> void:
	# The helper awaits its settle, so every caller must await it too.
	city.player.global_position = _inside_cafe_position(city)
	await _settle(SETTLE_FRAMES)
	_tap(city, TouchControls.ButtonKind.BREW)
	assert_object(city.brew_pot.stand()).is_not_null()


func _brew_at_stand(city: CityRun, recipe: Recipe) -> BrewedCup:
	# One full live brew through the touch BREW tap: the recipe plan, the
	# Grind Dial, and the method minigame of the recipe. The helper awaits
	# its minigames, so every caller must await it too.
	_spend_one_cup(city)
	await _open_stand_by_touch(city)
	var stand := city.brew_pot.stand()
	stand.select_recipe(recipe)
	assert_bool(stand.start_button.disabled).is_false()
	stand.begin_selected_brew()
	var dial := stand.grind_dial()
	assert_object(dial).is_not_null()
	dial.model.position = (dial.model.zone_start() + dial.model.zone_end()) * 0.5
	dial.request_stop()
	await get_tree().process_frame
	if stand.pour_view() != null:
		await _finish_the_pour(stand)
	elif stand.press_view() != null:
		await _finish_the_press(stand)
	else:
		await _finish_the_watch(stand)
	assert_object(city.brew_pot.stand()).is_null()
	var cup := city.player.brew_hand.active_payload()
	assert_object(cup).is_not_null()
	return cup


func _finish_the_pour(stand: BrewStandView) -> void:
	stand.pour_view().pour_rate = 0.7
	var bloom := stand.pour_view().model
	var frames := 0
	while bloom.is_running() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame


func _finish_the_press(stand: BrewStandView) -> void:
	# Chase the hold like a player: pump the needle under the creeping zone
	# until the pull opens, then ride the pressure up to the mark and lift.
	var view := stand.press_view()
	var shot := view.model
	var frames := 0
	while shot.step == PressShot.Step.HOLD and frames < MAX_FRAMES_TO_WAIT:
		view.held = shot.pressure < shot.zone_center
		await get_tree().process_frame
		frames += 1
	frames = 0
	while (
		shot.is_running()
		and shot.pressure < view.balance.release_mark_pressure - 0.03
		and frames < MAX_FRAMES_TO_WAIT
	):
		view.held = true
		await get_tree().process_frame
		frames += 1
	view.held = false
	frames = 0
	while shot.is_running() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	await get_tree().process_frame


func _finish_the_watch(stand: BrewStandView) -> void:
	# The lift at the rim: the first rim tick costs no grace, so the lift
	# lands the full foam score.
	var view: FoamWatchView = stand.foam_view()
	var watch := view.model
	var frames := 0
	while not watch.is_at_rim() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	assert_bool(watch.is_at_rim()).is_true()
	view.request_lift()
	await get_tree().process_frame
	await get_tree().process_frame
