# ABOUTME: Integration tests for the cure weapons of GAME_DESIGN section 11.
# ABOUTME: Covers the Travel Mug ricochet, the Thermos splash, the French Press
# ABOUTME: cone, the Moka Launcher arc, the Minigun stream, and the Auto-Drip
# ABOUTME: Turret, each through the real player scene.
extends GdUnitTestSuite

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const TOUCH_SCENE := preload("res://scenes/touch/touch_controls.tscn")
const SCAVENGE_POINT_SCENE := preload("res://scenes/components/scavenge_point.tscn")
const BALANCE := preload("res://resources/balance/cure_weapons.tres")
const SUPPLY_BALANCE := preload("res://resources/balance/coffee_supply.tres")
const TRAVEL_MUG_ITEM := preload("res://resources/items/gear/travel_mug.tres")

const MAX_FRAMES_TO_WAIT := 600
const SETTLE_MARGIN_FRAMES := 5
# The player spawn sits in open floor, far from any wall or zone.
const PLAYER_SPAWN := Vector2(400, 360)

var _player: Player


func before_test() -> void:
	_player = PLAYER_SCENE.instantiate() as Player
	_player.position = PLAYER_SPAWN
	add_child(auto_free(_player))
	await get_tree().physics_frame


func after_test() -> void:
	# Spawned gear is a plain child of the suite node: free it here, or it
	# outlives the case and lands in the orphan count.
	for child: Node in get_children():
		if not is_instance_valid(child):
			continue
		if child is TravelMug or child is ThermosFlask or child is MokaPot:
			child.free()
		elif child is AutoDripTurret:
			child.free()
	Input.action_release(&"fire_weapon")


func _equip(weapon: CureArmory.Weapon) -> void:
	_player.armory.unlock(weapon)
	assert_bool(_player.armory.equip(weapon)).is_true()


func _spawn_walker(scene: PackedScene, offset: Vector2) -> Sleepwalker:
	# A calm walker stays where the test puts it: it still spots the player
	# and still grabs, but its feet never carry it anywhere.
	var walker := scene.instantiate() as Sleepwalker
	var calm := walker.balance.duplicate() as SleepwalkerBalance
	calm.walk_speed = 0.0
	calm.chase_speed = 0.0
	walker.balance = calm
	walker.position = _player.position + offset
	add_child(auto_free(walker))
	return walker


func _neighbor(offset: Vector2) -> Sleepwalker:
	return _spawn_walker(NEIGHBOR_SCENE, offset)


func _wall_at(offset: Vector2, size: Vector2) -> void:
	# A static wall on the environment layer, the geometry the cups and the
	# flasks break on.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	wall.position = _player.position + offset
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	add_child(auto_free(wall))


func _fire(aim: Vector2 = Vector2.RIGHT) -> bool:
	return _player.try_action(&"fire_weapon", aim)


func _fired_projectile() -> Node:
	# The projectile the last fire left in the tree, or nothing.
	for child: Node in get_children():
		if child is TravelMug or child is ThermosFlask or child is MokaPot:
			return child
	return null


func _watch_exit(node: Node) -> Array:
	# The flag flips when the watched node leaves the tree, so the waits never
	# touch the freed object.
	var tracked: Array = [true]
	node.tree_exited.connect(func() -> void: tracked[0] = false)
	return tracked


func _await_awake(sleeper: Sleepwalker) -> void:
	var frames := 0
	while not sleeper.is_awake() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1


func _await_settled(tracked: Array) -> void:
	var frames := 0
	while bool(tracked[0]) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame


func test_the_travel_mug_wakes_two_sleepers_and_rolls_back() -> void:
	var first := _neighbor(Vector2(120, 0))
	var second := _neighbor(Vector2(260, 20))
	# A near-dry supply proves the free throw better than a full one.
	_player.coffee_supply.cups = 1
	_equip(CureArmory.Weapon.TRAVEL_MUG)

	assert_bool(_fire()).is_true()
	var mug := _fired_projectile()
	assert_object(mug).is_not_null()
	var tracked := _watch_exit(mug)
	await _await_awake(first)
	await _await_awake(second)
	await _await_settled(tracked)

	# The lid keeps the coffee inside: the mug costs nothing and comes home,
	# even straight from an empty pot.
	assert_int(_player.coffee_supply.cups).is_equal(1)
	_player.coffee_supply.cups = 0
	assert_bool(_fire()).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(0)
	assert_bool(bool(tracked[0])).is_false()


func test_the_travel_mug_bounces_around_a_corner() -> void:
	# A wall hides the second sleeper from the throw line. The ricochet
	# ignores the wall, section 11: the mug curves around the corner.
	var first := _neighbor(Vector2(120, 0))
	var hidden := _neighbor(Vector2(280, 0))
	_wall_at(Vector2(200, 0), Vector2(20, 400))
	_equip(CureArmory.Weapon.TRAVEL_MUG)

	assert_bool(_fire()).is_true()
	await _await_awake(first)
	await _await_awake(hidden)


func test_the_travel_mug_bounces_off_the_tinfoil_hat() -> void:
	var hat_man := _spawn_walker(TINFOIL_MAN_SCENE, Vector2(120, 0))
	var behind := _neighbor(Vector2(240, 0))
	_equip(CureArmory.Weapon.TRAVEL_MUG)

	assert_bool(_fire()).is_true()
	await _await_awake(behind)
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	# The hat stops the payload, not the steel: the sleeper stays asleep and
	# the mug still ricochets on.
	assert_bool(hat_man.is_awake()).is_false()
	assert_bool(behind.is_awake()).is_true()


func test_the_thermos_breaks_into_a_wide_splash() -> void:
	var hit := _neighbor(Vector2(150, 0))
	var inside := _neighbor(Vector2(150, -120))
	var far := _neighbor(Vector2(150, 210))
	var cups_before: int = _player.coffee_supply.cups
	_equip(CureArmory.Weapon.THERMOS)

	assert_bool(_fire()).is_true()
	await _await_awake(hit)
	await _await_awake(inside)

	assert_bool(far.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - SUPPLY_BALANCE.thermos_cost)
	assert_float(120.0).is_less_equal(BALANCE.thermos_splash_radius)
	assert_float(210.0).is_greater(BALANCE.thermos_splash_radius)


func test_the_thermos_splash_stops_at_a_wall() -> void:
	# The flask breaks on the wall face. The splash reaches around the burst
	# point but never through the wall, so the sleeper behind it sleeps on.
	_wall_at(Vector2(240, 0), Vector2(20, 400))
	var clear_of_the_wall := _neighbor(Vector2(150, -100))
	var behind := _neighbor(Vector2(330, 0))
	_equip(CureArmory.Weapon.THERMOS)

	assert_bool(_fire()).is_true()
	await _await_awake(clear_of_the_wall)
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(behind.is_awake()).is_false()


func test_the_thermos_splash_spares_the_tinfoil_hat() -> void:
	var hat_man := _spawn_walker(TINFOIL_MAN_SCENE, Vector2(150, 0))
	var beside := _neighbor(Vector2(150, -110))
	_equip(CureArmory.Weapon.THERMOS)

	assert_bool(_fire()).is_true()
	await _await_awake(beside)
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(hat_man.is_awake()).is_false()


func test_the_french_press_pumps_once_and_fires_the_cone_on_the_next_press() -> void:
	var ahead := _neighbor(Vector2(80, 0))
	var angled := _neighbor(Vector2(61, 35))
	var beyond_reach := _neighbor(Vector2(150, 0))
	var beside := _neighbor(Vector2(0, 80))
	var cups_before: int = _player.coffee_supply.cups
	_equip(CureArmory.Weapon.FRENCH_PRESS)

	# One pump loads, and a load wakes nobody and costs nothing.
	assert_bool(_fire()).is_true()
	assert_bool(_player.armory.is_press_loaded()).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before)

	assert_bool(_fire()).is_true()
	assert_bool(ahead.is_awake()).is_true()
	assert_bool(angled.is_awake()).is_true()
	assert_bool(beyond_reach.is_awake()).is_false()
	assert_bool(beside.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - SUPPLY_BALANCE.french_press_cost)


func test_a_dry_supply_keeps_the_press_loaded() -> void:
	_equip(CureArmory.Weapon.FRENCH_PRESS)
	assert_bool(_fire()).is_true()
	_player.coffee_supply.cups = 0

	# The loaded press cannot pay its cups: the shot refuses and the load
	# stays for the refill.
	assert_bool(_fire()).is_false()
	assert_bool(_player.armory.is_press_loaded()).is_true()

	_player.coffee_supply.cups = SUPPLY_BALANCE.french_press_cost
	assert_bool(_fire()).is_true()
	assert_bool(_player.armory.is_press_loaded()).is_false()


func test_the_moka_launcher_brews_during_the_flight_and_splashes_large() -> void:
	var landing := _neighbor(Vector2(300, 0))
	var inside := _neighbor(Vector2(300, 180))
	var far := _neighbor(Vector2(300, 300))
	var cups_before: int = _player.coffee_supply.cups
	_equip(CureArmory.Weapon.MOKA_LAUNCHER)

	assert_bool(_fire()).is_true()
	var peak_arc := 0.0
	var frames := 0
	while not landing.is_awake() and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1
		for child: Node in get_children():
			var pot := child as MokaPot
			if pot != null and is_instance_valid(pot):
				peak_arc = maxf(peak_arc, -pot.visual.position.y)
	await _await_awake(inside)

	# The high arc of section 11: the pot rides visibly above the street, and
	# the brew it made during the flight wakes a large area.
	assert_float(peak_arc).is_greater_equal(100.0)
	assert_bool(landing.is_awake()).is_true()
	assert_bool(inside.is_awake()).is_true()
	assert_bool(far.is_awake()).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - SUPPLY_BALANCE.moka_launcher_cost)
	assert_float(180.0).is_less_equal(BALANCE.moka_splash_radius)
	assert_float(300.0).is_greater(BALANCE.moka_splash_radius)


func test_the_minigun_streams_six_cups_per_second() -> void:
	var ahead := _neighbor(Vector2(100, 0))
	var further := _neighbor(Vector2(220, 0))
	var off_stream := _neighbor(Vector2(100, 90))
	_equip(CureArmory.Weapon.MINIGUN)
	var cups_before: int = _player.coffee_supply.cups

	# A single press owns no shot: only the held stream fires, section 11.
	assert_bool(_fire()).is_false()
	Input.action_press(&"fire_weapon")
	for _frame: int in range(60):
		await get_tree().physics_frame
	Input.action_release(&"fire_weapon")

	assert_int(cups_before - _player.coffee_supply.cups).is_between(5, 7)
	assert_bool(ahead.is_awake()).is_true()
	assert_bool(further.is_awake()).is_true()
	assert_bool(off_stream.is_awake()).is_false()


func test_the_minigun_stream_stops_when_the_supply_runs_dry() -> void:
	var ahead := _neighbor(Vector2(100, 0))
	_equip(CureArmory.Weapon.MINIGUN)
	_player.coffee_supply.cups = 2

	Input.action_press(&"fire_weapon")
	for _frame: int in range(150):
		await get_tree().physics_frame
	Input.action_release(&"fire_weapon")

	# The stream never dips below zero, and the sleeper it sprayed is awake.
	assert_int(_player.coffee_supply.cups).is_equal(0)
	assert_bool(ahead.is_awake()).is_true()


func test_the_auto_drip_turret_drips_alone_below_it() -> void:
	var below := _neighbor(Vector2(30, 0))
	var cups_before: int = _player.coffee_supply.cups
	_equip(CureArmory.Weapon.AUTO_DRIP_TURRET)

	assert_bool(_fire()).is_true()
	assert_int(_player.coffee_supply.cups).is_equal(
		cups_before - SUPPLY_BALANCE.auto_drip_turret_cost
	)
	# The tower works alone, section 11: the player walks far away and the
	# drip still lands.
	_player.position = PLAYER_SPAWN + Vector2(-260, 240)
	await _await_awake(below)


func test_the_auto_drip_turret_reaches_only_what_stands_below_it() -> void:
	var below := _neighbor(Vector2(100, 0))
	var outside := _neighbor(Vector2(200, 0))
	_equip(CureArmory.Weapon.AUTO_DRIP_TURRET)
	assert_bool(_fire()).is_true()

	await _await_awake(below)
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(outside.is_awake()).is_false()
	assert_float(100.0).is_less_equal(BALANCE.turret_drip_radius)
	assert_float(200.0).is_greater(BALANCE.turret_drip_radius)


func test_the_auto_drip_turret_runs_dry_after_the_tank() -> void:
	_equip(CureArmory.Weapon.AUTO_DRIP_TURRET)
	assert_bool(_fire()).is_true()
	var turret := _fired_turret()
	assert_object(turret).is_not_null()
	var tracked := _watch_exit(turret)

	await _await_settled(tracked)

	# The tank pays eight seconds of drips, then the tower folds.
	assert_bool(bool(tracked[0])).is_false()
	assert_float(BALANCE.turret_tank_seconds).is_less_equal(8.5)


func test_the_auto_drip_turret_spares_the_tinfoil_hat() -> void:
	var hat_man := _spawn_walker(TINFOIL_MAN_SCENE, Vector2(40, 0))
	var below := _neighbor(Vector2(-40, 0))
	_equip(CureArmory.Weapon.AUTO_DRIP_TURRET)
	assert_bool(_fire()).is_true()

	await _await_awake(below)
	for _margin: int in range(SETTLE_MARGIN_FRAMES):
		await get_tree().physics_frame

	assert_bool(hat_man.is_awake()).is_false()


func test_fire_and_swap_refuse_without_a_found_weapon() -> void:
	assert_int(_player.armory.equipped_weapon()).is_equal(CureArmory.NO_WEAPON)
	assert_bool(_player.try_action(&"fire_weapon", Vector2.RIGHT)).is_false()
	assert_bool(_player.try_action(&"cycle_weapon")).is_false()
	assert_int(_player.coffee_supply.cups).is_equal(_player.coffee_supply.carry_limit())


func test_a_found_weapon_pickup_unlocks_the_armory() -> void:
	var find_point := SCAVENGE_POINT_SCENE.instantiate() as ScavengePoint
	var drop := ScavengeDrop.new()
	drop.item = TRAVEL_MUG_ITEM
	drop.amount = 1
	find_point.drops = [drop]
	find_point.position = _player.position
	add_child(auto_free(find_point))

	var frames := 0
	while not _player.armory.is_found(CureArmory.Weapon.TRAVEL_MUG) and frames < MAX_FRAMES_TO_WAIT:
		await get_tree().physics_frame
		frames += 1

	# The first find equips itself, section 11, and the gear rides the bag.
	assert_bool(_player.armory.is_found(CureArmory.Weapon.TRAVEL_MUG)).is_true()
	assert_int(_player.armory.equipped_weapon()).is_equal(CureArmory.Weapon.TRAVEL_MUG)
	assert_bool(_player.inventory.has_item("travel_mug")).is_true()


func test_the_weapon_button_fires_and_holds_on_touch() -> void:
	var touch := TOUCH_SCENE.instantiate() as TouchControls
	touch.player = _player
	add_child(auto_free(touch))
	await get_tree().physics_frame
	var weapon_button := touch.button(TouchControls.ButtonKind.WEAPON)
	weapon_button.set_available(true)

	# A tap fires one shot of a discrete weapon, with the stick aim.
	var cups_before: int = _player.coffee_supply.cups
	_equip(CureArmory.Weapon.THERMOS)
	weapon_button.press()
	assert_int(_player.coffee_supply.cups).is_equal(cups_before - SUPPLY_BALANCE.thermos_cost)

	# The hold streams the Minigun and the lift stops it: the cups hold
	# still after the finger leaves the button.
	_equip(CureArmory.Weapon.MINIGUN)
	weapon_button.press()
	Input.flush_buffered_events()
	for _frame: int in range(30):
		await get_tree().physics_frame
	var mid_stream: int = _player.coffee_supply.cups
	weapon_button.lift()
	Input.flush_buffered_events()
	for _frame: int in range(30):
		await get_tree().physics_frame

	assert_int(mid_stream).is_less(_player.coffee_supply.carry_limit())
	assert_int(_player.coffee_supply.cups).is_equal(mid_stream)


func _fired_turret() -> AutoDripTurret:
	for child: Node in get_children():
		var turret := child as AutoDripTurret
		if turret != null:
			return turret
	return null
