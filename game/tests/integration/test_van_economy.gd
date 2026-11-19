# ABOUTME: Integration tests for the van scrap economy of the live route, T101.
# ABOUTME: Proves gameplay loot alone funds the field cafe across the move east.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

const MAX_FRAMES_TO_WAIT := 600
# The van parks north-east of the garage, clear of every crowd marker so the
# field base invites only the fans the test places on the tables.
const VAN_PARK_OFFSET := Vector2(430.0, -130.0)

# The travel cases own whole scenes under the root; they leave the physics
# space when the case ends, one way or the other.
var _scenes: Array[Node] = []


func before_test() -> void:
	# A parked van level or traveler from an earlier suite must never leak
	# into a case that builds its own city.
	VanHandoff.reset()
	MoveHandoff.reset()


func after_test() -> void:
	# A failed assert can stop a test mid-walk; never leak a pressed key.
	Input.action_release(&"move_right")
	var tree := get_tree()
	if tree.current_scene != null and _scenes.has(tree.current_scene):
		tree.current_scene = null
	for node: Node in _scenes:
		if is_instance_valid(node):
			node.free()
	_scenes.clear()
	# A case that stops between the park and the arrival must not leave its
	# van level or traveler parked for the next suite that builds a later
	# city.
	VanHandoff.reset()
	MoveHandoff.reset()


func test_san_coffesco_loot_alone_funds_both_van_levels() -> void:
	# T101, section 10: the crates of the first city pay for the kitchen and
	# the field cafe on their own, through the scavenge points and the van
	# interact only. No load_state, no direct bag grants.
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wake_the_crowd(city)

	await _receive_the_van_gift(city)
	await _scavenge_the_city(city)
	assert_int(city.player.inventory.count(SCRAP_PART.item_id)).is_equal(
		_scavenge_block_count(city) * city.balance.scavenge_scrap_parts
	)

	await _upgrade_the_van_at(city)
	await _upgrade_the_van_at(city)
	assert_int(city.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	assert_int(city.player.inventory.count(SCRAP_PART.item_id)).is_equal(
		(
			_scavenge_block_count(city) * city.balance.scavenge_scrap_parts
			- city.van().balance.kitchen_scrap_cost
			- city.van().balance.field_cafe_scrap_cost
		)
	)

	city.player.global_position += Vector2(200.0, 0.0)
	assert_bool(city.call_van()).is_true()
	assert_bool(city.van().is_field_base_open()).is_true()


func test_steamtle_loot_funds_the_field_cafe_after_the_move_east() -> void:
	# T101, the pinned acceptance case: the player scavenges San Coffesco,
	# buys the kitchen, and walks the road east. The van level rides the move
	# and the Steamtle crates alone fund the field cafe, so the Sleepvana
	# crowd recruit runs through plain play.
	var tree := get_tree()
	var west := SAN_COFFESCO_SCENE.instantiate() as CityRun
	tree.root.add_child(west)
	tree.current_scene = west
	_scenes.append(west)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wake_the_crowd(west)

	await _receive_the_van_gift(west)
	await _scavenge_the_city(west)
	await _upgrade_the_van_at(west)
	assert_int(west.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)
	# The scrap San Coffesco did not spend rides east in the van, section 10.
	var carried_scrap := west.player.inventory.count(SCRAP_PART.item_id)

	# The move east: the completed city hands the player to Steamtle.
	_complete_the_city(west)
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

	# The van level survived the move east: the kitchen came along, section 10.
	assert_int(east.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)
	# The moving day carried the bag east too: the scrap the west city did not
	# spend rides in the van, section 10.
	assert_int(east.player.inventory.count(SCRAP_PART.item_id)).is_equal(carried_scrap)
	_wake_the_crowd(east)
	await _scavenge_the_city(east)
	assert_int(east.player.inventory.count(SCRAP_PART.item_id)).is_equal(
		carried_scrap + _scavenge_block_count(east) * east.balance.scavenge_scrap_parts
	)
	await _upgrade_the_van_at(east)
	assert_int(east.van_state.level()).is_equal(MobileCafe.Level.FIELD_CAFE)
	assert_int(east.player.inventory.count(SCRAP_PART.item_id)).is_equal(
		(
			carried_scrap
			+ _scavenge_block_count(east) * east.balance.scavenge_scrap_parts
			- east.van().balance.field_cafe_scrap_cost
		)
	)

	# The field base opens where the player parks, and the Sleepvana crowd
	# recruit runs on it, section 13.
	var stage := east.signature_quest as SleepvanaStage
	assert_object(stage).is_not_null()
	east.player.global_position = stage.garage_position() + VAN_PARK_OFFSET
	assert_bool(east.call_van()).is_true()
	assert_bool(east.van().is_field_base_open()).is_true()

	_wake_the_band(stage)
	var fans := _place_gathered_fans(east, stage.balance.crowd_size)
	await _await_the_gathered_crowd(east, stage.balance.crowd_size)
	assert_bool(stage.try_interact()).is_true()
	assert_str(east.hud.toast_message()).is_equal(SleepvanaStage.RECRUIT_TOAST)
	assert_bool(stage.quest.is_crowd_recruited()).is_true()
	for fan: Sleepwalker in fans:
		assert_bool(fan.is_following()).is_true()


func _scavenge_block_count(run: CityRun) -> int:
	var map := run.city_map()
	var count := 0
	for i: int in range(map.block_count()):
		if map.block_view(i).kind() == CityBlock.Kind.SCAVENGE:
			count += 1
	return count


func _wake_the_crowd(run: CityRun) -> void:
	# Awakened sleepwalkers never hug or stun, so the flow cases stay steady.
	for i: int in range(run.crowd_count()):
		run.crowd_enemy(i).wake_up()


func _receive_the_van_gift(run: CityRun) -> void:
	# The survivors hand the van over when the player walks up, section 10.
	run.player.global_position = run.van().global_position
	var frames := 0
	while not run.van_state.is_owned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(run.van_state.is_owned()).is_true()


func _scavenge_the_city(run: CityRun) -> void:
	# Walks the player over every scavenge point of the city: the loot enters
	# the bag the same way as in live play, one crate at a time.
	var map := run.city_map()
	for i: int in range(map.block_count()):
		var view := map.block_view(i)
		if view.kind() != CityBlock.Kind.SCAVENGE:
			continue
		var point := view.scavenge_point()
		run.player.global_position = point.global_position
		var frames := 0
		while not point.is_depleted() and frames < MAX_FRAMES_TO_WAIT:
			await get_tree().physics_frame
			frames += 1
		(
			assert_bool(point.is_depleted())
			. override_failure_message("scavenge block %d of %s" % [i, run.definition.city_id])
			. is_true()
		)


func _upgrade_the_van_at(run: CityRun) -> void:
	# The interact at the van pays the next level with the bag scrap.
	run.player.global_position = run.van().global_position
	var frames := 0
	while not run.van().is_player_at_van() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(run.van().is_player_at_van()).is_true()
	assert_int(run.interact_with_van()).is_equal(MobileCafeVan.Interaction.UPGRADED)


func _complete_the_city(run: CityRun) -> void:
	# The wired travel needs a completed city behind it: fuse, switch, cure.
	run.player.pickup_item(FUSE_ITEM, 1)
	var tower := run.city_map().broadcast_tower()
	tower.insert_fuse(run.player)
	tower.switch_off()
	run.notify_boss_cured()


func _wake_the_band(stage: SleepvanaStage) -> void:
	# The three simple orders wake the three members, so the quest enters the
	# crowd stage like in live play.
	var orders := [stage.order_bassist, stage.order_drummer, stage.order_guitarist]
	for i: int in range(stage.members().size()):
		assert_bool(stage.members()[i].try_wake(_order_cup(orders[i]))).is_true()
	assert_int(stage.quest.phase()).is_equal(SleepvanaQuest.Phase.CROWD_STAGE)


func _place_gathered_fans(run: CityRun, count: int) -> Array[Sleepwalker]:
	# Awakened survivors placed on the field base ring count as gathered, the
	# same seats the van invite fills in live play.
	var fans: Array[Sleepwalker] = []
	for i: int in range(count):
		var fan := run.crowd_enemy(i)
		fan.wake_up()
		var angle := TAU * float(i) / 6.0
		fan.global_position = run.van().global_position + Vector2.from_angle(angle) * 78.0
		fans.append(fan)
	return fans


func _await_the_gathered_crowd(run: CityRun, count: int) -> void:
	# The van invites the fans inside its reach on its own physics beat, and
	# the notice overlap needs its own frames to report the player at the van.
	var frames := 0
	while (
		(not run.van().is_player_at_van() or run.van().gathered_survivors().size() < count)
		and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1
	assert_bool(run.van().is_player_at_van()).is_true()
	assert_int(run.van().gathered_survivors().size()).is_greater_equal(count)


func _order_cup(order: Recipe) -> BrewedCup:
	# A good-tier brew of the order recipe: the cheapest bean and the pinned
	# roast that still satisfy the order's own match rules.
	var bean_id := "house"
	if order.bean_match == Recipe.Match.EXACT:
		bean_id = order.bean_id
	elif order.min_bean_quality > BeanType.Quality.BASIC:
		bean_id = "golden_coast_arabica"
	var roast_id := "light"
	if order.roast_match == Recipe.Match.EXACT:
		roast_id = ["light", "medium", "dark"][order.roast]
	return _brew(bean_id, roast_id, order.method_id, order.extra_id, 85.0)


func _brew(
	bean_id: String, roast_id: String, method_id: String, extra_id: String, score: float
) -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean(bean_id),
		LIBRARY.find_roast(roast_id),
		LIBRARY.find_method(method_id),
		extra_id,
		score
	)
