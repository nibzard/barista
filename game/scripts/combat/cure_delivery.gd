# ABOUTME: CureDelivery is the shared wake math of every cure weapon: the
# ABOUTME: splash, the cone, and the drip. The Tinfoil Man's hat stops every
# ABOUTME: thrown or splash delivery, section 6, so all three ask the same guard.
class_name CureDelivery
extends RefCounted

# Shared group for every body a cure can wake: street sleepwalkers plus boss
# and quest wake targets (FishSeller, DemoTable, SleepJamBand, BandMember,
# RobotaxiEngineer, Aisle7Husband).
const WAKEABLE_GROUP := &"wakeables"


static func target_point(target: Node2D) -> Vector2:
	# Raised or offset wakeables (like the Sleep Jam stage) report their
	# actual stage center so aim-assist, serve reach, and splashes land true.
	if target.has_method(&"aim_point"):
		return target.aim_point() as Vector2
	return target.global_position


static func splash_wake(
	origin: Vector2, radius: float, payload: BrewedCup, tree: SceneTree, world: World2D
) -> int:
	# The burst wakes every sleeping target the coffee reaches: inside the
	# radius and clear of walls, so no coffee flies through geometry. The
	# tinfoil hat keeps the splash off its wearer, section 6.
	if payload == null or radius <= 0.0:
		return 0
	var woken := 0
	for target: Node2D in _wakeable_targets(tree):
		if _skip_delivery_target(target):
			continue
		if target_point(target).distance_to(origin) > radius:
			continue
		if not _has_clear_sight(origin, target, world):
			continue
		if target.try_wake(payload):
			woken += 1
	return woken


static func cone_wake(
	origin: Vector2,
	aim: Vector2,
	reach: float,
	half_angle_degrees: float,
	payload: BrewedCup,
	tree: SceneTree,
	world: World2D
) -> int:
	# The cone wakes every sleeping target in the arc in front of the firer:
	# inside the reach, inside the angle, and clear of walls. The tinfoil hat
	# stops the spray like any delivery, section 6.
	if payload == null or aim == Vector2.ZERO:
		return 0
	var woken := 0
	for target: Node2D in _wakeable_targets(tree):
		if _skip_delivery_target(target):
			continue
		var offset := target_point(target) - origin
		if offset.length() > reach:
			continue
		if offset.length_squared() > 0.0001:
			var angle := absf(rad_to_deg(angle_difference(aim.angle(), offset.angle())))
			if angle > half_angle_degrees:
				continue
		if not _has_clear_sight(origin, target, world):
			continue
		if target.try_wake(payload):
			woken += 1
	return woken


static func drip_wake(origin: Vector2, radius: float, payload: BrewedCup, tree: SceneTree) -> int:
	# The drip of the Auto-Drip Turret falls from above, section 11, so walls
	# never stand in its way: every sleeping target below the tower takes the
	# payload, except the tinfoil hat, which keeps the drip off its wearer.
	if payload == null or radius <= 0.0:
		return 0
	var woken := 0
	for target: Node2D in _wakeable_targets(tree):
		if _skip_delivery_target(target):
			continue
		if target_point(target).distance_to(origin) > radius:
			continue
		if target.try_wake(payload):
			woken += 1
	return woken


static func _wakeable_targets(tree: SceneTree) -> Array[Node2D]:
	var targets: Array[Node2D] = []
	for node: Node in tree.get_nodes_in_group(WAKEABLE_GROUP):
		var target := node as Node2D
		if target != null and target.has_method(&"try_wake"):
			targets.append(target)
	return targets


static func _skip_delivery_target(target: Node2D) -> bool:
	if target.has_method(&"is_awake") and target.is_awake():
		return true
	if target.has_method(&"hat_stops_thrown_coffee") and target.hat_stops_thrown_coffee():
		return true
	return false


static func _has_clear_sight(origin: Vector2, target: Node2D, world: World2D) -> bool:
	var exclude: Array[RID] = []
	if target is CollisionObject2D:
		exclude.append((target as CollisionObject2D).get_rid())
	return LineOfSight.is_clear(origin, target_point(target), world, exclude)
