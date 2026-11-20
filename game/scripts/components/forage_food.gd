# ABOUTME: ForageFood is the shared base of everything a sleepwalker eats.
# ABOUTME: Section 6: they eat everything they find, also coffee plants.
class_name ForageFood
extends Area2D

signal eaten

@export var balance: ForageBalance

var _consumed := false


func _ready() -> void:
	# The smell radius comes from the balance data, so the shape stays a
	# placeholder circle, like the Bean Slick shape does.
	var shape_node := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if shape_node != null:
		var circle := shape_node.shape as CircleShape2D
		if circle != null:
			circle = circle.duplicate() as CircleShape2D
			circle.radius = balance.smell_radius
			shape_node.shape = circle


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the other area components:
	# sibling signal order is not guaranteed. A sleepwalker that refuses the
	# food gets the offer again on the next frame, so a stagger ends in a
	# meal and not in a lost plate.
	if _consumed:
		return
	for body: Node2D in get_overlapping_bodies():
		var walker := body as Sleepwalker
		if walker == null:
			continue
		if not LineOfSight.is_clear(global_position, walker.global_position, get_world_2d()):
			continue
		walker.notice_food(self)


func is_consumed() -> bool:
	return _consumed


func consume() -> void:
	# One meal ends the food: the first sleepwalker that finishes eating
	# devours it, and every other eater loses the plate. The eaters learn
	# that on their next frame, when the food is gone from the tree.
	if _consumed:
		return
	_consumed = true
	eaten.emit()
	visible = false
	queue_free()
