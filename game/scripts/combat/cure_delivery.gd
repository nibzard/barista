# ABOUTME: CureDelivery is the shared wake math of every cure weapon: the
# ABOUTME: splash, the cone, and the drip. The Tinfoil Man's hat stops every
# ABOUTME: thrown or splash delivery, section 6, so all three ask the same guard.
class_name CureDelivery
extends RefCounted


static func splash_wake(
	origin: Vector2, radius: float, payload: BrewedCup, tree: SceneTree, world: World2D
) -> int:
	# The burst wakes every sleeping walker the coffee reaches: inside the
	# radius and clear of walls, so no coffee flies through geometry. The
	# tinfoil hat keeps the splash off its wearer, section 6.
	if payload == null or radius <= 0.0:
		return 0
	var woken := 0
	for node: Node in tree.get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var sleeper := node as Sleepwalker
		if sleeper == null or sleeper.is_awake() or sleeper.hat_stops_thrown_coffee():
			continue
		if sleeper.global_position.distance_to(origin) > radius:
			continue
		if not LineOfSight.is_clear(origin, sleeper.global_position, world):
			continue
		if sleeper.try_wake(payload):
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
	# The cone wakes every sleeping walker in the arc in front of the firer:
	# inside the reach, inside the angle, and clear of walls. The tinfoil hat
	# stops the spray like any delivery, section 6.
	if payload == null or aim == Vector2.ZERO:
		return 0
	var woken := 0
	for node: Node in tree.get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var sleeper := node as Sleepwalker
		if sleeper == null or sleeper.is_awake() or sleeper.hat_stops_thrown_coffee():
			continue
		var offset := sleeper.global_position - origin
		if offset.length() > reach:
			continue
		var angle := absf(rad_to_deg(angle_difference(aim.angle(), offset.angle())))
		if angle > half_angle_degrees:
			continue
		if not LineOfSight.is_clear(origin, sleeper.global_position, world):
			continue
		if sleeper.try_wake(payload):
			woken += 1
	return woken


static func drip_wake(origin: Vector2, radius: float, payload: BrewedCup, tree: SceneTree) -> int:
	# The drip of the Auto-Drip Turret falls from above, section 11, so walls
	# never stand in its way: every sleeping walker below the tower takes the
	# payload, except the tinfoil hat, which keeps the drip off its wearer.
	if payload == null or radius <= 0.0:
		return 0
	var woken := 0
	for node: Node in tree.get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var sleeper := node as Sleepwalker
		if sleeper == null or sleeper.is_awake() or sleeper.hat_stops_thrown_coffee():
			continue
		if sleeper.global_position.distance_to(origin) > radius:
			continue
		if sleeper.try_wake(payload):
			woken += 1
	return woken
