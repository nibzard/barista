# ABOUTME: BeanSlick is the pile of beans the player drops, section 11: a
# ABOUTME: sleepwalker that steps on it slips, slides, and stays down for a beat.
# ABOUTME: The slick lasts for its lifetime, then the floor is clean again.
class_name BeanSlick
extends Area2D

# Placeholder bean look until the art pass: loose beans on the floor.
const BEAN_TINT := Color(0.36, 0.22, 0.12, 0.55)
const BEAN_DOT_TINT := Color(0.22, 0.13, 0.07, 0.9)
const BEAN_DOT_RADIUS := 3.0
# A fixed scatter of beans, so the patch draws the same every frame.
const BEAN_DOTS: Array[Vector2] = [
	Vector2(-14, -8),
	Vector2(4, -16),
	Vector2(16, -2),
	Vector2(-4, 6),
	Vector2(-18, 12),
	Vector2(10, 14),
	Vector2(0, -4),
	Vector2(20, -12),
]

@export var balance: SupportToolsBalance

var _life_time_left := 0.0
var _slipped: Array[Sleepwalker] = []


func _ready() -> void:
	_life_time_left = balance.bean_slick_lifetime_seconds
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var circle := shape_node.shape as CircleShape2D
		if circle != null:
			circle = circle.duplicate() as CircleShape2D
			circle.radius = balance.bean_slick_radius
			shape_node.shape = circle
	queue_redraw()


func seconds_left() -> float:
	return _life_time_left


func _physics_process(delta: float) -> void:
	# Poll the overlap every physics frame, like the other area components:
	# sibling signal order is not guaranteed. A sleepwalker that left the
	# patch may slip again when it steps back in.
	_life_time_left = maxf(0.0, _life_time_left - delta)
	if _life_time_left <= 0.0:
		queue_free()
		return
	var inside := _sleepwalkers_inside()
	for walker: Sleepwalker in _slipped.duplicate():
		if not is_instance_valid(walker) or not inside.has(walker):
			_slipped.erase(walker)
	for walker: Sleepwalker in inside:
		if walker.is_awake() or _slipped.has(walker):
			continue
		_slipped.append(walker)
		walker.slip(
			_slip_direction(walker),
			balance.slip_slide_speed,
			balance.slip_slide_seconds,
			balance.slip_down_seconds
		)


func _sleepwalkers_inside() -> Array[Sleepwalker]:
	var walkers: Array[Sleepwalker] = []
	for body: Node2D in get_overlapping_bodies():
		var walker := body as Sleepwalker
		if walker != null:
			walkers.append(walker)
	return walkers


func _slip_direction(walker: Sleepwalker) -> Vector2:
	# The feet shoot the way the body was walking. A standing sleepwalker
	# tips away from the pile center.
	if walker.velocity.length() > 1.0:
		return walker.velocity.normalized()
	var away := walker.global_position - global_position
	if away.length() > 1.0:
		return away.normalized()
	return Vector2.RIGHT


func _draw() -> void:
	# Placeholder patch: a circle of loose beans that matches the area radius.
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		return
	draw_circle(Vector2.ZERO, circle.radius, BEAN_TINT)
	for dot: Vector2 in BEAN_DOTS:
		if dot.length() <= circle.radius:
			draw_circle(dot, BEAN_DOT_RADIUS, BEAN_DOT_TINT)
