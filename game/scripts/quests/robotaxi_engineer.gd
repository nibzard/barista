# ABOUTME: RobotaxiEngineer is the sleeping routing engineer of the depot
# ABOUTME: control room, section 13: a cup target that wakes to his own
# ABOUTME: code-like order.
class_name RobotaxiEngineer
extends StaticBody2D

# He sleeps in the pajama indigo of every sleeper; the wake turns it green
# like every awakened sleeper.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
# The wake line holds for a few seconds, like the master line.
const LINE_HOLD_SECONDS := 5.0

# The order written like code, section 13. The label shows it while he sleeps.
@export var order_code := ""
@export var role_label := ""
@export var wake_line := ""

# The quest rule decides before the wake lands, like the husband of aisle 7.
# The stage binds the machine after it builds the depot.
var quest: RobotaxiDepotQuest = null

var _awake := false
var _line_time_left := 0.0

@onready var visual: Polygon2D = $Visual
@onready var line_label: Label = $LineLabel


func _ready() -> void:
	add_to_group(CureDelivery.WAKEABLE_GROUP)
	visual.color = SLEEPING_COLOR
	line_label.text = _idle_text()
	line_label.visible = true


func _physics_process(delta: float) -> void:
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0:
		line_label.visible = false


func is_awake() -> bool:
	return _awake


func try_wake(cup: BrewedCup) -> bool:
	# A cup that lands on him asks the quest rule: the order decides through
	# the tier-led match, and the wake lands only when the rule accepts.
	if _awake or quest == null:
		return false
	if not quest.receive_cup(cup):
		return false
	wake_now()
	return true


func wake_now(restore := false) -> void:
	# The wake beat: the green tint and the code-comment thank-you, section 13.
	# A silent restore hides the sleeping order without replaying the line.
	if _awake:
		return
	_awake = true
	visual.color = AWAKE_COLOR
	if restore:
		line_label.visible = false
		return
	if not wake_line.is_empty():
		line_label.text = wake_line
		line_label.visible = true
		_line_time_left = LINE_HOLD_SECONDS


func _idle_text() -> String:
	# The sleeper shows his role and his order, written like code, so the
	# player knows what to brew at first sight.
	return "%s\n%s" % [role_label, order_code]
