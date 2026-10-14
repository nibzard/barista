# ABOUTME: BroadcastTower is the city goal: one fuse opens the switch that ends the address.
# ABOUTME: The beat after the switch: mid-word stop, one second of silence, then birdsong.
class_name BroadcastTower
extends Area2D

signal fuse_inserted
signal switched_off
signal birdsong

enum Phase { BROADCASTING, FUSED, SILENCE, BIRDSONG }

const FUSE_ITEM := preload("res://resources/items/materials/fuse.tres")

# Placeholder tower colors until the art pass brings the real landmark.
const MAST_COLOR := Color(0.25, 0.2, 0.18, 1)
const BASE_COLOR := Color(0.35, 0.28, 0.22, 1)
const BEACON_ON_COLOR := Color(0.78, 0.16, 0.14, 1)
const BEACON_SILENCE_COLOR := Color(0.12, 0.1, 0.1, 1)
const BEACON_BIRDSONG_COLOR := Color(0.95, 0.8, 0.3, 1)
const SLOT_EMPTY_COLOR := Color(0.12, 0.1, 0.1, 1)
const SLOT_FILLED_COLOR := Color(0.95, 0.7, 0.2, 1)
const MAST_WIDTH := 10.0
const MAST_HEIGHT := 110.0
const BASE_WIDTH := 34.0
const BASE_HEIGHT := 18.0
const BEACON_RADIUS := 9.0
const SLOT_SIZE := 12.0

@export var balance: BroadcastTowerBalance

var phase: Phase = Phase.BROADCASTING

var _silence_time := 0.0
var _player_inside: Player = null


func _physics_process(delta: float) -> void:
	# Poll the overlap every physics frame, like the sleep zones do: signal
	# delivery order between siblings is not guaranteed.
	_player_inside = _find_player_inside()
	if phase == Phase.SILENCE:
		_silence_time += delta
		if _silence_time >= balance.silence_seconds:
			_set_phase(Phase.BIRDSONG)
			birdsong.emit()


func can_insert_fuse(player: Player) -> bool:
	if phase != Phase.BROADCASTING or player == null:
		return false
	if player.is_asleep():
		return false
	return player.inventory.count(FUSE_ITEM.item_id) >= balance.fuses_needed


func insert_fuse(player: Player) -> bool:
	# One fuse opens one broadcast tower; the fuse leaves the bag for good.
	if not can_insert_fuse(player):
		return false
	if not player.inventory.remove(FUSE_ITEM.item_id, balance.fuses_needed):
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
	if _player_inside == null or _player_inside.is_asleep():
		return
	if not event.is_action_pressed(&"interact"):
		return
	if phase == Phase.BROADCASTING:
		insert_fuse(_player_inside)
	elif phase == Phase.FUSED:
		switch_off()


func _draw() -> void:
	# Placeholder tower: base, mast, beacon, and the fuse slot at the foot.
	var base_rect := Rect2(-BASE_WIDTH * 0.5, -BASE_HEIGHT * 0.5, BASE_WIDTH, BASE_HEIGHT)
	draw_rect(base_rect, BASE_COLOR)
	draw_rect(Rect2(-MAST_WIDTH * 0.5, -MAST_HEIGHT, MAST_WIDTH, MAST_HEIGHT), MAST_COLOR)
	draw_circle(Vector2(0, -MAST_HEIGHT - BEACON_RADIUS), BEACON_RADIUS, _beacon_color())
	draw_rect(Rect2(-SLOT_SIZE * 0.5, BASE_HEIGHT * 0.5, SLOT_SIZE, SLOT_SIZE), _slot_color())


func _beacon_color() -> Color:
	match phase:
		Phase.SILENCE:
			return BEACON_SILENCE_COLOR
		Phase.BIRDSONG:
			return BEACON_BIRDSONG_COLOR
		_:
			return BEACON_ON_COLOR


func _slot_color() -> Color:
	return SLOT_FILLED_COLOR if phase != Phase.BROADCASTING else SLOT_EMPTY_COLOR
