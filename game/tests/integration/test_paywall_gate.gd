# ABOUTME: Integration tests for the paywall gate of T049, section 4: the
# ABOUTME: first city is free, one payment unlocks the full game.
extends GdUnitTestSuite

const SAN_COFFESCO_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const STEAMTLE_SCENE := preload("res://scenes/city/steamtle.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
const TEST_SAVE_ROOT := "user://test-paywall-gate"

var _city: CityRun


func before_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	# A parked traveler from an earlier suite must never leak into a run this
	# suite builds.
	MoveHandoff.reset()
	_city = SAN_COFFESCO_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	_remove_dir(TEST_SAVE_ROOT)
	MoveHandoff.reset()
	# A failed assert can stop a test mid-walk; never leak the pressed key.
	Input.action_release(&"move_right")


func test_the_completed_city_keeps_its_road_behind_the_locked_gate() -> void:
	# The unlock state forced locked: the city is complete and the road east
	# is armed, but the paywall barrier still holds the walk west of the
	# bridge, section 4.
	_wake_the_crowd()
	_complete_the_city()
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_bool(_city.roads.east_active()).is_true()
	var gate := _city.bridge_gate()
	assert_bool(gate.is_open()).is_false()

	var arrivals: Array[int] = []
	_city.east_road_taken.connect(func() -> void: arrivals.append(1))
	# The tower birdsong toast lands seconds after the switch and would race
	# a toast read, so the case counts the gate's own paywall beat instead.
	var paywall_hits: Array[int] = []
	gate.paywall_reached.connect(func() -> void: paywall_hits.append(1))
	await _walk_east_from_the_city_edge()

	# The barrier stopped the walk west of the gate, the travel never fired,
	# and the gate spoke its paywall line once.
	assert_float(_city.player.global_position.x).is_less(gate.global_position.x - 10.0)
	assert_int(arrivals.size()).is_equal(0)
	assert_int(paywall_hits.size()).is_equal(1)


func test_one_press_at_the_gate_pays_the_stub_and_opens_the_road() -> void:
	# The locked gate answers the interact key with the stubbed purchase
	# interface: one payment, granted at once, and the bridge opens for good.
	# A paid gate passes the key on instead.
	_wake_the_crowd()
	var gate := _city.bridge_gate()
	_city.player.global_position = gate.global_position - Vector2(40.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(gate.try_purchase(_city.purchase_gateway, _city.unlock_state)).is_true()
	assert_bool(gate.is_open()).is_true()
	assert_bool(_city.unlock_state.is_unlocked()).is_true()
	assert_str(_city.hud.toast_message()).is_equal(CityRun.ROAD_OPEN_TEXT)
	assert_bool(gate.try_purchase(_city.purchase_gateway, _city.unlock_state)).is_false()


func test_the_interact_key_at_the_gate_runs_the_purchase() -> void:
	# The full input path: the interact key at the locked gate drives the
	# purchase through the run's key chain, the touch-first way in.
	_wake_the_crowd()
	var gate := _city.bridge_gate()
	_city.player.global_position = gate.global_position - Vector2(40.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_city._unhandled_input(_interact_press())

	assert_bool(gate.is_open()).is_true()
	assert_bool(_city.unlock_state.is_unlocked()).is_true()


func test_a_paid_state_opens_the_gate_at_build_time() -> void:
	# The unlock state forced unlocked: a run that starts paid, like a reload
	# of a purchase, opens its bridge at bind time, before any input.
	_city.free()
	_city = null
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	city.unlock_state.unlock()
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(city.bridge_gate().is_open()).is_true()


func test_the_payment_writes_the_slot_at_once() -> void:
	# Section 4 with section 18: the purchase records its own save point, so
	# a closed app never loses the paid bridge.
	_city.free()
	_city = null
	var city := SAN_COFFESCO_SCENE.instantiate() as CityRun
	city.save_system = SaveSystem.new(_slot("purchase-save"))
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame
	# The spawn is a cafe entry, so that save point lands first; the purchase
	# writes after it, and the slot keeps the newer point.
	var frames := 0
	while not city.save_system.has_run_state() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(city.save_system.has_run_state()).is_true()

	city.unlock_state.unlock()

	assert_str(city.save_system.saved_save_point()).is_equal(SaveData.POINT_PURCHASE)
	assert_bool(bool(city.save_system.saved_run_state().get("unlock", false))).is_true()


func test_steamtle_has_no_paywall_behind_the_paid_bridge() -> void:
	# The paywall stands at the bridge out of San Coffesco only: the second
	# city sits behind the paid bridge, so its deck carries no gate.
	_city.free()
	_city = null
	var city := STEAMTLE_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(city.city_index).is_equal(2)
	assert_object(city.bridge_gate()).is_null()
	assert_object(city.roads.east()).is_not_null()


func test_pourtland_has_no_paywall_behind_the_paid_bridge() -> void:
	# The last city of the version keeps its deck open the same way.
	_city.free()
	_city = null
	var city := POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(city.city_index).is_equal(3)
	assert_object(city.bridge_gate()).is_null()


func _wake_the_crowd() -> void:
	# Awakened sleepwalkers never hug or stun, so the flow cases stay steady.
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _complete_the_city() -> void:
	_city.player.pickup_item(FUSE_ITEM, 1)
	var tower := _city.city_map().broadcast_tower()
	tower.insert_fuse(_city.player)
	tower.switch_off()
	_city.notify_boss_cured()
	if _city.continue_button.visible:
		_city.continue_button.pressed.emit()


func _walk_east_from_the_city_edge() -> void:
	# Walk the player into the barrier from the tower edge of the city.
	var bounds := _city.city_map().city_size()
	_city.player.global_position = Vector2(bounds.x - 60.0, bounds.y * 0.5)
	await get_tree().physics_frame
	Input.action_press(&"move_right")
	var frames := 0
	while frames < 120:
		await get_tree().physics_frame
		frames += 1
	Input.action_release(&"move_right")


func _interact_press() -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	return event


func _slot(case_name: String) -> String:
	return "%s/%s/slot.json" % [TEST_SAVE_ROOT, case_name]


func _remove_dir(path: String) -> void:
	# Godot 4.7 ships no recursive remove, so the suite walks the tree itself
	# and leaves no test slot behind on the device.
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
	for name: String in entries:
		var child := path.path_join(name)
		if DirAccess.dir_exists_absolute(child):
			_remove_dir(child)
		else:
			DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(path)
