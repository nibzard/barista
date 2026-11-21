# ABOUTME: Squash plays a short squash-and-stretch on a CanvasItem, for throws and hits.
# ABOUTME: Presentation only: the scale always returns to its rest value.
class_name Squash
extends RefCounted

const META_KEY := &"squash_tween"
const SECONDS := 0.16


static func play(item: Node2D, squash_scale: Vector2 = Vector2(1.18, 0.84)) -> void:
	if item == null or not item.is_inside_tree():
		return
	var previous: Variant = item.get_meta(META_KEY, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	var rest := Vector2.ONE
	item.scale = squash_scale
	var tween := item.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", rest, SECONDS)
	item.set_meta(META_KEY, tween)
