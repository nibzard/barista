# ABOUTME: BandMember is one sleeper of Sleepvana at his site: a cup target
# ABOUTME: that wakes to his own order, like the fish sellers of the market.
class_name BandMember
extends StaticBody2D

signal woke_up

# Sleeping band members wear the pajama indigo of every sleeper; the wake turns
# it green like every awakened sleeper.
const SLEEPING_COLOR := Color(0.42, 0.38, 0.72)
const AWAKE_COLOR := Color(0.45, 0.85, 0.5)
# The spoken line holds for a few seconds, like the master line.
const LINE_HOLD_SECONDS := 4.0
# The frontman sleeps behind the crowd rule, so his label says so, section 13.
const FRONTMAN_HINT := "THE FRONTMAN WAKES ONLY TO A FULL CROWD."

@export var brewing_balance: BrewingBalance
# The order that wakes this member: one of the three simple orders, or the
# frontman order for the encore.
@export var order: Recipe
@export var role_label := ""
@export var wake_line := ""
# The frontman ignores his order until the full crowd stands at the garage.
@export var is_frontman := false

var stage: SleepvanaStage = null
# The index of the member's site: 0 greenhouse, 1 sofa, 2 garage.
var site_index := -1

var _awake := false
var _line_time_left := 0.0

@onready var visual: Polygon2D = $Visual
@onready var line_label: Label = $LineLabel


func _ready() -> void:
	visual.color = SLEEPING_COLOR
	line_label.visible = true
	line_label.text = _idle_text()


func _physics_process(delta: float) -> void:
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0:
		line_label.visible = false


func bind_stage(quest_stage: SleepvanaStage, index: int) -> void:
	stage = quest_stage
	site_index = index


func is_awake() -> bool:
	return _awake


func order_text() -> String:
	if order == null:
		return ""
	return "ORDER: %s." % order.display_name.to_upper()


func try_wake(cup: BrewedCup) -> bool:
	# A cup that lands on the member asks his order. The tier-led rule of the
	# bosses applies: a perfect cup wakes anyone, a weak cup no one, and between
	# the tiers only the order itself.
	if _awake or order == null:
		return false
	if is_frontman:
		# The frontman delegates to the stage: the crowd condition and the
		# encore window decide before the order does.
		if stage == null:
			return false
		return stage.receive_frontman_cup(cup)
	if not BossCure.accepted(cup, order, brewing_balance):
		return false
	wake_now()
	return true


func wake_now() -> void:
	# The wake beat itself: the green tint, the line, the signal.
	if _awake:
		return
	_awake = true
	visual.color = AWAKE_COLOR
	if not wake_line.is_empty():
		line_label.text = wake_line
		line_label.visible = true
		_line_time_left = LINE_HOLD_SECONDS
	woke_up.emit()


func announce_encore() -> void:
	# The encore begins: the sleeping frontman mumbles his order at last, so
	# the player knows what to brew, section 13.
	if _awake or not is_frontman:
		return
	line_label.text = "%s\n%s" % [role_label, order_text()]
	line_label.visible = true


func _idle_text() -> String:
	# The sleeping member shows his role and his order, so the player knows
	# what to brew at first sight. The frontman shows the crowd rule instead.
	if is_frontman:
		return "%s\n%s" % [role_label, FRONTMAN_HINT]
	return "%s\n%s" % [role_label, order_text()]
