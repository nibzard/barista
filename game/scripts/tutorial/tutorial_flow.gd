# ABOUTME: TutorialFlow is the pure step machine of the first ten minutes, section 19.
# ABOUTME: The world reports events; this class owns the order and the prompts.
class_name TutorialFlow
extends RefCounted

signal step_changed(from_step: Step, to_step: Step)
signal finished

# One value per beat of section 19, in play order.
enum Step { VIDEO, MOVE, DRINK, DOOR, THROW, POLE, SURVIVOR, ROAD, TOWER, FINALE, DONE }

# One short prompt per step. Section 19: no menus, no text walls.
const PROMPT_MOVE := "MOVE."
const PROMPT_DRINK := "DRINK ONE CUP."
const PROMPT_DOOR := "A NEIGHBOR WALKS PAST. OPEN THE DOOR."
const PROMPT_THROW := "THROW YOUR CUP."
const PROMPT_POLE := "THE SPEAKER DRAINS YOU. STEP BACK INSIDE."
const PROMPT_SURVIVOR := "SOMEONE WAITS AT THE DOOR."
const PROMPT_TOWER := "THE TOWER. FIND A FUSE. SWITCH IT OFF."
const PROMPT_ROAD_PREFIX := "ON THE WAY: "
const PROMPT_ROAD_SEPARATOR := " - "
const PROMPT_VIDEO_END := ""
# The hug override: the road prompt hands the line to the mash lesson.
const MASH_PROMPT := "A HUG! MASH TO BREAK FREE."
# The three lessons of the road, section 19 step 8, in prompt order.
const LESSON_HUG := "BREAK A HUG"
const LESSON_DODGE := "DODGE"
const LESSON_BREW := "BREW AT THE POT"

# The fixed prompts per step. The road composes its own line from the lessons
# left, and the video, the finale, and a done tutorial stay silent.
var _step_prompts := {
	Step.MOVE: PROMPT_MOVE,
	Step.DRINK: PROMPT_DRINK,
	Step.DOOR: PROMPT_DOOR,
	Step.THROW: PROMPT_THROW,
	Step.POLE: PROMPT_POLE,
	Step.SURVIVOR: PROMPT_SURVIVOR,
	Step.TOWER: PROMPT_TOWER,
}

var _step := Step.VIDEO
var _hug_broken := false
var _dodged := false
var _brewed := false


func current_step() -> Step:
	return _step


func is_done() -> bool:
	return _step == Step.DONE


func prompt_text() -> String:
	if _step == Step.ROAD:
		return PROMPT_ROAD_PREFIX + PROMPT_ROAD_SEPARATOR.join(road_lessons_remaining())
	return str(_step_prompts.get(_step, PROMPT_VIDEO_END))


func road_lessons_remaining() -> Array[String]:
	# The road lessons that still stand, in prompt order. Any order completes
	# them; all three must land before the tower step.
	var lessons: Array[String] = []
	if not _hug_broken:
		lessons.append(LESSON_HUG)
	if not _dodged:
		lessons.append(LESSON_DODGE)
	if not _brewed:
		lessons.append(LESSON_BREW)
	return lessons


func end_video() -> bool:
	# The video ends by its 20 seconds or by the skip; both paths land here.
	return _advance_from(Step.VIDEO, Step.MOVE)


func notify_moved() -> bool:
	return _advance_from(Step.MOVE, Step.DRINK)


func notify_drank() -> bool:
	# The cup is in: the meter filled, section 19 step 3.
	return _advance_from(Step.DRINK, Step.DOOR)


func notify_left_cafe() -> bool:
	return _advance_from(Step.DOOR, Step.THROW)


func notify_sleepwalker_woke() -> bool:
	# The first throw hit: the Neighbor wakes, says thanks, and shuffles away.
	return _advance_from(Step.THROW, Step.POLE)


func notify_back_in_cafe() -> bool:
	# The safe-zone lesson lands: the player stepped back inside, step 6.
	return _advance_from(Step.POLE, Step.SURVIVOR)


func notify_survivor_spoke() -> bool:
	# "The tower. Kill the speaker." The tower marker appears, step 7.
	return _advance_from(Step.SURVIVOR, Step.ROAD)


func notify_hug_broken() -> bool:
	# The first hug broke, section 19 step 8.
	if _step != Step.ROAD or _hug_broken:
		return false
	_hug_broken = true
	_check_road_complete()
	return true


func notify_dodged() -> bool:
	# The first dodge roll landed, section 19 step 8.
	if _step != Step.ROAD or _dodged:
		return false
	_dodged = true
	_check_road_complete()
	return true


func notify_brewed() -> bool:
	# The first Grind Dial brew finished, section 19 step 8.
	if _step != Step.ROAD or _brewed:
		return false
	_brewed = true
	_check_road_complete()
	return true


func _check_road_complete() -> void:
	# All three lessons stand: the road ends and the tower waits.
	if _hug_broken and _dodged and _brewed:
		_set_step(Step.TOWER)


func notify_tower_off() -> bool:
	# The tower beat lands at the tower step. A player who rushed past the road
	# lessons still gets the finale: the tower never waits, step 9.
	if _step == Step.TOWER or _step == Step.ROAD:
		_set_step(Step.FINALE)
		return true
	return false


func notify_finale_ended() -> bool:
	# The camera came back: the title card is done, step 10.
	return _advance_from(Step.FINALE, Step.DONE)


func save_state() -> Dictionary:
	# The auto-save of section 18 stores the step and the road lessons.
	return {"step": _step, "hug": _hug_broken, "dodge": _dodged, "brew": _brewed}


func load_state(saved: Dictionary) -> void:
	# A loaded tutorial never replays a beat: the state lands silent.
	_step = saved.get("step", Step.VIDEO) as Step
	_hug_broken = bool(saved.get("hug", false))
	_dodged = bool(saved.get("dodge", false))
	_brewed = bool(saved.get("brew", false))


func _advance_from(from_step: Step, to_step: Step) -> bool:
	if _step != from_step:
		return false
	_set_step(to_step)
	return true


func _set_step(to_step: Step) -> void:
	var from_step := _step
	_step = to_step
	step_changed.emit(from_step, to_step)
	if to_step == Step.DONE:
		finished.emit()
