# ABOUTME: MasterNpc is a brewing master in the world: the figure at the cafe
# ABOUTME: that teaches the lesson when the player walks up, section 8.
class_name MasterNpc
extends Node2D

enum Interaction { NOT_AT_MASTER, LESSON_TAUGHT, SCHOOL_DONE }

# Every master joins this group, so a city run finds its masters even when a
# quest stands one later, like the Aisle 7 husband.
const MASTER_GROUP := &"brewing_masters"

# The spoken line holds for a few seconds, like the HUD toast.
const LINE_HOLD_SECONDS := 4.0
# The chalkboard toast of a lesson beat: the count, every new recipe, and the
# school end when the last lesson lands.
const LESSON_TOAST_TEXT := "%s, LESSON %d OF %d. +%d SKILL."
const LESSON_RECIPE_TEXT := " NEW RECIPE: %s."
const SCHOOL_DONE_TOAST_TEXT := "%s HAS TAUGHT EVERY LESSON."
# Placeholder master figure until the art pass: a robe in the master color,
# a head, and one cup in the hand.
const HEAD_COLOR := Color(0.96, 0.85, 0.72, 1)
const HEAD_RADIUS := 10.0
const ROBE_RECT := Rect2(-16.0, -18.0, 32.0, 44.0)
const CUP_COLOR := Color(0.93, 0.87, 0.72, 1)
const CUP_CENTER := Vector2(22.0, 2.0)
const CUP_RADIUS := 6.0
const NAME_TEXT_SIZE := 15
const NAME_TEXT_COLOR := Color(0.96, 0.93, 0.85, 1)

@export var master: BrewingMaster
@export var notice_radius := 70.0

var _school: MasterLessons = null
var _line_time_left := 0.0
var _last_granted: Array[String] = []

@onready var line_label: Label = $LineLabel


func _ready() -> void:
	add_to_group(MASTER_GROUP)
	_compose_notice_area()
	line_label.visible = false
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _line_time_left > 0.0:
		_line_time_left = maxf(0.0, _line_time_left - delta)
		if _line_time_left == 0.0:
			line_label.visible = false


func bind_master(master_data: BrewingMaster, school: MasterLessons) -> void:
	master = master_data
	_school = school
	queue_redraw()


func is_player_at_master() -> bool:
	return _player_at_master() != null


func interact() -> Interaction:
	# One button at the master: a lesson while lessons remain, then only the
	# catchphrase. The school owns the lesson flow; this only speaks.
	if master == null or _school == null or not is_player_at_master():
		return Interaction.NOT_AT_MASTER
	if not _school.can_take_lesson(master.master_id):
		_last_granted.clear()
		_speak(master.catchphrase)
		return Interaction.SCHOOL_DONE
	_last_granted = _school.take_lesson(master.master_id)
	_speak("%s %s" % [master.catchphrase, master.lesson_line])
	return Interaction.LESSON_TAUGHT


func spoken_line() -> String:
	return line_label.text


func is_speaking() -> bool:
	return line_label.visible


func announce_text(outcome: Interaction, skill_gain: int, library: BrewingLibrary) -> String:
	# The toast line of the beat, built on the school numbers: the lesson
	# count, every granted recipe, and the school end when the last lesson
	# lands. The caller owns the chalkboard the line lands on.
	if outcome == Interaction.SCHOOL_DONE:
		return SCHOOL_DONE_TOAST_TEXT % master.display_name.to_upper()
	var text := (
		LESSON_TOAST_TEXT
		% [
			master.display_name.to_upper(),
			_school.lessons_taken(master.master_id),
			_school.lessons_per_master(),
			skill_gain,
		]
	)
	for recipe_id: String in _last_granted:
		var recipe := library.find_recipe(recipe_id) if library != null else null
		if recipe != null:
			text += LESSON_RECIPE_TEXT % recipe.display_name.to_upper()
	if _school.is_school_complete(master.master_id):
		text += " " + SCHOOL_DONE_TOAST_TEXT % master.display_name.to_upper()
	return text


func _speak(line_text: String) -> void:
	line_label.text = line_text
	line_label.visible = true
	_line_time_left = LINE_HOLD_SECONDS


func _player_at_master() -> Player:
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return null
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _compose_notice_area() -> void:
	var notice := Area2D.new()
	notice.name = "NoticeArea"
	notice.collision_layer = 0
	notice.collision_mask = 2
	notice.monitorable = false
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = notice_radius
	shape_node.shape = circle
	notice.add_child(shape_node)
	add_child(notice)


func _draw() -> void:
	if master == null:
		return
	draw_rect(ROBE_RECT, master.accent_color)
	draw_circle(Vector2(0.0, ROBE_RECT.position.y - HEAD_RADIUS * 0.5), HEAD_RADIUS, HEAD_COLOR)
	draw_circle(CUP_CENTER, CUP_RADIUS, CUP_COLOR)
	draw_line(
		CUP_CENTER + Vector2(0.0, -CUP_RADIUS - 1.5),
		CUP_CENTER + Vector2(0.0, -CUP_RADIUS - 7.0),
		NAME_TEXT_COLOR,
		1.5
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-100.0, ROBE_RECT.position.y - HEAD_RADIUS * 2.0 - 8.0),
		master.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER,
		200.0,
		NAME_TEXT_SIZE,
		NAME_TEXT_COLOR
	)
