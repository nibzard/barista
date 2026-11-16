# ABOUTME: ColorFill drives the wake front: its owner goes from pencil sketch to full color.
# ABOUTME: It writes fill, fill_origin, and fill_radius into the hand_drawn material of its parent.
class_name ColorFill
extends Node

signal filled

@export var duration := 1.2
# World-space distance that the front must travel to color the whole owner.
@export var radius := 300.0
# A sanctuary, like the cafe, starts and stays in full color.
@export var start_filled := false

var _progress := 0.0
var _running := false
var _origin := Vector2.ZERO


func _ready() -> void:
	_progress = 1.0 if start_filled else 0.0
	_apply()


func _process(delta: float) -> void:
	advance(delta)


func start(origin: Vector2) -> void:
	if is_filled():
		return
	_origin = origin
	_running = true
	_apply()


func advance(delta: float) -> void:
	if not _running:
		return
	if duration <= 0.0:
		_progress = 1.0
	else:
		_progress = minf(1.0, _progress + delta / duration)
	_apply()
	if _progress >= 1.0:
		_running = false
		filled.emit()


func fill_now() -> void:
	_progress = 1.0
	_running = false
	_apply()


func reset() -> void:
	_progress = 0.0
	_running = false
	_apply()


func progress() -> float:
	return _progress


func is_filled() -> bool:
	return _progress >= 1.0


func is_running() -> bool:
	return _running


func _apply() -> void:
	var owner_item := get_parent() as CanvasItem
	if owner_item == null:
		return
	var material := owner_item.material as ShaderMaterial
	if material == null:
		return
	# Ease out: the color rushes in at the hit, then settles at the edges.
	var eased := 1.0 - pow(1.0 - _progress, 2.0)
	material.set_shader_parameter("fill", eased)
	material.set_shader_parameter("fill_origin", _origin)
	material.set_shader_parameter("fill_radius", radius)
