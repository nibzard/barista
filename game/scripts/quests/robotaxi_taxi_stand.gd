# ABOUTME: RobotaxiTaxiStand is one robotaxi stop of the city, section 13: a
# ABOUTME: sign on the curb and the notice circle where the interact key hails
# ABOUTME: a ride once the fleet re-routes.
class_name RobotaxiTaxiStand
extends Node2D

# Placeholder look until the art pass: a thin pole with a lit TAXI sign.
const POLE_COLOR := Color(0.75, 0.75, 0.78, 1.0)
const SIGN_COLOR := Color(0.99, 0.83, 0.25, 1.0)
const SIGN_TEXT_COLOR := Color(0.15, 0.12, 0.08, 1.0)
const POLE_WIDTH := 6.0
const POLE_HEIGHT := 40.0
const SIGN_SIZE := Vector2(74.0, 26.0)
const SIGN_TEXT_SIZE := 15
# The arriving player steps out just south of the sign, on the street.
const DROP_OFFSET := Vector2(0.0, 46.0)

var stand_name := ""


func setup(stand_display_name: String, notice_radius: float) -> void:
	# The stage names the stop and sizes its notice circle from the quest
	# balance, then the stand composes its area before it enters the tree.
	stand_name = stand_display_name
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


func is_player_at_stand() -> bool:
	# True while the player stands inside the notice circle, like the master
	# spot and the van.
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return false
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func drop_position() -> Vector2:
	# Where a routed taxi lets the player out.
	return global_position + DROP_OFFSET


func _draw() -> void:
	draw_rect(
		Rect2(Vector2(-POLE_WIDTH * 0.5, -POLE_HEIGHT), Vector2(POLE_WIDTH, POLE_HEIGHT)),
		POLE_COLOR
	)
	var sign_rect := Rect2(Vector2(-SIGN_SIZE.x * 0.5, -POLE_HEIGHT - SIGN_SIZE.y), SIGN_SIZE)
	draw_rect(sign_rect, SIGN_COLOR)
	draw_rect(sign_rect, Color(0.2, 0.15, 0.1, 1.0), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		sign_rect.position + Vector2(0.0, SIGN_TEXT_SIZE + 4.0),
		"TAXI",
		HORIZONTAL_ALIGNMENT_CENTER,
		SIGN_SIZE.x,
		SIGN_TEXT_SIZE,
		SIGN_TEXT_COLOR
	)
