# ABOUTME: Sleepwalker is the shared enemy engine: wander, chase, hug, wake.
# ABOUTME: The EnemyType resource defines the type, its cure, and its behavior.
class_name Sleepwalker
extends CharacterBody2D

signal woke_up
signal first_met(type_id: String)
signal flashed
signal pitched
signal spoke(line: String)

enum State { WANDER, CHASE, HUG, AWAKE, PHOTO, FORAGE, EATING }
enum DashPhase { REST, WINDUP, BURST }

const SLEEPWALKER_GROUP := &"sleepwalkers"
# The flash burst brightens the whole placeholder body for one beat.
const FLASH_MODULATE := Color(2.5, 2.5, 2.5, 1.0)
# The windup tint telegraphs the dash: red means he is about to dart.
const DASH_WINDUP_MODULATE := Color(1.0, 0.5, 0.5, 1.0)
# A staggered sleepwalker dims on the body node, so the type telegraphs like
# the dash red stay untouched on the visual node below.
const STAGGER_MODULATE := Color(0.62, 0.62, 0.74, 0.9)
# Brain freeze ices the pajamas over while the freeze lasts.
const BRAIN_FREEZE_MODULATE := Color(0.55, 0.78, 1.0, 0.9)
# A slipped sleepwalker lies flat on the floor for the length of the fall.
const SLIP_ROTATION := PI * 0.5
# The Moonwalker leans far back while he slides, section 6, so the body
# reads as one who ducks under any guard.
const MOON_LEAN_ROTATION := -0.35

@export var balance: SleepwalkerBalance
@export var enemy_type: EnemyType
@export var library: BrewingLibrary
@export var brewing_balance: BrewingBalance
@export var tourist_balance: TouristBalance
@export var tech_bro_balance: TechBroBalance
@export var gamer_balance: GamerBalance
@export var karen_balance: KarenBalance
@export var moonwalker_balance: MoonwalkerBalance
# Section 6: the foraging rule. The walker takes the bait only while the
# balance says so, so the V1 scope call is one field in forage.tres.
@export var forage_balance: ForageBalance

var state := State.WANDER
var player: Player = null
# Section 6: the Moonwalker never walks forward. The gait owns his slides,
# his backwards facing, and his reversed telegraph.
var moonwalk_gait: MoonwalkGait = null

var _wander_direction := Vector2.ZERO
var _wander_timer := 0.0
var _met_announced := false
var _rng := RandomNumberGenerator.new()
var _photo_cooldown := 0.0
var _photo_windup := 0.0
var _photo_recovery := 0.0
var _state_after_photo := State.WANDER
var _pitch_cooldown := 0.0
var _dash_phase := DashPhase.REST
var _dash_timer := 0.0
var _dash_direction := Vector2.ZERO
var _graze_cooldown := 0.0
var _gathering := false
var _gather_target := Vector2.ZERO
var _follow_target: Node2D = null
var _follow_stop_distance := 0.0
var _stagger_time_left := 0.0
var _slide_time_left := 0.0
var _slide_velocity := Vector2.ZERO
var _down_time_left := 0.0
var _brain_freeze_time_left := 0.0
var _brain_freeze_speed_factor := 1.0
var _food_target: ForageFood = null
var _eat_time_left := 0.0

@onready var sense_area: Area2D = $SenseArea
@onready var hug_area: Area2D = $HugArea
@onready var visual: Polygon2D = $Visual
@onready var nightcap: Polygon2D = $Visual/Nightcap


func _ready() -> void:
	add_to_group(SLEEPWALKER_GROUP)
	add_to_group(CureDelivery.WAKEABLE_GROUP)
	_rng.randomize()
	_pick_wander_direction()
	visual.color = enemy_type.pajama_color
	nightcap.color = enemy_type.pajama_color
	# The art direction pass: the placeholder rectangle becomes the cast
	# figure of ART_DIRECTION section 7, built from the type data.
	SleeperFigure.build(visual, nightcap, enemy_type)
	if enemy_type.special_behavior == EnemyType.SpecialBehavior.PHOTO_FLASH:
		_photo_cooldown = tourist_balance.photo_interval_seconds
	if enemy_type.special_behavior == EnemyType.SpecialBehavior.DRONE_ATTACK:
		_pitch_cooldown = tech_bro_balance.pitch_interval_seconds
	if enemy_type.special_behavior == EnemyType.SpecialBehavior.MOONWALK:
		moonwalk_gait = MoonwalkGait.new(moonwalker_balance)
		moonwalk_gait.aim(_wander_direction)


func _physics_process(delta: float) -> void:
	_tick_control_timers(delta)
	if state == State.AWAKE:
		velocity = _awake_velocity()
	elif is_under_tool_control():
		# A staggered or shoved sleepwalker is out of control: it slides or
		# stands dazed, and no grab, photo, flash, or dash fires.
		velocity = _controlled_velocity()
	else:
		if _photo_cadence_due(delta):
			_begin_photo()
		if _pitch_cadence_due(delta):
			_emit_pitch()
		match state:
			State.WANDER:
				_process_wander(delta)
				_try_spot_player()
			State.CHASE, State.HUG:
				_process_engage(delta)
			State.PHOTO:
				_process_photo(delta)
			State.FORAGE:
				_process_forage(delta)
			State.EATING:
				_process_eating(delta)
		velocity *= _speed_factor()
	move_and_slide()


func wake_up(restore := false) -> void:
	if state == State.AWAKE:
		return
	if state == State.HUG and _has_valid_player():
		player.clear_grab(self)
	state = State.AWAKE
	velocity = Vector2.ZERO
	_food_target = null
	_eat_time_left = 0.0
	_stagger_time_left = 0.0
	_slide_time_left = 0.0
	_slide_velocity = Vector2.ZERO
	_down_time_left = 0.0
	_brain_freeze_time_left = 0.0
	_brain_freeze_speed_factor = 1.0
	visual.modulate = Color.WHITE
	_update_control_look()
	# The wake beat of the art direction, ART_DIRECTION section 1: the sketch
	# colors in from the cup hit, the eyes pop open, and the drool arc goes.
	# A restored wake, T134, replays no beat: the color front stands complete
	# at once, no wake line floats, and no signal fires, because the save
	# already recorded the wake.
	SleeperFigure.set_awake(visual, true, global_position, restore)
	if restore:
		return
	if not enemy_type.wake_line.is_empty():
		spoke.emit(enemy_type.wake_line)
	woke_up.emit()


func is_awake() -> bool:
	return state == State.AWAKE


func gather_at(point: Vector2) -> void:
	# An awakened survivor drifts to a field base slot and stays there,
	# section 10.
	_gather_target = point
	_gathering = true


func stop_gathering() -> void:
	_gathering = false


func is_gathering() -> bool:
	return _gathering


func follow(target: Node2D, stop_distance: float) -> void:
	# An awakened survivor walks with a leader, like the fan crowd of the
	# Sleepvana show, section 13. Following ends the table gather.
	_gathering = false
	_follow_target = target
	_follow_stop_distance = stop_distance


func stop_following() -> void:
	_follow_target = null


func is_following() -> bool:
	return _follow_target != null


func _awake_velocity() -> Vector2:
	# Awake survivors stand at their slot, or trail their leader when they
	# follow one.
	if _follow_target != null and is_instance_valid(_follow_target):
		var offset := _follow_target.global_position - global_position
		if offset.length() <= _follow_stop_distance:
			return Vector2.ZERO
		return offset.normalized() * balance.follow_speed
	return _gather_velocity()


func _gather_velocity() -> Vector2:
	if not _gathering:
		return Vector2.ZERO
	var offset := _gather_target - global_position
	if offset.length() <= balance.gather_stop_distance:
		return Vector2.ZERO
	return offset.normalized() * balance.walk_speed


func try_wake(cup: BrewedCup) -> bool:
	if state == State.AWAKE:
		return false
	if not CureMatcher.can_wake(cup, enemy_type.cure, library, brewing_balance):
		return false
	wake_up()
	return true


func hat_stops_thrown_coffee() -> bool:
	# The Tinfoil Man's defense, section 6: the tinfoil hat stops thrown
	# coffee, so no payload gets through while it flies, cure or not. Splash
	# attacks do not reach under the brim either, so every thrown or splash
	# delivery must ask this guard. Only a cup served directly wakes him.
	return enemy_type.special_behavior == EnemyType.SpecialBehavior.TINFOIL_HAT


func stagger(duration: float) -> void:
	# A support tool staggers the sleepwalker, section 11: it stands dazed,
	# holds no hug, and wakes to no cup. Staggers do not stack: the longer
	# stagger wins while one runs.
	if state == State.AWAKE:
		return
	if state == State.HUG:
		if _has_valid_player():
			player.clear_grab(self)
		state = State.CHASE
	_stagger_time_left = maxf(_stagger_time_left, duration)
	_update_control_look()


func is_staggered() -> bool:
	return _stagger_time_left > 0.0


func push_away(direction: Vector2, speed: float, seconds: float) -> void:
	# The shove of a melee tool: the body slides one short beat on top of any
	# stagger, then the stagger holds it in place.
	if state == State.AWAKE or seconds <= 0.0:
		return
	_slide_velocity = direction.normalized() * speed
	_slide_time_left = seconds


func slip(direction: Vector2, speed: float, slide_seconds: float, down_seconds: float) -> void:
	# The Bean Slick, section 11: the feet shoot forward, the body slides, and
	# the sleepwalker stays down for a beat before it moves again.
	if state == State.AWAKE:
		return
	var fall_seconds := slide_seconds + down_seconds
	push_away(direction, speed, slide_seconds)
	stagger(fall_seconds)
	_down_time_left = fall_seconds
	_update_control_look()


func is_slipping() -> bool:
	return _down_time_left > 0.0


func apply_brain_freeze(duration: float, speed_factor: float) -> void:
	# The Iced Sprayer, section 11: iced coffee wakes nobody, but the brain
	# freeze slows the sleepwalker while it lasts.
	if state == State.AWAKE:
		return
	_brain_freeze_time_left = maxf(_brain_freeze_time_left, duration)
	_brain_freeze_speed_factor = speed_factor
	_update_control_look()


func is_brain_frozen() -> bool:
	return _brain_freeze_time_left > 0.0


func notice_food(food: ForageFood) -> bool:
	# Section 6: sleepwalkers eat everything they find, also coffee plants.
	# Only a wandering sleeper takes the bait: the dream of the warm hug wins
	# once a chase runs, an awake survivor forages no more, and a body under
	# tool control has no say until the tool lets go. The food offers again
	# every physics frame, so a refusal now costs nothing.
	if forage_balance == null or not forage_balance.foraging_enabled:
		return false
	if state != State.WANDER or is_under_tool_control():
		return false
	if _food_target != null:
		return false
	_food_target = food
	state = State.FORAGE
	return true


func is_under_tool_control() -> bool:
	# True while a support tool owns the body: a stagger, a shove, or a slip.
	return _stagger_time_left > 0.0 or _slide_time_left > 0.0


func _controlled_velocity() -> Vector2:
	if _slide_time_left > 0.0:
		return _slide_velocity
	return Vector2.ZERO


func _speed_factor() -> float:
	# Brain freeze slows every gait while it lasts, section 11.
	return _brain_freeze_speed_factor if _brain_freeze_time_left > 0.0 else 1.0


func _tick_control_timers(delta: float) -> void:
	if _graze_cooldown > 0.0:
		_graze_cooldown = maxf(0.0, _graze_cooldown - delta)
	if _stagger_time_left > 0.0:
		_stagger_time_left = maxf(0.0, _stagger_time_left - delta)
	if _slide_time_left > 0.0:
		_slide_time_left = maxf(0.0, _slide_time_left - delta)
	if _down_time_left > 0.0:
		_down_time_left = maxf(0.0, _down_time_left - delta)
	if _brain_freeze_time_left > 0.0:
		_brain_freeze_time_left = maxf(0.0, _brain_freeze_time_left - delta)
		if _brain_freeze_time_left <= 0.0:
			_brain_freeze_speed_factor = 1.0
	_update_control_look()


func _update_control_look() -> void:
	# The control looks ride on the body node, never on the visual node, so
	# the type telegraphs like the dash red stay untouched. A slipped body
	# lies flat until it stands up again.
	visual.rotation = SLIP_ROTATION if _down_time_left > 0.0 else _moon_lean()
	if moonwalk_gait != null and state != State.AWAKE:
		# The reverse telegraph, section 24: the red signal rides the phase
		# that follows the slide, on the visual node like the dash red.
		visual.modulate = (DASH_WINDUP_MODULATE if moonwalk_gait.is_telegraphing() else Color.WHITE)
	if _stagger_time_left > 0.0 or _down_time_left > 0.0:
		modulate = STAGGER_MODULATE
	elif _brain_freeze_time_left > 0.0:
		modulate = BRAIN_FREEZE_MODULATE
	else:
		modulate = Color.WHITE


func _process_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_pick_wander_direction()
	if enemy_type.special_behavior == EnemyType.SpecialBehavior.DASH_CHARGE:
		# The dash is the Gamer's gait, so even his wandering comes in bursts.
		velocity = _dash_gait(delta, _wander_direction)
	elif enemy_type.special_behavior == EnemyType.SpecialBehavior.KAREN_SURPRISE:
		# The Karen lulls: a slow creep that hides the sprint, section 6.
		velocity = _wander_direction * karen_balance.lull_speed
	elif enemy_type.special_behavior == EnemyType.SpecialBehavior.MOONWALK:
		# Even his wandering comes in backwards slides, section 6.
		velocity = moonwalk_gait.step(delta, _wander_direction)
	else:
		velocity = _wander_direction * balance.walk_speed


func _process_engage(delta: float) -> void:
	match enemy_type.special_behavior:
		EnemyType.SpecialBehavior.SIMPLE_HUG:
			_engage_simple_hug()
		EnemyType.SpecialBehavior.PHOTO_FLASH:
			_engage_photo_flash()
		EnemyType.SpecialBehavior.DRONE_ATTACK:
			_engage_drone_attack()
		EnemyType.SpecialBehavior.DASH_CHARGE:
			_engage_dash_charge(delta)
		EnemyType.SpecialBehavior.TINFOIL_HAT:
			_engage_simple_hug()
		EnemyType.SpecialBehavior.KAREN_SURPRISE:
			_engage_karen_surprise()
		EnemyType.SpecialBehavior.MOONWALK:
			_engage_moonwalk(delta)


func _engage_photo_flash() -> void:
	# The Tourist never chases and never hugs. He stops and photographs the
	# player, and the flash does all the work. The danger is the stun: other
	# sleepwalkers close in while the player cannot act.
	velocity = Vector2.ZERO


func _engage_drone_attack() -> void:
	# The Tech Bro never chases and never hugs. He stops mid-pitch and lets
	# the drone do the fighting.
	velocity = Vector2.ZERO


func _pitch_cadence_due(delta: float) -> bool:
	# The Tech Bro sleep-pitches startup ideas to nobody on a steady cadence,
	# player or not. The pitch never stops his walk.
	if enemy_type.special_behavior != EnemyType.SpecialBehavior.DRONE_ATTACK:
		return false
	if state != State.WANDER and state != State.CHASE:
		return false
	_pitch_cooldown -= delta
	return _pitch_cooldown <= 0.0


func _emit_pitch() -> void:
	_pitch_cooldown = tech_bro_balance.pitch_interval_seconds
	pitched.emit()


func _photo_cadence_due(delta: float) -> bool:
	# The Tourist takes photos of everything, player or not, on a steady
	# cadence. The next photo starts from wandering or from engaging.
	if enemy_type.special_behavior != EnemyType.SpecialBehavior.PHOTO_FLASH:
		return false
	if state != State.WANDER and state != State.CHASE:
		return false
	_photo_cooldown -= delta
	return _photo_cooldown <= 0.0


func _begin_photo() -> void:
	_state_after_photo = state
	state = State.PHOTO
	velocity = Vector2.ZERO
	_photo_windup = tourist_balance.flash_windup_seconds
	_photo_recovery = tourist_balance.photo_recovery_seconds
	_photo_cooldown = tourist_balance.photo_interval_seconds


func _process_photo(delta: float) -> void:
	velocity = Vector2.ZERO
	if _photo_windup > 0.0:
		# He raises the camera: the windup is the player's dodge window.
		_photo_windup = maxf(0.0, _photo_windup - delta)
		if _photo_windup <= 0.0:
			_fire_flash()
		return
	_photo_recovery = maxf(0.0, _photo_recovery - delta)
	if _photo_recovery <= 0.0:
		_resume_after_photo()


func _fire_flash() -> void:
	# The flash reaches everything the Tourist can see. A rolling or
	# freshly-freed player is invulnerable, so the shot misses. A sleeping
	# player has nothing left to dazzle.
	visual.modulate = FLASH_MODULATE
	flashed.emit()
	if not _has_valid_player():
		_is_player_in_area(sense_area)
	if not _has_valid_player() or player.is_invulnerable() or player.is_asleep():
		return
	if player.global_position.distance_to(global_position) > tourist_balance.flash_radius:
		return
	if not LineOfSight.is_clear(global_position, player.global_position, get_world_2d()):
		return
	player.apply_stun(tourist_balance.flash_stun_seconds)


func _resume_after_photo() -> void:
	# He checks the shot, then goes back to what he did before.
	visual.modulate = Color.WHITE
	state = _state_after_photo


func _process_forage(_delta: float) -> void:
	# The walker smells food and heads for it, section 6. The food can die on
	# the way, eaten by somebody else: the walker goes back to wandering.
	if not _food_target_valid():
		_abandon_food()
		return
	var offset := _food_target.global_position - global_position
	if offset.length() <= forage_balance.eat_range:
		state = State.EATING
		velocity = Vector2.ZERO
		_eat_time_left = forage_balance.eat_duration_seconds
		return
	velocity = offset.normalized() * forage_balance.forage_speed


func _process_eating(delta: float) -> void:
	# The meal stands the walker still for its whole length. Raw caffeine
	# wakes nobody, so the walker sleeps on after the last bite, and only the
	# distraction remains, exactly as the transcript intends.
	velocity = Vector2.ZERO
	if not _food_target_valid():
		_abandon_food()
		return
	_eat_time_left = maxf(0.0, _eat_time_left - delta)
	if _eat_time_left > 0.0:
		return
	var food := _food_target
	_food_target = null
	food.consume()
	state = State.WANDER


func _abandon_food() -> void:
	_food_target = null
	_eat_time_left = 0.0
	state = State.WANDER


func _food_target_valid() -> bool:
	return (
		_food_target != null and is_instance_valid(_food_target) and not _food_target.is_consumed()
	)


func _engage_simple_hug() -> void:
	_engage_chase_at(balance.chase_speed)


func _engage_karen_surprise() -> void:
	# The surprise attack, section 6: the slow creep snaps into a full sprint
	# the moment she spots the player. No windup and no telegraph; the grab
	# stays the plain hug.
	_engage_chase_at(karen_balance.sprint_speed)


func _engage_moonwalk(delta: float) -> void:
	# Section 6: he does not hug. He closes in on backwards slides, and the
	# pass itself is the attack: he leans far back and slides under the
	# guard, so no parry and no block stops the pass.
	state = State.CHASE
	if not _has_valid_player():
		player = null
		state = State.WANDER
		return
	velocity = moonwalk_gait.step(delta, (player.global_position - global_position).normalized())
	_try_graze_player()


func _try_graze_player() -> void:
	# The brush of the slide costs the meter its price, at most once per
	# cooldown. A rolling player is invulnerable: the slide passes under him
	# too. The graze is the only touch he makes, section 6: he does not hug.
	if _graze_cooldown > 0.0 or not _has_valid_player():
		return
	if player.is_invulnerable() or player.is_asleep():
		return
	if not _is_player_in_area(hug_area):
		return
	player.sleep_meter.drain(moonwalker_balance.graze_meter_cost)
	_graze_cooldown = moonwalker_balance.graze_cooldown_seconds


func _moon_lean() -> float:
	if moonwalk_gait == null or state == State.AWAKE or not moonwalk_gait.is_sliding():
		return 0.0
	return MOON_LEAN_ROTATION


func _engage_chase_at(chase_speed: float) -> void:
	if _try_hug_grab():
		return
	state = State.CHASE
	if not _has_valid_player():
		player = null
		state = State.WANDER
		return
	velocity = (player.global_position - global_position).normalized() * chase_speed


func _engage_dash_charge(delta: float) -> void:
	# The Gamer closes in on fast, short dashes. The dash only moves him: the
	# grab stays the plain hug, so a dash that reaches the player ends in a hug
	# like any sleepwalker.
	if _try_hug_grab():
		return
	state = State.CHASE
	if not _has_valid_player():
		player = null
		state = State.WANDER
		return
	velocity = _dash_gait(delta, (player.global_position - global_position).normalized())


func _try_hug_grab() -> bool:
	# Poll the sensor areas instead of body_entered/exited signals: the signal
	# delivery order between sibling areas is not guaranteed and can misorder
	# the WANDER/CHASE/HUG transitions. A rolling or freshly-freed player
	# cannot be grabbed: the hug slides off.
	if (
		_is_player_in_area(hug_area)
		and _has_valid_player()
		and not player.is_invulnerable()
		and not player.is_asleep()
	):
		if player.toolbelt.try_parry_hug(self) or player.toolbelt.try_block_hug(self, player):
			# The hug never lands: the Steam Wand parry of section 14 or the
			# Portafilter shield of section 11 throws the sleepwalker off.
			state = State.CHASE
			velocity = Vector2.ZERO
			return true
		state = State.HUG
		velocity = Vector2.ZERO
		if _dash_phase == DashPhase.WINDUP:
			visual.modulate = Color.WHITE
		player.set_grabbed_by(self)
		player.sleep_meter.escalate_drain(SleepMeter.DrainTier.HUG)
		return true
	if state == State.HUG and _has_valid_player():
		player.clear_grab(self)
	return false


func _has_valid_player() -> bool:
	return player != null and is_instance_valid(player)


func _dash_gait(delta: float, steer_direction: Vector2) -> Vector2:
	# The Gamer's gait, wander and chase alike: a rest, a windup telegraph,
	# then one short committed dash. The direction locks when the dash fires,
	# so a sideways dodge slips the pass.
	_dash_timer -= delta
	match _dash_phase:
		DashPhase.REST:
			if _dash_timer <= 0.0:
				_dash_phase = DashPhase.WINDUP
				_dash_timer = gamer_balance.windup_seconds
				visual.modulate = DASH_WINDUP_MODULATE
			return Vector2.ZERO
		DashPhase.WINDUP:
			if _dash_timer <= 0.0:
				_dash_phase = DashPhase.BURST
				_dash_timer = gamer_balance.dash_duration_seconds
				_dash_direction = steer_direction
				visual.modulate = Color.WHITE
			return Vector2.ZERO
		DashPhase.BURST:
			if _dash_timer <= 0.0:
				_dash_phase = DashPhase.REST
				_dash_timer = gamer_balance.rest_seconds
				return Vector2.ZERO
			return _dash_direction * gamer_balance.dash_speed
	return Vector2.ZERO


func _try_spot_player() -> void:
	# A cinematic holds the player out of play while the input stays locked,
	# like the opening video of the first ten minutes. The crowd does not
	# notice a player who cannot react: no spot, no chase, and no first
	# meeting starts behind the lock.
	for body: Node2D in sense_area.get_overlapping_bodies():
		if body is not Player:
			continue
		if (body as Player).is_input_locked():
			return
		player = body
		state = State.CHASE
		if not _met_announced:
			_met_announced = true
			first_met.emit(enemy_type.type_id)
		return


func _is_player_in_area(area: Area2D) -> bool:
	for body: Node2D in area.get_overlapping_bodies():
		if body is Player:
			player = body
			return true
	return false


func _pick_wander_direction() -> void:
	_wander_timer = _rng.randf_range(
		balance.wander_change_min_seconds, balance.wander_change_max_seconds
	)
	if _rng.randf() < balance.idle_chance:
		_wander_direction = Vector2.ZERO
	else:
		_wander_direction = Vector2.from_angle(_rng.randf() * TAU).normalized()
