# ABOUTME: BrewingSkills tracks the 0-10 brewing skill per method, section 14.
# ABOUTME: Pure logic with no nodes, so tests run without a scene tree.
class_name BrewingSkills
extends RefCounted

signal skill_gained(method_id: String, new_skill: int)
signal auto_brew_opened(method_id: String)

var balance: BrewingBalance

var _skills: Dictionary = {}
var _auto_brew_announced: Dictionary = {}


func _init(brewing_balance: BrewingBalance = null) -> void:
	balance = brewing_balance


func skill(method_id: String) -> int:
	return int(_skills.get(method_id, 0))


func max_skill() -> int:
	return balance.max_method_skill if balance != null else 0


func record_brew(method_id: String, score: float) -> int:
	# Section 14: a good brew (score 80 or more) trains +1 skill, a perfect
	# brew (95 or more) trains +2, a weak brew trains nothing.
	if balance == null:
		return 0
	var gain := 0
	if score >= balance.perfect_tier_min_score:
		gain = balance.perfect_brew_skill_gain
	elif score >= balance.good_tier_min_score:
		gain = balance.good_brew_skill_gain
	return _apply_gain(method_id, gain)


func record_master_lesson(method_id: String) -> int:
	# Section 14: one master lesson trains +2 skill. The masters task owns
	# who teaches and how many lessons exist; this call is the grant hook.
	if balance == null:
		return 0
	return _apply_gain(method_id, balance.master_lesson_skill_gain)


func is_auto_brew_available(method_id: String) -> bool:
	# Section 14: at skill 10, auto-brew opens for the method.
	if balance == null:
		return false
	return skill(method_id) >= max_skill()


func auto_brew_score() -> float:
	# Section 14: auto-brew always scores 80. It never scores 95.
	return balance.auto_brew_score if balance != null else 0.0


func save_state() -> Dictionary:
	# The save system stores every method skill as one plain table,
	# section 18.
	return _skills.duplicate()


func load_state(saved: Dictionary) -> void:
	# A loaded game never replays a skill beat or an auto-brew opening.
	var ceiling := max_skill()
	_skills.clear()
	_auto_brew_announced.clear()
	for method_id: String in saved.keys():
		var loaded := clampi(int(saved[method_id]), 0, ceiling)
		_skills[method_id] = loaded
		_auto_brew_announced[method_id] = loaded >= ceiling


func _apply_gain(method_id: String, gain: int) -> int:
	# The skill never passes the cap, section 14.
	if gain <= 0:
		return 0
	var ceiling := max_skill()
	var old_skill := skill(method_id)
	var new_skill := mini(old_skill + gain, ceiling)
	if new_skill == old_skill:
		return 0
	_skills[method_id] = new_skill
	skill_gained.emit(method_id, new_skill)
	if new_skill >= ceiling:
		_announce_auto_brew(method_id)
	return new_skill - old_skill


func _announce_auto_brew(method_id: String) -> void:
	if _auto_brew_announced.get(method_id, false):
		return
	_auto_brew_announced[method_id] = true
	auto_brew_opened.emit(method_id)
