# ABOUTME: CafeTelevision is the cafe set of section 22: the screen where the
# ABOUTME: Dr. Morgen video replays after the opening, one press at a time.
class_name CafeTelevision
extends Node2D

# Placeholder set drawing until the art pass: a wall screen with a standby
# light, a faint cup on the glass, and the video name above it.
const FRAME_COLOR := Color(0.08, 0.07, 0.07, 1.0)
const SCREEN_COLOR := Color(0.05, 0.08, 0.08, 1.0)
const SHELF_COLOR := Color(0.13, 0.1, 0.08, 1.0)
const STANDBY_COLOR := Color(0.6, 0.12, 0.1, 1.0)
const CUP_GLYPH_COLOR := Color(0.55, 0.75, 0.8, 0.5)
const NAME_TEXT_COLOR := Color(0.96, 0.93, 0.85, 1.0)
const FRAME_RECT := Rect2(-32.0, -24.0, 64.0, 44.0)
const SCREEN_RECT := Rect2(-27.0, -19.0, 54.0, 34.0)
const SHELF_RECT := Rect2(-36.0, 20.0, 72.0, 5.0)
const STANDBY_CENTER := Vector2(22.0, 14.0)
const STANDBY_RADIUS := 2.5
const CUP_RECT := Rect2(-7.0, -13.0, 14.0, 16.0)
const CUP_HANDLE_CENTER := Vector2(9.0, -6.0)
const CUP_HANDLE_RADIUS := 4.0
const NAME_TEXT := "DR. MORGEN"
const NAME_TEXT_SIZE := 15
const NAME_RECT := Rect2(-90.0, -58.0, 180.0, 20.0)

# How close the player stands to start a replay, in pixels.
@export var notice_radius := 64.0


func _ready() -> void:
	_compose_notice_area()
	queue_redraw()


func is_player_at_television() -> bool:
	# The replay starts from the set itself, like the master lesson.
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return false
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return true
	return false


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
	draw_rect(FRAME_RECT, FRAME_COLOR)
	draw_rect(SCREEN_RECT, SCREEN_COLOR)
	draw_rect(CUP_RECT, CUP_GLYPH_COLOR)
	draw_arc(CUP_HANDLE_CENTER, CUP_HANDLE_RADIUS, -PI * 0.5, PI * 0.5, 8, CUP_GLYPH_COLOR, 2.0)
	draw_circle(STANDBY_CENTER, STANDBY_RADIUS, STANDBY_COLOR)
	draw_rect(SHELF_RECT, SHELF_COLOR)
	draw_string(
		ThemeDB.fallback_font,
		NAME_RECT.position,
		NAME_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER,
		NAME_RECT.size.x,
		NAME_TEXT_SIZE,
		NAME_TEXT_COLOR
	)
