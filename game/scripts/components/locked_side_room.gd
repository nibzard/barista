# ABOUTME: LockedSideRoom is the locked vault of the shared city block kit.
# ABOUTME: One vault key opens the door; the Geisha Vault beans wait inside.
class_name LockedSideRoom
extends Node2D

signal unlocked

# Placeholder vault colors until the art pass brings real scavenge props.
const WALL_FILL := Color(0.27, 0.21, 0.31, 1)
const WALL_EDGE := Color(0.14, 0.1, 0.18, 1)
const DOOR_LOCKED_COLOR := Color(0.78, 0.6, 0.2, 0.95)
const DOOR_OPEN_COLOR := Color(0.85, 0.7, 0.45, 0.95)
# The interact reach of the door: the player stands at the threshold, like at
# the fuse slot of the tower, and the touch USE button opens the vault.
const DOOR_REACH_RADIUS := 60.0

# Section 17: all cities share one block kit, so the vault keeps one shape.
# The door stays wider than the walking bodies (28 by 40), so the player and
# the sleepwalkers pass through it with room to spare.
@export var room_size := Vector2(170.0, 200.0)
@export var wall_thickness := 16.0
@export var door_width := 80.0
# Section 15: the item the locked door consumes on unlock. The city data
# authors it, and the validator reports a room without one.
@export var key: ItemType

var _built := false
var _locked := true
var _player_at_door: Player = null


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	_build_walls()
	if _locked:
		_build_locked_door()
	_build_door_reach()
	queue_redraw()


func _build_walls() -> void:
	# The vault walls follow the shell idiom, section 17: the environment
	# layer of the project stops the walking bodies and the coffee flights.
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	add_child(walls)
	for rect: Rect2 in wall_rects():
		var shape_node := CollisionShape2D.new()
		shape_node.position = rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		walls.add_child(shape_node)


func _build_locked_door() -> void:
	# The lock itself: one solid strip in the door gap. It leaves with the
	# key, and the door patch redraws in the open color.
	var door := StaticBody2D.new()
	door.name = "LockedDoor"
	door.collision_layer = 1
	add_child(door)
	var shape_node := CollisionShape2D.new()
	shape_node.position = door_rect().get_center()
	var shape := RectangleShape2D.new()
	shape.size = door_rect().size
	shape_node.shape = shape
	door.add_child(shape_node)


func _build_door_reach() -> void:
	var reach := Area2D.new()
	reach.name = "DoorReach"
	reach.collision_layer = 0
	reach.collision_mask = 2
	reach.monitorable = false
	reach.position = door_position()
	add_child(reach)
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = DOOR_REACH_RADIUS
	shape_node.shape = shape
	reach.add_child(shape_node)


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the tower does: signal
	# delivery order between siblings is not guaranteed.
	_player_at_door = _find_player_at_door()


func is_locked() -> bool:
	return _locked


func can_unlock(player: Player) -> bool:
	# One vault key opens one locked door. A sleeping player turns no key.
	if not _locked or player == null:
		return false
	if player.is_asleep():
		return false
	return key != null and player.inventory.count(key.item_id) >= 1


func try_unlock(player: Player) -> bool:
	# The key leaves the bag for good, the same rule as the tower fuse.
	if not can_unlock(player):
		return false
	if not player.inventory.remove(key.item_id, 1):
		return false
	_open_door()
	unlocked.emit()
	return true


func save_state() -> bool:
	# The save system stores the door state as one plain bit.
	return not _locked


func load_state(was_unlocked: bool) -> void:
	# A loaded room never re-locks: no key returns to any bag on a reload.
	if was_unlocked and _locked:
		_open_door()


func loot_point() -> ScavengePoint:
	# The finds of the room, added by the city kit. Null when the city holds
	# no room, or before the kit composes the block.
	return get_node_or_null(^"Loot") as ScavengePoint


func door_barrier() -> StaticBody2D:
	# The solid strip of the lock. It leaves the tree on unlock.
	return get_node_or_null(^"LockedDoor") as StaticBody2D


func wall_rects() -> Array[Rect2]:
	# The wall band of the vault: the north, west, and east sides run whole,
	# and the south side splits around the door gap.
	var rects: Array[Rect2] = []
	var half := room_size * 0.5
	var t := wall_thickness
	rects.append(_rect_at(Vector2(0.0, -half.y + t * 0.5), Vector2(room_size.x, t)))
	rects.append(_rect_at(Vector2(-half.x + t * 0.5, 0.0), Vector2(t, room_size.y - t * 2.0)))
	rects.append(_rect_at(Vector2(half.x - t * 0.5, 0.0), Vector2(t, room_size.y - t * 2.0)))
	var side_length := (room_size.x - door_width) * 0.5
	var side_center := (room_size.x + door_width) * 0.25
	rects.append(_rect_at(Vector2(-side_center, half.y - t * 0.5), Vector2(side_length, t)))
	rects.append(_rect_at(Vector2(side_center, half.y - t * 0.5), Vector2(side_length, t)))
	return rects


func interior_rect() -> Rect2:
	# The open floor inside the walls. The finds of the room stand here.
	return Rect2(
		Vector2(-room_size.x * 0.5 + wall_thickness, -room_size.y * 0.5 + wall_thickness),
		room_size - Vector2(wall_thickness, wall_thickness) * 2.0
	)


func footprint_rect() -> Rect2:
	# The outer rect of the vault, walls included.
	return Rect2(-room_size * 0.5, room_size)


func door_position() -> Vector2:
	# The local center of the door opening, on the south side.
	return Vector2(0.0, room_size.y * 0.5)


func door_rect() -> Rect2:
	# The threshold strip: the floor patch the door gap leaves open. The
	# locked strip of the lock fills it while the door stays shut.
	return Rect2(
		Vector2(-door_width * 0.5, room_size.y * 0.5 - wall_thickness),
		Vector2(door_width, wall_thickness)
	)


func contains_point(point: Vector2) -> bool:
	return footprint_rect().has_point(point)


func _open_door() -> void:
	_locked = false
	var barrier := door_barrier()
	if barrier != null:
		# The lock leaves the tree at once, so the door reads open in the same
		# frame; the free itself stays deferred, safe inside physics.
		remove_child(barrier)
		barrier.queue_free()
	queue_redraw()


func _find_player_at_door() -> Player:
	var reach := get_node_or_null(^"DoorReach") as Area2D
	if reach == null:
		return null
	for body: Node2D in reach.get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _unhandled_input(event: InputEvent) -> void:
	if (
		_player_at_door == null
		or not is_instance_valid(_player_at_door)
		or _player_at_door.is_asleep()
		or _player_at_door.is_input_locked()
	):
		return
	if not event.is_action_pressed(&"interact"):
		return
	if try_unlock(_player_at_door) and get_viewport() != null:
		get_viewport().set_input_as_handled()


func _rect_at(center: Vector2, rect_size: Vector2) -> Rect2:
	return Rect2(center - rect_size * 0.5, rect_size)


func _draw() -> void:
	if not _built:
		return
	for rect: Rect2 in wall_rects():
		draw_rect(rect, WALL_FILL)
		draw_rect(rect, WALL_EDGE, false, 2.0)
	draw_rect(door_rect(), DOOR_LOCKED_COLOR if _locked else DOOR_OPEN_COLOR)
