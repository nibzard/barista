# ABOUTME: TutorialDirector plays the first ten minutes of section 19 inside the run.
# ABOUTME: The pure TutorialFlow owns the step machine; this node watches the world,
# ABOUTME: stages the scripted actors, and renders the prompts and the cinematics.
class_name TutorialDirector
extends CanvasLayer

# Scene consts of city scenes stay paths here, never preloads: the director
# compiles before the city scripts in some launch orders, and a compile-time
# preload opens a resource load whose cycle can hand every later scene in the
# city graph an empty or missing resource (T102).
const SLEEP_ZONE_SCENE_PATH := "res://scenes/components/sleep_zone.tscn"
const NEIGHBOR_SCENE_PATH := "res://scenes/enemies/neighbor.tscn"
const GRIND_DIAL_SCENE := preload("res://scenes/minigames/grind_dial.tscn")

# The survivor line of section 19 step 7, word for word.
const SURVIVOR_LINE := "The tower. Kill the speaker."
const SAFE_ZONE_LESSON_TEXT := "SAFE ZONE. THE CAFE KEEPS YOU AWAKE."
const BREW_TOAST_TEXT := "CUP BREWED. SCORE %d."
const BREW_NOT_HERE_TEXT := "BREW AT THE CAFE POT."
# The tutorial brews the cafe standard: the plain filter cup.
const FILTER_METHOD_ID := "filter"
# The woken Neighbor shuffles this far away from the cafe, step 5.
const SHUFFLE_DISTANCE := 600.0
# The thanks line floats above the woken Neighbor.
const THANKS_WIDTH := 300.0
const THANKS_OFFSET := Vector2(-THANKS_WIDTH * 0.5, -96.0)

@export var balance: TutorialBalance

var flow := TutorialFlow.new()

var _run: CityRun = null
var _actors: Node2D = null
var _window_neighbor: Sleepwalker = null
var _survivor: TutorialSurvivor = null
var _pole: SleepZone = null
var _thanks_label: Label = null
var _thanks_time_left := 0.0
var _video_time := 0.0
var _wake_position := Vector2.ZERO
var _saw_drink := false
var _pole_step_time := 0.0
var _was_grabbed := false
var _tower_off_seen := false
var _first_wake_done := false
var _dial: GrindDialView = null
var _finale_time := 0.0
var _map_shown := false
var _title_shown := false
var _finale_restored := false
var _finale_zoom_target := Vector2.ONE
var _finale_camera_start := Vector2.ZERO
var _finale_camera_target := Vector2.ZERO

@onready var video_view: TutorialVideoView = $VideoView
@onready var prompt_label: Label = $PromptLabel
@onready var finale_view: TutorialFinaleView = $FinaleView


func setup(run: CityRun) -> void:
	# The ride begins: the quest markers stay hidden until the survivor names
	# the tower, and the video owns the screen, section 19 step 1.
	_run = run
	_actors = Node2D.new()
	_actors.name = "TutorialActors"
	run.add_child(_actors)
	flow.step_changed.connect(_on_step_changed)
	run.quest_markers().set_suppressed(true)
	var tower := run.city_map().broadcast_tower()
	if tower != null:
		tower.birdsong.connect(_on_tower_birdsong)
	video_view.visible = false
	finale_view.visible = false
	_enter_step(flow.current_step())


func window_neighbor() -> Sleepwalker:
	# The scripted Neighbor of section 19 step 4.
	return _window_neighbor


func pole_zone() -> SleepZone:
	# The tutorial speaker pole of section 19 step 6.
	return _pole


func survivor_npc() -> TutorialSurvivor:
	return _survivor


func grind_dial_view() -> GrindDialView:
	return _dial


func thanks_line() -> String:
	# The line above the first woken Neighbor, step 5.
	if _thanks_label == null or not _thanks_label.visible:
		return ""
	return _thanks_label.text


func begin_brew() -> void:
	# The first Grind Dial brew, section 19 step 8. The start_brew key and any
	# test reach this entry; the pot rule comes from the run.
	if _dial != null:
		return
	_dial = GRIND_DIAL_SCENE.instantiate() as GrindDialView
	_dial.name = "TutorialGrindDial"
	_dial.method = _run.player.brewing_library.find_method(FILTER_METHOD_ID)
	_dial.finished.connect(_on_dial_finished)
	add_child(_dial)
	_run.player.set_input_locked(true)


func _unhandled_input(event: InputEvent) -> void:
	if flow.current_step() == TutorialFlow.Step.VIDEO and _is_press(event):
		flow.end_video()
		get_viewport().set_input_as_handled()
	elif (
		flow.current_step() == TutorialFlow.Step.ROAD
		and _dial == null
		and event.is_action_pressed(&"start_brew")
	):
		get_viewport().set_input_as_handled()
		if _run.brewing_allowed_here():
			begin_brew()
		else:
			_run.hud.show_toast(BREW_NOT_HERE_TEXT)


func _is_press(event: InputEvent) -> bool:
	# Any press skips the video: a key, a tap, or a click, section 19 step 1.
	return (
		(event is InputEventKey and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
		or (event is InputEventMouseButton and event.pressed)
	)


func _physics_process(delta: float) -> void:
	if _run == null:
		return
	_tick_thanks(delta)
	match flow.current_step():
		TutorialFlow.Step.VIDEO:
			_tick_video(delta)
		TutorialFlow.Step.MOVE:
			_tick_move()
		TutorialFlow.Step.DRINK:
			_tick_drink()
		TutorialFlow.Step.DOOR:
			_tick_door()
		TutorialFlow.Step.POLE:
			_tick_pole(delta)
		TutorialFlow.Step.SURVIVOR:
			_tick_survivor()
		TutorialFlow.Step.ROAD:
			_tick_road()
		TutorialFlow.Step.FINALE:
			_tick_finale(delta)
		_:
			pass
	_refresh_prompt()


func _on_step_changed(from_step: TutorialFlow.Step, to_step: TutorialFlow.Step) -> void:
	_leave_step(from_step)
	_enter_step(to_step)


func _leave_step(from_step: TutorialFlow.Step) -> void:
	match from_step:
		TutorialFlow.Step.VIDEO:
			video_view.stop()
			video_view.visible = false
			_run.player.set_input_locked(false)
			# The player watched the address rehearsal and wakes groggy,
			# section 22: the meter starts low so the first drink visibly fills.
			var meter := _run.player.sleep_meter
			meter.drain(meter.value - balance.wake_meter_value)
		TutorialFlow.Step.ROAD:
			_close_dial()
			_release_player_lock()
		_:
			pass


func _enter_step(to_step: TutorialFlow.Step) -> void:
	match to_step:
		TutorialFlow.Step.VIDEO:
			_video_time = 0.0
			video_view.setup(balance.video_seconds)
			video_view.start()
			video_view.visible = true
			_run.player.set_input_locked(true)
		TutorialFlow.Step.MOVE:
			_wake_position = _run.player.global_position
		TutorialFlow.Step.DOOR:
			_spawn_window_neighbor()
		TutorialFlow.Step.THROW:
			_watch_first_wake()
		TutorialFlow.Step.POLE:
			_pole_step_time = 0.0
			# The step can change inside the physics flush (the first wake lands
			# from the cup's body signal), so the new area enters the tree one
			# frame later, outside the flush.
			_spawn_pole.call_deferred()
		TutorialFlow.Step.SURVIVOR:
			_spawn_survivor()
		TutorialFlow.Step.ROAD:
			_was_grabbed = _run.player.is_grabbed()
		TutorialFlow.Step.TOWER:
			if _tower_off_seen:
				flow.notify_tower_off()
		TutorialFlow.Step.FINALE:
			_begin_finale()
		_:
			pass


func _tick_video(delta: float) -> void:
	_video_time += delta
	video_view.set_progress(_video_time / balance.video_seconds)
	if _video_time >= balance.video_seconds:
		flow.end_video()


func _tick_move() -> void:
	if _run.player.global_position.distance_to(_wake_position) >= balance.move_min_distance:
		flow.notify_moved()


func _tick_drink() -> void:
	# The lesson lands when the drink channel closes: the meter filled.
	var meter := _run.player.sleep_meter
	if meter.is_drinking():
		_saw_drink = true
	elif _saw_drink:
		_saw_drink = false
		flow.notify_drank()


func _tick_door() -> void:
	var cafe_zone := _cafe_zone()
	if cafe_zone == null:
		return
	if not cafe_zone.has_player_inside():
		flow.notify_left_cafe()


func _tick_pole(delta: float) -> void:
	_pole_step_time += delta
	var cafe_zone := _cafe_zone()
	if cafe_zone == null:
		return
	if _pole_step_time >= balance.pole_min_seconds and cafe_zone.has_player_inside():
		flow.notify_back_in_cafe()
		_run.hud.show_toast(SAFE_ZONE_LESSON_TEXT)


func _tick_survivor() -> void:
	if _survivor == null or _survivor.has_spoken():
		return
	if (
		_run.player.global_position.distance_to(_survivor.global_position)
		<= balance.survivor_notice_radius
	):
		_survivor.speak(SURVIVOR_LINE, balance.line_hold_seconds)
		_run.quest_markers().set_suppressed(false)
		flow.notify_survivor_spoke()


func _tick_road() -> void:
	var player := _run.player
	if player.is_grabbed():
		_was_grabbed = true
	elif _was_grabbed:
		_was_grabbed = false
		flow.notify_hug_broken()
	if player.is_dodging():
		flow.notify_dodged()


func _on_tower_birdsong() -> void:
	# The beat of section 19 step 9: silence, then birdsong, then the finale.
	_tower_off_seen = true
	flow.notify_tower_off()


func _watch_first_wake() -> void:
	# The first wake by a thrown cup completes the throw lesson. A stray wake
	# that happened before the step still counts, without the stage line.
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var walker := node as Sleepwalker
		if walker == null:
			continue
		walker.woke_up.connect(_on_first_wake.bind(walker))
	if _any_sleepwalker_awake():
		flow.notify_sleepwalker_woke()


func _on_first_wake(walker: Sleepwalker) -> void:
	if flow.current_step() != TutorialFlow.Step.THROW or _first_wake_done:
		return
	_first_wake_done = true
	_show_thanks(walker)
	var away := (
		walker.global_position
		+ (walker.global_position - _cafe_center()).normalized() * SHUFFLE_DISTANCE
	)
	walker.gather_at(away)
	flow.notify_sleepwalker_woke()


func _any_sleepwalker_awake() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"sleepwalkers"):
		var walker := node as Sleepwalker
		if walker != null and walker.is_awake():
			return true
	return false


func _show_thanks(walker: Sleepwalker) -> void:
	# He wakes, says thanks, and shuffles away, section 19 step 5.
	_thanks_label = Label.new()
	_thanks_label.position = walker.global_position + THANKS_OFFSET
	_thanks_label.size = Vector2(THANKS_WIDTH, 64.0)
	_thanks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thanks_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_thanks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thanks_label.add_theme_font_size_override("font_size", 20)
	_thanks_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	_thanks_label.text = walker.enemy_type.wake_line
	_thanks_label.visible = not _thanks_label.text.is_empty()
	_actors.add_child(_thanks_label)
	_thanks_time_left = balance.line_hold_seconds


func _tick_thanks(delta: float) -> void:
	if _thanks_label == null or _thanks_time_left <= 0.0:
		return
	_thanks_time_left = maxf(0.0, _thanks_time_left - delta)
	if _thanks_time_left == 0.0:
		_hide_thanks()


func _hide_thanks() -> void:
	if _thanks_label == null:
		return
	_thanks_label.queue_free()
	_thanks_label = null
	_thanks_time_left = 0.0


func _spawn_window_neighbor() -> void:
	# A Neighbor sleepwalks past the window, section 19 step 4. He is a real
	# Neighbor of the crowd, so his wake feeds the SleepyDex like any other.
	var cafe_block := _cafe_block()
	if cafe_block == null:
		return
	_window_neighbor = (load(NEIGHBOR_SCENE_PATH) as PackedScene).instantiate() as Sleepwalker
	_window_neighbor.name = "WindowNeighbor"
	_actors.add_child(_window_neighbor)
	_window_neighbor.global_position = (
		cafe_block.global_position + cafe_block.size * balance.window_neighbor_fraction
	)
	_window_neighbor.first_met.connect(_run.sleepy_dex().meet)


func _spawn_pole() -> void:
	# A speaker pole drones at the door the player just used, section 19 step 6:
	# the zone spawns around the player, so the drain starts at once. The pole
	# is real: it keeps droning until the tower of the city dies.
	_pole = (load(SLEEP_ZONE_SCENE_PATH) as PackedScene).instantiate() as SleepZone
	_pole.name = "TutorialSpeakerPole"
	_pole.kind = SleepZone.Kind.SLEEP
	var shape_node := _pole.get_node(^"CollisionShape2D") as CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = balance.pole_zone_radius
	shape_node.shape = circle
	_actors.add_child(_pole)
	_pole.global_position = _run.player.global_position
	var tower := _run.city_map().broadcast_tower()
	if tower != null:
		tower.switched_off.connect(_on_tower_switched_off)


func _on_tower_switched_off() -> void:
	# The address of the city is dead, so the tutorial pole goes quiet too,
	# exactly like the kit poles the city map silences.
	if _pole != null:
		_pole.silence_broadcast()


func _spawn_survivor() -> void:
	# The survivor stands at the door, just outside the safe zone, step 7.
	var cafe_block := _cafe_block()
	if cafe_block == null:
		return
	_survivor = TutorialSurvivor.new()
	_survivor.name = "DoorSurvivor"
	_actors.add_child(_survivor)
	_survivor.global_position = (
		_cafe_center() + Vector2(0.0, cafe_block.cafe_zone_radius() + balance.survivor_door_gap)
	)


func _on_dial_finished(dial_result: GrindResult) -> void:
	# The ground cup lands in the hand, the skill trains, and the lesson ends.
	_run.player.coffee_supply.add_cups(1)
	_run.player.brewing_skills.record_brew(FILTER_METHOD_ID, dial_result.score)
	_run.hud.show_toast(BREW_TOAST_TEXT % roundi(dial_result.score))
	_close_dial()
	flow.notify_brewed()


func _close_dial() -> void:
	if _dial == null:
		return
	_dial.queue_free()
	_dial = null
	_release_player_lock()


func _release_player_lock() -> void:
	# Only the video and the finale hold a lock past their own end.
	var step := flow.current_step()
	if step == TutorialFlow.Step.VIDEO or step == TutorialFlow.Step.FINALE:
		return
	_run.player.set_input_locked(false)


func _begin_finale() -> void:
	# Section 19 step 10: the camera pans out over the whole city, three cities
	# appear on the map, and the title card lands.
	_finale_time = 0.0
	_map_shown = false
	_title_shown = false
	_finale_restored = false
	_run.cinematic_camera = true
	_run.player.set_input_locked(true)
	var viewport_size := get_viewport().get_visible_rect().size
	var total := _run.city_map().city_size() + Vector2(CityRun.BRIDGE_DECK_WIDTH, 0.0)
	var fit := (
		minf(viewport_size.x / total.x, viewport_size.y / total.y) * balance.finale_zoom_margin
	)
	_finale_zoom_target = Vector2(fit, fit)
	_finale_camera_start = _run.camera.global_position
	_finale_camera_target = total * 0.5


func _tick_finale(delta: float) -> void:
	_finale_time += delta
	var pan := balance.finale_pan_seconds
	if _finale_time < pan:
		var share := smoothstep(0.0, 1.0, _finale_time / pan)
		_run.camera.zoom = Vector2.ONE.lerp(_finale_zoom_target, share)
		_run.camera.global_position = _finale_camera_start.lerp(_finale_camera_target, share)
		return
	if not _map_shown:
		_map_shown = true
		finale_view.visible = true
		finale_view.show_map()
	var title_at := pan + balance.finale_map_hold_seconds
	if _finale_time >= title_at and not _title_shown:
		_title_shown = true
		finale_view.show_title()
	if _finale_time < title_at + balance.title_hold_seconds + balance.finale_fade_seconds:
		return
	if not _finale_restored:
		# The camera comes back behind the backdrop, so the cut stays hidden.
		_finale_restored = true
		_run.camera.zoom = Vector2.ONE
		_run.cinematic_camera = false
		return
	finale_view.visible = false
	finale_view.reset()
	_run.player.set_input_locked(false)
	flow.notify_finale_ended()


func _refresh_prompt() -> void:
	var text := flow.prompt_text()
	if flow.current_step() == TutorialFlow.Step.ROAD and _run.player.is_grabbed():
		text = TutorialFlow.MASH_PROMPT
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()


func _cafe_block() -> CityBlockView:
	return _run.city_map().find_block_of_kind(CityBlock.Kind.CAFE)


func _cafe_center() -> Vector2:
	var cafe_block := _cafe_block()
	if cafe_block == null:
		return Vector2.ZERO
	return cafe_block.global_position + cafe_block.size * 0.5


func _cafe_zone() -> SleepZone:
	var cafe_block := _cafe_block()
	if cafe_block == null:
		return null
	return cafe_block.safe_zone()
