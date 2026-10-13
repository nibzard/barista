# ABOUTME: ScavengePoint is a one-time loot spot: walk over it and the loot enters the bag.
# ABOUTME: Buildings place these points; section 15 gear and materials come from them.
class_name ScavengePoint
extends Area2D

signal looted

# Placeholder crate colors until the art pass brings real scavenge props.
const CRATE_FILL := Color(0.55, 0.4, 0.25, 0.9)
const CRATE_EDGE := Color(0.3, 0.2, 0.12, 1.0)
const CRATE_HALF_SIZE := 14.0

@export var drops: Array[ScavengeDrop] = []

var _remaining: Dictionary = {}
var _depleted := false


func _ready() -> void:
	# Copy the authored drops into runtime stock: drop resources are shared
	# data, so the point never mutates them.
	for drop: ScavengeDrop in drops:
		if drop.item == null or drop.amount <= 0:
			continue
		_remaining[drop.item] = int(_remaining.get(drop.item, 0)) + drop.amount
	queue_redraw()


func _physics_process(_delta: float) -> void:
	# Poll the overlap every physics frame, like the sleep zones do: signal
	# delivery order between siblings is not guaranteed.
	if _depleted:
		return
	var player := _player_inside()
	if player != null:
		_give_loot(player)


func is_depleted() -> bool:
	return _depleted


func remaining_amount(item: ItemType) -> int:
	return int(_remaining.get(item, 0))


func _player_inside() -> Player:
	for body: Node2D in get_overlapping_bodies():
		if body is Player:
			return body
	return null


func _give_loot(player: Player) -> void:
	# Each unit that fits moves into the bag; loot that does not fit stays in
	# the point for a later visit. The point ends when its stock runs out.
	var stock: Array = _remaining.keys()
	var gave_something := false
	for item: ItemType in stock:
		var amount: int = _remaining[item]
		var added: int = player.pickup_item(item, amount)
		if added <= 0:
			continue
		gave_something = true
		var left := amount - added
		if left <= 0:
			_remaining.erase(item)
		else:
			_remaining[item] = left
	if gave_something and _remaining.is_empty():
		_depleted = true
		visible = false
		looted.emit()


func _draw() -> void:
	# Placeholder crate marker, skipped once the point stands empty.
	if _depleted:
		return
	var rect := Rect2(
		-CRATE_HALF_SIZE, -CRATE_HALF_SIZE, CRATE_HALF_SIZE * 2.0, CRATE_HALF_SIZE * 2.0
	)
	draw_rect(rect, CRATE_FILL)
	draw_rect(rect, CRATE_EDGE, false, 2.0)
