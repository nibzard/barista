# ABOUTME: Integration tests for the touch controls: simulated touch events
# ABOUTME: drive the core actions of the game with no keyboard, section 4.
extends GdUnitTestSuite

const CITY_SCENE := preload("res://scenes/city/san_coffesco.tscn")
const INTRO_SCENE := preload("res://scenes/city/san_coffesco_intro.tscn")
const CITY_RUN_SCENE := preload("res://scenes/city/city_run.tscn")
const CITY_DEFINITION := preload("res://resources/city/san_coffesco.tres")
const CITY_BALANCE := preload("res://resources/balance/city.tres")
const TOUCH_BALANCE := preload("res://resources/balance/touch_controls.tres")
const SCRAP_PART := preload("res://resources/items/materials/scrap_part.tres")
const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

const MAX_FRAMES_TO_WAIT := 600
const RIDE_FRAMES_TO_WAIT := 1600

var _city: CityRun
var _ride_run: CityRun


func before_test() -> void:
	_city = CITY_SCENE.instantiate() as CityRun
	add_child(auto_free(_city))
	# The run builds its bodies inside _ready. The area overlaps report from
	# the third physics step onward, so settle three frames before every case.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	# A failed assert can stop a test mid-drag; never leak a held stick.
	for run: CityRun in [_city, _ride_run]:
		if is_instance_valid(run) and is_instance_valid(run.touch_controls):
			run.touch_controls.stick().force_release()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func test_the_layer_sits_ready_for_play() -> void:
	assert_object(_city.touch_controls).is_not_null()
	assert_object(_city.touch_controls.player).is_same(_city.player)
	assert_bool(_city.touch_controls.visible).is_true()
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.USE).visible).is_true()
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.SERVE).visible).is_true()
	# The context buttons wait for the run to open them.
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.REFILL).visible).is_false()
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.VAN).visible).is_false()


func test_the_coasters_wear_chalk_icons_not_words() -> void:
	# ART_DIRECTION section 11: icons replace words on the touch buttons.
	# Cup for throw, mug for drink, roll arrow for dodge; the layer applies
	# its map when it enters the tree.
	var controls := _city.touch_controls
	for kind: TouchControls.ButtonKind in TouchControls.ButtonKind.values():
		assert_int(controls.button(kind).icon).is_equal(TouchControls.icon_for(kind))
	assert_int(controls.button(TouchControls.ButtonKind.THROW).icon).is_equal(TouchButton.Icon.CUP)
	assert_int(controls.button(TouchControls.ButtonKind.DRINK).icon).is_equal(TouchButton.Icon.MUG)
	assert_int(controls.button(TouchControls.ButtonKind.DODGE).icon).is_equal(
		TouchButton.Icon.ROLL_ARROW
	)


func test_the_stick_moves_the_player() -> void:
	_wake_the_crowd()
	var start := _city.player.global_position
	_hold_stick(Vector2.RIGHT)

	assert_float(Input.get_action_strength(&"move_right")).is_equal(1.0)
	var frames := 0
	while _city.player.global_position.distance_to(start) < 80.0 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_float(_city.player.global_position.x - start.x).is_greater(80.0)

	_release_stick()
	await get_tree().physics_frame
	assert_float(Input.get_action_strength(&"move_right")).is_equal(0.0)
	assert_vector(_city.player.velocity).is_equal(Vector2.ZERO)


func test_the_stick_reads_analog_tilt() -> void:
	var stick := _city.touch_controls.stick()
	var center := stick.get_global_rect().get_center()
	_city.touch_controls._input(_touch(true, center))
	# Halfway between the dead zone and the rim: a light but real tilt.
	var halfway := (
		TOUCH_BALANCE.stick_dead_zone_pixels
		+ (TOUCH_BALANCE.stick_max_distance_pixels - TOUCH_BALANCE.stick_dead_zone_pixels) * 0.5
	)
	_city.touch_controls._input(_drag(center + Vector2(halfway, 0.0)))

	assert_float(Input.get_action_strength(&"move_right")).is_equal_approx(0.5, 0.01)
	_release_stick()


func test_the_throw_button_throws_where_the_stick_aims() -> void:
	_wake_the_crowd_except_first()
	var target := _city.crowd_enemy(0)
	target.set_physics_process(false)
	target.velocity = Vector2.ZERO
	target.global_position = _city.player.global_position + Vector2(150.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var cups_before := _city.player.coffee_supply.cups
	_hold_stick(Vector2.RIGHT)
	_tap(TouchControls.ButtonKind.THROW)

	var cup := _find_flying_cup()
	assert_object(cup).is_not_null()
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before - 1)

	var frames := 0
	while is_instance_valid(cup) and not target.is_awake() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(target.is_awake()).is_true()
	_release_stick()


func test_the_throw_button_mashes_a_hug_free() -> void:
	_wake_the_crowd()
	_city.player.set_grabbed_by(_city.crowd_enemy(0))
	assert_bool(_city.player.is_grabbed()).is_true()

	for i: int in range(_city.player.balance.hug_mash_presses_to_break):
		_tap(TouchControls.ButtonKind.THROW)

	assert_bool(_city.player.is_grabbed()).is_false()
	assert_bool(_city.player.is_invulnerable()).is_true()


func test_the_dodge_button_rolls() -> void:
	_wake_the_crowd()
	_hold_stick(Vector2.RIGHT)
	_tap(TouchControls.ButtonKind.DODGE)

	assert_bool(_city.player.is_dodging()).is_true()
	assert_bool(_city.player.is_invulnerable()).is_true()
	_release_stick()


func test_a_tap_on_the_world_does_not_throw_behind_the_button() -> void:
	# The THROW button owns touch throws. The left click a tap emulates must
	# not also throw a cup toward the tap position.
	_wake_the_crowd()
	var cups_before := _city.player.coffee_supply.cups
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.device = TouchControls.EMULATED_MOUSE_DEVICE
	tap.position = Vector2(640.0, 360.0)

	_city.player._unhandled_input(tap)
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before)
	assert_object(_find_flying_cup()).is_null()

	# The key path still throws: the guard blocks only the emulated click.
	var press := InputEventAction.new()
	press.action = &"throw_coffee"
	press.pressed = true
	_city.player._unhandled_input(press)
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before - 1)
	assert_object(_find_flying_cup()).is_not_null()


func test_the_drink_button_opens_the_drink_channel() -> void:
	_tap(TouchControls.ButtonKind.DRINK)
	assert_bool(_city.player.sleep_meter.is_drinking()).is_true()


func test_the_refill_button_fills_the_supply_inside_the_cafe() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	player.global_position = _city.city_map().cafe_spawn().global_position
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.REFILL).visible).is_true()
	_tap(TouchControls.ButtonKind.REFILL)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(player.coffee_supply.cups).is_equal(player.coffee_supply.carry_limit())


func test_the_refill_button_hides_outside_the_cafe() -> void:
	_wake_the_crowd()
	var player := _city.player
	player.coffee_supply.spend_cups(player.coffee_supply.cups)
	player.global_position = _tower().global_position
	# The area overlap report follows the move one step behind, and the run
	# reads it on the next physics tick after that.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.REFILL).visible).is_false()
	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.BREW).visible).is_false()


func test_the_use_button_upgrades_the_van() -> void:
	await _own_the_van_with_a_walk()
	_city.player.pickup_item(SCRAP_PART, _city.van().balance.kitchen_scrap_cost)

	_tap(TouchControls.ButtonKind.USE)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_int(_city.van_state.level()).is_equal(MobileCafe.Level.KITCHEN)


func test_the_van_button_parks_the_field_base_where_the_player_stands() -> void:
	await _own_the_van_with_a_walk()
	_city.van_state.load_state(MobileCafe.Level.FIELD_CAFE)
	var park := Vector2(900.0, 300.0)
	_city.player.global_position = park
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.touch_controls.button(TouchControls.ButtonKind.VAN).visible).is_true()
	_tap(TouchControls.ButtonKind.VAN)
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_bool(_city.van().is_field_base_open()).is_true()
	assert_vector(_city.van().global_position).is_equal(park)


func test_the_use_button_runs_the_tower_beat() -> void:
	_wake_the_crowd()
	var tower := _tower()
	var tower_block := _city.city_map().find_block_of_kind(CityBlock.Kind.TOWER)
	_city.player.global_position = tower_block.tower_fuse_point().global_position

	var frames := 0
	while _city.player.inventory.count("fuse") < 1 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_city.player.inventory.count("fuse")).is_equal(1)

	_city.player.global_position = tower.global_position
	await _await_player_at_tower(tower)

	_tap(TouchControls.ButtonKind.USE)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.FUSED)

	_tap(TouchControls.ButtonKind.USE)
	frames = 0
	while tower.phase != BroadcastTower.Phase.BIRDSONG and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.BIRDSONG)
	assert_str(_city.hud.toast_message()).is_equal(CityRun.WAKE_UP_RESTORED_TEXT)


func test_the_controls_stand_down_while_the_player_is_locked() -> void:
	_wake_the_crowd()
	var cups_before := _city.player.coffee_supply.cups
	_city.player.set_input_locked(true)
	await _until_visible(_city, false)

	assert_bool(_city.touch_controls.visible).is_false()
	_tap(TouchControls.ButtonKind.THROW)
	assert_int(_city.player.coffee_supply.cups).is_equal(cups_before)
	assert_object(_find_flying_cup()).is_null()

	_city.player.set_input_locked(false)
	await _until_visible(_city, true)
	assert_bool(_city.touch_controls.visible).is_true()


func test_the_dex_opens_from_a_touch_on_the_phone_button() -> void:
	assert_bool(_city.hud.dex_button.visible).is_true()
	var center := _city.hud.dex_button.get_global_rect().get_center()
	get_tree().root.push_input(_touch(true, center), true)
	await get_tree().process_frame
	get_tree().root.push_input(_touch(false, center), true)
	await get_tree().process_frame

	assert_bool(_city.hud.dex_app.is_open()).is_true()
	# The phone owns the screen: the play controls stand down behind it.
	await _until_visible(_city, false)
	assert_bool(_city.touch_controls.visible).is_false()


func test_the_completion_screen_hands_the_controls_back() -> void:
	# T093: the city-complete beat used to own the screen forever. No dismiss
	# path existed, so the touch layer stood down for good and a touch-only
	# player froze behind the victory screen. The continue tap ends the beat,
	# the controls return, and the walk east rides them to the travel trigger.
	_city.free()
	_city = null
	var run := CITY_RUN_SCENE.instantiate() as CityRun
	run.definition = CITY_DEFINITION
	run.balance = CITY_BALANCE
	_ride_run = run
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_wake_the_crowd_on(run)

	# Drive the city to completion: fuse, switch, cure.
	run.player.pickup_item(FUSE_ITEM, 1)
	var tower := run.city_map().broadcast_tower()
	tower.insert_fuse(run.player)
	tower.switch_off()
	run.notify_boss_cured()

	# The completion screen owns the screen and the play controls stood down.
	assert_bool(run.overlay.visible).is_true()
	assert_bool(run.status_label.visible).is_true()
	assert_bool(run.restart_button.visible).is_false()
	assert_bool(run.continue_button.visible).is_true()
	await _until_visible(run, false)
	assert_bool(run.touch_controls.visible).is_false()

	# A touch on the continue button dismisses the screen.
	await _tap_the_continue_button(run)
	var frames := 0
	while run.overlay.visible and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	assert_bool(run.overlay.visible).is_false()
	assert_bool(run.status_label.visible).is_false()
	assert_bool(run.continue_button.visible).is_false()

	# The touch layer returns and the stick carries the walk east.
	await _until_visible(run, true)
	assert_bool(run.touch_controls.visible).is_true()
	var arrivals: Array[int] = []
	run.east_road_taken.connect(func() -> void: arrivals.append(1))
	run.unlock_state.unlock()
	run.player.global_position = run.roads.east().global_position - Vector2(100.0, 0.0)
	await get_tree().physics_frame
	_hold_stick_on(run, Vector2.RIGHT)
	frames = 0
	while arrivals.is_empty() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	_release_stick_on(run)
	assert_int(frames).is_less(MAX_FRAMES_TO_WAIT)
	assert_int(arrivals.size()).is_equal(1)


func test_the_intro_rides_on_touch_alone() -> void:
	# The first ten minutes with no keyboard at all: every input verb is a
	# simulated touch on the on-screen controls, section 19.
	# The plain city of before_test must go first: two runs share one physics
	# space, and its idle player would sit inside the intro cafe zone forever.
	_city.free()
	_city = null
	var run := INTRO_SCENE.instantiate() as CityRun
	_ride_run = run
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var director := run.get_node(^"Tutorial") as TutorialDirector
	assert_int(director.flow.current_step()).is_equal(TutorialFlow.Step.VIDEO)
	# The wandering cafe crowd would race the scripted beats for the player:
	# park it far west, like the tutorial suite does. The hug lesson pulls its
	# own Neighbor in by hand.
	_park_the_crowd_west(run)

	# Step 1: any tap skips the video.
	get_tree().root.push_input(_touch(true, Vector2(640.0, 300.0)), true)
	await get_tree().process_frame
	assert_int(director.flow.current_step()).is_equal(TutorialFlow.Step.MOVE)
	# The play controls hid for the video: wait for their return before the
	# ride drives them.
	await _until_visible(run, true)

	# Step 2: the stick moves the player.
	_hold_stick_on(run, Vector2.RIGHT)
	await _ride_until(run, TutorialFlow.Step.DRINK)
	_release_stick_on(run)

	# Step 3: the DRINK button fills the meter.
	_tap_on(run, TouchControls.ButtonKind.DRINK)
	await _ride_until(run, TutorialFlow.Step.DOOR)

	# Step 4: the stick walks the player out of the cafe. The cafe is a real
	# building now (T063), so the ride steers for the south door instead of
	# holding straight down into the wall west of it.
	var cafe_building := run.city_map().find_block_of_kind(CityBlock.Kind.CAFE).cafe_building()
	var door_world := cafe_building.global_position + cafe_building.door_position()
	_hold_stick_on(run, (door_world - run.player.global_position).normalized())
	await _ride_until(run, TutorialFlow.Step.THROW)
	_release_stick_on(run)

	# Step 5: the stick aims, the THROW button wakes him.
	_park_the_crowd_west(run)
	var walker := director.window_neighbor()
	walker.set_physics_process(false)
	walker.velocity = Vector2.ZERO
	walker.global_position = run.player.global_position + Vector2(150.0, 0.0)
	_hold_stick_on(run, Vector2.RIGHT)
	_tap_on(run, TouchControls.ButtonKind.THROW)
	await _ride_until(run, TutorialFlow.Step.POLE)
	_release_stick_on(run)

	# Step 6: the stick walks back into the safe zone, then rests inside it:
	# the lesson needs two seconds of safe-zone quiet.
	var cafe_block := run.city_map().find_block_of_kind(CityBlock.Kind.CAFE)
	var cafe_center := cafe_block.global_position + cafe_block.size * 0.5
	_hold_stick_on(run, (cafe_center - run.player.global_position).normalized())
	var frames := 0
	while not cafe_block.safe_zone().has_player_inside() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	_release_stick_on(run)
	await _ride_until(run, TutorialFlow.Step.SURVIVOR)

	# Step 7: the stick walks to the survivor at the door.
	_hold_stick_on(
		run, (director.survivor_npc().global_position - run.player.global_position).normalized()
	)
	await _ride_until(run, TutorialFlow.Step.ROAD)
	_release_stick_on(run)

	# Step 8: the three road lessons. The brew needs the cafe pot, so the
	# stick walks back in first; the BREW button opens the dial, and a tap on
	# the dial stops the marker.
	_hold_stick_on(run, (cafe_center - run.player.global_position).normalized())
	frames = 0
	while (
		run.player.global_position.distance_to(cafe_center) > 100.0 and frames < MAX_FRAMES_TO_WAIT
	):
		await get_tree().physics_frame
		frames += 1
	_release_stick_on(run)
	_tap_on(run, TouchControls.ButtonKind.BREW)
	var dial := director.grind_dial_view()
	frames = 0
	while dial == null and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		dial = director.grind_dial_view()
		frames += 1
	assert_object(dial).is_not_null()
	await _until_visible(run, false)
	assert_bool(run.touch_controls.visible).is_false()
	while dial.model.position < dial.model.zone_start() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	dial._unhandled_input(_touch(true, Vector2(640.0, 360.0)))
	await get_tree().physics_frame
	# The dial held the player locked; wait for the controls to return before
	# the next lesson taps them.
	await _until_visible(run, true)

	# The dodge lesson: one DODGE tap.
	_tap_on(run, TouchControls.ButtonKind.DODGE)
	await get_tree().physics_frame

	# The hug lesson: a Neighbor grabs, and the THROW taps mash him free.
	var enemy := run.crowd_enemy(0)
	enemy.global_position = run.player.global_position + Vector2(14.0, 0.0)
	frames = 0
	while not run.player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(run.player.is_grabbed()).is_true()
	while run.player.is_grabbed():
		_tap_on(run, TouchControls.ButtonKind.THROW)
		await get_tree().physics_frame
	await _ride_until(run, TutorialFlow.Step.TOWER)

	# Step 9: the USE button inserts the scavenged fuse and switches the tower.
	var tower := run.city_map().broadcast_tower()
	var tower_block := run.city_map().find_block_of_kind(CityBlock.Kind.TOWER)
	run.player.global_position = tower_block.tower_fuse_point().global_position
	frames = 0
	while run.player.inventory.count("fuse") < 1 and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	run.player.global_position = tower.global_position
	await _await_player_at_tower(tower)
	_tap_on(run, TouchControls.ButtonKind.USE)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_int(tower.phase).is_equal(BroadcastTower.Phase.FUSED)
	_tap_on(run, TouchControls.ButtonKind.USE)

	# Step 10: the finale plays out and hands the controls back.
	frames = 0
	while not director.flow.is_done() and frames < RIDE_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(director.flow.is_done()).is_true()
	await _until_visible(run, true)
	assert_bool(run.touch_controls.visible).is_true()


func _until_visible(run: CityRun, want: bool) -> void:
	# The visibility flip happens in a _process tick that can land one frame
	# after the state change, so poll for it instead of trusting one frame.
	var frames := 0
	while run.touch_controls.visible != want and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1


func _tap_the_continue_button(run: CityRun) -> void:
	# The continue button answers a plain touch, like every on-screen control.
	var center := run.continue_button.get_global_rect().get_center()
	get_tree().root.push_input(_touch(true, center), true)
	await get_tree().process_frame
	get_tree().root.push_input(_touch(false, center), true)


func _wake_the_crowd_on(run: CityRun) -> void:
	# Awakened sleepwalkers never hug, so the completion ride stays steady.
	for i: int in range(run.crowd_count()):
		run.crowd_enemy(i).wake_up()


func _hold_stick(direction: Vector2) -> void:
	_hold_stick_on(_city, direction)


func _hold_stick_on(run: CityRun, direction: Vector2) -> void:
	var center := run.touch_controls.stick().get_global_rect().get_center()
	var distance := TOUCH_BALANCE.stick_max_distance_pixels
	run.touch_controls._input(_touch(true, center))
	run.touch_controls._input(_drag(center + direction.normalized() * distance))


func _release_stick() -> void:
	_release_stick_on(_city)


func _release_stick_on(run: CityRun) -> void:
	run.touch_controls._input(_touch(false, Vector2.ZERO))


func _tap(kind: TouchControls.ButtonKind) -> void:
	_tap_on(_city, kind)


func _tap_on(run: CityRun, kind: TouchControls.ButtonKind) -> void:
	var button := run.touch_controls.button(kind)
	var center := button.get_global_rect().get_center()
	run.touch_controls._input(_touch(true, center, 1))
	run.touch_controls._input(_touch(false, center, 1))
	# A tap can queue a synthesized action press; the flush pushes it out at
	# once, because under load the headless input transport drops buffered
	# events.
	Input.flush_buffered_events()


func _touch(pressed: bool, position: Vector2, index := 0) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	touch.position = position
	return touch


func _drag(position: Vector2) -> InputEventScreenDrag:
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = position
	return drag


func _ride_until(run: CityRun, step: TutorialFlow.Step) -> void:
	var frames := 0
	while _director_step(run) != step and frames < RIDE_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_int(_director_step(run)).is_equal(step)


func _director_step(run: CityRun) -> TutorialFlow.Step:
	var director := run.get_node(^"Tutorial") as TutorialDirector
	return director.flow.current_step()


func _wake_the_crowd() -> void:
	for i: int in range(_city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _wake_the_crowd_except_first() -> void:
	for i: int in range(1, _city.crowd_count()):
		_city.crowd_enemy(i).wake_up()


func _park_the_crowd_west(run: CityRun) -> void:
	# The wandering crowd would race the scripted Neighbor for the aim cone.
	for i: int in range(run.crowd_count()):
		run.crowd_enemy(i).global_position = Vector2(-500.0, 360.0)


func _find_flying_cup() -> CoffeeCup:
	for node: Node in _city.get_children():
		var cup := node as CoffeeCup
		if cup != null:
			return cup
	return null


func _tower() -> BroadcastTower:
	return _city.city_map().broadcast_tower()


func _await_player_at_tower(tower: BroadcastTower) -> void:
	# The tap must land only after the tower's own poll has seen the player:
	# the tower area reports a teleport after a physics flush, and the tower
	# reads that flush one step later in its physics tick. The wait runs on
	# the outcome, never on a fixed frame count, plus one extra step for the
	# tower's poll.
	var frames := 0
	while not _tower_holds_player(tower) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	await get_tree().physics_frame


func _tower_holds_player(tower: BroadcastTower) -> bool:
	for body: Node2D in tower.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func _own_the_van_with_a_walk() -> void:
	# The touch stick walks the player into the van's notice area: the gift
	# lands through movement alone, section 10.
	_wake_the_crowd()
	var van := _city.van()
	_city.player.global_position = van.global_position + Vector2(-120.0, 0.0)
	_hold_stick(Vector2.RIGHT)
	var frames := 0
	while not _city.van_state.is_owned() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	_release_stick()
	assert_bool(_city.van_state.is_owned()).is_true()
	await get_tree().physics_frame
	await get_tree().physics_frame
