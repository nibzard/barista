# ABOUTME: CityRoads owns the travel of one city: the road east over the
# ABOUTME: bridge deck, section 4, and the road west back along the route,
# ABOUTME: section 23. It builds the triggers, arms them on completion, and
# carries the traveler across the scene change.
class_name CityRoads
extends RefCounted

# The run arrives as a plain Node: naming the run class here would tie this
# component's compile back into the city script (T112).
var _run: Node = null
var _east: Area2D = null
var _west: Area2D = null


static func build(
	run: Node,
	city_bounds: Vector2,
	deck_width: float,
	east_entered: Callable,
	west_entered: Callable
) -> CityRoads:
	# Both roads start deaf (monitoring off); the run arms them when the city
	# completes. A city without a city west of it, the first one on the route,
	# passes an invalid Callable and builds no road west.
	var roads := CityRoads.new()
	roads._run = run
	roads._east = RoadEast.build(run, city_bounds, deck_width, east_entered)
	if west_entered.is_valid():
		roads._west = RoadWest.build(run, city_bounds, west_entered)
	return roads


func east() -> Area2D:
	# The travel trigger on the deck east of the gate.
	return _east


func west() -> Area2D:
	# The travel trigger at the west edge of the city. Null in the first city
	# of the route, which has no city west of it.
	return _west


func east_active() -> bool:
	# The road east listens only after the city completes.
	return _east != null and _east.monitoring


func west_active() -> bool:
	# The road west listens only after the city completes too, so the finished
	# route stays open both ways.
	return _west != null and _west.monitoring


func arm_east() -> void:
	# The monitoring flip waits for the end of the physics step, so the change
	# never lands mid-flush.
	if _east != null:
		_east.set_deferred(&"monitoring", true)


func arm_west() -> void:
	if _west != null:
		_west.set_deferred(&"monitoring", true)


func travel(destination: PackedScene) -> void:
	# A road travels only when the city scene names its destination: the road
	# east finds none in the last city of the version, the road west none in
	# the first one.
	if destination == null:
		return
	_park_traveler()
	_change_scene.call_deferred(destination)


func _park_traveler() -> void:
	# Section 10, moving day: the van carries its own level across the scene
	# change, the fridge parks its live steep beside it, and the van carries
	# every belonging of the traveler, west as much as east. The quest chain
	# already moved when the road parked its traveler, so the arriving city
	# reads a log that names it.
	var van_state: MobileCafe = _run.van_state
	if van_state != null:
		VanHandoff.park(van_state.save_state())
	var fridge: ColdBrewFridge = _run.cold_fridge
	ColdBrewHandoff.park(fridge.save_state() if fridge != null else {})
	MoveHandoff.park_traveler(_run.player, _run.dex, _run.unlock_state, _run.quest_log)


func _change_scene(destination: PackedScene) -> void:
	# The trigger fires inside the physics step, and the scene change frees
	# collision nodes. The engine rejects that removal mid-callback, so the
	# travel waits for idle time.
	_run.get_tree().change_scene_to_packed(destination)
