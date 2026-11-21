# ABOUTME: FishThrowers is the Steamtle boss: the fish sellers of the market.
# ABOUTME: A steady volley of perfect-aim fish, and a head-first cure rule.
class_name FishThrowers
extends Node2D

signal crew_woke
signal spoke(line: String)

# The toast of the wake beat: the last throw and the cheer end the fight.
const WAKE_TOAST := "THE FISH THROWERS ARE AWAKE. ONE LAST THROW, AND THE MARKET CHEERS."
# Sleeping fish sellers wear the pajama indigo of every sleeper; the wake
# turns it green like every awakened sleeper.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
const SENSE_ZONE_NAME := "MarketSense"
# The market shirt under the rubber apron, and the taller head fishmonger.
const OUTFIT_COLOR := Color("#35507A")
const HEAD_SCALE := 1.1
const FLIGHTS_NAME := "FishFlights"

const FISH_SCENE := preload("res://scenes/projectiles/fish.tscn")

@export var balance: FishThrowersBalance
@export var brewing_balance: BrewingBalance
# The cure of the market, section 6: one tall cup of the market dark roast.
@export var cure: Recipe

var _members: Array[FishSeller] = []
var _head: FishSeller = null
var _volley: FishVolley = null
var _sense: Area2D = null
var _flights: Node2D = null
var _cured := false


func _ready() -> void:
	_collect_members()
	_tint_members(SLEEPING_COLOR)
	_dress_members()
	_build_sense()
	_flights = Node2D.new()
	_flights.name = FLIGHTS_NAME
	add_child(_flights)
	_volley = FishVolley.new(_members.size(), balance.volley_interval_seconds)


func _physics_process(delta: float) -> void:
	# The market plays its volley only while the fight lives and the player
	# stands inside the market reach. Off the market, the rhythm waits.
	if _cured:
		return
	var player := _sense_player()
	if player == null:
		return
	var thrower := _volley.tick(delta)
	if thrower < 0:
		return
	var from := _members[thrower].global_position
	var aim := FishVolley.aim(from, player.global_position)
	if aim == Vector2.ZERO:
		return
	_throw_fish(from, aim, false)


static func cure_accepted(cup: BrewedCup, cure: Recipe, brew_balance: BrewingBalance) -> bool:
	# The cure condition of the fight, the shared tier-led rule of the bosses:
	# between the tiers, only the market dark roast in a tall cup works.
	return BossCure.accepted(cup, cure, brew_balance)


func receive_cup(seller: FishSeller, cup: BrewedCup) -> bool:
	# The head-first cure rule, section 6: only the apron of the head
	# fishmonger takes the cure, and only while the market sleeps. A cup that
	# lands on a crew member wakes nobody, because the head must wake first.
	if _cured or seller == null:
		return false
	if not seller.is_head:
		return false
	if not cure_accepted(cup, cure, brewing_balance):
		return false
	_wake_the_market()
	return true


func is_cured() -> bool:
	return _cured


func save_state() -> Dictionary:
	# Section 18: the cure of the market rides the run slot as one plain flag,
	# so a reloaded arena never replays a fight the save already ended.
	return {"cured": _cured}


func load_state(saved: Dictionary) -> void:
	# A saved cure lands silent: the market wakes, but no celebration fish
	# flies and no cheer speaks, because the save point already recorded the
	# beat.
	if not bool(saved.get("cured", false)):
		return
	_cured = true
	_tint_members(AWAKE_COLOR)
	for member: FishSeller in _members:
		member.set_awake(true)
	for fish: Fish in live_fish():
		fish.harmless = true


func head() -> FishSeller:
	return _head


func members() -> Array[FishSeller]:
	return _members.duplicate()


func crew_members() -> Array[FishSeller]:
	# Every seller of the market except the head fishmonger.
	var crew: Array[FishSeller] = []
	for member: FishSeller in _members:
		if not member.is_head:
			crew.append(member)
	return crew


func live_fish() -> Array[Fish]:
	# The fish in flight right now, aimed volley and celebration alike.
	var fish: Array[Fish] = []
	if _flights == null:
		return fish
	for child: Node in _flights.get_children():
		var one := child as Fish
		if one != null:
			fish.append(one)
	return fish


func _collect_members() -> void:
	for child: Node in get_node(^"Members").get_children():
		var member := child as FishSeller
		if member == null:
			continue
		member.bind_crew(self)
		_members.append(member)
		if member.is_head:
			_head = member


func _dress_members() -> void:
	# Every seller wears the yellow rubber apron. The head stands a little
	# taller, so the player sees who holds the cure apron.
	for i: int in _members.size():
		var member: FishSeller = _members[i]
		PersonFigure.dress(
			member.get_node(^"Visual") as Polygon2D,
			"fish_seller_%d" % i,
			OUTFIT_COLOR,
			ChibiPainter.Gear.RUBBER_APRON,
			HEAD_SCALE if member.is_head else 1.0
		)


func _tint_members(tint: Color) -> void:
	for member: FishSeller in _members:
		var visual := member.get_node(^"Visual") as Polygon2D
		if visual != null:
			visual.color = tint


func _build_sense() -> void:
	# The market reach: the volley runs while the player stands inside it.
	_sense = Area2D.new()
	_sense.name = SENSE_ZONE_NAME
	_sense.collision_layer = 0
	_sense.collision_mask = 2
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = balance.volley_trigger_radius
	shape_node.shape = circle
	_sense.add_child(shape_node)
	add_child(_sense)


func _sense_player() -> Player:
	for body: Node2D in _sense.get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _throw_fish(from: Vector2, flight_direction: Vector2, celebration: bool) -> void:
	var fish := FISH_SCENE.instantiate() as Fish
	fish.direction = flight_direction
	fish.harmless = celebration
	_flights.add_child(fish)
	fish.global_position = from


func _wake_the_market() -> void:
	# The cure landed in the apron: the head wakes first, the crew follows,
	# and the whole market throws the fish one last time, all together, and
	# cheers. Then the fight is over, section 6.
	_cured = true
	_tint_members(AWAKE_COLOR)
	for member: FishSeller in _members:
		member.set_awake(true)
		PersonFigure.celebrate(member.get_node(^"Visual") as Polygon2D)
	for fish: Fish in live_fish():
		fish.harmless = true
	# The wake can arrive inside a physics callback, like the landing of the
	# thrown cure cup, so the celebration fish spawn on the deferred queue.
	for member: FishSeller in _members:
		_throw_fish.call_deferred(member.global_position, Vector2.UP, true)
	if not balance.cheer_line.is_empty():
		spoke.emit(balance.cheer_line)
	crew_woke.emit()
