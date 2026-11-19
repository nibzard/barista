# ABOUTME: Integration tests for the support tools of GAME_DESIGN section 11.
# ABOUTME: Covers the Tamper push, the Steam Wand parry window, the Portafilter
# ABOUTME: shield and bash, the Iced Sprayer brain freeze, and the Bean Slick.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const BEAN_SLICK_SCENE := preload("res://scenes/components/bean_slick.tscn")
const TOUCH_SCENE := preload("res://scenes/touch/touch_controls.tscn")
const BALANCE := preload("res://resources/balance/support_tools.tres")

const MAX_FRAMES_TO_WAIT := 600
# The player spawn sits in open floor, far from any wall or zone.
const PLAYER_SPAWN := Vector2(400, 360)
# Close enough for the short tool reaches, outside the 18 px hug circle.
const TAMPER_TARGET_OFFSET := Vector2(44, 0)

var _player: Player


func before_test() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = PLAYER_SPAWN
	add_child(auto_free(_player))
	await get_tree().physics_frame


func after_test() -> void:
	# A dropped slick is a plain child of the suite node: free it here, or it
	# outlives the case and lands in the orphan count.
	for child: Node in get_children():
		if is_instance_valid(child) and child is BeanSlick:
			child.free()


func _equip(tool: int) -> void:
	_player.toolbelt.unlock_all()
	assert_bool(_player.toolbelt.equip(tool as SupportToolbelt.Tool)).is_true()


func _spawn_walker(offset: Vector2) -> Sleepwalker:
	# A calm walker stays where the test puts it: it still spots the player,
	# still chases, and still grabs, but its feet never carry it anywhere.
	var walker := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	var calm := walker.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	calm.chase_speed = 0.0
	walker.balance = calm
	walker.position = _player.position + offset
	add_child(auto_free(walker))
	return walker


func _drop_hugger_on_the_player(offset: Vector2) -> Sleepwalker:
	# A hugger that arrives after a swing: it spawns far away outside the
	# sense circle, then the test moves it next to the player, so the grab
	# attempt lands only after the caller has set the scene up.
	var hugger := _spawn_walker(Vector2(300, 300))
	hugger.global_position = _player.global_position + offset
	return hugger


func test_the_tamper_staggers_exactly_one_sleepwalker() -> void:
	var near := _spawn_walker(TAMPER_TARGET_OFFSET)
	var second := _spawn_walker(Vector2(55, 0))
	var behind := _spawn_walker(Vector2(-45, 0))
	_equip(SupportToolbelt.Tool.TAMPER)

	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_bool(near.is_staggered()).is_true()
	assert_bool(second.is_staggered()).is_false()
	assert_bool(behind.is_staggered()).is_false()


func test_the_tamper_pushes_the_target_away() -> void:
	var target := _spawn_walker(TAMPER_TARGET_OFFSET)
	var start := target.global_position
	_equip(SupportToolbelt.Tool.TAMPER)

	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	for _frame: int in range(30):
		await get_tree().physics_frame
	# The push slides the body the balanced distance, then the stagger holds it.
	var moved := target.global_position.distance_to(start)
	assert_float(moved).is_between(35.0, 55.0)


func test_the_tamper_stagger_wears_off_after_the_balanced_time() -> void:
	var target := _spawn_walker(TAMPER_TARGET_OFFSET)
	_equip(SupportToolbelt.Tool.TAMPER)
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()

	var frames := 0
	while target.is_staggered() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	# 1.2 seconds at 60 physics frames per second.
	assert_int(frames).is_between(70, 73)
	assert_bool(target.is_awake()).is_false()


func test_a_stagger_releases_a_held_hug() -> void:
	var hugger := _spawn_walker(Vector2(0, -20))
	var frames := 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_true()

	hugger.stagger(BALANCE.tamper_stagger_seconds)

	assert_bool(_player.is_grabbed()).is_false()
	assert_bool(hugger.is_staggered()).is_true()


func test_the_tamper_wakes_nobody_and_costs_no_coffee() -> void:
	var target := _spawn_walker(TAMPER_TARGET_OFFSET)
	_equip(SupportToolbelt.Tool.TAMPER)
	var cups_before: int = _player.coffee_supply.cups

	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)
	for _frame: int in range(90):
		await get_tree().physics_frame
	assert_bool(target.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)


func test_the_steam_wand_hits_every_sleepwalker_in_the_cone() -> void:
	var ahead := _spawn_walker(Vector2(70, 0))
	var angled := _spawn_walker(Vector2(61, 35))
	var beside := _spawn_walker(Vector2(0, 60))
	var beyond := _spawn_walker(Vector2(115, 0))
	_equip(SupportToolbelt.Tool.STEAM_WAND)

	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_bool(ahead.is_staggered()).is_true()
	assert_bool(angled.is_staggered()).is_true()
	# Beside sits at 90 degrees off the aim, beyond the 45 degree half-cone.
	assert_bool(beside.is_staggered()).is_false()
	# Beyond sits dead ahead but outside the 90 px reach.
	assert_bool(beyond.is_staggered()).is_false()
	assert_bool(ahead.is_awake()).is_false()
	assert_bool(angled.is_awake()).is_false()


func test_a_parried_hug_staggers_the_attacker_for_three_seconds() -> void:
	_equip(SupportToolbelt.Tool.STEAM_WAND)
	# The swing aims away from the hugger, so only the parry window meets her.
	var hugger := _drop_hugger_on_the_player(Vector2(0, -20))
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_bool(_player.toolbelt.is_parrying()).is_true()

	# The hugger spots the player and lunges: the parry lands inside the
	# 0.3 second window, a few frames after the swing.
	var frames := 0
	while not hugger.is_staggered() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
		assert_bool(_player.is_grabbed()).is_false()
	assert_bool(hugger.is_staggered()).is_true()
	# The window spent itself on the one parry.
	assert_bool(_player.toolbelt.is_parrying()).is_false()
	assert_bool(hugger.is_awake()).is_false()

	# The parry stagger holds the hugger off for the full 3.0 seconds of
	# section 14, counted from the parry frame. The frame the stagger ends,
	# the hugger is free to grab again, so the guard covers the held frames.
	var held := 0
	while hugger.is_staggered() and held < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		held += 1
		if hugger.is_staggered():
			assert_bool(_player.is_grabbed()).is_false()
	assert_int(held).is_between(178, 182)

	# The recovered hugger, still at the player's arm, grabs like any other.
	frames = 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(_player.is_grabbed()).is_true()


func test_the_parry_window_shuts_after_three_tenths_of_a_second() -> void:
	_equip(SupportToolbelt.Tool.STEAM_WAND)
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()

	# 25 frames pass: the 0.3 second window is long gone. Only now does the
	# hugger arrive, so her grab attempt meets a shut window.
	for _frame: int in range(25):
		await get_tree().physics_frame
	assert_bool(_player.toolbelt.is_parrying()).is_false()
	var hugger := _drop_hugger_on_the_player(Vector2(0, -20))

	var frames := 0
	while not _player.is_grabbed() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	# The late swing parried nothing: the hug lands and the hugger stands.
	assert_bool(_player.is_grabbed()).is_true()
	assert_bool(hugger.is_staggered()).is_false()


func test_one_swing_stops_one_hug() -> void:
	_equip(SupportToolbelt.Tool.STEAM_WAND)
	var first := _drop_hugger_on_the_player(Vector2(0, -20))
	var second := _drop_hugger_on_the_player(Vector2(0, 20))
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()

	for _frame: int in range(10):
		await get_tree().physics_frame
	# The window bought exactly one parry; the second hugger holds the player.
	assert_int(int(first.is_staggered()) + int(second.is_staggered())).is_equal(1)
	assert_bool(_player.is_grabbed()).is_true()
	assert_bool(_player.toolbelt.is_parrying()).is_false()


func test_the_portafilter_blocks_hugs() -> void:
	_equip(SupportToolbelt.Tool.PORTAFILTER)
	assert_int(_player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.PORTAFILTER)
	var hugger := _spawn_walker(Vector2(0, -20))

	var blocked := false
	for _frame: int in range(60):
		await get_tree().physics_frame
		assert_bool(_player.is_grabbed()).is_false()
		blocked = blocked or hugger.is_staggered()
	# The shield stopped the hug and shoved the hugger out of the grab circle.
	assert_bool(blocked).is_true()
	var distance := hugger.global_position.distance_to(_player.global_position)
	assert_float(distance).is_between(40.0, 60.0)
	assert_bool(hugger.is_awake()).is_false()


func test_the_portafilter_bash_staggers_and_pushes() -> void:
	var target := _spawn_walker(TAMPER_TARGET_OFFSET)
	var start := target.global_position
	_equip(SupportToolbelt.Tool.PORTAFILTER)

	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_bool(target.is_staggered()).is_true()
	var frames := 0
	while target.is_staggered() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	# 1.5 seconds at 60 physics frames per second.
	assert_int(frames).is_between(88, 93)
	assert_float(target.global_position.distance_to(start)).is_between(45.0, 65.0)
	assert_bool(target.is_awake()).is_false()


func test_the_iced_sprayer_slows_the_chase_without_waking() -> void:
	var chaser := _spawn_walker(Vector2(100, 0))
	var running := chaser.balance.duplicate() as SleepwalkerBalance
	running.chase_speed = 70.0
	chaser.balance = running
	var frames := 0
	while chaser.state != Sleepwalker.State.CHASE and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	_equip(SupportToolbelt.Tool.ICED_SPRAYER)
	var cups_before: int = _player.coffee_supply.cups
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)

	# Hold the chase at a fixed 100 px: the speed alone tells the story. The
	# frame the freeze ends, the chase runs free again, so the speed guard
	# covers only the frozen frames.
	var slowed_frames := 0
	while chaser.is_brain_frozen() and slowed_frames < MAX_FRAMES_TO_WAIT:
		chaser.global_position = _player.global_position + Vector2(100, 0)
		await get_tree().physics_frame
		slowed_frames += 1
		if chaser.is_brain_frozen():
			assert_float(chaser.velocity.x).is_equal_approx(-31.5, 1.0)
	# 2.5 seconds at 60 physics frames per second.
	assert_int(slowed_frames).is_between(147, 152)
	assert_bool(chaser.is_awake()).is_false()

	# The freeze wears off and the chase runs at full speed again.
	chaser.global_position = _player.global_position + Vector2(100, 0)
	await get_tree().physics_frame
	assert_float(chaser.velocity.x).is_equal_approx(-70.0, 1.0)
	assert_bool(chaser.is_brain_frozen()).is_false()


func test_the_bean_slick_trips_a_sleepwalker() -> void:
	var walker := _spawn_walker(Vector2(80, 0))
	_equip(SupportToolbelt.Tool.BEAN_SLICK)
	assert_bool(_player.use_tool()).is_true()

	# The walker steps onto the pile under the player.
	walker.global_position = _player.global_position + Vector2(5, 0)
	var frames := 0
	while not walker.is_slipping() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(walker.is_slipping()).is_true()
	assert_bool(walker.is_staggered()).is_true()
	# A slipped sleepwalker lies flat on the floor.
	assert_float(walker.visual.rotation).is_equal_approx(Sleepwalker.SLIP_ROTATION, 0.01)

	var slipped_at := walker.global_position
	while walker.is_staggered():
		await get_tree().physics_frame
	# The feet shot away from the pile: the body slid clear of it.
	assert_float(walker.global_position.distance_to(_player.global_position)).is_greater(40.0)
	assert_float(slipped_at.distance_to(walker.global_position)).is_greater(20.0)
	assert_float(walker.visual.rotation).is_equal(0.0)
	assert_bool(walker.is_awake()).is_false()


func test_the_bean_slick_expires_after_its_lifetime() -> void:
	var slick := BEAN_SLICK_SCENE.instantiate() as BeanSlick
	var brief := BALANCE.duplicate() as SupportToolsBalance
	brief.bean_slick_lifetime_seconds = 0.2
	slick.balance = brief
	add_child(auto_free(slick))
	slick.position = _player.position
	await get_tree().physics_frame
	assert_float(slick.seconds_left()).is_greater(0.0)

	var frames := 0
	while is_instance_valid(slick) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	assert_bool(is_instance_valid(slick)).is_false()


func test_no_support_tool_ever_costs_coffee() -> void:
	_player.coffee_supply.cups = 0
	var tools: Array[int] = [
		SupportToolbelt.Tool.TAMPER,
		SupportToolbelt.Tool.STEAM_WAND,
		SupportToolbelt.Tool.PORTAFILTER,
		SupportToolbelt.Tool.ICED_SPRAYER,
		SupportToolbelt.Tool.BEAN_SLICK,
	]
	_player.toolbelt.unlock_all()
	for tool: int in tools:
		assert_bool(_player.toolbelt.equip(tool as SupportToolbelt.Tool)).is_true()
		assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
		# Section 11: no support tool draws from the coffee supply.
		assert_int(_player.coffee_supply.cups).is_equal(0)


func test_each_swing_waits_for_its_cooldown() -> void:
	_equip(SupportToolbelt.Tool.TAMPER)
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_true()
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_false()

	var frames := 0
	while _player.use_tool(Vector2.RIGHT) == false and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	# 0.5 seconds at 60 physics frames per second.
	assert_int(frames).is_between(28, 32)


func test_the_swap_walks_the_belt_and_an_empty_belt_fires_nothing() -> void:
	assert_bool(_player.toolbelt.has_any()).is_false()
	assert_bool(_player.use_tool(Vector2.RIGHT)).is_false()

	_player.toolbelt.unlock(SupportToolbelt.Tool.TAMPER)
	_player.toolbelt.unlock(SupportToolbelt.Tool.ICED_SPRAYER)
	assert_int(_player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)

	assert_bool(_player.try_action(&"cycle_tool")).is_true()
	assert_int(_player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.ICED_SPRAYER)
	assert_bool(_player.try_action(&"cycle_tool")).is_true()
	assert_int(_player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.TAMPER)


func test_the_touch_tool_and_swap_buttons_drive_the_belt() -> void:
	var board := TOUCH_SCENE.instantiate() as TouchControls
	add_child(auto_free(board))
	board.player = _player
	# The tool buttons wait for the run to open them, like the other context
	# buttons: an empty belt shows no tool buttons at all. The readout waits
	# with them: an empty belt names no tool.
	assert_bool(board.button(TouchControls.ButtonKind.TOOL).visible).is_false()
	assert_bool(board.button(TouchControls.ButtonKind.SWAP).visible).is_false()
	assert_bool(board.tool_readout.visible).is_false()
	board.set_button_available(TouchControls.ButtonKind.TOOL, true)
	board.set_button_available(TouchControls.ButtonKind.SWAP, true)

	var target := _spawn_walker(TAMPER_TARGET_OFFSET)
	_player.toolbelt.unlock_all()
	assert_bool(_player.toolbelt.equip(SupportToolbelt.Tool.TAMPER)).is_true()
	await _until_readout(board, "Tamper")

	_tap(board, TouchControls.ButtonKind.TOOL)
	assert_bool(target.is_staggered()).is_true()

	_tap(board, TouchControls.ButtonKind.SWAP)
	assert_int(_player.toolbelt.equipped_tool()).is_equal(SupportToolbelt.Tool.STEAM_WAND)
	await _until_readout(board, "Steam Wand")
	assert_bool(board.tool_readout.visible).is_true()


func _tap(board: TouchControls, kind: TouchControls.ButtonKind) -> void:
	# The tap fires its effect synchronously, so no frame wait is needed.
	var center: Vector2 = board.button(kind).get_global_rect().get_center()
	board._input(_touch(true, center))
	board._input(_touch(false, center))


func _until_readout(board: TouchControls, tool_name: String) -> void:
	# The readout polls the belt once per process frame, so the wait runs on
	# the drawn text, never on a fixed frame count.
	var frames := 0
	while board.tool_readout.text != tool_name and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().process_frame
		frames += 1
	assert_str(board.tool_readout.text).is_equal(tool_name)


func _touch(pressed: bool, position: Vector2) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.pressed = pressed
	event.position = position
	event.index = 1
	return event
