# ABOUTME: SleepvanaStage is the Sleepvana side quest in the world: the band at
# ABOUTME: its three sites, the fan crowd, the encore, and the concert wake event.
class_name SleepvanaStage
extends SignatureQuest

signal spoke(line: String)

const BAND_MEMBER_SCENE := preload("res://scenes/quests/band_member.tscn")

# The three sleeping places of the band, section 13. The garage also holds the
# frontman and plays the encore and the concert.
const SITE_GREENHOUSE := "Greenhouse"
const SITE_SOFA := "The Sofa"
const SITE_GARAGE := "The Garage"

const QUEST_ID := "sleepvana"
const SONG_LINE := "One last show. Smells like bean spirit!"
const QUEST_ACCEPT_TOAST := "SLEEPVANA NEEDS ONE LAST SHOW. WAKE THE BAND."
const CROWD_STAGE_TOAST := "THE BAND IS AWAKE. GATHER %d FANS AT THE FIELD CAFE."
const NOT_ENOUGH_FANS_TOAST := "THE CROWD IS TOO SMALL. THE FIELD CAFE NEEDS %d FANS."
const RECRUIT_TOAST := "THE FANS FOLLOW YOU. LEAD THEM TO THE GARAGE."
const ENCORE_TOAST := "THE CROWD IS HERE. THE ENCORE PLAYS. BREW THE FRONTMAN ORDER."
const ENCORE_MISSED_TOAST := "THE ENCORE ENDS. THE CROWD DRIFTS APART. GATHER AGAIN."
const CONCERT_TOAST := "SMELLS LIKE BEAN SPIRIT! EVERY SLEEPWALKER IN HEARING RANGE WAKES."

# The garage hosts the guitarist and the frontman side by side.
const MEMBER_OFFSET := Vector2(56.0, 0.0)
const FRONTMAN_OFFSET := Vector2(-56.0, 0.0)
# The fans trail behind the player, one spacing step per fan.
const FOLLOW_SPACING := 18.0

@export var balance: SleepvanaBalance
@export var brewing_balance: BrewingBalance
# The three simple orders and the frontman order, section 13.
@export var order_bassist: Recipe
@export var order_drummer: Recipe
@export var order_guitarist: Recipe
@export var order_frontman: Recipe

var quest: SleepvanaQuest = null

# The run arrives as a plain Node: naming the run class here would tie the
# stage's compile back into the city script (T112).
var _run: Node = null
var _members: Array[BandMember] = []
var _frontman: BandMember = null
var _fans: Array[Sleepwalker] = []
var _garage_position := Vector2.ZERO
var _quest_accepted := false
var _log_state_applied := false


func _ready() -> void:
	quest = SleepvanaQuest.new(balance)


func setup(run: Node) -> void:
	# The stage builds the band at its three sites and wires every quest beat
	# to the world: toasts, the fan crowd, and the quest log.
	_run = run
	_build_band()
	_wire_beats()


func _physics_process(delta: float) -> void:
	if quest == null or _run == null:
		return
	_apply_loaded_log_state()
	quest.tick(delta)
	if quest.phase() == SleepvanaQuest.Phase.CROWD_STAGE and quest.is_crowd_recruited():
		quest.crowd_arrived(_fans_at_garage())


func try_interact() -> bool:
	# The interact key at the open field cafe recruits the gathered crowd for
	# the show, section 13. Anywhere else keeps the key for the van.
	if _run == null or quest == null:
		return false
	var player: Player = _run.player
	if player.is_asleep() or player.is_grabbed() or player.is_input_locked():
		return false
	if quest.phase() != SleepvanaQuest.Phase.CROWD_STAGE or quest.is_crowd_recruited():
		return false
	var van: MobileCafeVan = _run.van()
	if van == null or not van.is_field_base_open() or not van.is_player_at_van():
		return false
	var gathered: Array[Sleepwalker] = van.gathered_survivors()
	if not quest.recruit_crowd(gathered.size()):
		_run.hud.show_toast(NOT_ENOUGH_FANS_TOAST % balance.crowd_size)
		return true
	_hire_fans(gathered)
	_run.hud.show_toast(RECRUIT_TOAST)
	return true


func receive_frontman_cup(cup: BrewedCup) -> bool:
	# The frontman cure rule: the encore window and the frontman order, through
	# the same tier-led rule as the boss cures.
	if quest == null or not quest.accepts_frontman_cup():
		return false
	if not BossCure.accepted(cup, order_frontman, brewing_balance):
		return false
	_frontman.wake_now()
	return quest.wake_the_frontman()


func members() -> Array[BandMember]:
	return _members.duplicate()


func frontman() -> BandMember:
	return _frontman


func fans() -> Array[Sleepwalker]:
	return _fans.duplicate()


func garage_position() -> Vector2:
	return _garage_position


func _build_band() -> void:
	# The band sleeps at its three named sites, section 13. The garage is the
	# stage of the last show: the guitarist sleeps there, and the frontman
	# sleeps beside him behind the crowd rule.
	var map: CityMap = _run.city_map()
	_place_site_member(
		SITE_GREENHOUSE,
		order_bassist,
		"THE BASSIST",
		"The plants kept me company. Thanks, barista.",
		0
	)
	_place_site_member(
		SITE_SOFA, order_drummer, "THE DRUMMER", "Five more minutes... fine. One more show.", 1
	)
	var garage: CityBlockView = map.find_quest_site(SITE_GARAGE)
	if garage == null or garage.quest_site_marker() == null:
		return
	_garage_position = garage.quest_site_marker().global_position
	_place_site_member(
		SITE_GARAGE, order_guitarist, "THE GUITARIST", "Tuned to drop bean. Let us play.", 2
	)
	_frontman = _place_member(
		order_frontman, "THE FRONTMAN", SONG_LINE, -1, _garage_position + FRONTMAN_OFFSET, true
	)


func _place_site_member(
	site_name: String, order: Recipe, role: String, line: String, index: int
) -> void:
	# One of the three sleeping members at his named site.
	var map: CityMap = _run.city_map()
	var view: CityBlockView = map.find_quest_site(site_name)
	if view == null or view.quest_site_marker() == null:
		return
	var member := _place_member(
		order, role, line, index, view.quest_site_marker().global_position + MEMBER_OFFSET
	)
	_members.append(member)


func _place_member(
	order: Recipe, role: String, line: String, index: int, position: Vector2, frontman := false
) -> BandMember:
	# Every export lands before the child enters the tree, so _ready reads the
	# full member: the role label and the crowd hint need no second pass.
	var member := BAND_MEMBER_SCENE.instantiate() as BandMember
	member.name = "Band" + role.replace("THE ", "")
	member.brewing_balance = brewing_balance
	member.order = order
	member.role_label = role
	member.wake_line = line
	member.is_frontman = frontman
	add_child(member)
	member.global_position = position
	member.bind_stage(self, index)
	return member


func _wire_beats() -> void:
	quest.member_woke.connect(_on_member_woke)
	quest.band_ready.connect(_on_band_ready)
	quest.encore_began.connect(_on_encore_began)
	quest.encore_missed.connect(_on_encore_missed)
	quest.frontman_woke.connect(_on_frontman_woke)
	for member: BandMember in _members:
		member.woke_up.connect(_on_member_band_wake.bind(member.site_index))


func _on_member_band_wake(site_index: int) -> void:
	# A member woke on his own order; the quest records the site.
	quest.record_member_wake(site_index)


func _on_member_woke(_site_index: int) -> void:
	# The first woken member asks for the reunion show, so the side quest turns
	# active and its marker appears, section 12.
	if _quest_accepted:
		return
	_quest_accepted = true
	_run.quest_log.accept(QUEST_ID)
	_run.hud.show_toast(QUEST_ACCEPT_TOAST)


func _on_band_ready() -> void:
	_run.hud.show_toast(CROWD_STAGE_TOAST % balance.crowd_size)


func _on_encore_began() -> void:
	_run.hud.show_toast(ENCORE_TOAST)
	_frontman.announce_encore()


func _apply_loaded_log_state() -> void:
	# Section 18: a reload resumes the completed quest silently without
	# replaying the concert beat.
	if _log_state_applied:
		return
	_log_state_applied = true
	var saved: SideQuest = _run.quest_log.quest(QUEST_ID)
	if saved == null or not saved.is_complete():
		return
	_quest_accepted = true
	quest.load_state({"phase": SleepvanaQuest.Phase.CONCERT, "woke_sites": [0, 1, 2]})
	for member: BandMember in _members:
		member.wake_now(true)
	if _frontman != null:
		_frontman.wake_now(true)


func _on_encore_missed() -> void:
	_run.hud.show_toast(ENCORE_MISSED_TOAST)
	if _frontman != null:
		_frontman.reset_encore()
	_release_fans()


func _on_frontman_woke() -> void:
	_play_concert()


func _hire_fans(gathered: Array[Sleepwalker]) -> void:
	# The gathered fans leave the tables and follow the player to the garage.
	_run.van().release_survivors(gathered)
	_fans = gathered.duplicate()
	for i: int in range(_fans.size()):
		var fan := _fans[i]
		fan.follow(_run.player, fan.balance.gather_stop_distance + FOLLOW_SPACING * float(i))


func _release_fans() -> void:
	for fan: Sleepwalker in _fans:
		if is_instance_valid(fan):
			fan.stop_following()
	_fans.clear()


func _fans_at_garage() -> int:
	var arrived := 0
	for fan: Sleepwalker in _fans:
		if not is_instance_valid(fan):
			continue
		if fan.global_position.distance_to(_garage_position) <= balance.garage_arrival_radius:
			arrived += 1
	return arrived


func _play_concert() -> void:
	# The reward, section 13: one last concert. The hit song plays diegetic,
	# and every sleepwalker in hearing range of the garage wakes.
	_release_fans()
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var walker := node as Sleepwalker
		if walker == null or walker.is_awake():
			continue
		if walker.global_position.distance_to(_garage_position) <= balance.concert_wake_radius:
			walker.wake_up()
	_run.quest_log.complete(QUEST_ID)
	spoke.emit(SONG_LINE)
	_run.hud.show_toast(CONCERT_TOAST)
