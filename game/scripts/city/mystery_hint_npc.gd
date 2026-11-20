# ABOUTME: MysteryHintNpc is one awake speaker of the Moonwalker mystery.
# ABOUTME: The figure says its one clue line when the player walks up, section 24.
class_name MysteryHintNpc
extends Node2D

# Every hint speaker joins this group, so a city run and its tests find them.
const HINT_GROUP := &"mystery_hints"
# The spoken line holds for a few seconds, like the master line.
const LINE_HOLD_SECONDS := 5.0
# Placeholder awake figure until the art pass: a pastel outfit, a head, and
# the speaker name in chalk above.
const HEAD_COLOR := Color(0.96, 0.85, 0.72, 1)
const BODY_COLOR := Color(0.55, 0.62, 0.82, 1)
const HEAD_RADIUS := 9.0
const HEAD_OFFSET := Vector2(0.0, -24.0)
const BODY_RECT := Rect2(-14.0, -16.0, 28.0, 38.0)
const NAME_TEXT_SIZE := 13
const NAME_TEXT_COLOR := Color(0.96, 0.93, 0.85, 1)
const NAME_OFFSET := Vector2(-120.0, -92.0)
const NAME_SIZE := Vector2(240.0, 20.0)
const LINE_WIDTH := 360.0
const LINE_TEXT_SIZE := 16
const LINE_COLOR := Color(0.96, 0.93, 0.85, 1)
const LINE_OFFSET := Vector2(-LINE_WIDTH * 0.5, -128.0)
const LINE_HEIGHT := 68.0

@export var hint: MysteryHint
@export var notice_radius := 120.0

var _line_label: Label = null
var _line_time_left := 0.0
var _player_near := false


func _ready() -> void:
	add_to_group(HINT_GROUP)
	_compose_line_label()
	_compose_name_label()
	_compose_notice_area()
	_line_label.visible = false


func _physics_process(delta: float) -> void:
	# The hint speaks on the way in, once per visit: the edge trigger keeps a
	# player who stands around out of a loop, and the next visit replays the
	# clue because mysteries stay forgettable.
	var near := is_player_near()
	if near and not _player_near and hint != null:
		speak(hint.line)
	_player_near = near
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0:
		_line_label.visible = false


func speak(line_text: String) -> void:
	_line_label.text = line_text
	_line_label.visible = true
	_line_time_left = LINE_HOLD_SECONDS


func spoken_line() -> String:
	return _line_label.text


func is_speaking() -> bool:
	return _line_label.visible


func is_player_near() -> bool:
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return false
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func _compose_line_label() -> void:
	_line_label = Label.new()
	_line_label.name = "LineLabel"
	_line_label.position = LINE_OFFSET
	_line_label.size = Vector2(LINE_WIDTH, LINE_HEIGHT)
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_font_size_override(&"font_size", LINE_TEXT_SIZE)
	_line_label.add_theme_color_override(&"font_color", LINE_COLOR)
	add_child(_line_label)


func _compose_name_label() -> void:
	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.position = NAME_OFFSET
	name_label.size = NAME_SIZE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", NAME_TEXT_SIZE)
	name_label.add_theme_color_override(&"font_color", NAME_TEXT_COLOR)
	name_label.text = hint.speaker_name if hint != null else ""
	add_child(name_label)


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
	draw_rect(BODY_RECT, BODY_COLOR)
	draw_circle(HEAD_OFFSET, HEAD_RADIUS, HEAD_COLOR)
