# ABOUTME: CityWalls builds the hard boundary of one city run: the box around
# ABOUTME: the blocks plus the bridge deck reach, section 17. Pure geometry.
class_name CityWalls
extends RefCounted

const THICKNESS := 40.0


static func build(parent: Node, city_bounds: Vector2, deck_width: float) -> void:
	# The city stands inside a hard boundary; the bridge deck reaches east.
	var walls := Node2D.new()
	walls.name = "Walls"
	parent.add_child(walls)
	var total_width := city_bounds.x + deck_width
	var side_length := city_bounds.y + THICKNESS * 2.0
	_add(
		walls,
		"Top",
		Vector2(total_width * 0.5, -THICKNESS * 0.5),
		Vector2(total_width + THICKNESS * 2.0, THICKNESS)
	)
	_add(
		walls,
		"Bottom",
		Vector2(total_width * 0.5, city_bounds.y + THICKNESS * 0.5),
		Vector2(total_width + THICKNESS * 2.0, THICKNESS)
	)
	_add(
		walls,
		"West",
		Vector2(-THICKNESS * 0.5, city_bounds.y * 0.5),
		Vector2(THICKNESS, side_length)
	)
	_add(
		walls,
		"East",
		Vector2(total_width + THICKNESS * 0.5, city_bounds.y * 0.5),
		Vector2(THICKNESS, side_length)
	)


static func _add(
	parent: Node2D, wall_name: String, wall_position: Vector2, wall_size: Vector2
) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.position = wall_position
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	shape_node.shape = shape
	wall.add_child(shape_node)
	parent.add_child(wall)
