# ABOUTME: Integration tests for the moving day of T049, section 10: the van
# ABOUTME: carries every belonging from the old city cafe to the new one.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const HOUSE_BEANS_ITEM := preload("res://resources/items/beans/house.tres")
const THERMOS_BELT_ITEM := preload("res://resources/items/gear/thermos_belt.tres")
const BREWING_LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600

# The travel case owns whole scenes under the root; they leave the physics
# space when the case ends, one way or the other.
var _scenes: Array[Node] = []


func before_test() -> void:
	# A parked van level or traveler from an earlier suite must never leak
	# into a case that builds its own city.
	VanHandoff.reset()
	MoveHandoff.reset()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")
	var tree := get_tree()
	if tree.current_scene != null and _scenes.has(tree.current_scene):
		tree.current_scene = null
	for node: Node in _scenes:
		if is_instance_valid(node):
			node.free()
	_scenes.clear()
	VanHandoff.reset()
	MoveHandoff.reset()


func test_the_move_east_carries_every_belonging() -> void:
	# Section 10: the player stocks the self in San Coffesco, pays the
	# bridge, and walks the road east. The van unpacks the same traveler by
	# the new Steamtle cafe: bag, cups, belt, brewed batch, skills, dex,
	# meter, wake-ups, and the paid flag, then the unload beat plays at the
	# van.
	var tree := get_tree()
	var west := SAN_COFFESCO_SCENE.instantiate() as CityRun
	tree.root.add_child(west)
	tree.current_scene = west
	_scenes.append(west)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wake_the_crowd(west)

	_complete_the_city(west)
	west.player.wake_ups.remaining = 2
	west.player.sleep_meter.value = 46.5
	west.player.pickup_item(THERMOS_BELT_ITEM, 1)
	west.player.pickup_item(HOUSE_BEANS_ITEM, 5)
	west.player.coffee_supply.cups = 3
	west.player.brew_hand.receive(_special_cup(), 2)
	west.player.brewing_skills.record_master_lesson(&"filter")
	west.sleepy_dex().meet("tech_bro")
	west.unlock_state.unlock()
	await get_tree().physics_frame
	await get_tree().physics_frame

	west.player.global_position = west.road_east().global_position
	var frames := 0
	while (
		(tree.current_scene == null or tree.current_scene == west) and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		await get_tree().process_frame
		frames += 1
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	var east := tree.current_scene as CityRun
	_scenes.append(east)
	assert_str(east.definition.city_id).is_equal("steamtle")

	# Every belonging crossed the bridge in the van, and the paid flag rode
	# along: one payment unlocks the full game, section 4.
	assert_int(east.player.inventory.count("house")).is_equal(5)
	assert_bool(east.player.coffee_supply.has_thermos_belt).is_true()
	assert_int(east.player.coffee_supply.cups).is_equal(3)
	assert_int(east.player.brew_hand.cups_left()).is_equal(2)
	var payload: BrewedCup = east.player.brew_hand.active_payload()
	assert_object(payload).is_not_null()
	assert_str(payload.bean.bean_id).is_equal("geisha_vault")
	assert_int(east.player.brewing_skills.skill(&"filter")).is_equal(2)
	assert_bool(east.sleepy_dex().is_found("tech_bro")).is_true()
	# The meter drifts down while the frames pass, so the pin reads a band.
	assert_float(east.player.sleep_meter.value).is_between(40.0, 47.0)
	assert_int(east.player.wake_ups.remaining).is_equal(2)
	assert_bool(east.unlock_state.is_unlocked()).is_true()

	# The moving day beat still plays at the van by the new cafe, once.
	assert_bool(east.is_moving_day_done()).is_false()
	east.player.global_position = east.van().global_position
	frames = 0
	while not east.is_moving_day_done() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(east.is_moving_day_done()).is_true()
	assert_str(east.hud.toast_message()).is_equal(CityRun.MOVING_DAY_TEXT)


func test_a_fresh_arrival_without_a_move_starts_plain() -> void:
	# A run that never traveled keeps its plain start: the handoff reads
	# empty, so no borrowed state lands.
	var east := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(east))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(east.player.inventory.count("house")).is_equal(0)
	assert_int(east.player.brewing_skills.skill(&"filter")).is_equal(0)
	assert_bool(east.sleepy_dex().is_found("tech_bro")).is_false()
	assert_bool(east.unlock_state.is_unlocked()).is_false()
	assert_int(east.player.wake_ups.remaining).is_equal(5)


func _wake_the_crowd(run: CityRun) -> void:
	# Awakened sleepwalkers never hug or stun, so the flow cases stay steady.
	for i: int in range(run.crowd_count()):
		run.crowd_enemy(i).wake_up()


func _complete_the_city(run: CityRun) -> void:
	run.player.pickup_item(FUSE_ITEM, 1)
	var tower := run.city_map().broadcast_tower()
	tower.insert_fuse(run.player)
	tower.switch_off()
	run.notify_boss_cured()


func _special_cup() -> BrewedCup:
	# A brewed special cup, like one the espresso minigame earned: a payload
	# no plain pot refills.
	return BrewedCup.new(
		BREWING_LIBRARY.find_bean("geisha_vault"),
		BREWING_LIBRARY.find_roast("dark"),
		BREWING_LIBRARY.find_method("espresso"),
		"double_shot",
		92.5
	)
