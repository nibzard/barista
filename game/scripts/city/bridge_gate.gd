# ABOUTME: BridgeGate is the paywall at the road east out of the free city.
# ABOUTME: The gate reads the UnlockState; the real billing is external, see T053.
class_name BridgeGate
extends StaticBody2D

signal paywall_reached
signal opened

# Placeholder gate colors until the art pass brings the real bridge.
const POST_COLOR := Color(0.25, 0.2, 0.18, 1)
const BARRIER_CLOSED_COLOR := Color(0.78, 0.16, 0.14, 1)
const BARRIER_OPEN_COLOR := Color(0.3, 0.75, 0.4, 1)
const BARRIER_WIDTH := 16.0
const POST_WIDTH := 20.0
const POST_HEIGHT := 48.0

@export var gate_span := 720.0
@export var notice_radius := 160.0

var _open := false
var _player_notified := false


func _ready() -> void:
	_compose_barrier()
	_compose_notice_area()


func bind_unlock_state(state: UnlockState) -> void:
	# The one payment unlocks the full game: the open beat runs no matter who
	# paid. A state that is already unlocked opens the gate at once.
	if state.is_unlocked():
		open()
		return
	state.unlocked.connect(open)


func try_purchase(gateway: PurchaseGateway, state: UnlockState) -> bool:
	# One press at the locked gate starts the one payment of section 4 through
	# the purchase interface. The stub grants at once; the store flow of T053
	# answers the same call. Returns false when another handler should take
	# the key: the gate stands open or nobody stands at it.
	if _open or gateway == null or state == null:
		return false
	if not _player_inside_notice_area():
		return false
	gateway.begin_purchase(state)
	return true


func is_open() -> bool:
	return _open


func open() -> void:
	# The barrier lifts for good. The call is idempotent.
	if _open:
		return
	_open = true
	var barrier := get_node(^"Barrier") as CollisionShape2D
	barrier.set_deferred("disabled", true)
	queue_redraw()
	opened.emit()


func _compose_barrier() -> void:
	var barrier := CollisionShape2D.new()
	barrier.name = "Barrier"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BARRIER_WIDTH, gate_span)
	barrier.shape = shape
	add_child(barrier)


func _compose_notice_area() -> void:
	var notice := Area2D.new()
	notice.name = "NoticeArea"
	notice.collision_layer = 0
	notice.collision_mask = 2
	notice.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = notice_radius
	shape.shape = circle
	notice.add_child(shape)
	add_child(notice)


func _physics_process(_delta: float) -> void:
	# Poll the notice area every physics frame, like the sleep zones do: a
	# locked gate tells every approaching player about the paywall once per
	# stay, then stays quiet until the player steps away.
	if _open:
		return
	var player_inside := _player_inside_notice_area()
	if player_inside and not _player_notified:
		_player_notified = true
		paywall_reached.emit()
	elif not player_inside and _player_notified:
		_player_notified = false


func _player_inside_notice_area() -> bool:
	var notice := get_node_or_null(^"NoticeArea") as Area2D
	if notice == null:
		return false
	for body: Node2D in notice.get_overlapping_bodies():
		if body is Player:
			return true
	return false


func _draw() -> void:
	# Placeholder toll gate: two posts and a barrier that lifts when open.
	var half_span := gate_span * 0.5
	for post_y: float in [-half_span + POST_HEIGHT * 0.5, half_span - POST_HEIGHT * 0.5]:
		var post_rect := Rect2(
			-POST_WIDTH * 0.5, post_y - POST_HEIGHT * 0.5, POST_WIDTH, POST_HEIGHT
		)
		draw_rect(post_rect, POST_COLOR)
	if _open:
		draw_circle(Vector2.ZERO, BARRIER_WIDTH * 0.5, BARRIER_OPEN_COLOR)
		return
	var barrier_rect := Rect2(
		-BARRIER_WIDTH * 0.5, -half_span + POST_HEIGHT, BARRIER_WIDTH, gate_span - POST_HEIGHT * 2.0
	)
	draw_rect(barrier_rect, BARRIER_CLOSED_COLOR)
