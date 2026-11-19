# ABOUTME: Integration tests for the serve action: the barista hands one brewed
# ABOUTME: cup straight to the sleeper in arm's reach, no throw, section 6.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CUP_SCENE := preload("res://scenes/projectiles/coffee_cup.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const POURTLAND_SCENE := preload("res://scenes/city/pourtland.tscn")
const TURKISH_POT_ITEM := preload("res://resources/items/appliances/turkish_pot.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")

var _player: Player


func before_test() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.cup_scene = CUP_SCENE
	_player.position = Vector2(200, 200)
	add_child(auto_free(_player))
	await get_tree().physics_frame


func test_the_serve_hands_the_standard_cup_to_a_sleeper_in_reach() -> void:
	var neighbor := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	await get_tree().physics_frame
	var cups_before := _player.coffee_supply.cups

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(neighbor.is_awake()).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - 1)


func test_no_sleeper_in_reach_refuses_the_serve() -> void:
	var far := _frozen_walker(NEIGHBOR_SCENE, Vector2(400, 0))
	await get_tree().physics_frame
	var cups_before := _player.coffee_supply.cups

	assert_bool(_player.try_action(&"serve_coffee")).is_false()
	assert_bool(far.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)


func test_the_serve_spends_the_brewed_cup_from_the_hand() -> void:
	# The brewed batch of the minigames rides the serve like it rides the
	# throw: the payload goes out, the batch counts one cup down.
	var neighbor := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	assert_bool(_player.brew_hand.receive(_turkish_cup(), 2)).is_true()

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(neighbor.is_awake()).is_true()
	assert_int(_player.brew_hand.cups_left()).is_equal(1)
	assert_str(_player.brew_hand.active_payload().method.method_id).is_equal("turkish")


func test_a_served_turkish_cup_wakes_the_tinfoil_man() -> void:
	# The acceptance case of the task: the Turkish cure reaches him through
	# gameplay, and the wake holds after the serve.
	var tinfoil := _frozen_walker(TINFOIL_MAN_SCENE, Vector2(40, 0))
	assert_bool(_player.brew_hand.receive(_turkish_cup(), 1)).is_true()

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(tinfoil.is_awake()).is_true()

	for _frame: int in range(60):
		await get_tree().physics_frame
	assert_bool(tinfoil.is_awake()).is_true()
	# Awake walkers leave the serve scan, so a second serve finds nobody.
	assert_bool(_player.try_action(&"serve_coffee")).is_false()


func test_the_hat_does_not_stop_the_serve_but_the_cure_decides() -> void:
	# The hat stops the throw, section 6, not the handoff: a served plain cup
	# reaches him and spends like a thrown wrong cup, and the brewed Turkish
	# cure follows the same path to the wake.
	var tinfoil := _frozen_walker(TINFOIL_MAN_SCENE, Vector2(40, 0))
	var cups_before := _player.coffee_supply.cups

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(tinfoil.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - 1)

	assert_bool(_player.brew_hand.receive(_turkish_cup(), 1)).is_true()
	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(tinfoil.is_awake()).is_true()


func test_the_serve_targets_the_nearest_sleeper() -> void:
	var near := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	var far := _frozen_walker(NEIGHBOR_SCENE, Vector2(55, 0))
	await get_tree().physics_frame

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(near.is_awake()).is_true()
	assert_bool(far.is_awake()).is_false()


func test_the_serve_skips_awake_walkers() -> void:
	var awake := _frozen_walker(NEIGHBOR_SCENE, Vector2(30, 0))
	awake.wake_up()
	var sleeping := _frozen_walker(NEIGHBOR_SCENE, Vector2(50, 0))
	await get_tree().physics_frame

	assert_bool(_player.try_action(&"serve_coffee")).is_true()
	assert_bool(sleeping.is_awake()).is_true()
	assert_bool(awake.is_awake()).is_true()


func test_a_stunned_player_cannot_serve() -> void:
	var neighbor := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	await get_tree().physics_frame
	_player.apply_stun(1.0)
	var cups_before := _player.coffee_supply.cups

	assert_bool(_player.try_action(&"serve_coffee")).is_false()
	assert_bool(neighbor.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)


func test_the_serve_key_hands_the_cup() -> void:
	# The serve rides the normal input action pipeline, the same action the
	# touch button fires.
	var neighbor := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	await get_tree().physics_frame

	_player._unhandled_input(_key(KEY_G))
	assert_bool(neighbor.is_awake()).is_true()


func test_a_grabbed_player_mashes_the_hug_instead_of_serving() -> void:
	var neighbor := _frozen_walker(NEIGHBOR_SCENE, Vector2(40, 0))
	await get_tree().physics_frame
	_player.set_grabbed_by(neighbor)
	var cups_before := _player.coffee_supply.cups

	for _press: int in range(5):
		assert_bool(_player.try_action(&"serve_coffee")).is_false()
	assert_bool(_player.is_grabbed()).is_false()
	assert_bool(neighbor.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)


func test_the_live_pourtland_path_serves_a_brewed_turkish_cup_past_the_hat() -> void:
	# The whole live chain on the real city: room in the hand, the Turkish
	# brew through the stand behind the scavenged pot, then the SERVE touch
	# button hands the brewed cup to a Tinfoil Man of the Pourtland crowd.
	var city := POURTLAND_SCENE.instantiate() as CityRun
	add_child(auto_free(city))
	for _settle: int in range(4):
		await get_tree().physics_frame

	for i: int in range(city.crowd_count()):
		city.crowd_enemy(i).global_position = Vector2(-800.0, 360.0)
	city.player.throw_cup(Vector2.LEFT)
	await get_tree().physics_frame

	city.player.inventory.add(TURKISH_POT_ITEM, 1)
	city.player.brewing_skills.load_state({"turkish": 10})
	city._unhandled_input(_key(KEY_B))
	var stand := city.brew_pot.stand()
	assert_object(stand).is_not_null()
	stand.select_recipe(LIBRARY.find_recipe("turkish_cup"))
	stand.begin_auto_brew()
	await get_tree().process_frame
	assert_object(city.brew_pot.stand()).is_null()
	var payload := city.player.brew_hand.active_payload()
	assert_str(payload.method.method_id).is_equal("turkish")

	var tinfoil := _find_tinfoil_man(city)
	assert_object(tinfoil).is_not_null()
	var calm := tinfoil.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	calm.chase_speed = 0.0
	tinfoil.balance = calm
	tinfoil.global_position = city.player.global_position + Vector2(0, -40)
	await get_tree().physics_frame

	var cups_before := city.player.coffee_supply.cups
	_tap_serve(city)
	assert_bool(tinfoil.is_awake()).is_true()
	assert_int(city.player.coffee_supply.cups).is_equal(cups_before - 1)


func _frozen_walker(scene: PackedScene, offset: Vector2) -> Sleepwalker:
	# A walker with a frozen gait stands where it spawned, so the serve reach
	# stays honest through every frame of the case.
	var walker := scene.instantiate() as Sleepwalker
	var calm := walker.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	calm.chase_speed = 0.0
	walker.balance = calm
	walker.position = _player.position + offset
	add_child(auto_free(walker))
	return walker


func _turkish_cup() -> BrewedCup:
	return BrewedCup.new(
		LIBRARY.find_bean("house"),
		LIBRARY.find_roast("medium"),
		LIBRARY.find_method("turkish"),
		"",
		85.0
	)


func _find_tinfoil_man(city: CityRun) -> Sleepwalker:
	for i: int in range(city.crowd_count()):
		var walker := city.crowd_enemy(i)
		if walker.enemy_type.type_id == "tinfoil_man":
			return walker
	return null


func _tap_serve(city: CityRun) -> void:
	# The SERVE touch button through the raw touch entry point, the same path
	# a finger takes, section 4.
	var button := city.touch_controls.button(TouchControls.ButtonKind.SERVE)
	var center := button.get_global_rect().get_center()
	city.touch_controls._input(_touch(true, center, 1))
	city.touch_controls._input(_touch(false, center, 1))


func _touch(pressed: bool, position: Vector2, index := 0) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = pressed
	touch.position = position
	return touch


func _key(code: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = true
	return key
