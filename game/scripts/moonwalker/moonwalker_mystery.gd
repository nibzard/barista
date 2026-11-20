# ABOUTME: MoonwalkerMystery plays the section 24 mystery inside one city run.
# ABOUTME: The hint speakers of the route, and the dawn haunt: the fight, the
# ABOUTME: wake finale, and the optional dance-off that teaches the Moonwalk.
class_name MoonwalkerMystery
extends Node2D

signal spoke(line: String)

enum Phase { WAITING, FIGHT, FINALE, OFFER, DANCE_OFF, DEPARTING, DONE }

# The one spin, then the one toe stand, then the one small "hee-hee",
# section 24: the finale steps in order.
enum FinaleStep { SPIN, TOE_STAND, HEE_HEE }

# The mystery rides the run behind this group, so tests and the run find it
# without a compile-time handle into the city script.
const MYSTERY_GROUP := &"moonwalker_mystery"
# Loaded at use time, the kit rule: the city run, the enemy scenes, and the
# minigame views share one big load graph, and a const preload here binds an
# empty scene whenever another load of the same resource runs (T102).
const MOONWALKER_SCENE_PATH := "res://scenes/enemies/moonwalker.tscn"
const DANCE_OFF_SCENE_PATH := "res://scenes/minigames/dance_off.tscn"
const HINT_NPC_SCENE_PATH := "res://scenes/city/mystery_hint_npc.tscn"
# The dance-off overlay rides above the HUD, like the brew overlays.
const OVERLAY_LAYER := 10
# The figure takes the interact key inside this radius of himself.
const OFFER_RADIUS := 110.0
# He leaves the way he came: one long backwards slide into the dawnless day.
const DEPART_SECONDS := 0.9

const DAWN_TOAST := "DAWN. THE SPEAKERS STAY DEAD. WATCH THE PLAZAS."
const WAKE_TOAST := "THE MOONWALKER. STATUS: SMOOTH."
const OFFER_TOAST := "HE OFFERS ONE DANCE-OFF. STAND AT HIM AND PRESS INTERACT."
const RETURN_TOAST := "HE RETURNS WITH THE DAWN. ONE DANCE-OFF STANDS."
const GONE_TOAST := "THE DAWN CLOSES. HE SLIDES AWAY."
const DODGE_TOAST := "THE MOONWALK DODGE IS YOURS. NO POWER. ONLY STYLE."
const LOSE_TOAST := "NOT SMOOTH ENOUGH. HE RETURNS AT DAWN."

@export var balance: MoonwalkerBalance

var _phase: Phase = Phase.WAITING
var _clock: DawnClock = null
var _figure: Sleepwalker = null
var _dance_view: DanceOffView = null
var _overlay_layer: CanvasLayer = null
var _finale_step: FinaleStep = FinaleStep.SPIN
var _beat_time_left := 0.0
var _depart_direction := Vector2.RIGHT
var _dawn_toasted := false
var _offer_hinted := false

# The run arrives as a plain Node: naming the run class here would tie this
# script's compile back into the city script (T112).
var _run: Node = null
var _player: Player = null
var _map: CityMap = null
var _dex: SleepyDex = null
var _haunts := false


func _ready() -> void:
	add_to_group(MYSTERY_GROUP)


func setup(run: Node) -> void:
	# The mystery binds itself to the run: the map, the player, the dex, and
	# the toast line of the HUD. The hint speakers build in every city that
	# authors them; the haunt arms only where the city names it.
	_run = run
	_player = run.player
	_map = run.city_map()
	_dex = run.sleepy_dex()
	_build_hints()
	_haunts = run.definition.moonwalker_haunts
	if _haunts:
		_clock = DawnClock.new(balance)


func _physics_process(delta: float) -> void:
	if not _haunts or _run == null:
		return
	_clock.tick(delta)
	_tick_dawn_toast()
	match _phase:
		Phase.WAITING:
			_tick_waiting()
		Phase.FIGHT:
			_tick_fight()
		Phase.FINALE:
			_tick_finale(delta)
		Phase.OFFER:
			_tick_offer()
		Phase.DANCE_OFF:
			pass
		Phase.DEPARTING:
			_tick_departing(delta)
		Phase.DONE:
			pass


func phase() -> Phase:
	return _phase


func figure() -> Sleepwalker:
	return _figure


func dawn_clock() -> DawnClock:
	return _clock


func dance_off_view() -> DanceOffView:
	# The live dance-off overlay, while it plays.
	return _dance_view


func owns_screen() -> bool:
	# The dance-off overlay owns the whole screen, like the brew stand: the
	# touch buttons stand down behind it.
	return _dance_view != null


func mystery_done() -> bool:
	# The mystery ends only when both halves landed: the hidden entry open
	# and the Moonwalk dodge taught.
	return _dex.is_found("moonwalker") and _player.dodge_style == Player.DodgeStyle.MOONWALK


func hint_npcs() -> Array[MysteryHintNpc]:
	# The hint speakers of this run, in tree order.
	var found: Array[MysteryHintNpc] = []
	for node: Node in get_tree().get_nodes_in_group(MysteryHintNpc.HINT_GROUP):
		var npc := node as MysteryHintNpc
		if npc != null and is_ancestor_of(npc):
			found.append(npc)
	return found


func try_begin_dance_off() -> bool:
	# One button at the woken figure: the dance-off opens when the player
	# stands at him. Anywhere else keeps the press for the run.
	if _phase != Phase.OFFER or _figure == null:
		return false
	if _player.is_asleep() or _player.is_input_locked():
		return false
	if _player.global_position.distance_to(_figure.global_position) > OFFER_RADIUS:
		return false
	_open_dance_off()
	return true


func _unhandled_input(event: InputEvent) -> void:
	# The dance-off moment owns the interact key: the offer consumes the
	# press at the figure, and the beats consume every press while the
	# overlay plays, so the run chain below never answers the same press.
	if not event.is_action_pressed(&"interact"):
		return
	if _run != null and _run.brew_pot != null and _run.brew_pot.holds_interact():
		return
	if _run != null and _run.signature_quest != null and _run.signature_quest.holds_interact():
		return
	if _phase == Phase.DANCE_OFF or try_begin_dance_off():
		get_viewport().set_input_as_handled()


func _build_hints() -> void:
	# Section 24: one awake speaker per authored clue, standing at the named
	# site of the city, like the busker of the San Coffesco park.
	for hint: MysteryHint in _run.definition.mystery_hints:
		var site: CityBlockView = _map.find_quest_site(hint.site_name)
		if site == null or site.quest_site_marker() == null:
			continue
		var npc := (load(HINT_NPC_SCENE_PATH) as PackedScene).instantiate() as MysteryHintNpc
		npc.name = "Hint" + hint.speaker_name.to_pascal_case()
		npc.hint = hint
		add_child(npc)
		npc.global_position = site.quest_site_marker().global_position


func _tick_waiting() -> void:
	if mystery_done():
		_phase = Phase.DONE
		return
	if not MoonwalkerSpawnRule.should_spawn(
		_clock.is_dawn(), _tower_off(), _player_in_silent_zone(), false
	):
		return
	_spawn_figure()


func _tick_fight() -> void:
	# The fight holds while the dawn holds. He leaves with the light when
	# the window closes, and the cure ends the fight into the finale.
	if _figure.is_awake():
		_begin_finale()
		return
	if not _clock.is_dawn():
		_run.hud.show_toast(GONE_TOAST)
		_begin_depart()


func _tick_finale(delta: float) -> void:
	# Section 24: one spin, one toe stand, one small "hee-hee", in order,
	# one beat each. The hidden entry opens on the last beat.
	_beat_time_left = maxf(0.0, _beat_time_left - delta)
	var progress := 1.0 - _beat_time_left / balance.finale_beat_seconds
	match _finale_step:
		FinaleStep.SPIN:
			# The spin rides the whole body: the figure resets its own
			# visual rotation every physics frame, and the parent of a tree
			# ticks first, so a visual spin would be erased before the draw.
			_figure.rotation = TAU * progress
		FinaleStep.TOE_STAND:
			_figure.visual.scale = Vector2(1.0, 1.0 + 0.18 * progress)
		FinaleStep.HEE_HEE:
			pass
	if _beat_time_left > 0.0:
		return
	match _finale_step:
		FinaleStep.SPIN:
			_figure.rotation = 0.0
			_finale_step = FinaleStep.TOE_STAND
		FinaleStep.TOE_STAND:
			_figure.visual.scale = Vector2.ONE
			_finale_step = FinaleStep.HEE_HEE
		FinaleStep.HEE_HEE:
			_finish_wake()
			return
	_beat_time_left = balance.finale_beat_seconds


func _tick_offer() -> void:
	# The offer stands while the dawn stands. The walk-up hint names it once,
	# and the dawn closes it: he returns with the next one.
	if not _clock.is_dawn():
		_begin_depart()
		return
	if (
		not _offer_hinted
		and _player.global_position.distance_to(_figure.global_position) <= OFFER_RADIUS
	):
		_offer_hinted = true
		_run.hud.show_toast(OFFER_TOAST)


func _tick_departing(delta: float) -> void:
	# He slides away, backwards like always, and the dawn waits for the next
	# meeting.
	_beat_time_left = maxf(0.0, _beat_time_left - delta)
	_figure.global_position += _depart_direction * balance.slide_speed * delta
	if _beat_time_left > 0.0:
		return
	_figure.queue_free()
	_figure = null
	_phase = Phase.DONE if mystery_done() else Phase.WAITING


func _tick_dawn_toast() -> void:
	# One quiet toast names the window, only while the tower stays dead: the
	# mystery never speaks over a city that still plays the address.
	if _clock.is_dawn():
		if not _dawn_toasted and _tower_off() and not mystery_done():
			_dawn_toasted = true
			_run.hud.show_toast(DAWN_TOAST)
	else:
		_dawn_toasted = false


func _spawn_figure() -> void:
	# Section 24: a figure slides backwards across the plaza. He enters at
	# the zone edge and crosses through its center, where the player stands.
	var zone := _player_silent_zone()
	if zone == null:
		return
	_figure = (load(MOONWALKER_SCENE_PATH) as PackedScene).instantiate() as Sleepwalker
	_figure.name = "MoonwalkerFigure"
	add_child(_figure)
	_figure.global_position = zone.global_position + Vector2(balance.appear_distance, 0.0)
	_figure.moonwalk_gait.aim(Vector2.LEFT)
	WakeLinePresenter.attach(_figure, spoke)
	if _dex.is_found("moonwalker"):
		# He woke here before and the dance-off still stands: he returns
		# awake, straight to the offer.
		_figure.wake_up()
		_detach_figure_from_groups()
		_offer_hinted = false
		_phase = Phase.OFFER
		_run.hud.show_toast(RETURN_TOAST)
		return
	_phase = Phase.FIGHT


func _begin_finale() -> void:
	_detach_figure_from_groups()
	_phase = Phase.FINALE
	_finale_step = FinaleStep.SPIN
	_beat_time_left = balance.finale_beat_seconds


func _finish_wake() -> void:
	# The last beat: the small "hee-hee" floats above him, the hidden entry
	# opens with its smooth status, and the toast names him.
	spoke.emit(_figure.enemy_type.wake_line)
	_dex.meet("moonwalker")
	_run.hud.show_toast(WAKE_TOAST)
	_offer_hinted = false
	_phase = Phase.OFFER


func _begin_depart() -> void:
	_detach_figure_from_groups()
	if _figure != null:
		_figure.set_physics_process(false)
	_phase = Phase.DEPARTING
	_beat_time_left = DEPART_SECONDS
	_depart_direction = Vector2.RIGHT


func _detach_figure_from_groups() -> void:
	# Once awake or leaving, the mystery figure is no longer a crowd sleeper:
	# the field cafe tables never gather him before he slides away.
	if _figure == null:
		return
	if _figure.is_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		_figure.remove_from_group(Sleepwalker.SLEEPWALKER_GROUP)
	if _figure.is_in_group(CureDelivery.WAKEABLE_GROUP):
		_figure.remove_from_group(CureDelivery.WAKEABLE_GROUP)
	if _run != null and _run.van() != null:
		var leaving: Array[Sleepwalker] = [_figure]
		_run.van().release_survivors(leaving)


func _open_dance_off() -> void:
	if _overlay_layer == null:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "MoonwalkerOverlay"
		_overlay_layer.layer = OVERLAY_LAYER
		add_child(_overlay_layer)
	_dance_view = (load(DANCE_OFF_SCENE_PATH) as PackedScene).instantiate() as DanceOffView
	_dance_view.name = "DanceOff"
	_dance_view.balance = balance
	_dance_view.finished.connect(_on_dance_finished)
	_overlay_layer.add_child(_dance_view)
	_player.set_input_locked(true)
	_phase = Phase.DANCE_OFF


func _on_dance_finished(dance_won: bool) -> void:
	# The dance ends: the view closes, the player takes the screen back, and
	# a win teaches the Moonwalk dodge, a cosmetic roll variant with no
	# power, only style, section 24. A loss sends him into the dawn.
	_dance_view.queue_free()
	_dance_view = null
	_player.set_input_locked(false)
	if dance_won:
		_player.dodge_style = Player.DodgeStyle.MOONWALK
		_run.hud.show_toast(DODGE_TOAST)
	else:
		_run.hud.show_toast(LOSE_TOAST)
	_begin_depart()


func _tower_off() -> bool:
	var tower := _map.broadcast_tower()
	return tower != null and tower.is_switched_off()


func _player_silent_zone() -> SleepZone:
	# The silent zone the player stands in, section 24: a speaker pole zone
	# whose broadcast died with the tower.
	for i: int in range(_map.block_count()):
		var zone := _map.block_view(i).pole_zone()
		if zone != null and MoonwalkerSpawnRule.zone_is_silent(zone):
			return zone
	return null


func _player_in_silent_zone() -> bool:
	return _player_silent_zone() != null
