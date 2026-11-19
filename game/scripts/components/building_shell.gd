# ABOUTME: BuildingShell is the enterable house of the shared city block kit.
# ABOUTME: Solid walls with one door gap; the scavenge loot waits inside.
class_name BuildingShell
extends Node2D

# The art direction pass, section 20: wood-brown walls on cream, espresso
# contours, and a butter rim on the door the player can use.
const DOOR_RIM_WIDTH := 6.0

# Section 17: all cities share one block kit, so the shell keeps one shape.
# The door stays wider than the walking bodies (28 by 40), so the player and
# the sleepwalkers pass through it with room to spare.
@export var building_size := Vector2(460.0, 270.0)
@export var wall_thickness := 16.0
@export var door_width := 96.0

var _built := false
var _palette: ArtPalette


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	_palette = ArtPalette.world()
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	# The environment layer of the project: the player and the sleepwalkers
	# collide with it, and the cup flight and the aim cone read it as
	# geometry, so no coffee crosses a house wall.
	walls.collision_layer = 1
	add_child(walls)
	for rect: Rect2 in wall_rects():
		var shape_node := CollisionShape2D.new()
		shape_node.position = rect.get_center()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		walls.add_child(shape_node)
	queue_redraw()


func wall_rects() -> Array[Rect2]:
	# The wall band of the shell: the north, west, and east sides run whole,
	# and the south side splits around the door gap.
	var rects: Array[Rect2] = []
	var half := building_size * 0.5
	var t := wall_thickness
	rects.append(_rect_at(Vector2(0.0, -half.y + t * 0.5), Vector2(building_size.x, t)))
	rects.append(_rect_at(Vector2(-half.x + t * 0.5, 0.0), Vector2(t, building_size.y - t * 2.0)))
	rects.append(_rect_at(Vector2(half.x - t * 0.5, 0.0), Vector2(t, building_size.y - t * 2.0)))
	var side_length := (building_size.x - door_width) * 0.5
	var side_center := (building_size.x + door_width) * 0.25
	rects.append(_rect_at(Vector2(-side_center, half.y - t * 0.5), Vector2(side_length, t)))
	rects.append(_rect_at(Vector2(side_center, half.y - t * 0.5), Vector2(side_length, t)))
	return rects


func interior_rect() -> Rect2:
	# The open floor inside the walls. The scavenge crate and the authored
	# finds of the block stand on this floor.
	return Rect2(
		Vector2(-building_size.x * 0.5 + wall_thickness, -building_size.y * 0.5 + wall_thickness),
		building_size - Vector2(wall_thickness, wall_thickness) * 2.0
	)


func footprint_rect() -> Rect2:
	# The outer rect of the shell, walls included.
	return Rect2(-building_size * 0.5, building_size)


func door_position() -> Vector2:
	# The local center of the door opening, on the south side.
	return Vector2(0.0, building_size.y * 0.5)


func door_rect() -> Rect2:
	# The threshold strip: the floor patch the door gap leaves open.
	return Rect2(
		Vector2(-door_width * 0.5, building_size.y * 0.5 - wall_thickness),
		Vector2(door_width, wall_thickness)
	)


func contains_point(point: Vector2) -> bool:
	return footprint_rect().has_point(point)


func _rect_at(center: Vector2, rect_size: Vector2) -> Rect2:
	return Rect2(center - rect_size * 0.5, rect_size)


func _draw() -> void:
	if not _built or _palette == null:
		return
	# Wood-brown walls on the cream block, with espresso contours. The door
	# keeps its warm butter rim: it is the way in, and the value rules mark
	# everything the player can use.
	var wall_fill := _palette.espresso.lerp(_palette.cream, 0.58)
	for rect: Rect2 in wall_rects():
		draw_rect(rect, wall_fill)
		draw_rect(rect, _palette.espresso, false, 2.0)
	draw_rect(door_rect().grow(DOOR_RIM_WIDTH * 0.5), _palette.butter)
	draw_rect(door_rect(), _palette.espresso.lerp(_palette.butter, 0.35))
