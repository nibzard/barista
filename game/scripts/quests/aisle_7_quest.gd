# ABOUTME: Aisle7Quest is the pure state machine of the Aisle 7 side quest,
# ABOUTME: section 13: the photo, one Turkish cup, the sweet hug, the master.
class_name Aisle7Quest
extends RefCounted

signal photo_taken
signal husband_woke
signal sweet_hug

enum Phase { PHOTO_WAIT, HUSBAND_ASLEEP, SWEET_HUG, MASTER_OPEN }

# The Turkish recipe wakes the husband, section 15: any bean, a medium roast,
# the Turkish pot. The tiers lead, like every boss cure.
var cure: Recipe
var brewing_balance: BrewingBalance

var _phase: int = Phase.PHOTO_WAIT


func _init(quest_cure: Recipe = null, brew_balance: BrewingBalance = null) -> void:
	cure = quest_cure
	brewing_balance = brew_balance


func phase() -> int:
	return _phase


func take_photo() -> bool:
	# The wife hands the player the photo, section 13. Only then does the
	# husband accept a brew.
	if _phase != Phase.PHOTO_WAIT:
		return false
	_phase = Phase.HUSBAND_ASLEEP
	photo_taken.emit()
	return true


func receive_cup(cup: BrewedCup) -> bool:
	# One Turkish cup brewed in front of him wakes the husband. The same
	# tier-led rule as the boss cures decides: a perfect cup wakes him from any
	# brew, a weak cup wakes nobody, and between the tiers only the Turkish
	# recipe itself works.
	if _phase != Phase.HUSBAND_ASLEEP:
		return false
	if not BossCure.accepted(cup, cure, brewing_balance):
		return false
	_phase = Phase.SWEET_HUG
	husband_woke.emit()
	return true


func is_husband_awake() -> bool:
	return _phase == Phase.SWEET_HUG or _phase == Phase.MASTER_OPEN


func hug_completed() -> bool:
	# The wife reached him: he holds her, the only sweet hug in the game, and
	# the sleeper becomes the teacher.
	if _phase != Phase.SWEET_HUG:
		return false
	_phase = Phase.MASTER_OPEN
	sweet_hug.emit()
	return true


func is_master_unlocked() -> bool:
	# The Turkish master teaches after the hug, section 13.
	return _phase == Phase.MASTER_OPEN


func save_state() -> Dictionary:
	# The save system stores the quest as one plain number, section 18.
	return {"phase": _phase}


func load_state(saved: Dictionary) -> void:
	# A loaded quest never replays a beat. An unknown number keeps the quest at
	# the photo wait.
	var saved_phase := int(saved.get("phase", Phase.PHOTO_WAIT))
	match saved_phase:
		Phase.PHOTO_WAIT, Phase.HUSBAND_ASLEEP, Phase.SWEET_HUG, Phase.MASTER_OPEN:
			_phase = saved_phase
		_:
			_phase = Phase.PHOTO_WAIT
