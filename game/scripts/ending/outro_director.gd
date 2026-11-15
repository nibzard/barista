# ABOUTME: OutroDirector plays the version ending of section 16 after the last
# ABOUTME: city completes: the Karen marches onto the road east and blocks it,
# ABOUTME: she demands the manager, and the credits catch her mid-sentence. The
# ABOUTME: pure OutroFlow owns the order; this node stages the actors and the views.
class_name OutroDirector
extends CanvasLayer

const KAREN_SCENE := preload("res://scenes/ending/outro_karen.tscn")

# Section 23, sized for version 1: the three cities stay open for these.
const POST_GAME_TEXT := (
	"THE CITIES STAY OPEN AND AWAKE."
	+ " FINISH THE SIDE QUESTS. COMPLETE THE SLEEPYDEX. FIND EVERY HIDDEN GLOVE."
)
# Where the Karen blocks the road east, as a share of the bridge deck. She
# stands west of the paywall gate: she is the wall of the version.
const KAREN_DECK_FRACTION := 0.4
# She marches in from beyond the east end of the deck.
const KAREN_MARCH_INSET := 60.0
# The demand line floats above her, wide enough for the whole line.
const DEMAND_WIDTH := 340.0
const DEMAND_OFFSET := Vector2(-DEMAND_WIDTH * 0.5, -110.0)
# The camera rests this far west of her, so she stands right of the center.
const CAMERA_WEST_OFFSET := 180.0

@export var balance: OutroBalance

var flow := OutroFlow.new()

var _run: CityRun = null
var _karen: OutroKaren = null
var _demand_label: Label = null
var _time := 0.0
var _camera_start := Vector2.ZERO
var _camera_target := Vector2.ZERO

@onready var credits_view: OutroCreditsView = $CreditsView


func setup(run: CityRun) -> void:
	# The director waits dormant until the last city completes. A loaded world
	# never replays a played beat: a finished outro leaves the Karen blocking
	# the road, silent.
	_run = run
	flow.step_changed.connect(_on_step_changed)
	credits_view.finished.connect(_on_credits_finished)
	credits_view.visible = false
	_enter_step(flow.current_step(), true)


func begin() -> void:
	# CityRun calls this when the last city completes. The flow refuses a
	# second run on its own.
	flow.begin()


func karen() -> OutroKaren:
	# The Karen of the outro. Null until the outro stages her.
	return _karen


func demand_text() -> String:
	# The demand line above the Karen, or empty while it stays hidden.
	if _demand_label == null or not _demand_label.visible:
		return ""
	return _demand_label.text


func _unhandled_input(event: InputEvent) -> void:
	# Any press skips the credit roll, like the video of section 19.
	if flow.current_step() == OutroFlow.Step.CREDITS and _is_press(event):
		credits_view.skip()
		get_viewport().set_input_as_handled()


func _is_press(event: InputEvent) -> bool:
	return (
		(event is InputEventKey and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)


func _physics_process(delta: float) -> void:
	if _run == null:
		return
	match flow.current_step():
		OutroFlow.Step.ARRIVAL:
			_tick_arrival(delta)
		OutroFlow.Step.DEMAND:
			_tick_demand(delta)
		_:
			pass


func _on_step_changed(from_step: OutroFlow.Step, to_step: OutroFlow.Step) -> void:
	_leave_step(from_step)
	_enter_step(to_step, false)


func _leave_step(from_step: OutroFlow.Step) -> void:
	if from_step == OutroFlow.Step.DEMAND:
		_hide_demand_line()


func _enter_step(to_step: OutroFlow.Step, silent: bool) -> void:
	match to_step:
		OutroFlow.Step.WAITING:
			pass
		OutroFlow.Step.ARRIVAL:
			_time = 0.0
			_run.player.set_input_locked(true)
			_run.cinematic_camera = true
			_camera_start = _run.camera.global_position
			_camera_target = _karen_spot() + Vector2(-CAMERA_WEST_OFFSET, 0.0)
			# The completion can land inside a physics flush, like a boss cup
			# hit, so the new body enters the tree one frame later, outside it.
			_stage_karen.call_deferred()
		OutroFlow.Step.DEMAND:
			_show_demand_line()
		OutroFlow.Step.CREDITS:
			credits_view.visible = true
			credits_view.begin(flow.caught_line(), balance.credits_roll_seconds)
		OutroFlow.Step.POST_GAME:
			_end_outro(silent)


func _tick_arrival(delta: float) -> void:
	# The camera glides toward the bridge while the Karen marches in and
	# blocks the road. The step ends when she stands in place.
	_time += delta
	var share := clampf(_time / balance.karen_march_seconds, 0.0, 1.0)
	_run.camera.global_position = (_camera_start.lerp(_camera_target, smoothstep(0.0, 1.0, share)))
	if _karen != null:
		_karen.march(delta, balance.karen_march_seconds)
	if share >= 1.0 and _karen != null and _karen.is_in_place():
		flow.notify_karen_blocked()


func _tick_demand(delta: float) -> void:
	# She speaks. The hold ends mid-sentence: the credits cut her off before
	# any demand could finish, section 16.
	_time += delta
	if _time >= balance.demand_hold_seconds:
		flow.notify_credits_started()


func _on_credits_finished() -> void:
	if flow.current_step() == OutroFlow.Step.CREDITS:
		flow.notify_credits_ended()


func _end_outro(silent: bool) -> void:
	# The roll is over. The camera returns to the player, the world stays open,
	# and the Karen keeps blocking the road east, forever.
	credits_view.visible = false
	_run.cinematic_camera = false
	_run.camera.global_position = _run.player.global_position
	if silent:
		_stage_karen_blocking.call_deferred()
		return
	_hide_demand_line()
	_run.player.set_input_locked(false)
	_run.hud.show_toast(POST_GAME_TEXT)


func _stage_karen() -> void:
	if _karen != null:
		return
	_karen = KAREN_SCENE.instantiate() as OutroKaren
	_karen.name = "OutroKaren"
	_run.add_child(_karen)
	var spot := _karen_spot()
	var city_bounds := _run.city_map().city_size()
	var from := Vector2(city_bounds.x + CityRun.BRIDGE_DECK_WIDTH + KAREN_MARCH_INSET, spot.y)
	_karen.place(spot, from)


func _stage_karen_blocking() -> void:
	# The loaded post-game world: no march, no signal, she just stands there.
	if _karen != null:
		return
	_karen = KAREN_SCENE.instantiate() as OutroKaren
	_karen.name = "OutroKaren"
	_run.add_child(_karen)
	_karen.stand_at(_karen_spot())


func _karen_spot() -> Vector2:
	var city_bounds := _run.city_map().city_size()
	return Vector2(
		city_bounds.x + CityRun.BRIDGE_DECK_WIDTH * KAREN_DECK_FRACTION, city_bounds.y * 0.5
	)


func _show_demand_line() -> void:
	# The full demand floats above her while she blocks the road.
	_hide_demand_line()
	if _karen == null:
		return
	_demand_label = Label.new()
	_demand_label.position = _karen.global_position + DEMAND_OFFSET
	_demand_label.size = Vector2(DEMAND_WIDTH, 84.0)
	_demand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_demand_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_demand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_demand_label.add_theme_font_size_override("font_size", 24)
	_demand_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	_demand_label.text = flow.demand_line()
	_run.add_child(_demand_label)


func _hide_demand_line() -> void:
	if _demand_label == null:
		return
	_demand_label.queue_free()
	_demand_label = null
