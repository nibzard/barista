# ABOUTME: SleepvanaQuest is the pure state machine of the Sleepvana side quest.
# ABOUTME: Three members wake to three orders, then the crowd stage, the encore,
# ABOUTME: and the concert wake event, section 13 of GAME_DESIGN.md.
class_name SleepvanaQuest
extends RefCounted

signal member_woke(site_index: int)
signal band_ready
signal crowd_recruited(fan_count: int)
signal encore_began
signal encore_missed
signal frontman_woke

enum Phase { BAND_ASLEEP, CROWD_STAGE, ENCORE, CONCERT }

# The band sleeps in three places: greenhouse, sofa, garage. The frontman is
# the fourth member; he sleeps at the garage and needs the full crowd.
const MEMBER_COUNT := 3

var balance: SleepvanaBalance

var _phase: int = Phase.BAND_ASLEEP
var _woke_sites: Array[int] = []
var _crowd_recruited := false
var _encore_time_left := 0.0


func _init(quest_balance: SleepvanaBalance = null) -> void:
	balance = quest_balance


func phase() -> int:
	return _phase


func record_member_wake(site_index: int) -> bool:
	# One band member woke at his site. The wake of the last member arms the
	# crowd stage: from there the frontman wakes only to a full crowd.
	if site_index < 0 or site_index >= MEMBER_COUNT:
		return false
	if _woke_sites.has(site_index):
		return false
	_woke_sites.append(site_index)
	member_woke.emit(site_index)
	if _woke_sites.size() == MEMBER_COUNT:
		_phase = Phase.CROWD_STAGE
		band_ready.emit()
	return true


func members_awake_count() -> int:
	return _woke_sites.size()


func is_band_ready() -> bool:
	return _woke_sites.size() >= MEMBER_COUNT


func can_recruit_crowd(gathered_fans: int) -> bool:
	# The crowd-gather condition, section 13: a full crowd stands at the field
	# cafe. The van level rule and the arrived-at-tables rule sit outside, with
	# the van that owns the tables.
	if balance == null:
		return false
	return _phase == Phase.CROWD_STAGE and gathered_fans >= balance.crowd_size


func recruit_crowd(gathered_fans: int) -> bool:
	# The player leads the gathered fans away from the tables. The quest keeps
	# the crowd stage until the fans reach the garage.
	if not can_recruit_crowd(gathered_fans):
		return false
	_crowd_recruited = true
	crowd_recruited.emit(gathered_fans)
	return true


func is_crowd_recruited() -> bool:
	return _crowd_recruited


func crowd_arrived(fans_at_garage: int) -> bool:
	# The led crowd reaches the garage, so the encore begins: the window in
	# which the frontman order works.
	if _phase != Phase.CROWD_STAGE or not _crowd_recruited:
		return false
	if fans_at_garage < balance.crowd_size:
		return false
	_phase = Phase.ENCORE
	_encore_time_left = balance.encore_seconds
	encore_began.emit()
	return true


func tick(delta: float) -> void:
	# The encore window runs out: the crowd drifts apart, and the player
	# gathers a new crowd at the field cafe for the next encore.
	if _phase != Phase.ENCORE:
		return
	_encore_time_left = maxf(0.0, _encore_time_left - delta)
	if _encore_time_left == 0.0:
		_phase = Phase.CROWD_STAGE
		_crowd_recruited = false
		encore_missed.emit()


func encore_time_left() -> float:
	return _encore_time_left


func accepts_frontman_cup() -> bool:
	# The frontman order works only during the encore, section 13.
	return _phase == Phase.ENCORE


func wake_the_frontman() -> bool:
	# The order landed during the encore: the concert plays, and the wake event
	# follows in the world.
	if _phase != Phase.ENCORE:
		return false
	_phase = Phase.CONCERT
	frontman_woke.emit()
	return true


func is_concert_done() -> bool:
	return _phase == Phase.CONCERT


func save_state() -> Dictionary:
	# The save system stores the whole quest state as one dict, section 18.
	return {
		"phase": _phase,
		"woke_sites": _woke_sites.duplicate(),
		"crowd_recruited": _crowd_recruited,
	}


func load_state(saved: Dictionary) -> void:
	# A loaded quest never replays a beat.
	var saved_phase := int(saved.get("phase", Phase.BAND_ASLEEP))
	match saved_phase:
		Phase.BAND_ASLEEP, Phase.CROWD_STAGE, Phase.ENCORE, Phase.CONCERT:
			_phase = saved_phase
		_:
			_phase = Phase.BAND_ASLEEP
	_woke_sites.clear()
	for site: int in saved.get("woke_sites", []):
		if site >= 0 and site < MEMBER_COUNT and not _woke_sites.has(site):
			_woke_sites.append(site)
	_crowd_recruited = bool(saved.get("crowd_recruited", false)) and _phase != Phase.BAND_ASLEEP
	if _phase == Phase.ENCORE and balance != null:
		_encore_time_left = balance.encore_seconds
	else:
		_encore_time_left = 0.0
