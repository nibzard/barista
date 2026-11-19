# ABOUTME: RoadEast builds the travel trigger of the completed city, section 4:
# ABOUTME: the area on the bridge deck that hands the player to the next city.
class_name RoadEast
extends RefCounted

# The trigger sits on the deck east of the open gate.
const ROAD_EAST_FRACTION := 0.85
const ROAD_EAST_RADIUS := 44.0


static func build(
	parent: Node, city_bounds: Vector2, deck_width: float, entered: Callable
) -> Area2D:
	# The road east opens when the city completes. The trigger starts deaf
	# (monitoring off); the run arms it on completion.
	var road := Area2D.new()
	road.name = "RoadEast"
	road.collision_layer = 0
	road.collision_mask = 2
	road.monitoring = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ROAD_EAST_RADIUS
	shape_node.shape = circle
	road.add_child(shape_node)
	road.body_entered.connect(entered)
	road.position = Vector2(city_bounds.x + deck_width * ROAD_EAST_FRACTION, city_bounds.y * 0.5)
	parent.add_child(road)
	return road
