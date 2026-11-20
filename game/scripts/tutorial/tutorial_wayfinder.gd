# ABOUTME: TutorialWayfinder draws a pulsing golden world arrow from the player
# ABOUTME: toward the active tutorial step target plus a glowing destination ring.
class_name TutorialWayfinder
extends Node2D

const ARROW_COLOR := Color(0.99, 0.84, 0.32, 0.92)
const RING_COLOR := Color(0.99, 0.84, 0.32, 0.65)
const OUTLINE_COLOR := Color(0.18, 0.12, 0.08, 0.9)

var player: Node2D = null
var target_position := Vector2.ZERO
var active := false

var _pulse := 0.0


func _ready() -> void:
	z_index = 38


func _process(delta: float) -> void:
	if not active:
		return
	_pulse += delta
	queue_redraw()


func set_target(from_player: Node2D, world_target: Vector2, enabled: bool) -> void:
	player = from_player
	target_position = world_target
	if active != enabled:
		active = enabled
		queue_redraw()


func _draw() -> void:
	if not active or player == null or not is_instance_valid(player):
		return
	var origin := player.global_position
	var to_target := target_position - origin
	var dist := to_target.length()
	var wave := 0.5 + 0.5 * sin(_pulse * 6.5)
	var ring_r := 32.0 + wave * 8.0
	draw_arc(target_position, ring_r, 0.0, TAU, 36, RING_COLOR, 4.0, true)
	if dist < 44.0:
		return
	var dir := to_target / dist
	var side := Vector2(-dir.y, dir.x)
	var arrow_dist := minf(58.0 + wave * 6.0, dist - 22.0)
	var tip := origin + dir * (arrow_dist + 18.0)
	var base := origin + dir * arrow_dist
	var pts := PackedVector2Array([tip, base + side * 11.0, base - side * 11.0])
	draw_colored_polygon(pts, ARROW_COLOR)
	var closed := PackedVector2Array([tip, base + side * 11.0, base - side * 11.0, tip])
	draw_polyline(closed, OUTLINE_COLOR, 2.2, true)
