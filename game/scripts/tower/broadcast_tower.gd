# ABOUTME: BroadcastTower is the city goal: one fuse opens the switch that ends the address.
# ABOUTME: The beat after the switch: mid-word stop, one second of silence, then birdsong.
class_name BroadcastTower
extends Area2D

signal fuse_inserted
signal switched_off
signal birdsong

enum Phase { BROADCASTING, FUSED, SILENCE, BIRDSONG }

# The fuse item stays a path, never a preload: the city kit preloads the same
# resource, and a compile-time const binds an empty resource whenever another
# load of it is already running (T102).
const FUSE_ITEM_PATH := "res://resources/items/materials/fuse.tres"

# The art direction pass, section 20: the tower is Mug Roasters Co.
# property, corporate red and black, a smiling mug, friendly evil. The
# beacon burns mug red while the address plays; the switch-off puts a chalk
# strike of the survivors over the logo.
const MAST_WIDTH := 10.0
const MAST_HEIGHT := 110.0
const BASE_WIDTH := 34.0
const BASE_HEIGHT := 18.0
const BEACON_RADIUS := 9.0
const SLOT_SIZE := 12.0
# The corporate logo panel at the foot of the mast.
const PANEL_SIZE := Vector2(64.0, 26.0)
const PANEL_OFFSET := Vector2(0.0, -BASE_HEIGHT - PANEL_SIZE.y * 0.5 - 6.0)
const MUG_FACE_RADIUS := 8.0
const CHALK_STRIKE_WIDTH := 3.0

@export var balance: BroadcastTowerBalance

var phase: Phase = Phase.BROADCASTING

var _silence_time := 0.0
var _player_inside: Player = null
var _palette: ArtPalette


func _ready() -> void:
	_palette = ArtPalette.world()


func _physics_process(delta: float) -> void:
	# Poll the overlap every physics frame, like the sleep zones do: signal
	# delivery order between siblings is not guaranteed.
	_player_inside = _find_player_inside()
	if phase == Phase.SILENCE:
		_silence_time += delta
		if _silence_time >= balance.silence_seconds:
			_set_phase(Phase.BIRDSONG)
			birdsong.emit()


func _fuse_item() -> ItemType:
	# Loaded at use time: the city kit preloads the same resource, and the
	# compile-time const can bind an empty resource mid-load (T102).
	return load(FUSE_ITEM_PATH) as ItemType


func can_insert_fuse(player: Player) -> bool:
	if phase != Phase.BROADCASTING or player == null:
		return false
	if player.is_asleep():
		return false
	return player.inventory.count(_fuse_item().item_id) >= balance.fuses_needed


func insert_fuse(player: Player) -> bool:
	# One fuse opens one broadcast tower; the fuse leaves the bag for good.
	if not can_insert_fuse(player):
		return false
	if not player.inventory.remove(_fuse_item().item_id, balance.fuses_needed):
		return false
	_set_phase(Phase.FUSED)
	fuse_inserted.emit()
	return true


func switch_off() -> bool:
	# Fuse-gated: only a tower with a fuse in the slot goes dark. The address
	# stops mid-word at this moment, and the woken people of the city stay
	# awake for good.
	if phase != Phase.FUSED:
		return false
	_set_phase(Phase.SILENCE)
	switched_off.emit()
	return true


func is_switched_off() -> bool:
	return phase == Phase.SILENCE or phase == Phase.BIRDSONG


func is_wake_up_restored() -> bool:
	# With the address dead, no power of the city can put woken people back to
	# sleep.
	return is_switched_off()


func save_state() -> int:
	# The save system stores the phase as a plain number and reads it back.
	return phase


func load_state(saved: int) -> void:
	# A loaded tower never replays the switch beat: any off state loads fully
	# rested, and no signal fires on the load path.
	match saved:
		Phase.FUSED:
			phase = Phase.FUSED
		Phase.SILENCE, Phase.BIRDSONG:
			phase = Phase.BIRDSONG
		_:
			phase = Phase.BROADCASTING
	queue_redraw()


func _set_phase(next: Phase) -> void:
	phase = next
	queue_redraw()


func _find_player_inside() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _player_inside == null or _player_inside.is_asleep() or _player_inside.is_input_locked():
		return
	if not event.is_action_pressed(&"interact"):
		return
	if phase == Phase.BROADCASTING and insert_fuse(_player_inside):
		get_viewport().set_input_as_handled()
	elif phase == Phase.FUSED and switch_off():
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	# Only the live broadcast animates: the waves pulse from the beacon.
	if phase == Phase.BROADCASTING or phase == Phase.FUSED:
		queue_redraw()


func _draw() -> void:
	# The corporate landmark: a black lattice mast on a concrete plinth, a
	# red logo billboard with the smiling mug, and the beacon that carries
	# the address. The fuse slot waits at the foot, and a silenced tower
	# wears the chalk strike of the survivors.
	if _palette == null:
		return
	_draw_plinth()
	_draw_mast()
	_draw_beacon()
	_draw_logo_panel()
	var slot := Rect2(-SLOT_SIZE * 0.5, BASE_HEIGHT * 0.5, SLOT_SIZE, SLOT_SIZE)
	draw_rect(slot.grow(2.0), _palette.mug_black)
	draw_rect(slot, _slot_color())


func _draw_plinth() -> void:
	# The shadow falls to the bottom-left in the low sun, section 5.
	var shadow := PackedVector2Array(
		[
			Vector2(-MAST_WIDTH, BASE_HEIGHT * 0.5),
			Vector2(MAST_WIDTH, BASE_HEIGHT * 0.5),
			Vector2(-MAST_HEIGHT * 0.45, BASE_HEIGHT * 0.5 + MAST_HEIGHT * 0.3),
			Vector2(-MAST_HEIGHT * 0.6, BASE_HEIGHT * 0.5 + MAST_HEIGHT * 0.25),
		]
	)
	draw_colored_polygon(shadow, Color(0.2, 0.22, 0.32, 0.22))
	# Guy wires hold the mast down at both sides.
	for side: float in [-1.0, 1.0]:
		draw_line(
			Vector2(side * MAST_WIDTH * 0.3, -MAST_HEIGHT * 0.62),
			Vector2(side * BASE_WIDTH * 1.4, BASE_HEIGHT * 0.4),
			Color(_palette.mug_black, 0.55),
			1.2,
			true
		)
	var base_rect := Rect2(-BASE_WIDTH * 0.5, -BASE_HEIGHT * 0.5, BASE_WIDTH, BASE_HEIGHT)
	var concrete := _palette.cream.lerp(_palette.rain, 0.35)
	draw_rect(base_rect.grow(3.0), _palette.mug_black)
	draw_rect(base_rect, concrete)
	draw_rect(Rect2(base_rect.position, Vector2(BASE_WIDTH, 4.0)), concrete.lightened(0.25))


func _draw_mast() -> void:
	# A tapered steel truss with cross braces, black like every Mug Roasters
	# object, so it reads as a real tower and not a pole.
	var foot := MAST_WIDTH * 1.4
	var head := MAST_WIDTH * 0.35
	var top := -MAST_HEIGHT
	var bottom := -BASE_HEIGHT * 0.5
	var ink := _palette.mug_black
	for side: float in [-1.0, 1.0]:
		draw_line(Vector2(side * foot, bottom), Vector2(side * head, top), ink, 3.0, true)
	var sections := 6
	for i: int in sections:
		var t0 := float(i) / float(sections)
		var t1 := float(i + 1) / float(sections)
		var y0 := lerpf(bottom, top, t0)
		var y1 := lerpf(bottom, top, t1)
		var w0 := lerpf(foot, head, t0)
		var w1 := lerpf(foot, head, t1)
		draw_line(Vector2(-w0, y0), Vector2(w1, y1), ink, 1.5, true)
		draw_line(Vector2(w0, y0), Vector2(-w1, y1), ink, 1.5, true)
		draw_line(Vector2(-w1, y1), Vector2(w1, y1), ink, 1.5, true)
	# Two dish antennas on the upper mast.
	for dish: Vector2 in [Vector2(-1.0, -0.72), Vector2(1.0, -0.82)]:
		var center := Vector2(dish.x * (head + 6.0), MAST_HEIGHT * dish.y)
		draw_circle(center, 5.5, _palette.cream.lerp(_palette.rain, 0.3))
		draw_arc(center, 5.5, 0.0, TAU, 12, ink, 1.5, true)


func _draw_beacon() -> void:
	var center := Vector2(0, -MAST_HEIGHT - BEACON_RADIUS)
	var color := _beacon_color()
	if phase == Phase.BROADCASTING or phase == Phase.FUSED:
		# The sleep signal ripples out from the beacon in red rings.
		var t := fmod(float(Time.get_ticks_msec()) * 0.001, 1.6) / 1.6
		for ring: int in 3:
			var p := fmod(t + float(ring) / 3.0, 1.0)
			draw_arc(
				center,
				BEACON_RADIUS + 6.0 + 46.0 * p,
				PI * 1.1,
				PI * 1.9,
				18,
				Color(_palette.mug_red, 0.6 * (1.0 - p)),
				2.5,
				true
			)
	draw_circle(center, BEACON_RADIUS + 5.0, Color(color, 0.25))
	draw_circle(center, BEACON_RADIUS, color)
	draw_arc(center, BEACON_RADIUS, 0.0, TAU, 16, _palette.mug_black, 2.0, true)
	draw_circle(center + Vector2(-3.0, -3.0), 2.5, Color(1.0, 1.0, 1.0, 0.6))


func _draw_logo_panel() -> void:
	# Mug Roasters Co. is flat, perfect print in a hand-drawn world: mug red
	# and mug black only, no paper grain. The mascot smiles too much.
	var panel_rect := Rect2(PANEL_OFFSET - PANEL_SIZE * 0.5, PANEL_SIZE)
	draw_rect(panel_rect.grow(2.0), _palette.mug_black)
	draw_rect(panel_rect, _palette.mug_red)
	var face := PANEL_OFFSET + Vector2(-PANEL_SIZE.x * 0.28, 0)
	draw_circle(face, MUG_FACE_RADIUS, Color.WHITE)
	draw_circle(face + Vector2(-3.0, -2.0), 1.1, _palette.mug_black)
	draw_circle(face + Vector2(3.0, -2.0), 1.1, _palette.mug_black)
	# The smile that is the same in every picture.
	draw_arc(face + Vector2(0, 1.5), 4.0, 0.35, PI - 0.35, 8, _palette.mug_black, 1.6)
	# The handle of the mug.
	draw_arc(
		face + Vector2(MUG_FACE_RADIUS + 2.0, 0), 3.0, -PI * 0.5, PI * 0.5, 8, Color.WHITE, 1.6
	)
	# The word sits right of the mug and fits the panel at every font size.
	var text_left := face.x + MUG_FACE_RADIUS + 6.0
	var text_width := panel_rect.end.x - 3.0 - text_left
	draw_string(
		ChalkTheme.display_font(),
		Vector2(text_left, PANEL_OFFSET.y + 5.0),
		"GRIND",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_width,
		13,
		Color.WHITE
	)
	if is_switched_off():
		# The survivors strike the logo through with chalk, section 8.
		var strike_from := panel_rect.position + Vector2(4, 4)
		var strike_to := panel_rect.position + panel_rect.size - Vector2(4, 4)
		draw_line(strike_from, strike_to, _palette.cream, CHALK_STRIKE_WIDTH)
		draw_line(
			panel_rect.position + Vector2(panel_rect.size.x - 4.0, 4.0),
			panel_rect.position + Vector2(4.0, panel_rect.size.y - 4.0),
			_palette.cream,
			CHALK_STRIKE_WIDTH
		)


func _beacon_color() -> Color:
	match phase:
		Phase.SILENCE:
			return _palette.rain.lerp(_palette.cream, 0.3)
		Phase.BIRDSONG:
			return _palette.butter
		_:
			return _palette.mug_red


func _slot_color() -> Color:
	return (
		_palette.butter
		if phase != Phase.BROADCASTING
		else _palette.espresso.lerp(_palette.cream, 0.3)
	)
