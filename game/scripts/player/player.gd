# ABOUTME: Player is the barista: moves, dodges, throws cups, drinks coffee to stay awake.
# ABOUTME: Input handling stays here; the meter, the supply, and the wake-ups are components.
class_name Player
extends CharacterBody2D

signal woke_in_cafe
signal died

# Section 24: the Moonwalker teaches the Moonwalk dodge, a cosmetic roll
# variant with no power, only style.
enum DodgeStyle { ROLL, MOONWALK }

const STANDARD_BEAN_ID := "house"
const STANDARD_ROAST_ID := "medium"
const STANDARD_METHOD_ID := "filter"
const THERMOS_BELT_ID := "thermos_belt"
const COFFEE_SEEDLING_ID := "coffee_seedling"
# A dazzled player glows dazed yellow until the stun wears off.
const STUN_MODULATE := Color(1.0, 0.92, 0.45, 1.0)
# The Moonwalk dodge leans the barista back through the whole roll: style,
# never power, section 24.
const MOONWALK_LEAN := -0.3

@export var balance: PlayerBalance
@export var meter_balance: SleepMeterBalance
@export var supply_balance: CoffeeSupplyBalance
@export var wake_ups_balance: WakeUpsBalance
@export var cup_balance: CoffeeCupBalance
@export var support_tools_balance: SupportToolsBalance
@export var cluster_bomb_balance: ClusterBombBalance
@export var cure_weapons_balance: CureWeaponsBalance
@export var brewing_library: BrewingLibrary
@export var brewing_balance: BrewingBalance
# The cosmetic options of section 5: the run paints the created barista
# through the catalog, never through hardcoded looks.
@export var appearance_catalog: AppearanceCatalog
@export var cup_scene: PackedScene
@export var bean_slick_scene: PackedScene
@export var coffee_plant_scene: PackedScene
# The cure weapon scenes of section 11: the thrown gear and the deployable
# tower the armory spawns.
@export var travel_mug_scene: PackedScene
@export var thermos_scene: PackedScene
@export var moka_pot_scene: PackedScene
@export var auto_drip_turret_scene: PackedScene

# The created look of section 5, pure cosmetics. A run assigns the slot look
# and the setter repaints the placeholder body; null keeps the scene look.
# The roll look of the player. The Moonwalk variant changes only the lean
# of the dodge: same speed, same window, same invulnerability.
var dodge_style: DodgeStyle = DodgeStyle.ROLL

var appearance: CharacterAppearance = null:
	set(new_appearance):
		appearance = new_appearance
		BaristaPortrait.build(visual, appearance, appearance_catalog)

var _asleep := false
var _input_locked := false
var _grabber: Sleepwalker = null
var _mash_presses := 0
var _dodge_time_left := 0.0
var _dodge_cooldown_time_left := 0.0
var _grace_time_left := 0.0
var _stun_time_left := 0.0
var _dodge_direction := Vector2.RIGHT
var _last_move_direction := Vector2.RIGHT
# The aim the fire press captured: the Minigun stream keeps it while the
# action stays held, like the throw keeps its press aim.
var _weapon_aim := Vector2.ZERO

@onready var sleep_meter := SleepMeter.new(meter_balance)
@onready var coffee_supply := CoffeeSupply.new(supply_balance)
# The brewed batch in hand: the last brew rides its cups out of the hand,
# and the plain pot covers the rest.
@onready var brew_hand := BrewHand.new()
@onready var wake_ups := WakeUps.new(wake_ups_balance)
@onready var inventory := Inventory.new()
# Section 11: the support tools control the sleepwalkers and cost no coffee.
@onready var toolbelt := SupportToolbelt.new(support_tools_balance)
# Section 11: the cure weapons deliver brewed coffee and pay the supply. The
# found set rides the bag as gear, so the save holds it, section 18.
@onready var armory := CureArmory.new()
# Section 14: the caffeine cluster bomb charges. Crafted from bag beans,
# never drawn from the coffee supply, maximum 3 on the rack.
@onready var cluster_bombs := ClusterBombRack.new(cluster_bomb_balance)
# Section 14: the brewing skill per method. Solo brews and master lessons
# train it; the brew flow calls record_brew.
@onready var brewing_skills := BrewingSkills.new(brewing_balance)
@onready var cup_spawn: Marker2D = $CupSpawn
@onready var visual: Polygon2D = $Visual


func _physics_process(delta: float) -> void:
	if _asleep:
		velocity = Vector2.ZERO
		return
	if _input_locked:
		# A locked player is out of play, like during a tutorial cinematic or a
		# minigame overlay: no moves, no drain, no grabs.
		velocity = Vector2.ZERO
		return
	_tick_combat_timers(delta)
	if Input.is_action_pressed(&"fire_weapon"):
		# The Coffee Minigun, section 11: the stream runs while the fire
		# action stays held, on the key and on the touch button alike.
		_stream_minigun(delta)
	if _grabber != null or is_stunned():
		velocity = Vector2.ZERO
	elif is_dodging():
		velocity = _dodge_direction * balance.dodge_speed
	else:
		var input_direction := Input.get_vector(
			&"move_left", &"move_right", &"move_up", &"move_down"
		)
		if input_direction != Vector2.ZERO:
			_last_move_direction = input_direction
		var speed := balance.move_speed
		if sleep_meter.is_drinking():
			speed *= balance.drink_slow_walk_factor
		velocity = input_direction * speed
	move_and_slide()
	sleep_meter.tick(delta)
	if sleep_meter.is_asleep():
		fall_asleep()


func _tick_combat_timers(delta: float) -> void:
	if _dodge_time_left > 0.0:
		_dodge_time_left = maxf(0.0, _dodge_time_left - delta)
	if _dodge_cooldown_time_left > 0.0:
		_dodge_cooldown_time_left = maxf(0.0, _dodge_cooldown_time_left - delta)
	if _grace_time_left > 0.0:
		_grace_time_left = maxf(0.0, _grace_time_left - delta)
	if _stun_time_left > 0.0:
		_stun_time_left = maxf(0.0, _stun_time_left - delta)
	toolbelt.tick(delta)
	if is_stunned():
		visual.modulate = STUN_MODULATE
	elif is_invulnerable():
		visual.modulate = Color(1.0, 1.0, 1.0, 0.5)
	else:
		visual.modulate = Color.WHITE
	# The Moonwalk dodge leans back through the roll. It reads on the visual
	# node only: no balance value and no timing change rides with it.
	if is_dodging() and dodge_style == DodgeStyle.MOONWALK:
		visual.rotation = MOONWALK_LEAN
	else:
		visual.rotation = 0.0


func fall_asleep() -> void:
	# The meter is empty: the player sleeps on the spot. One wake-up pays for
	# the wake in the cafe, and the world stays as it is. A sleep at zero
	# wake-ups is full death instead.
	if _asleep:
		return
	_asleep = true
	velocity = Vector2.ZERO
	if wake_ups.register_sleep() == WakeUps.SleepOutcome.DIED:
		died.emit()
		return
	woke_in_cafe.emit()
	wake_in_cafe()


func wake_in_cafe() -> void:
	# The player wakes in the cafe: a new day starts with a full meter.
	sleep_meter.reset()
	_grabber = null
	_mash_presses = 0
	_stun_time_left = 0.0
	_asleep = false


func is_asleep() -> bool:
	return _asleep


func set_input_locked(locked: bool) -> void:
	# The cinematics of the first ten minutes hold the player still: the
	# opening video, the brew dial, and the finale pan.
	_input_locked = locked


func is_input_locked() -> bool:
	return _input_locked


func begin_dodge(direction: Vector2) -> bool:
	# The dodge roll: a short burst of speed with invulnerability for the
	# whole roll. A grabbed or dazzled player cannot roll; mashing is the
	# only way out of a grab. The cooldown after each roll stops chain
	# rolls from making the player permanently untouchable.
	if (
		_asleep
		or _grabber != null
		or is_stunned()
		or is_dodging()
		or _dodge_cooldown_time_left > 0.0
	):
		return false
	_dodge_direction = (
		direction.normalized() if direction != Vector2.ZERO else _last_move_direction
	)
	_dodge_time_left = balance.dodge_duration_seconds
	_dodge_cooldown_time_left = balance.dodge_cooldown_seconds
	return true


func is_dodging() -> bool:
	return _dodge_time_left > 0.0


func is_invulnerable() -> bool:
	# A locked player is out of play, so no hug and no flash can land.
	return is_dodging() or _grace_time_left > 0.0 or _input_locked


func apply_stun(duration: float) -> void:
	# A dazzle from the Tourist's flash or a bump from the Tech Bro's drone
	# staggers the player for a moment. Stuns do not stack: the longer stun
	# wins while one runs.
	_stun_time_left = maxf(_stun_time_left, duration)


func is_stunned() -> bool:
	return _stun_time_left > 0.0


func is_grabbed() -> bool:
	return _grabber != null


func set_grabbed_by(sleepwalker: Sleepwalker) -> void:
	if _grabber == null:
		_grabber = sleepwalker
		_mash_presses = 0


func clear_grab(sleepwalker: Sleepwalker) -> void:
	if _grabber == sleepwalker:
		_grabber = null
		_mash_presses = 0


func struggle() -> bool:
	# A grabbed player mashes presses to break the hug. The breaking press
	# frees the player and buys a grace window against an instant re-grab.
	if _grabber == null:
		return false
	_mash_presses += 1
	if _mash_presses >= balance.hug_mash_presses_to_break:
		_grabber = null
		_mash_presses = 0
		_grace_time_left = balance.hug_break_grace_seconds
		return true
	return false


func use_tool(aim: Vector2 = Vector2.ZERO) -> bool:
	# The equipped support tool fires toward the aim, section 11. Support
	# tools wake nobody and cost no coffee: they control the sleepwalkers.
	if _asleep or _input_locked or _grabber != null or is_stunned():
		return false
	var tool := toolbelt.equipped_tool()
	if tool == SupportToolbelt.NO_TOOL or toolbelt.is_on_cooldown(tool):
		return false
	if not coffee_supply.fire(CoffeeSupply.Weapon.SUPPORT_TOOL):
		return false
	var direction := aim.normalized() if aim != Vector2.ZERO else _last_move_direction
	match tool:
		SupportToolbelt.Tool.TAMPER:
			_swing_tamper(direction)
		SupportToolbelt.Tool.STEAM_WAND:
			_swing_steam_wand(direction)
		SupportToolbelt.Tool.PORTAFILTER:
			_bash_portafilter(direction)
		SupportToolbelt.Tool.ICED_SPRAYER:
			_spray_iced(direction)
		SupportToolbelt.Tool.BEAN_SLICK:
			_drop_bean_slick()
		_:
			return false
	toolbelt.start_cooldown(tool)
	return true


func _cycle_tool() -> bool:
	# The swap: the next found tool rides in the slot. The shared action
	# entry is the only caller, key and touch alike.
	if _asleep or _input_locked:
		return false
	return toolbelt.cycle()


func _swing_tamper(direction: Vector2) -> void:
	# The Tamper: one melee push. It staggers the nearest sleepwalker in the
	# short reach and shoves it back, section 11.
	var target := _nearest_sleepwalker_in_cone(
		direction,
		support_tools_balance.tamper_reach,
		support_tools_balance.tamper_half_angle_degrees
	)
	if target == null:
		return
	target.stagger(support_tools_balance.tamper_stagger_seconds)
	target.push_away(
		_away_from_player(target),
		support_tools_balance.tamper_push_speed,
		support_tools_balance.tamper_push_seconds
	)


func _swing_steam_wand(direction: Vector2) -> void:
	# The Steam Wand: a melee cone of steam. Every sleepwalker inside
	# staggers briefly, and the swing opens the parry window of section 14.
	for walker: Sleepwalker in _sleepwalkers_in_cone(
		direction,
		support_tools_balance.steam_wand_reach,
		support_tools_balance.steam_wand_half_angle_degrees
	):
		walker.stagger(support_tools_balance.steam_wand_stagger_seconds)
	toolbelt.open_parry_window()


func _bash_portafilter(direction: Vector2) -> void:
	# The Portafilter bash: a heavy melee hit. It staggers and shoves every
	# sleepwalker in the short arc in front of the player, section 11.
	for walker: Sleepwalker in _sleepwalkers_in_cone(
		direction,
		support_tools_balance.portafilter_bash_reach,
		support_tools_balance.portafilter_bash_half_angle_degrees
	):
		walker.stagger(support_tools_balance.portafilter_bash_stagger_seconds)
		walker.push_away(
			_away_from_player(walker),
			support_tools_balance.portafilter_bash_push_speed,
			support_tools_balance.portafilter_bash_push_seconds
		)


func _spray_iced(direction: Vector2) -> void:
	# The Iced Sprayer: iced coffee wakes nobody, but the brain freeze slows
	# every sleepwalker in the cone, section 11.
	for walker: Sleepwalker in _sleepwalkers_in_cone(
		direction,
		support_tools_balance.sprayer_reach,
		support_tools_balance.sprayer_half_angle_degrees
	):
		walker.apply_brain_freeze(
			support_tools_balance.brain_freeze_seconds,
			support_tools_balance.brain_freeze_speed_factor
		)


func _drop_bean_slick() -> void:
	# The Bean Slick: a pile of beans lands under the player, and every
	# sleepwalker that steps on it slips, section 11.
	var slick := bean_slick_scene.instantiate() as BeanSlick
	get_parent().add_child(slick)
	slick.global_position = global_position


func _plant_coffee_seedling() -> bool:
	# Section 6: sleepwalkers eat everything they find, also coffee plants.
	# The seedling becomes a coffee plant under the player's feet, and every
	# sleeper that smells it stops hunting and eats. Planting spends one
	# seedling from the bag and no coffee supply.
	if _asleep or _input_locked or _grabber != null or is_stunned():
		return false
	if not inventory.remove(COFFEE_SEEDLING_ID, 1):
		return false
	var plant := coffee_plant_scene.instantiate() as CoffeePlant
	get_parent().add_child(plant)
	plant.global_position = global_position
	return true


func _sleepwalkers_in_cone(
	direction: Vector2, reach: float, half_angle_degrees: float
) -> Array[Sleepwalker]:
	var hits: Array[Sleepwalker] = []
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var walker := node as Sleepwalker
		if walker == null or walker.is_awake():
			continue
		var offset := walker.global_position - global_position
		if offset.length() > reach:
			continue
		var angle := absf(rad_to_deg(angle_difference(direction.angle(), offset.angle())))
		if angle > half_angle_degrees:
			continue
		hits.append(walker)
	return hits


func _nearest_sleepwalker_in_cone(
	direction: Vector2, reach: float, half_angle_degrees: float
) -> Sleepwalker:
	var best: Sleepwalker = null
	var best_distance := reach
	for walker: Sleepwalker in _sleepwalkers_in_cone(direction, reach, half_angle_degrees):
		var distance := walker.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = walker
			best_distance = distance
	return best


func _away_from_player(walker: Sleepwalker) -> Vector2:
	# The shove direction of a melee hit: away from the player. A target on
	# the exact same spot flies the way the swing aimed.
	var away := walker.global_position - global_position
	if away.length() > 1.0:
		return away.normalized()
	return _last_move_direction


func drink_cup() -> bool:
	if _asleep or _grabber != null or is_stunned():
		return false
	# The same cup heals the meter or wakes a sleepwalker, never both.
	if not coffee_supply.spend_cups(supply_balance.drink_cost):
		return false
	brew_hand.consume()
	sleep_meter.begin_drinking()
	return true


func refill_supply() -> int:
	return coffee_supply.refill_at_cafe()


func pickup_item(item: ItemType, amount: int) -> int:
	# Scavenged goods enter the bag; a sleeping player picks nothing up.
	# The thermos belt raises the coffee carry limit as soon as it is worn.
	if _asleep:
		return 0
	var added: int = inventory.add(item, amount)
	if added > 0 and item.item_id == THERMOS_BELT_ID:
		coffee_supply.equip_thermos_belt()
	if added > 0:
		# A found cure weapon joins the armory the moment its gear enters the
		# bag, section 11.
		armory.grant_item(item.item_id)
	return added


func _unhandled_input(event: InputEvent) -> void:
	if _asleep or _input_locked:
		return
	if _is_emulated_touch_click(event):
		# A screen tap emulates a left click. The THROW button owns touch
		# throws with its stick aim, so the emulated click must not also throw
		# a cup toward the tap position, section 4.
		return
	if is_grabbed():
		if _is_mash_press(event):
			struggle()
		return
	if event.is_action_pressed(&"throw_coffee"):
		try_action(&"throw_coffee", get_global_mouse_position() - global_position)
	elif event.is_action_pressed(&"drink_coffee"):
		try_action(&"drink_coffee")
	elif event.is_action_pressed(&"serve_coffee"):
		try_action(&"serve_coffee")
	elif event.is_action_pressed(&"dodge"):
		try_action(
			&"dodge", Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		)
	elif event.is_action_pressed(&"use_tool"):
		try_action(&"use_tool", get_global_mouse_position() - global_position)
	elif event.is_action_pressed(&"plant_coffee"):
		try_action(&"plant_coffee")
	elif event.is_action_pressed(&"cycle_tool"):
		try_action(&"cycle_tool")
	elif event.is_action_pressed(&"fire_weapon"):
		try_action(&"fire_weapon", get_global_mouse_position() - global_position)
	elif event.is_action_pressed(&"cycle_weapon"):
		try_action(&"cycle_weapon")


func _is_emulated_touch_click(event: InputEvent) -> bool:
	# The mouse event a touch emulates carries device -1, TouchControls.
	var mouse := event as InputEventMouseButton
	return mouse != null and mouse.device == TouchControls.EMULATED_MOUSE_DEVICE


func try_action(action: StringName, aim_direction: Vector2 = Vector2.ZERO) -> bool:
	# One entry for the key path and the touch buttons: the shared rules of a
	# player press live here. A grabbed player mashes the hug instead of acting.
	# The aim comes from the caller: the mouse on desktop, the stick on touch.
	if _asleep or _input_locked:
		return false
	if _grabber != null:
		struggle()
		return false
	var result := false
	match action:
		&"throw_coffee":
			result = throw_cup(aim_direction) != null
		&"drink_coffee":
			result = drink_cup()
		&"serve_coffee":
			result = _serve_cup()
		&"dodge":
			result = begin_dodge(aim_direction)
		&"use_tool":
			result = use_tool(aim_direction)
		&"plant_coffee":
			result = _plant_coffee_seedling()
		&"cycle_tool":
			result = _cycle_tool()
		&"fire_weapon":
			result = _fire_cure_weapon(aim_direction)
		&"cycle_weapon":
			result = _cycle_weapon()
	return result


func _is_mash_press(event: InputEvent) -> bool:
	return (
		event.is_action_pressed(&"throw_coffee")
		or event.is_action_pressed(&"drink_coffee")
		or event.is_action_pressed(&"serve_coffee")
		or event.is_action_pressed(&"dodge")
		or event.is_action_pressed(&"use_tool")
		or event.is_action_pressed(&"fire_weapon")
	)


func throw_cup(direction: Vector2) -> CoffeeCup:
	if _asleep or _grabber != null or is_stunned():
		return null
	if not coffee_supply.fire(CoffeeSupply.Weapon.CUP_THROW):
		return null
	var aim := direction.normalized() if direction != Vector2.ZERO else _last_move_direction
	var start := cup_spawn.global_position
	var landing := AimCone.landing_point(
		start,
		aim,
		_reachable_sleepwalker_candidates(start),
		cup_balance.aim_cone_half_angle_degrees,
		cup_balance.throw_range,
		cup_balance.flight_time_seconds
	)
	var cup := cup_scene.instantiate() as CoffeeCup
	cup.direction = aim
	cup.brewed = brew_hand.active_payload()
	if cup.brewed == null:
		cup.brewed = _standard_cup()
	get_parent().add_child(cup)
	cup.global_position = start
	cup.launch(landing)
	brew_hand.consume()
	return cup


func _reachable_sleepwalker_candidates(start: Vector2) -> Array[AimCandidate]:
	# The cone snaps only to sleepers a thrown cup can truly reach. Walls
	# hide the rest: a snap through a wall would break on the wall, so the
	# aim skips the sleeper behind it. Each candidate carries its velocity,
	# so the landing point leads a mover to its impact-time position.
	var candidates: Array[AimCandidate] = []
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var sleepwalker := node as Sleepwalker
		if sleepwalker == null or sleepwalker.is_awake():
			continue
		if not LineOfSight.is_clear(start, sleepwalker.global_position, get_world_2d()):
			continue
		candidates.append(AimCandidate.new(sleepwalker.global_position, sleepwalker.velocity))
	return candidates


func _serve_cup() -> bool:
	# The serve action, section 6: the barista hands one cup straight to the
	# sleeper at arm's length. No cup flies, so the tinfoil hat stops
	# nothing; the Turkish cure of the Tinfoil Man travels this path. The
	# handoff pays the one cup a throw pays, and a wrong cure spends it the
	# way a wrong throw does: handed over, sipped, and no wake.
	if _asleep or _grabber != null or is_stunned():
		return false
	var target := _sleeper_in_serve_reach()
	if target == null:
		return false
	if not coffee_supply.fire(CoffeeSupply.Weapon.CUP_THROW):
		return false
	var payload := brew_hand.active_payload()
	if payload == null:
		payload = _standard_cup()
	brew_hand.consume()
	target.try_wake(payload)
	return true


func _sleeper_in_serve_reach() -> Sleepwalker:
	# The nearest sleeping walker inside the serve reach, any direction: the
	# serve needs no aim, the barista walks up and hands the cup over.
	var best: Sleepwalker = null
	var best_distance := balance.serve_reach
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var walker := node as Sleepwalker
		if walker == null or walker.is_awake():
			continue
		var distance := walker.global_position.distance_to(global_position)
		if distance <= best_distance:
			best = walker
			best_distance = distance
	return best


func _standard_cup() -> BrewedCup:
	# The cafe-standard cup: a plain filter brew that wakes basic types only.
	return BrewedCup.new(
		brewing_library.find_bean(STANDARD_BEAN_ID),
		brewing_library.find_roast(STANDARD_ROAST_ID),
		brewing_library.find_method(STANDARD_METHOD_ID),
		"",
		brewing_balance.standard_cup_score
	)


func _fire_cure_weapon(aim_direction: Vector2) -> bool:
	# The equipped cure weapon fires toward the aim, section 11. Every weapon
	# delivers brewed coffee and pays the supply its own cost. The Minigun
	# owns no shot: its stream runs while the fire action stays held.
	if _asleep or _grabber != null or is_stunned():
		return false
	var weapon := armory.equipped_weapon()
	if weapon == CureArmory.NO_WEAPON:
		return false
	var direction := (
		aim_direction.normalized() if aim_direction != Vector2.ZERO else _last_move_direction
	)
	_weapon_aim = direction
	var fired := false
	match weapon:
		CureArmory.Weapon.TRAVEL_MUG:
			fired = _throw_travel_mug(direction)
		CureArmory.Weapon.THERMOS:
			fired = _throw_thermos(direction)
		CureArmory.Weapon.FRENCH_PRESS:
			fired = _fire_french_press(direction)
		CureArmory.Weapon.MOKA_LAUNCHER:
			fired = _fire_moka_launcher(direction)
		CureArmory.Weapon.AUTO_DRIP_TURRET:
			fired = _deploy_auto_drip_turret()
		CureArmory.Weapon.MINIGUN:
			pass
	return fired


func _cycle_weapon() -> bool:
	# The weapon swap: the next found cure weapon in the canonical order. The
	# shared action entry is the only caller, key and touch alike.
	if _asleep or _input_locked:
		return false
	return armory.cycle()


func _throw_travel_mug(direction: Vector2) -> bool:
	# The Travel Mug, section 11: sealed steel, so no cup leaves the supply.
	# It seeks the first sleeper through the aim cone, ricochets to a second
	# one around corners, and rolls back to the hand.
	if not coffee_supply.fire(CoffeeSupply.Weapon.TRAVEL_MUG):
		return false
	var start := cup_spawn.global_position
	var landing := AimCone.landing_point(
		start,
		direction,
		_reachable_sleepwalker_candidates(start),
		cup_balance.aim_cone_half_angle_degrees,
		cure_weapons_balance.travel_mug_throw_range,
		cure_weapons_balance.travel_mug_flight_time_seconds
	)
	var mug := travel_mug_scene.instantiate() as TravelMug
	mug.direction = direction
	# The lid keeps the coffee inside: the payload rides the mug out and back,
	# so the batch in hand loses nothing.
	mug.brewed = _peek_weapon_payload()
	mug.thrower = self
	get_parent().add_child(mug)
	mug.global_position = start
	mug.launch(landing)
	return true


func _throw_thermos(direction: Vector2) -> bool:
	# The Thermos, section 11: a thrown flask that breaks and splashes coffee
	# in a wide area. Three cups pay the tank.
	if not coffee_supply.fire(CoffeeSupply.Weapon.THERMOS):
		return false
	var start := cup_spawn.global_position
	var landing := AimCone.landing_point(
		start,
		direction,
		_reachable_sleepwalker_candidates(start),
		cup_balance.aim_cone_half_angle_degrees,
		cure_weapons_balance.thermos_throw_range,
		cure_weapons_balance.thermos_flight_time_seconds
	)
	var flask := thermos_scene.instantiate() as ThermosFlask
	flask.direction = direction
	flask.brewed = _draw_weapon_payload()
	get_parent().add_child(flask)
	flask.global_position = start
	flask.launch(landing)
	return true


func _fire_french_press(direction: Vector2) -> bool:
	# The French Press, section 11: pump-action. One press loads the chamber
	# and pays nothing; the next press shoots the close-range cone.
	if not armory.is_press_loaded():
		armory.load_press()
		return true
	if not coffee_supply.fire(CoffeeSupply.Weapon.FRENCH_PRESS):
		return false
	armory.consume_press_load()
	CureDelivery.cone_wake(
		global_position,
		direction,
		cure_weapons_balance.french_press_reach,
		cure_weapons_balance.french_press_half_angle_degrees,
		_draw_weapon_payload(),
		get_tree(),
		get_world_2d()
	)
	return true


func _fire_moka_launcher(direction: Vector2) -> bool:
	# The Moka Launcher, section 11: a pressurized pot on a high arc. The
	# coffee brews during the flight, so the pot carries real coffee even
	# when the hand holds only plain cups. Four cups pay the shot.
	if not coffee_supply.fire(CoffeeSupply.Weapon.MOKA_LAUNCHER):
		return false
	var start := cup_spawn.global_position
	var landing := AimCone.landing_point(
		start,
		direction,
		_reachable_sleepwalker_candidates(start),
		cup_balance.aim_cone_half_angle_degrees,
		cure_weapons_balance.moka_throw_range,
		cure_weapons_balance.moka_flight_time_seconds
	)
	var pot := moka_pot_scene.instantiate() as MokaPot
	pot.direction = direction
	pot.brewed = _draw_weapon_payload()
	get_parent().add_child(pot)
	pot.global_position = start
	pot.launch(landing)
	return true


func _deploy_auto_drip_turret() -> bool:
	# The Auto-Drip Turret, section 11: the tower stands where the player is
	# and drips on every sleepwalker below it, alone, until the tank runs dry.
	if not coffee_supply.fire(CoffeeSupply.Weapon.AUTO_DRIP_TURRET):
		return false
	var turret := auto_drip_turret_scene.instantiate() as AutoDripTurret
	turret.payload = _draw_weapon_payload()
	get_parent().add_child(turret)
	turret.global_position = global_position
	return true


func _stream_minigun(delta: float) -> void:
	# The Coffee Minigun, section 11: a continuous stream in a narrow cone.
	# The supply pays six cups per second, the batch in hand rides its cups
	# out of the hand at the same rate, and the stream stops when the supply
	# runs dry.
	if armory.equipped_weapon() != CureArmory.Weapon.MINIGUN:
		return
	if _asleep or _input_locked or _grabber != null or is_stunned():
		return
	var before := coffee_supply.cups
	coffee_supply.fire_continuous(CoffeeSupply.Weapon.MINIGUN, delta)
	for _cup: int in range(before - coffee_supply.cups):
		brew_hand.consume()
	if before <= 0:
		return
	var aim := _weapon_aim if _weapon_aim != Vector2.ZERO else _last_move_direction
	CureDelivery.cone_wake(
		cup_spawn.global_position,
		aim,
		cure_weapons_balance.minigun_range,
		cure_weapons_balance.minigun_half_angle_degrees,
		_peek_weapon_payload(),
		get_tree(),
		get_world_2d()
	)


func _draw_weapon_payload() -> BrewedCup:
	# The payload of one weapon shot: the brewed batch in hand spends one of
	# its cups, and a hand of plain cups pays the cafe standard.
	var payload := brew_hand.active_payload()
	if payload == null:
		return _standard_cup()
	brew_hand.consume()
	return payload


func _peek_weapon_payload() -> BrewedCup:
	# The payload of the Travel Mug and the Minigun stream: the same batch as
	# any shot, but nothing leaves the hand, so every cup stays.
	var payload := brew_hand.active_payload()
	if payload == null:
		return _standard_cup()
	return payload
