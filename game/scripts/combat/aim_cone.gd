# ABOUTME: AimCone picks where a thrown cup lands: it snaps to the best sleepwalker
# ABOUTME: inside the wide aim cone, leads a mover to its impact-time position, or
# ABOUTME: flies straight to full range when no candidate fits.
class_name AimCone
extends RefCounted


static func landing_point(
	origin: Vector2,
	aim: Vector2,
	candidates: Array[AimCandidate],
	cone_half_angle_degrees: float,
	max_range: float,
	lead_time_seconds: float = 0.0
) -> Vector2:
	var best: AimCandidate = null
	var best_angle := cone_half_angle_degrees
	var best_distance := max_range
	for candidate: AimCandidate in candidates:
		var offset := candidate.position - origin
		var distance := offset.length()
		if distance <= 0.0 or distance > max_range:
			continue
		var angle := absf(rad_to_deg(angle_difference(aim.angle(), offset.angle())))
		if angle > best_angle:
			continue
		if angle < best_angle or distance < best_distance:
			best_angle = angle
			best_distance = distance
			best = candidate
	if best == null:
		return origin + aim.normalized() * max_range
	return _clamped_to_range(origin, best.position + best.velocity * lead_time_seconds, max_range)


static func _clamped_to_range(origin: Vector2, point: Vector2, max_range: float) -> Vector2:
	# A mover that walks past the throw range still gets no cup beyond the
	# range edge: the landing stops where a plain throw would.
	var offset := point - origin
	if offset.length() <= max_range:
		return point
	return origin + offset.limit_length(max_range)
