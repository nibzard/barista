# ABOUTME: RobotaxiDepotStage is the Robotaxi Depot side quest in the world,
# ABOUTME: section 13 of GAME_DESIGN.md: the depot control room with its
# ABOUTME: sleeping routing engineer, the robotaxi stands of the city, and the
# ABOUTME: fleet that hauls sleepwalkers to the player until his code-like
# ABOUTME: order wakes him into the fast travel reward.
class_name RobotaxiDepotStage
extends SignatureQuest

const QUEST_ID := "robotaxi_depot"
const ENGINEER_SCENE := preload("res://scenes/quests/robotaxi_engineer.tscn")
const CAB_SCENE := preload("res://scenes/quests/robotaxi_cab.tscn")
const STAND_SCENE := preload("res://scenes/quests/robotaxi_taxi_stand.tscn")

const ROLE_LABEL := "THE ROUTING ENGINEER"
# The order of the routing engineer, written like code, section 13: a triple
# shot oat cortado with milk at exactly 31 degrees.
const ORDER_LOOP_LINE := "while (asleep) { serve(order); }"
const ORDER_CODE := 'order = {shots: 3, style: "cortado", milk: "oat", temp_c: 31}'
const WAKE_LINE := "Route patched. // TODO: thank the barista."

const ACCEPT_TOAST := (
	"THE ROUTING ENGINEER SLEEPS."
	+ " THE ROBOTAXIS HAUL SLEEPWALKERS TO YOU."
	+ " HIS ORDER IS WRITTEN LIKE CODE."
)
const WAKE_TOAST := "THE ENGINEER WAKES. THE FLEET RE-ROUTES. THE TAXIS ARE FAST TRAVEL NOW."
const RIDE_TOAST := "THE TAXI ROUTES YOU TO %s."

# The control room stands on the quest landmark, north of the crowd lane and
# clear of it, so a walker on the street never stumbles into the depot notice.
const CONTROL_ROOM_FRACTION := Vector2(0.5, 0.24)
const CONTROL_ROOM_SIZE := Vector2(250.0, 150.0)
# The art direction pass, section 20: the depot room keeps to the paper
# palette. The console carries the San Coffesco teal, the tech accent.
const ROOM_FLOOR_COLOR := Color(0.78, 0.72, 0.6, 1.0)
const ROOM_EDGE_COLOR := Color(0.42, 0.29, 0.19, 1.0)
const CONSOLE_SIZE := Vector2(130.0, 26.0)
const CONSOLE_COLOR := Color(0.369, 0.604, 0.58, 1.0)
const ROOM_LABEL := "DEPOT CONTROL ROOM"
const ROOM_TEXT_SIZE := 14
const ROOM_TEXT_COLOR := Color(0.93, 0.95, 0.88, 1.0)
# The cab parks at the depot curb, south of the control room.
const CAB_PARK_OFFSET := Vector2(150.0, 60.0)

# The robotaxi stands of the city, section 13: the west edge, the depot, and
# the tower edge, all on the south street. The kind order names the blocks.
const STAND_KINDS: Array[CityBlock.Kind] = [
	CityBlock.Kind.CAFE,
	CityBlock.Kind.QUEST,
	CityBlock.Kind.TOWER,
]
const STAND_NAMES: Array[String] = ["THE CAFE", "THE DEPOT", "THE TOWER"]
const STAND_FRACTION := Vector2(0.14, 0.62)

@export var balance: RobotaxiDepotBalance
@export var brewing_balance: BrewingBalance
# The code-like order of the routing engineer, section 13.
@export var order: Recipe

var quest: RobotaxiDepotQuest = null

# The run arrives as a plain Node: naming the run class here would tie the
# stage's compile back into the city script (T112).
var _run: Node = null
var _engineer: RobotaxiEngineer = null
var _cab: RobotaxiCab = null
var _stands: Array[RobotaxiTaxiStand] = []
var _panel: RobotaxiRidePanel = null
var _depot_position := Vector2.ZERO
var _accepted := false
var _log_state_applied := false


func _ready() -> void:
	quest = RobotaxiDepotQuest.new(order, brewing_balance)


func setup(run: Node) -> void:
	# The stage builds the depot, its stands, and the fleet cab, then wires
	# every quest beat to the world: the toasts, the hauls, and the reward.
	_run = run
	_build_depot()
	_build_stands()
	quest.engineer_woke.connect(_on_engineer_woke)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if quest == null or _run == null:
		return
	_apply_loaded_log_state()
	_tick_accept()
	_tick_fleet(delta)


func try_interact() -> bool:
	# One button in the quest world: the interact key at a robotaxi stand. A
	# locked stand keeps the key free, because the van can park beside any
	# stand and its own beats matter more; a routed fleet opens the ride
	# board. Anywhere else keeps the key for the van.
	if _run == null or quest == null:
		return false
	var player: Player = _run.player
	if player.is_asleep() or player.is_grabbed() or player.is_input_locked():
		return false
	var stand := _stand_at_player()
	if stand == null:
		return false
	if not quest.is_fast_travel_unlocked():
		return false
	_open_ride_board(stand)
	return true


func holds_interact() -> bool:
	# The ride board owns the interact key while it plays, so its press cannot
	# also drive the van or a master lesson.
	return _panel != null


func owns_screen() -> bool:
	# The ride board owns the screen, so the run stands its touch buttons down
	# behind it, like the brew stand.
	return _panel != null


func engineer() -> RobotaxiEngineer:
	return _engineer


func cab() -> RobotaxiCab:
	return _cab


func stands() -> Array[RobotaxiTaxiStand]:
	return _stands.duplicate()


func ride_board() -> RobotaxiRidePanel:
	return _panel


func depot_position() -> Vector2:
	return _depot_position


func _build_depot() -> void:
	# The depot control room on the quest landmark of the city: the sleeping
	# engineer at his console, and the cab of the fleet at the curb.
	var map: CityMap = _run.city_map()
	var quest_block := map.find_block_of_kind(CityBlock.Kind.QUEST)
	if quest_block == null:
		return
	_depot_position = (quest_block.global_position + quest_block.size * CONTROL_ROOM_FRACTION)
	_engineer = ENGINEER_SCENE.instantiate() as RobotaxiEngineer
	_engineer.name = "RoutingEngineer"
	_engineer.role_label = ROLE_LABEL
	_engineer.order_code = "%s\n%s" % [ORDER_LOOP_LINE, ORDER_CODE]
	_engineer.wake_line = WAKE_LINE
	add_child(_engineer)
	_engineer.global_position = _depot_position
	_engineer.quest = quest
	_cab = CAB_SCENE.instantiate() as RobotaxiCab
	_cab.name = "RobotaxiCab"
	add_child(_cab)
	_cab.setup(_depot_position + CAB_PARK_OFFSET, balance)


func _build_stands() -> void:
	# The robotaxi stands of the fast travel network, section 13: the same
	# stops before and after the reward, so the city reads as one system.
	var map: CityMap = _run.city_map()
	for i: int in range(STAND_KINDS.size()):
		var block := map.find_block_of_kind(STAND_KINDS[i])
		if block == null:
			continue
		var stand := STAND_SCENE.instantiate() as RobotaxiTaxiStand
		stand.name = "TaxiStand%d" % i
		add_child(stand)
		stand.setup(STAND_NAMES[i], balance.stand_notice_radius)
		stand.global_position = block.global_position + block.size * STAND_FRACTION
		_stands.append(stand)


func _apply_loaded_log_state() -> void:
	# Section 18: a reload resumes the quest from the saved log, silent and
	# without a replayed beat. The quest log builds after the stage in the
	# run's build order, so the apply waits for this first physics tick.
	if _log_state_applied:
		return
	_log_state_applied = true
	if _engineer == null or _cab == null:
		return
	var saved: SideQuest = _run.quest_log.quest(QUEST_ID)
	if saved == null:
		return
	_accepted = not saved.is_offered()
	if not saved.is_complete():
		return
	quest.load_state({"phase": RobotaxiDepotQuest.Phase.FLEET_ROUTED})
	_engineer.wake_now(true)
	_cab.retire()


func _tick_accept() -> void:
	# The player walks into the depot and reads the order: the side quest
	# turns active and its marker appears, section 12.
	if _accepted or quest.phase() != RobotaxiDepotQuest.Phase.DEPOT_ASLEEP:
		return
	if _engineer == null:
		return
	var player: Player = _run.player
	if (
		player.global_position.distance_to(_engineer.global_position)
		> (balance.depot_notice_radius)
	):
		return
	_accepted = true
	_run.quest_log.accept(QUEST_ID)
	_run.hud.show_toast(ACCEPT_TOAST)


func _tick_fleet(delta: float) -> void:
	# The sleeping fleet keeps its route, section 13: the taxis pick up
	# sleepwalkers and deliver them to the player.
	if not quest.fleet_delivers_sleepwalkers() or _cab == null:
		return
	var player: Player = _run.player
	_cab.tick(delta, player, _passenger_candidate(player), _may_deliver(player))


func _passenger_candidate(player: Player) -> Sleepwalker:
	# The next hail, deterministic: the eligible sleeper nearest the cab. A
	# ride fetches only a wandering sleeper from the streets off the cafe
	# block, and never one already standing by the player.
	var best: Sleepwalker = null
	var best_distance := 0.0
	for node: Node in get_tree().get_nodes_in_group(Sleepwalker.SLEEPWALKER_GROUP):
		var walker := node as Sleepwalker
		if walker == null or walker.is_awake() or walker.state != Sleepwalker.State.WANDER:
			continue
		if _block_index_of(walker.global_position) == 0:
			continue
		if (
			player.global_position.distance_to(walker.global_position)
			< balance.pickup_min_player_distance
		):
			continue
		var distance := _cab.global_position.distance_to(walker.global_position)
		if best == null or distance < best_distance:
			best = walker
			best_distance = distance
	return best


func _may_deliver(player: Player) -> bool:
	# The fleet hauls for the player of the quest: an accepted quest, an awake
	# player outside the cafe safe zone, the one place the taxis hold back.
	if not _accepted or player.is_asleep():
		return false
	var map: CityMap = _run.city_map()
	var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
	if cafe_block == null:
		return false
	var safe_zone := cafe_block.safe_zone()
	return safe_zone == null or not safe_zone.has_player_inside()


func _block_index_of(position: Vector2) -> int:
	# The block row index of a world position, clamped to the city.
	var city_balance: CityBalance = _run.balance
	var map: CityMap = _run.city_map()
	var block_size := CityRules.block_size(city_balance)
	var index := int(position.x / block_size.x)
	return clampi(index, 0, map.block_count() - 1)


func _stand_at_player() -> RobotaxiTaxiStand:
	for stand: RobotaxiTaxiStand in _stands:
		if stand.is_player_at_stand():
			return stand
	return null


func _open_ride_board(stand: RobotaxiTaxiStand) -> void:
	# The routed taxi takes the hail: the board lists every stand but the one
	# under the player, and the overlay owns the player while it plays.
	if _panel != null:
		return
	var stand_index := _stand_index(stand)
	if stand_index < 0:
		return
	_panel = RobotaxiRidePanel.new()
	_panel.name = "RobotaxiRideBoard"
	add_child(_panel)
	_panel.destination_chosen.connect(_on_destination_chosen)
	_panel.closed.connect(_on_board_closed)
	_panel.begin(STAND_NAMES, stand_index)
	_run.player.set_input_locked(true)


func _close_ride_board() -> void:
	if _panel == null:
		return
	_panel.queue_free()
	_panel = null
	_run.player.set_input_locked(false)


func _on_destination_chosen(stand_index: int) -> void:
	# Fast travel, section 13: the taxi routes the player across the city to
	# the chosen stand.
	var stand := _stands[stand_index]
	_close_ride_board()
	_run.player.global_position = stand.drop_position()
	_run.hud.show_toast(RIDE_TOAST % stand.stand_name)


func _on_board_closed() -> void:
	_close_ride_board()


func _on_engineer_woke() -> void:
	# The order landed: the fleet re-routes, the cab retires from the hauling
	# route, and the side quest completes into the fast travel reward.
	_cab.retire()
	if not _run.quest_log.is_active(QUEST_ID):
		_run.quest_log.accept(QUEST_ID)
	_run.quest_log.complete(QUEST_ID)
	_run.hud.show_toast(WAKE_TOAST)


func _stand_index(stand: RobotaxiTaxiStand) -> int:
	for i: int in range(_stands.size()):
		if _stands[i] == stand:
			return i
	return -1


func _draw() -> void:
	# The depot control room, placeholder shapes until the art pass: a floor,
	# the routing console, and the room label.
	if _depot_position == Vector2.ZERO:
		return
	var floor_rect := Rect2(_depot_position - CONTROL_ROOM_SIZE * 0.5, CONTROL_ROOM_SIZE)
	draw_rect(floor_rect, ROOM_FLOOR_COLOR)
	draw_rect(floor_rect, ROOM_EDGE_COLOR, false, 4.0)
	draw_rect(
		Rect2(_depot_position - CONSOLE_SIZE * Vector2(0.5, 1.5), CONSOLE_SIZE), CONSOLE_COLOR
	)
	draw_string(
		ThemeDB.fallback_font,
		(
			_depot_position
			+ Vector2(-CONTROL_ROOM_SIZE.x * 0.5, CONTROL_ROOM_SIZE.y * 0.5 + ROOM_TEXT_SIZE)
		),
		ROOM_LABEL,
		HORIZONTAL_ALIGNMENT_CENTER,
		CONTROL_ROOM_SIZE.x,
		ROOM_TEXT_SIZE,
		ROOM_TEXT_COLOR
	)
