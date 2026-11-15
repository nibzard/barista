# ABOUTME: Aisle7Husband is the sleeping husband of aisle 7: a cup target that
# ABOUTME: wakes to one Turkish cup served in front of him, section 13.
class_name Aisle7Husband
extends StaticBody2D

# He sleeps in the pajama indigo of every sleeper; the wake turns it green
# like every awakened sleeper, and he cries.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
# His cry line holds longer than a common wake line: the beat is the payoff of
# the quest.
const LINE_HOLD_SECONDS := 6.0

@export var idle_text := ""
@export var cry_line := ""

# The quest rule decides before the wake lands. The stage binds the machine,
# and the husband never references the stage, so the cup projectile can name
# his type without a load cycle.
var quest: Aisle7Quest = null

var _awake := false
var _line_time_left := 0.0

@onready var visual: Polygon2D = $Visual
@onready var line_label: Label = $LineLabel


func _ready() -> void:
	visual.color = SLEEPING_COLOR
	line_label.text = idle_text
	line_label.visible = true


func _physics_process(delta: float) -> void:
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0 and _awake:
		line_label.visible = false


func is_awake() -> bool:
	return _awake


func try_wake(cup: BrewedCup) -> bool:
	# A cup that lands on him asks the quest rule first: the photo must be
	# taken, then the Turkish rule decides. The wake itself lands only when the
	# rule accepts, so no cup reaches him before the wife spoke.
	if _awake or quest == null:
		return false
	if not quest.receive_cup(cup):
		return false
	wake_now()
	return true


func wake_now() -> void:
	# The wake beat: the green tint and the cry line, section 13.
	if _awake:
		return
	_awake = true
	visual.color = AWAKE_COLOR
	if not cry_line.is_empty():
		line_label.text = cry_line
		line_label.visible = true
		_line_time_left = LINE_HOLD_SECONDS
