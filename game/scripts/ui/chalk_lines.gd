# ABOUTME: ChalkLines computes dashed strokes and curve points for the chalk interface.
# ABOUTME: Pure geometry with no nodes, so tests run without a scene tree.
class_name ChalkLines
extends RefCounted

# A dashed chalk line breaks into short marks with gaps, like the empty cup
# slots of the interface kit. The helpers return plain point data: the caller
# draws each piece with its own draw call.
const DEFAULT_DASH := 2.2
const DEFAULT_GAP := 1.8


static func dash_segments(
	points: PackedVector2Array, dash := DEFAULT_DASH, gap := DEFAULT_GAP
) -> PackedVector2Array:
	# The pieces of a dashed polyline through the points, in pairs: the piece
	# at index i runs from result[i * 2] to result[i * 2 + 1]. The pen starts
	# on a mark, and every mark and gap keeps its full length across corners.
	if points.size() < 2:
		return PackedVector2Array()
	var segments := PackedVector2Array()
	var pen_on := true
	var budget := dash
	var from := points[0]
	for i: int in range(1, points.size()):
		var to := points[i]
		var edge := to - from
		var length := edge.length()
		if length > 0.0001:
			var direction := edge / length
			var walked := 0.0
			while walked < length - 0.0001:
				var room := minf(budget, length - walked)
				if pen_on:
					segments.append(from + direction * walked)
					segments.append(from + direction * (walked + room))
				walked += room
				budget -= room
				if budget <= 0.0001:
					pen_on = not pen_on
					budget = dash if pen_on else gap
		from = to
	return segments


static func arc_points(
	center: Vector2, radius: float, start: float, end: float, steps := 16
) -> PackedVector2Array:
	# Points along an arc, for a chalk curve a caller fills in or dashes.
	var points := PackedVector2Array()
	for step: int in range(steps + 1):
		var angle := lerpf(start, end, float(step) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func curve_points(
	from: Vector2, control: Vector2, to: Vector2, steps := 10
) -> PackedVector2Array:
	# Points along one quadratic curve, for chalk curls like steam and leaves.
	var points := PackedVector2Array()
	for step: int in range(steps + 1):
		var weight := float(step) / float(steps)
		var opposite := 1.0 - weight
		points.append(
			from * opposite * opposite + control * 2.0 * opposite * weight + to * weight * weight
		)
	return points
