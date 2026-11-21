# ABOUTME: WakeBurst is the short pop of light when coffee wakes a sleepwalker.
# ABOUTME: Presentation only: it draws a ring and sparks for a fixed time, then frees itself.
class_name WakeBurst
extends Node2D

const DURATION := 0.55
const RING_START := 10.0
const RING_END := 46.0
const SPARK_COUNT := 9
const SPARK_DISTANCE := 54.0
const BUTTER := Color("#F2C866")
const CHALK := Color("#F4F0E6")

var _age := 0.0


func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	queue_redraw()


func progress() -> float:
	return clampf(_age / DURATION, 0.0, 1.0)


func _draw() -> void:
	var t := progress()
	var ease_out := 1.0 - pow(1.0 - t, 3.0)
	var fade := 1.0 - t
	draw_circle(
		Vector2.ZERO, lerpf(RING_START, RING_END, ease_out) * 0.8, Color(BUTTER, 0.18 * fade)
	)
	draw_arc(
		Vector2.ZERO,
		lerpf(RING_START, RING_END, ease_out),
		0.0,
		TAU,
		32,
		Color(BUTTER, 0.9 * fade),
		4.0 * fade + 1.0,
		true
	)
	for i: int in range(SPARK_COUNT):
		var direction := Vector2.from_angle(TAU * float(i) / float(SPARK_COUNT) + 0.3)
		var tip := direction * SPARK_DISTANCE * ease_out
		var tail := direction * SPARK_DISTANCE * maxf(ease_out - 0.25, 0.0)
		draw_line(tail, tip, Color(CHALK if i % 2 == 0 else BUTTER, fade), 3.0, true)
	# A chalk star pops over the head: the eyes open, section 7.
	var star_center := Vector2(0.0, -40.0 - 10.0 * ease_out)
	var star := PackedVector2Array()
	for i: int in range(10):
		var r := (10.0 if i % 2 == 0 else 4.0) * (0.6 + 0.6 * ease_out)
		star.append(star_center + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * r)
	draw_colored_polygon(star, Color(BUTTER, fade))
