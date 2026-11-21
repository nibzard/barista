# ABOUTME: CameraShake shakes its parent Camera2D through the offset, so it never fights the follow.
# ABOUTME: Any node kicks it with CameraShake.kick_in(viewport, strength); the shake decays to zero.
class_name CameraShake
extends Node

const NODE_NAME := "CameraShake"
const DECAY_PER_SECOND := 3.2
const MAX_TRAUMA := 1.0
# The largest offset in pixels at full trauma. The shake reads as a bump on a
# phone screen, not as an earthquake.
const MAX_OFFSET := 14.0
const SHAKE_SPEED := 38.0

var trauma := 0.0

var _time := 0.0


static func kick_in(viewport: Viewport, strength: float) -> void:
	# Find the shake on the active camera of the viewport. A scene without a
	# camera or without a shake ignores the kick.
	if viewport == null:
		return
	var camera := viewport.get_camera_2d()
	if camera == null:
		return
	var shake := camera.get_node_or_null(NodePath(NODE_NAME)) as CameraShake
	if shake != null:
		shake.kick(strength)


func kick(strength: float) -> void:
	trauma = clampf(trauma + strength, 0.0, MAX_TRAUMA)


func current_offset() -> Vector2:
	# Squared trauma: small kicks stay gentle, big ones bite.
	var amount := trauma * trauma * MAX_OFFSET
	return Vector2(sin(_time * SHAKE_SPEED), cos(_time * SHAKE_SPEED * 1.3)) * amount


func _process(delta: float) -> void:
	_time += delta
	trauma = maxf(trauma - DECAY_PER_SECOND * delta, 0.0)
	var camera := get_parent() as Camera2D
	if camera != null:
		camera.offset = current_offset()
