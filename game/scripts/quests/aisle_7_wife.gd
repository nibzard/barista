# ABOUTME: Aisle7Wife is the awake wife at the hardware store, section 13: she
# ABOUTME: holds the photo, speaks to the player, walks to her husband, and hugs him.
class_name Aisle7Wife
extends Node2D

# Placeholder look until the art pass: a rose dress, a head, the photo in her
# hand while she waits, and one small heart while the hug holds.
const HEAD_COLOR := Color(0.96, 0.85, 0.72, 1.0)
const DRESS_COLOR := Color(0.85, 0.5, 0.52, 1.0)
const PHOTO_COLOR := Color(0.97, 0.96, 0.9, 1.0)
const HEART_COLOR := Color(0.9, 0.3, 0.35, 1.0)
const DRESS_RECT := Rect2(-14.0, -16.0, 28.0, 38.0)
const HEAD_RADIUS := 9.0
const HEAD_OFFSET := Vector2(0.0, -24.0)
const PHOTO_RECT := Rect2(14.0, -8.0, 13.0, 17.0)
const HEART_CENTER := Vector2(0.0, -56.0)
const HEART_DOT_OFFSET := 3.0
const HEART_DOT_RADIUS := 4.0
const HEART_TIP_DROP := 8.0
const LINE_WIDTH := 340.0
const LINE_TEXT_SIZE := 16
const LINE_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const LINE_OFFSET := Vector2(-LINE_WIDTH * 0.5, -118.0)
const LINE_HEIGHT := 68.0

@export var notice_radius := 130.0

var _line_label: Label = null
var _line_time_left := 0.0
var _holds_photo := true
var _walking := false
var _walk_target := Vector2.ZERO
var _hugging := false


func _ready() -> void:
	_compose_line_label()
	_compose_notice_area()


func _physics_process(delta: float) -> void:
	if _line_time_left <= 0.0:
		return
	_line_time_left = maxf(0.0, _line_time_left - delta)
	if _line_time_left == 0.0:
		_line_label.visible = false


func is_player_near() -> bool:
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return false
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func speak(line_text: String, hold_seconds: float) -> void:
	_line_label.text = line_text
	_line_label.visible = true
	_line_time_left = hold_seconds


func spoken_line() -> String:
	return _line_label.text


func is_speaking() -> bool:
	return _line_label.visible


func holds_photo() -> bool:
	return _holds_photo


func set_photo_held(held: bool) -> void:
	# The photo leaves her hand for the player's bag.
	_holds_photo = held
	queue_redraw()


func begin_walk_to(target: Vector2) -> void:
	# Her husband woke: she crosses the aisle to him.
	_walking = true
	_walk_target = target


func is_walking() -> bool:
	return _walking


func step_walk(delta: float, speed: float, stop_distance: float) -> bool:
	# One step of the walk. Returns true when she stands at hug range; the
	# caller stops stepping after that.
	if not _walking:
		return true
	var to_target := _walk_target - global_position
	if to_target.length() <= stop_distance:
		_walking = false
		return true
	var step := minf(speed * delta, to_target.length() - stop_distance)
	global_position += to_target.normalized() * step
	return false


func is_hugging() -> bool:
	return _hugging


func set_hugging(hugging: bool) -> void:
	_hugging = hugging
	queue_redraw()


func _compose_line_label() -> void:
	_line_label = Label.new()
	_line_label.position = LINE_OFFSET
	_line_label.size = Vector2(LINE_WIDTH, LINE_HEIGHT)
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.add_theme_font_size_override("font_size", LINE_TEXT_SIZE)
	_line_label.add_theme_color_override("font_color", LINE_COLOR)
	_line_label.visible = false
	add_child(_line_label)


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
	draw_rect(DRESS_RECT, DRESS_COLOR)
	draw_circle(HEAD_OFFSET, HEAD_RADIUS, HEAD_COLOR)
	if _holds_photo:
		draw_rect(PHOTO_RECT, PHOTO_COLOR)
	if _hugging:
		_draw_heart()


func _draw_heart() -> void:
	# The only sweet hug in the game earns the only heart in the game.
	draw_circle(HEART_CENTER + Vector2(-HEART_DOT_OFFSET, 0.0), HEART_DOT_RADIUS, HEART_COLOR)
	draw_circle(HEART_CENTER + Vector2(HEART_DOT_OFFSET, 0.0), HEART_DOT_RADIUS, HEART_COLOR)
	var points := PackedVector2Array(
		[
			HEART_CENTER + Vector2(-HEART_DOT_OFFSET - HEART_DOT_RADIUS, -1.0),
			HEART_CENTER + Vector2(HEART_DOT_OFFSET + HEART_DOT_RADIUS, -1.0),
			HEART_CENTER + Vector2(0.0, HEART_TIP_DROP),
		]
	)
	draw_colored_polygon(points, HEART_COLOR)
