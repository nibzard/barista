# ABOUTME: OutroFlow is the pure step machine of the version ending, section 16.
# ABOUTME: The Karen blocks the road east, demands the manager, and the credits
# ABOUTME: catch her mid-sentence. The world reports events; this class owns the order.
class_name OutroFlow
extends RefCounted

signal step_changed(from_step: Step, to_step: Step)
signal finished

# One value per beat of section 16, in play order.
enum Step { WAITING, ARRIVAL, DEMAND, CREDITS, POST_GAME }

# The outro Karen speaks the wake line of her type, section 6: the manager.
const KAREN_TYPE := preload("res://resources/enemies/karen.tres")
# Where the credits cut her demand, as a share of the line: inside the last
# word, so the frozen line reads cut off mid-sentence.
const CAUGHT_CUT_FRACTION := 0.85
const CAUGHT_CUT_MARK := "—"

var _step := Step.WAITING


func current_step() -> Step:
	return _step


func has_played() -> bool:
	# True once the outro left its waiting state, so a played ending never
	# plays again.
	return _step != Step.WAITING


func is_post_game() -> bool:
	# Section 23: after the credits, the cities stay open and awake.
	return _step == Step.POST_GAME


func demand_line() -> String:
	# The full demand of the Karen of the outro.
	return KAREN_TYPE.wake_line


func caught_line() -> String:
	# The credits catch her mid-sentence, section 16: the frozen demand ends
	# inside the last word, on the cut mark.
	var line := demand_line()
	if line.is_empty():
		return ""
	var cut := maxi(1, int(floor(line.length() * CAUGHT_CUT_FRACTION)))
	return line.substr(0, cut) + CAUGHT_CUT_MARK


func begin() -> bool:
	# The last city is complete: the Karen appears on the road east. Only a
	# waiting, never-played outro can begin.
	return _advance_from(Step.WAITING, Step.ARRIVAL)


func notify_karen_blocked() -> bool:
	# She reached the road and blocks it: the demand starts.
	return _advance_from(Step.ARRIVAL, Step.DEMAND)


func notify_credits_started() -> bool:
	# The credits roll while she still speaks, so they catch her mid-sentence.
	return _advance_from(Step.DEMAND, Step.CREDITS)


func notify_credits_ended() -> bool:
	# The roll is over: the version ends and the post-game world begins.
	return _advance_from(Step.CREDITS, Step.POST_GAME)


func save_state() -> Dictionary:
	# The auto-save of section 18 stores the step, so a saved ending never
	# replays.
	return {"step": _step}


func load_state(saved: Dictionary) -> void:
	# A loaded outro lands silent: no signal fires, and a played ending stays
	# played. An unknown step keeps the outro waiting.
	match int(saved.get("step", Step.WAITING)):
		Step.WAITING, Step.ARRIVAL, Step.DEMAND, Step.CREDITS, Step.POST_GAME:
			_step = int(saved.get("step", Step.WAITING)) as Step
		_:
			_step = Step.WAITING


func _advance_from(from_step: Step, to_step: Step) -> bool:
	if _step != from_step:
		return false
	_step = to_step
	step_changed.emit(from_step, to_step)
	if to_step == Step.POST_GAME:
		finished.emit()
	return true
