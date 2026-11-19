# ABOUTME: RoadWest builds the travel trigger of the completed city back west,
# ABOUTME: section 23: the area at the west edge that returns the player to the
# ABOUTME: city before this one on the route.
class_name RoadWest
extends RefCounted

# The trigger stands at the west edge of the city, against the west wall.
const ROAD_WEST_INSET := 40.0
const ROAD_WEST_RADIUS := 44.0


static func build(parent: Node, city_bounds: Vector2, entered: Callable) -> Area2D:
	# The road west opens when the city completes, like the road east. The
	# trigger starts deaf (monitoring off); the run arms it on completion.
	var road := Area2D.new()
	road.name = "RoadWest"
	road.collision_layer = 0
	road.collision_mask = 2
	road.monitoring = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = ROAD_WEST_RADIUS
	shape_node.shape = circle
	road.add_child(shape_node)
	road.body_entered.connect(entered)
	road.position = Vector2(ROAD_WEST_INSET, city_bounds.y * 0.5)
	parent.add_child(road)
	return road
