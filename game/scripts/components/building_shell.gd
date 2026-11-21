# ABOUTME: BuildingShell is the enterable house of the shared city block kit.
# ABOUTME: Solid walls with one door gap; the scavenge loot waits inside.
class_name BuildingShell
extends Node2D

# The art direction pass, section 20: wood-brown walls on cream, espresso
# contours, and a butter rim on the door the player can use.
const DOOR_RIM_WIDTH := 6.0
# The height illusion: the visible south face of each east-west wall.
const WALL_FACE_HEIGHT := 12.0
const BRICK_LENGTH := 22.0
const SHADOW_OFFSET := Vector2(-14.0, 12.0)
const CAFE_FLOOR_TILE_PATH := "res://assets/art/tiles/cafe_floor_tile.jpg"

# Section 17: all cities share one block kit, so the shell keeps one shape.
# The door stays wider than the walking bodies (28 by 40), so the player and
# the sleepwalkers pass through it with room to spare.
@export var building_size := Vector2(460.0, 270.0)
@export var wall_thickness := 16.0
@export var door_width := 96.0

var _built := false
var _palette: ArtPalette
var _floor_tex: Texture2D = null


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
	if _floor_tex == null and ResourceLoader.exists(CAFE_FLOOR_TILE_PATH):
		_floor_tex = load(CAFE_FLOOR_TILE_PATH) as Texture2D
	# The low morning sun casts the house shadow to the bottom-left, section 5.
	# Shade is rainy blue, not gray.
	var footprint := footprint_rect()
	draw_rect(
		Rect2(footprint.position + SHADOW_OFFSET, footprint.size),
		Color(_palette.rain.darkened(0.45), 0.28)
	)
	var interior := interior_rect()
	if _floor_tex != null:
		draw_texture_rect(_floor_tex, interior, true, Color(1.0, 0.96, 0.9, 0.96))
	else:
		draw_rect(interior, _palette.cream.lightened(0.06))
	# The north wall shades a band of the floor below it.
	var shade := Rect2(interior.position, Vector2(interior.size.x, WALL_FACE_HEIGHT * 2.2))
	draw_rect(shade, Color(_palette.espresso, 0.16))
	draw_rect(
		Rect2(interior.position, Vector2(WALL_FACE_HEIGHT * 0.9, interior.size.y)),
		Color(_palette.espresso, 0.1)
	)
	# Wood-brown walls with espresso contours. The three-quarter camera of
	# section 7 shows the south face of each east-west wall as a brick band,
	# so the walls read as walls with height, not as lines on the floor.
	var wall_top := _palette.espresso.lerp(_palette.cream, 0.5)
	var wall_face := _palette.brick.lerp(_palette.espresso, 0.35)
	for rect: Rect2 in wall_rects():
		if rect.size.x > rect.size.y:
			_draw_wall_face(
				Rect2(Vector2(rect.position.x, rect.end.y), Vector2(rect.size.x, WALL_FACE_HEIGHT)),
				wall_face
			)
	for rect: Rect2 in wall_rects():
		draw_rect(rect, wall_top)
		draw_line(
			rect.position + Vector2(2.0, 2.0),
			Vector2(rect.end.x - 2.0, rect.position.y + 2.0),
			Color(_palette.cream, 0.45),
			2.0
		)
		draw_rect(rect, _palette.espresso, false, 2.5)
	# The door keeps its warm butter rim: it is the way in, and the value
	# rules mark everything the player can use. A mat waits outside it.
	draw_rect(door_rect().grow(DOOR_RIM_WIDTH * 0.6), _palette.butter)
	draw_rect(door_rect(), _palette.espresso.lerp(_palette.butter, 0.48))
	var mat := Rect2(
		Vector2(-door_width * 0.4, building_size.y * 0.5 + WALL_FACE_HEIGHT + 4.0),
		Vector2(door_width * 0.8, 16.0)
	)
	draw_rect(mat, _palette.brick.lerp(_palette.cream, 0.25))
	draw_rect(mat, _palette.espresso, false, 1.5)


func _draw_wall_face(face: Rect2, color: Color) -> void:
	draw_rect(face, color)
	var joint := Color(_palette.espresso, 0.55)
	var mid := face.position.y + face.size.y * 0.5
	draw_line(Vector2(face.position.x, mid), Vector2(face.end.x, mid), joint, 1.0)
	var x := face.position.x + BRICK_LENGTH * 0.5
	var row := 0
	while x < face.end.x:
		var top := face.position.y if row % 2 == 0 else mid
		draw_line(Vector2(x, top), Vector2(x, top + face.size.y * 0.5), joint, 1.0)
		x += BRICK_LENGTH * 0.5
		row += 1
	draw_rect(face, _palette.espresso, false, 2.0)
