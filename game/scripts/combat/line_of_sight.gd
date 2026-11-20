# ABOUTME: LineOfSight answers whether a flight line crosses environment geometry.
# ABOUTME: Walls and static obstacles sit on physics layer 1, sleepers on layer 4.
class_name LineOfSight
extends RefCounted

# The environment layer of the project: cafe and city walls, the bridge
# gate, and the static quest bodies. Sleepers ride layer 4, so they never
# block the cast and the check stays one wall-only ray.
const ENVIRONMENT_LAYER := 1


static func is_clear(from: Vector2, to: Vector2, world: World2D, exclude: Array[RID] = []) -> bool:
	# One ray along the flight line answers the reach question for a thrown
	# cup: the aim cone skips sleepers this ray cannot see, and a splash
	# wakes no sleeper behind a wall. hit_from_inside keeps a start point
	# already inside a wall honest: that wall still counts as blocked.
	if from == to:
		return true
	var query := PhysicsRayQueryParameters2D.create(from, to, ENVIRONMENT_LAYER, exclude)
	query.hit_from_inside = true
	return world.direct_space_state.intersect_ray(query).is_empty()
