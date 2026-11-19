# ABOUTME: Integration tests for the V1 playthrough, east chapter, T055.
# ABOUTME: One save slot walks Steamtle and Pourtland to the V1 credits.
extends GdUnitTestSuite

const MENU_SCENE := preload("res://scenes/main/menu.tscn")
const TOUCH_BALANCE := preload("res://resources/balance/touch_controls.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")
const GOLDEN_BEAN_ITEM := preload("res://resources/items/beans/golden_coast_arabica.tres")
const GEISHA_BEAN_ITEM := preload("res://resources/items/beans/geisha_vault.tres")
const SCRAP_ITEM := preload("res://resources/items/materials/scrap_part.tres")
const MOONWALKER_BALANCE := preload("res://resources/balance/moonwalker.tres")

const SAN_COFFESCO_SCENE_PATH := "res://scenes/city/san_coffesco.tscn"
const STEAMTLE_SCENE_PATH := "res://scenes/city/steamtle.tscn"
const POURTLAND_SCENE_PATH := "res://scenes/city/pourtland.tscn"
const TEST_SAVE_ROOT := "user://test-v1-east"
const MAX_FRAMES_TO_WAIT := 1200
const SETTLE_FRAMES := 6
# The fans the Sleepvana encore gathers, six of the woken crowd.
const SLEEPVANA_FANS := 6
# The center of the raised Sleep Jam stage: the CollisionShape2D sits 140 px
# above the band origin, and a thrown cup flies a straight line.
const STAGE_HEIGHT_OFFSET := Vector2(0.0, -140.0)

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
	_clear_current_scene()


func test_the_road_from_the_west_lands_in_steamtle_with_the_traveler() -> void:
	# The middle city opens with moving day, section 10: the west city
	# completes, the van carries the level east, and the player unpacks at
	# the new cafe van.
	var west := await _build_city_from_scene(SAN_COFFESCO_SCENE_PATH)
	_complete_the_city_beats(west)
	west.unlock_state.unlock()
	await _settle(SETTLE_FRAMES)
	SaveSystem.park_for_scene_change(SaveSystem.new(_slot_path()))
	west.player.global_position = west.roads.east().global_position
	var city := await _await_scene_change(west, STEAMTLE_SCENE_PATH) as CityRun
	assert_str(city.definition.city_id).is_equal("steamtle")
	assert_bool(city.van_state.is_owned()).is_true()
	# The van came along at its west level and moving day waits.
	assert_int(city.van_state.level()).is_equal(MobileCafe.Level.VAN)
	assert_bool(city.is_moving_day_done()).is_false()
	city.player.global_position = city.van().global_position + Vector2(0.0, -50.0)
	var unloaded := 0
	while not city.is_moving_day_done() and unloaded < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		unloaded += 1
	assert_bool(city.is_moving_day_done()).is_true()


func test_the_gamer_wakes_and_sleepvana_plays_the_last_concert() -> void:
	# The signature quest of Steamtle, section 13: the three orders wake the
	# band, the field cafe gathers the fans, and the encore order ends the
	# show with a city wake event.
	var city := await _continue_from_menu(STEAMTLE_SCENE_PATH)
	_city_checks(city)
	var stage := city.get_node(^"SignatureQuest") as SleepvanaStage
	assert_object(stage).is_not_null()
	_park_the_crowd_west(city)
	# The orders of the show pin better beans than the house jar, and any
	# bean recipe prefers a held bean: the scavenged region stock pays.
	city.player.inventory.add(GOLDEN_BEAN_ITEM, 8)

	# The Gamer of the Steamtle roster wakes from the triple Aeropress shot.
	await _brew_at_stand(city, LIBRARY.find_recipe("triple_shot"))
	var gamer := await _park_sleeper_east(city, "gamer")
	await _throw_east_by_touch_and_awake(city, gamer)
	assert_bool(city.sleepy_dex().is_found("gamer")).is_true()

	# The three simple orders wake the three members and accept the quest.
	var orders := [stage.order_bassist, stage.order_drummer, stage.order_guitarist]
	for i: int in range(stage.members().size()):
		await _brew_at_stand(city, orders[i])
		await _deliver_cup_at(city, stage.members()[i].global_position)
		assert_bool(stage.members()[i].is_awake()).is_true()
	assert_int(stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)

	# The encore order brews last, because every later brew replaces the cup
	# in hand: the twelve second window is too short for the stand, so the
	# hand carries the frontman cup into the show.
	await _brew_at_stand(city, LIBRARY.find_recipe("sleepvana_order_frontman"))

	# Scrap upgrades the van twice; the field cafe parks by the garage.
	city.player.inventory.add(SCRAP_ITEM, 17)
	await _settle(SETTLE_FRAMES)
	var van := city.van()
	city.player.global_position = van.global_position + Vector2(0.0, -50.0)
	await _settle(SETTLE_FRAMES)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_int(city.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_int(city.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	city.player.global_position = stage.garage_position() + Vector2(0.0, 240.0)
	_tap(city, TouchControls.ButtonKind.VAN)
	await _settle(SETTLE_FRAMES)
	assert_bool(city.van().is_field_base_open()).is_true()

	# The woken crowd gathers at the tables and follows the player east.
	var fans := _gather_fans(city, SLEEPVANA_FANS)
	var gathered := 0
	while (
		not city.van().is_player_at_van() or city.van().gathered_survivors().size() < SLEEPVANA_FANS
	):
		await get_tree().physics_frame
		gathered += 1
		if gathered >= MAX_FRAMES_TO_WAIT:
			break
	assert_int(city.van().gathered_survivors().size()).is_equal(SLEEPVANA_FANS)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	for fan: Sleepwalker in fans:
		assert_bool(fan.is_following()).is_true()
	city.player.global_position = stage.garage_position()
	var encore := 0
	while stage.quest.phase() != SleepvanaQuest.Phase.ENCORE and encore < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		encore += 1
	assert_int(stage.quest.phase()).is_equal(SleepvanaQuest.Phase.ENCORE)
	await _deliver_cup_at(city, stage.frontman().global_position)
	assert_bool(stage.frontman().is_awake()).is_true()
	assert_bool(city.quest_log.quest("sleepvana").is_complete()).is_true()


func test_the_market_cure_and_the_tower_silence_complete_steamtle() -> void:
	# The Fish Throwers of the public market drink the tall dark roast, the
	# tower goes silent, and the completed city opens the road to Pourtland.
	var city := await _continue_from_menu(STEAMTLE_SCENE_PATH)
	_city_checks(city)
	_wake_the_crowd(city)
	await _switch_the_tower_by_touch(city)
	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_TOWER_SWITCH)

	# A close and a reopen at the tower save point: the city comes back
	# silent with the road still to play, and the restored wake-up rides the
	# slot into the session.
	_clear_current_scene()
	await get_tree().physics_frame
	var reloaded := await _continue_from_menu(STEAMTLE_SCENE_PATH)
	assert_bool(reloaded.city_map().broadcast_tower().is_switched_off()).is_true()
	assert_bool(reloaded.progress.is_tower_off()).is_true()
	assert_bool(reloaded.progress.is_boss_cured()).is_false()
	assert_int(reloaded.player.wake_ups.remaining).is_equal(
		reloaded.save_system.saved_run_state().get("wake_ups", -1)
	)

	# The market cure: one tall cup of the market dark roast into the apron
	# of the head fishmonger, brewed live on the region bean.
	reloaded.player.inventory.add(GOLDEN_BEAN_ITEM, 2)
	await _brew_at_stand(reloaded, LIBRARY.find_recipe("market_dark_roast_tall"))
	var throwers := reloaded.boss() as FishThrowers
	assert_object(throwers).is_not_null()
	await _throw_east_by_touch_and_awake(reloaded, null, throwers.head().global_position)
	assert_bool(throwers.is_cured()).is_true()
	assert_bool(reloaded.is_city_complete()).is_true()
	assert_str(reloaded.save_system.saved_save_point()).is_equal(SaveData.POINT_BOSS_CURED)

	# The road east travels to Pourtland.
	SaveSystem.park_for_scene_change(SaveSystem.new(_slot_path()))
	reloaded.player.global_position = reloaded.roads.east().global_position
	var east := await _await_scene_change(reloaded, POURTLAND_SCENE_PATH) as CityRun
	assert_str(east.definition.city_id).is_equal("pourtland")
	assert_bool(east.van_state.is_owned()).is_true()
	# The arrival spawn writes the first save point of the new city, so the
	# next session continues into Pourtland and not back into Steamtle.
	var arrival := 0
	while (
		east.save_system.saved_save_point() != SaveData.POINT_CAFE_ENTRY
		and arrival < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		arrival += 1
	assert_str(east.save_system.saved_save_point()).is_equal(SaveData.POINT_CAFE_ENTRY)
	assert_str(east.save_system.continue_scene_path()).is_equal(POURTLAND_SCENE_PATH)


func test_the_aisle_7_husband_wakes_and_teaches_the_turkish_method() -> void:
	# The signature quest of Pourtland, section 13: the photo, the Turkish
	# brew at the sleeper, the sweet hug, and the sleeper who becomes the
	# teacher of the last masterless method.
	var city := await _continue_from_menu(POURTLAND_SCENE_PATH)
	_city_checks(city)
	var stage := city.get_node(^"SignatureQuest") as Aisle7Stage
	assert_object(stage).is_not_null()
	city.player.global_position = stage.wife().global_position
	await _settle(SETTLE_FRAMES)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_bool(city.quest_log.quest("aisle_7").is_active()).is_true()

	city.player.inventory.add(TURKISH_POT_ITEM, 1)
	city.player.global_position = stage.husband().global_position
	await _settle(SETTLE_FRAMES)
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	var watch := stage.foam_watch_view()
	assert_object(watch).is_not_null()
	var frames := 0
	while not watch.model.is_at_rim() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	watch.request_lift()
	var hug := 0
	while stage.quest.phase() != Aisle7Quest.Phase.SWEET_HUG and hug < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		hug += 1
	assert_int(stage.quest.phase()).is_equal(Aisle7Quest.Phase.SWEET_HUG)
	var master := 0
	var husband_master: MasterNpc = null
	while husband_master == null and master < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		husband_master = _quest_master_npc(city)
	assert_object(husband_master).is_not_null()
	city.player.global_position = husband_master.global_position
	await _settle(SETTLE_FRAMES)
	var skill_before := city.player.brewing_skills.skill(&"turkish")
	_fire_action(&"interact")
	await _settle(SETTLE_FRAMES)
	assert_int(city.player.brewing_skills.skill(&"turkish")).is_equal(skill_before + 2)


func test_the_tinfoil_man_takes_the_served_turkish_cup() -> void:
	# The serve action hands the Turkish cure past the hat, section 6: the
	# thrown cup dies on the tinfoil, the served cup wakes him.
	var city := await _continue_from_menu(POURTLAND_SCENE_PATH)
	_city_checks(city)
	_park_the_crowd_west(city)
	# The quest brew needs the scavenged Turkish pot in this session too.
	city.player.inventory.add(TURKISH_POT_ITEM, 1)
	await _brew_at_stand(city, LIBRARY.find_recipe("turkish_cup"))
	var tinfoil := await _park_sleeper_east(city, "tinfoil_man")
	tinfoil.global_position = city.player.global_position + Vector2(40.0, 0.0)
	await _settle(SETTLE_FRAMES)
	_tap(city, TouchControls.ButtonKind.SERVE)
	await _settle(SETTLE_FRAMES)
	assert_bool(tinfoil.is_awake()).is_true()
	assert_bool(city.sleepy_dex().is_found("tinfoil_man")).is_true()


func test_the_moonwalker_haunt_fights_at_dawn_and_teaches_the_dodge() -> void:
	# Section 24 in live play: the silent zone at dawn spawns him, the
	# ristretto wakes him, the dance-off win teaches the Moonwalk dodge.
	var city := await _continue_from_menu(POURTLAND_SCENE_PATH)
	_city_checks(city)
	await _switch_the_tower_by_touch(city)
	var mystery := (
		city.get_tree().get_first_node_in_group(&"moonwalker_mystery") as MoonwalkerMystery
	)
	assert_object(mystery).is_not_null()
	_park_the_crowd_west(city)
	var indices := CityRules.pole_block_indices(
		city.city_map().block_count(), city.city_map().balance
	)
	var zone := city.city_map().block_view(indices[0]).pole_zone()
	city.player.global_position = zone.global_position
	await _settle(SETTLE_FRAMES)
	var now := mystery.dawn_clock().time_of_day()
	mystery.dawn_clock().advance(
		MOONWALKER_BALANCE.day_cycle_seconds + MOONWALKER_BALANCE.dawn_length_seconds * 0.5 - now
	)
	var spawned := 0
	while mystery.figure() == null and spawned < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		spawned += 1
	var figure := mystery.figure()
	assert_object(figure).is_not_null()

	await _brew_at_stand(city, LIBRARY.find_recipe("ristretto"))
	figure.global_position = city.player.global_position + Vector2(40.0, 0.0)
	await _settle(SETTLE_FRAMES)
	_tap(city, TouchControls.ButtonKind.SERVE)
	var woke := 0
	while mystery.phase() != MoonwalkerMystery.Phase.OFFER and woke < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		woke += 1
	assert_int(mystery.phase()).is_equal(MoonwalkerMystery.Phase.OFFER)
	assert_bool(city.sleepy_dex().is_found("moonwalker")).is_true()

	assert_bool(mystery.try_begin_dance_off()).is_true()
	var view := mystery.dance_off_view()
	assert_object(view).is_not_null()
	for _beat: int in range(view.model.beats_total()):
		var beat := 0
		while not view.model.is_over() and not _near_next_beat(view) and beat < MAX_FRAMES_TO_WAIT:
			await get_tree().physics_frame
			beat += 1
		if view.model.is_over():
			break
		view.request_tap()
	var danced := 0
	while mystery.phase() != MoonwalkerMystery.Phase.DONE and danced < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		danced += 1
	assert_int(mystery.phase()).is_equal(MoonwalkerMystery.Phase.DONE)
	assert_int(city.player.dodge_style).is_equal(Player.DodgeStyle.MOONWALK)


func test_the_sleep_jam_ends_the_song_and_the_credits_close_v1() -> void:
	# The last boss of the route drinks the Geisha Vault cup, the outro takes
	# the city, the Karen demands the manager, and the credits catch her
	# mid-sentence, section 16. The final save reloads the ended version.
	var city := await _continue_from_menu(POURTLAND_SCENE_PATH)
	_city_checks(city)
	_wake_the_crowd(city)
	city.player.inventory.add(GEISHA_BEAN_ITEM, 2)
	# The lullaby of the arena drains the meter fast, section 6: the barista
	# drinks at the cafe before the show, like the loop of section 7 says. The
	# drink comes first, because a drink spends the brewed cup in hand.
	city.player.global_position = city.city_map().cafe_spawn().global_position
	await _settle(SETTLE_FRAMES)
	for drink: int in range(3):
		if not city.player.sleep_meter.is_drinking():
			_tap(city, TouchControls.ButtonKind.DRINK)
		var sips := 0
		while city.player.sleep_meter.is_drinking() and sips < 180:
			await get_tree().physics_frame
			sips += 1
	await _brew_at_stand(city, LIBRARY.find_recipe("geisha_vault_cup"))
	var band := city.boss() as SleepJamBand
	assert_object(band).is_not_null()
	await _deliver_cup_to_the_stage(city, band)
	assert_bool(band.is_awake()).is_true()
	assert_bool(city.is_city_complete()).is_true()

	var outro := city.get_node(^"Outro") as OutroDirector
	assert_object(outro).is_not_null()
	var demand := 0
	while outro.flow.current_step() != OutroFlow.Step.DEMAND and demand < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		demand += 1
	assert_int(outro.flow.current_step()).is_equal(OutroFlow.Step.DEMAND)
	assert_bool(city.sleepy_dex().is_found("karen")).is_true()
	var credits := 0
	while outro.flow.current_step() != OutroFlow.Step.CREDITS and credits < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		credits += 1
	assert_str(outro.credits_view.caught_line()).is_equal("Manager! I want to see the ma—")

	# The skip lands in the post game; the world returns behind the credits.
	var press := InputEventKey.new()
	press.pressed = true
	outro._unhandled_input(press)
	var post := 0
	while outro.flow.current_step() != OutroFlow.Step.POST_GAME and post < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		post += 1
	assert_bool(city.player.is_input_locked()).is_false()
	assert_bool(city.hud.is_toast_visible()).is_true()

	# The ended version writes its own save point, section 18: the final close
	# and reopen resumes the post-game world instead of replaying the credits.
	var final_save := 0
	while (
		city.save_system.saved_save_point() != SaveData.POINT_POST_GAME
		and final_save < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		final_save += 1
	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_POST_GAME)

	_clear_current_scene()
	await get_tree().physics_frame
	var reloaded := await _continue_from_menu(POURTLAND_SCENE_PATH)
	var reloaded_outro := reloaded.get_node(^"Outro") as OutroDirector
	assert_int(reloaded_outro.flow.current_step()).is_equal(OutroFlow.Step.POST_GAME)
	var staged := 0
	while reloaded_outro.karen() == null and staged < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		staged += 1
	assert_object(reloaded_outro.karen()).is_not_null()
	assert_bool(reloaded_outro.karen().is_in_place()).is_true()
	assert_bool(reloaded.player.is_input_locked()).is_false()


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


func _build_city_from_scene(scene_path: String) -> CityRun:
	# The run lands as the tree's current scene, the same topology a real
	# scene change acts on.
	var scene := load(scene_path) as PackedScene
	var city := scene.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot_path())
	get_tree().root.add_child(city)
	get_tree().current_scene = city
	_scene_leftovers.append(city)
	await get_tree().physics_frame
	await get_tree().physics_frame
	return city


func _continue_from_menu(expected_path: String) -> CityRun:
	var menu := MENU_SCENE.instantiate()
	menu.set(&"save_file_path", _slot_path())
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	_scene_leftovers.append(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	(menu.get_node(^"Center/VBox/PlayButton") as Button).pressed.emit()
	var city := await _await_scene_change(menu, expected_path) as CityRun
	await _settle(SETTLE_FRAMES)
	return city


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


func _complete_the_city_beats(city: CityRun) -> void:
	city.player.pickup_item(FUSE_ITEM, 1)
	var tower := city.city_map().broadcast_tower()
	assert_bool(tower.insert_fuse(city.player)).is_true()
	assert_bool(tower.switch_off()).is_true()
	city.notify_boss_cured()
	await get_tree().physics_frame
	await get_tree().physics_frame


func _fire_action(action: StringName) -> void:
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


func _hold_stick(city: CityRun, direction: Vector2) -> void:
	var center := city.touch_controls.stick().get_global_rect().get_center()
	city.touch_controls._input(_touch_event(true, center))
	city.touch_controls._input(
		_drag_event(center + direction.normalized() * TOUCH_BALANCE.stick_max_distance_pixels)
	)


func _drag_event(position: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = position
	return drag


func _release_stick(city: CityRun) -> void:
	city.touch_controls._input(_touch_event(false, Vector2.ZERO))


func _tap(city: CityRun, kind: TouchControls.ButtonKind) -> void:
	var button := city.touch_controls.button(kind)
	var center := button.get_global_rect().get_center()
	city.touch_controls._input(_touch_event(true, center, 1))
	city.touch_controls._input(_touch_event(false, center, 1))
	Input.flush_buffered_events()


func _switch_the_tower_by_touch(city: CityRun) -> void:
	# The interact action runs the insert and the switch, like the USE tap
	# fires it. An already silent tower only waits.
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


func _park_the_crowd_west(city: CityRun) -> void:
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)


func _wake_the_crowd(city: CityRun) -> void:
	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).wake_up()


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
	await _throw_by_touch(city, Vector2.RIGHT)


func _throw_by_touch(city: CityRun, direction: Vector2) -> void:
	# The stick aims, the THROW tap fires the throw action.
	_hold_stick(city, direction)
	await get_tree().physics_frame
	_tap(city, TouchControls.ButtonKind.THROW)
	_release_stick(city)


func _deliver_cup_at(city: CityRun, target: Vector2) -> void:
	# The player stands west of the target and throws the brewed cup at it.
	# A building can shove the player off the spot, so the aim reads the real
	# direction to the target after the settle, and a small target gets the
	# retry a player would give it.
	# The helper awaits its own waits, so every caller must await it too.
	# The quest sleepers sit outside the sleepwalker group, so the aim
	# assist snaps past them: a short stand-off shot keeps the cone scatter
	# inside the body.
	city.player.global_position = target + Vector2(-70.0, 0.0)
	await _settle(SETTLE_FRAMES)
	var aim := (target - city.player.global_position).normalized()
	for attempt: int in range(4):
		await _throw_by_touch(city, aim)
		await _settle(SETTLE_FRAMES)


func _deliver_cup_to_the_stage(city: CityRun, band: SleepJamBand) -> void:
	# The raised stage of the band sits above the street, and a thrown cup
	# flies a straight line at its spawn height: a street-level throw passes
	# under the boards. The live delivery of the fight walks beside the stage
	# at stage height and throws across it.
	# The helper awaits its own waits, so every caller must await it too.
	city.player.global_position = band.global_position + STAGE_HEIGHT_OFFSET + Vector2(-150.0, 0.0)
	await _settle(SETTLE_FRAMES)
	for attempt: int in range(3):
		await _throw_by_touch(city, Vector2.RIGHT)
		var frames := 0
		while not band.is_awake() and frames < 120:
			await get_tree().physics_frame
			frames += 1
		if band.is_awake():
			return
	assert_bool(band.is_awake()).is_true()


func _serve_cup_by_touch(city: CityRun, sleeper: Sleepwalker) -> void:
	# The SERVE tap hands the brewed cup to the sleeper at arm's length.
	# The helper awaits its own waits, so every caller must await it too.
	for attempt: int in range(3):
		city.player.global_position = sleeper.global_position + Vector2(-40.0, 0.0)
		await _settle(SETTLE_FRAMES)
		_tap(city, TouchControls.ButtonKind.SERVE)
		var frames := 0
		while sleeper.state != Sleepwalker.State.AWAKE and frames < 120:
			await get_tree().physics_frame
			frames += 1
		if sleeper.state == Sleepwalker.State.AWAKE:
			return
	assert_int(sleeper.state).is_equal(Sleepwalker.State.AWAKE)


func _throw_east_by_touch_and_awake(
	city: CityRun, sleeper: Sleepwalker, hit_position := Vector2.ZERO
) -> void:
	# The helper awaits its own waits, so every caller must await it too.
	# A missed cup or a stunned beat gets the retry a player would give it.
	if hit_position != Vector2.ZERO:
		await _deliver_cup_at(city, hit_position)
		return
	if sleeper == null:
		await _throw_east_by_touch(city)
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
	_park_the_crowd_west(city)
	city.player.throw_cup(Vector2.LEFT)


func _brew_at_stand(city: CityRun, recipe: Recipe) -> BrewedCup:
	# One full live brew through the touch BREW tap. The helper awaits its
	# minigames, so every caller must await it too.
	_spend_one_cup(city)
	city.player.global_position = city.city_map().cafe_spawn().global_position
	await _settle(SETTLE_FRAMES)
	_tap(city, TouchControls.ButtonKind.BREW)
	var stand := city.brew_pot.stand()
	assert_object(stand).is_not_null()
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


func _gather_fans(city: CityRun, count: int) -> Array[Sleepwalker]:
	# Awakened survivors placed on the field base tables count as gathered.
	var fans: Array[Sleepwalker] = []
	for i: int in range(count):
		var fan := city.crowd_enemy(i)
		fan.wake_up()
		var angle := TAU * float(i) / 6.0
		fan.global_position = city.van().global_position + Vector2.from_angle(angle) * 78.0
		fans.append(fan)
	return fans


func _quest_master_npc(city: CityRun) -> MasterNpc:
	for npc: MasterNpc in city.master_school.masters():
		if npc.master.master_id == "husband":
			return npc
	return null


func _near_next_beat(view: DanceOffView) -> bool:
	var model := view.model
	if model.next_beat() >= model.beats_total():
		return false
	return absf(model.elapsed() - model.beat_time(model.next_beat())) <= 0.033
