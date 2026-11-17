# ABOUTME: MorgenReplayPlayer replays the produced Dr. Morgen video on the
# ABOUTME: cafe television, section 22: the same view, length, and skip rule.
class_name MorgenReplayPlayer
extends CanvasLayer

signal finished

@export var balance: TutorialBalance

var _time := 0.0
var _playing := false
var _player: Player = null

@onready var video_view: TutorialVideoView = $VideoView


func begin(run_player: Player) -> void:
	# The television plays the video again: the same produced view, the same
	# pinned length, and any press skips it, like the opening.
	if run_player == null or _playing:
		return
	_player = run_player
	_time = 0.0
	_playing = true
	video_view.setup(balance.video_seconds)
	video_view.start()
	video_view.visible = true
	_player.set_input_locked(true)


func is_playing() -> bool:
	return _playing


func elapsed() -> float:
	return _time


func _physics_process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	video_view.set_progress(_time / balance.video_seconds)
	if _time >= balance.video_seconds:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	# Any press skips the replay: a key, a tap, or a click.
	if not _playing or not _is_press(event):
		return
	get_viewport().set_input_as_handled()
	_finish()


func _finish() -> void:
	_playing = false
	video_view.stop()
	video_view.visible = false
	if _player != null:
		_player.set_input_locked(false)
		_player = null
	finished.emit()


func _is_press(event: InputEvent) -> bool:
	return (
		(event is InputEventKey and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)
