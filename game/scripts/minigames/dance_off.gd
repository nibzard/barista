# ABOUTME: DanceOff is the rhythm judge of the Moonwalker dance-off, section 24.
# ABOUTME: Pure logic with no nodes: beats on a clock, taps judged by timing.
class_name DanceOff
extends RefCounted

signal beat_judged(verdict: Verdict, beat_index: int)
signal finished(won: bool)

enum Verdict { NONE, PERFECT, GOOD, MISS }

var balance: MoonwalkerBalance

var _elapsed := 0.0
var _running := false
var _over := false
var _won := false
var _next_beat := 0
var _hits := 0


func _init(dance_balance: MoonwalkerBalance) -> void:
	balance = dance_balance


func begin() -> void:
	_elapsed = 0.0
	_next_beat = 0
	_hits = 0
	_won = false
	_over = false
	_running = true


func tick(delta: float) -> void:
	# The clock runs only while the dance runs. A beat whose good window
	# closed with no tap misses itself, and the last closed beat ends the
	# dance with the verdict.
	if not _running:
		return
	_elapsed += delta
	while _next_beat < balance.dance_beat_count and _window_closed(_next_beat):
		beat_judged.emit(Verdict.MISS, _next_beat)
		_next_beat += 1
	if _next_beat >= balance.dance_beat_count and _window_closed(_next_beat - 1):
		_finish()


func tap() -> Verdict:
	# One tap against the earliest unjudged beat. Inside the perfect window
	# it lands perfect, inside the good window good, and an off-beat tap
	# misses without spending the beat: the next beat stays tappable.
	if not _running or _next_beat >= balance.dance_beat_count:
		return Verdict.NONE
	var offset := absf(_elapsed - beat_time(_next_beat))
	if offset > balance.dance_good_window_seconds:
		beat_judged.emit(Verdict.MISS, _next_beat)
		return Verdict.MISS
	var verdict := (
		Verdict.PERFECT if offset <= balance.dance_perfect_window_seconds else Verdict.GOOD
	)
	_hits += 1
	beat_judged.emit(verdict, _next_beat)
	_next_beat += 1
	return verdict


func is_running() -> bool:
	return _running


func is_over() -> bool:
	return _over


func won() -> bool:
	return _won


func hits() -> int:
	return _hits


func beats_total() -> int:
	return balance.dance_beat_count


func beat_time(index: int) -> float:
	return balance.dance_first_beat_delay_seconds + balance.dance_beat_interval_seconds * index


func elapsed() -> float:
	return _elapsed


func next_beat() -> int:
	# The cursor of the earliest unjudged beat: every beat before it holds a
	# verdict already, tapped or missed.
	return _next_beat


func _window_closed(index: int) -> bool:
	return _elapsed > beat_time(index) + balance.dance_good_window_seconds


func _finish() -> void:
	_running = false
	_over = true
	_won = _hits >= balance.dance_win_hits
	finished.emit(_won)
