# ABOUTME: SamOatman is the San Coffesco boss: a keynote guru in a gray fleece
# ABOUTME: vest who sleep-presents an endless product show to sleeping founders.
class_name SamOatman
extends Node2D

signal boss_woke
signal spoke(line: String)

enum PhaseKind { SLIDES, DEMO, FINALE }

# The toast of the wake beat, section 6: the woken guru presents the served
# cup as his next product.
const WAKE_TOAST := "SAM OATMAN IS AWAKE. THE CUP IS HIS NEXT PRODUCT."
# Sleeping bodies wear the pajama indigo of every sleeper; the wake turns it
# green like every awakened sleeper.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
# The screen wall behind the guru: lit while the slides show, dark while the
# live demo runs.
const SCREEN_LIT_COLOR := Color(0.85, 0.83, 0.72, 1)
const SCREEN_DARK_COLOR := Color(0.12, 0.1, 0.16, 1)
# The guru and his founders all wear the fleece vest over a dark shirt.
const OUTFIT_COLOR := Color("#2B2B33")
const GURU_SCALE := 1.15
const FOUNDER_SCALE := 0.8
const SLIDES_ZONE_NAME := "SlidesZone"
const DRIPPER_POINT_NAME := "DripperPoint"
# The cure gear stands beside the demo table, off the table body itself.
const DRIPPER_POINT_OFFSET := Vector2(190.0, -40.0)

# The drone scene stays a path, never a preload: the Tech Bro scene already
# holds it, and one scene with two const-preload owners can bind empty in one
# compile order (T102). The sleep zone and scavenge point scenes follow the
# same rule.
const DRONE_SCENE_PATH := "res://scenes/enemies/drone.tscn"
const SLEEP_ZONE_SCENE_PATH := "res://scenes/components/sleep_zone.tscn"
const SCAVENGE_POINT_SCENE_PATH := "res://scenes/components/scavenge_point.tscn"

@export var balance: SamOatmanBalance
@export var brewing_balance: BrewingBalance
# The cure of the fight, section 6: one cup off his own 700-dollar designer
# dripper, the V60 recipe the scavenge gear unlocks.
@export var cure: Recipe

var _phases: BossPhases = null
var _slides: SleepZone = null
var _dripper_point: ScavengePoint = null
var _screen: Polygon2D = null
var _guru: Polygon2D = null
var _founders: Array[Polygon2D] = []
var _table: DemoTable = null
var _drones: Array[Drone] = []
var _cured := false
var _opened := false


func _ready() -> void:
	_collect_hall()
	_tint_hall(SLEEPING_COLOR)
	PersonFigure.dress(_guru, "sam_oatman", OUTFIT_COLOR, ChibiPainter.Gear.VEST, GURU_SCALE)
	for i: int in _founders.size():
		PersonFigure.dress(
			_founders[i], "founder_%d" % i, OUTFIT_COLOR, ChibiPainter.Gear.VEST, FOUNDER_SCALE
		)
	PitchHallArt.attach(_screen, PitchHallArt.Kind.SCREEN, SCREEN_LIT_COLOR)
	if _table != null:
		PitchHallArt.attach(
			_table.get_node_or_null(^"Visual") as Polygon2D, PitchHallArt.Kind.TABLE
		)
	_build_slides()
	_build_dripper_point()
	_table.bind_show(self)
	# Two advancing phases make the three-act show: slides, live demo, then
	# the endless finale that only the cure ends.
	_phases = BossPhases.new([balance.slides_seconds, balance.demo_seconds])


func _physics_process(delta: float) -> void:
	if _cured:
		return
	if not _opened:
		# The opening line speaks on the first tick, after every listener of
		# the city wired itself to the spoke signal.
		_opened = true
		_enter_phase()
		return
	var crossed := _phases.tick(delta)
	if crossed >= 0:
		_enter_phase()


static func cure_accepted(cup: BrewedCup, cure: Recipe, brew_balance: BrewingBalance) -> bool:
	# The cure condition of the fight, the shared tier-led rule of the bosses:
	# between the tiers, only the designer dripper cup works.
	return BossCure.accepted(cup, cure, brew_balance)


func receive_cup(cup: BrewedCup) -> bool:
	# The cure delivery of the fight: a cup served on the demo table. The
	# right brew wakes the guru and ends the show; a wrong one washes off
	# the table while the keynote plays on.
	if _cured:
		return false
	if not cure_accepted(cup, cure, brewing_balance):
		return false
	_wake_the_guru()
	return true


func is_cured() -> bool:
	return _cured


func save_state() -> Dictionary:
	# Section 18: the cure of the show rides the run slot as one plain flag, so
	# a reloaded arena never replays a fight the save already ended.
	return {"cured": _cured}


func load_state(saved: Dictionary) -> void:
	# A saved cure lands silent: the show stands down and the hall wakes, but
	# no line speaks and no signal fires, because the save point already
	# recorded the beat.
	if not bool(saved.get("cured", false)):
		return
	_cured = true
	_opened = true
	_slides.set_active(false)
	_screen.color = SCREEN_DARK_COLOR
	for drone: Drone in _drones:
		if is_instance_valid(drone):
			drone.land_for_good()
	_tint_hall(AWAKE_COLOR)


func phase_index() -> int:
	return _phases.current() if _phases != null else 0


func phase_kind() -> PhaseKind:
	# The show script, section 6: the slides open, one live demo follows, and
	# the finale presents the coffee machine as the last product humanity
	# will ever need, forever.
	match phase_index():
		0:
			return PhaseKind.SLIDES
		1:
			return PhaseKind.DEMO
		_:
			return PhaseKind.FINALE


func slides_zone() -> SleepZone:
	# The reach of the boring slides, section 6: the boring-attack aura of
	# the fight. Tests and the audio system read it from outside.
	return _slides


func dripper_point() -> ScavengePoint:
	# The 700-dollar designer dripper of the guru, section 15: the scavenge
	# gear of the cure, standing beside the demo table like the tower fuse
	# stands at the foot of the tower.
	return _dripper_point


func demo_table() -> DemoTable:
	return _table


func live_drones() -> Array[Drone]:
	# The demo drones in flight right now, landed ones included.
	return _drones.duplicate()


func hall_members() -> Array[Polygon2D]:
	# The guru and every founder of the hall, the bodies the wake tints.
	var members := _founders.duplicate()
	members.append(_guru)
	return members


func _collect_hall() -> void:
	_guru = get_node_or_null(^"Guru") as Polygon2D
	_screen = get_node_or_null(^"Screen") as Polygon2D
	_table = get_node_or_null(^"DemoTable") as DemoTable
	var founders := get_node_or_null(^"Founders") as Node2D
	if founders == null:
		return
	for child: Node in founders.get_children():
		var founder := child as Polygon2D
		if founder != null:
			_founders.append(founder)


func _tint_hall(tint: Color) -> void:
	for member: Polygon2D in hall_members():
		if member != null:
			member.color = tint


func _build_slides() -> void:
	# The boring slides are the aura of the fight: they drain every player
	# inside their reach at the boring-attack rate, section 14, and a silent
	# broadcast tower never stops them, because the show is the guru's own.
	_slides = (load(SLEEP_ZONE_SCENE_PATH) as PackedScene).instantiate() as SleepZone
	_slides.name = SLIDES_ZONE_NAME
	_slides.kind = SleepZone.Kind.BORING
	var shape_node := _slides.get_node(^"CollisionShape2D") as CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = balance.slides_radius
	shape_node.shape = circle
	add_child(_slides)


func _build_dripper_point() -> void:
	# The cure starts as scavenge gear, section 6: the guru's own dripper
	# stands beside the demo table, so the fight hands the player its cure
	# piece the way the tower block hands over its fuse.
	var drop := ScavengeDrop.new()
	drop.item = balance.dripper_item
	drop.amount = 1
	_dripper_point = (load(SCAVENGE_POINT_SCENE_PATH) as PackedScene).instantiate() as ScavengePoint
	_dripper_point.name = DRIPPER_POINT_NAME
	_dripper_point.drops = [drop]
	_dripper_point.position = DRIPPER_POINT_OFFSET
	add_child(_dripper_point)


func _enter_phase() -> void:
	# Every fight phase starts with the words, section 6, then the act runs:
	# the slides pull while they show, and a live demo sends its drones.
	if not balance.phase_line.is_empty():
		spoke.emit(balance.phase_line)
	var showing_slides := phase_kind() != PhaseKind.DEMO
	_slides.set_active(showing_slides)
	_screen.color = SCREEN_LIT_COLOR if showing_slides else SCREEN_DARK_COLOR
	var drones_due := 0
	match phase_kind():
		PhaseKind.DEMO:
			drones_due = balance.demo_drones
		PhaseKind.FINALE:
			drones_due = balance.finale_drones
		_:
			drones_due = 0
	while _drones.size() < drones_due:
		_spawn_demo_drone()


func _spawn_demo_drone() -> void:
	# A live product demo, section 6: the guru sends the same drone the Tech
	# Bro pitches with. The drone orbits the stage and dives on its own
	# sense, so the show only spawns it and lets it fly.
	var drone := (load(DRONE_SCENE_PATH) as PackedScene).instantiate() as Drone
	# The drone anchors on its parent stage, so it must ride the boss itself.
	drone.anchor_path = ^".."
	add_child(drone)
	drone.global_position = _guru.global_position
	_drones.append(drone)


func _wake_the_guru() -> void:
	# The cure landed on the demo table, section 6: the guru drinks, wakes,
	# and presents the cup as his next product. The show ends: the slides go
	# dark, the demo drones land, and the hall of founders wakes with him.
	_cured = true
	_slides.set_active(false)
	_screen.color = SCREEN_DARK_COLOR
	for drone: Drone in _drones:
		drone.land_for_good()
	_tint_hall(AWAKE_COLOR)
	PersonFigure.celebrate(_guru)
	if not balance.wake_line.is_empty():
		spoke.emit(balance.wake_line)
	boss_woke.emit()
