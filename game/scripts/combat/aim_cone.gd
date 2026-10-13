# ABOUTME: AimCone picks where a thrown cup lands: it snaps to the best sleepwalker
# ABOUTME: inside the wide aim cone, or flies straight to full range when none fits.
class_name AimCone
extends RefCounted


static func landing_point(
	origin: Vector2,
	aim: Vector2,
	candidates: Array[Vector2],
	cone_half_angle_degrees: float,
	max_range: float
) -> Vector2:
	var best_point := origin + aim.normalized() * max_range
	var best_angle := cone_half_angle_degrees
	var best_distance := max_range
	for candidate: Vector2 in candidates:
		var offset := candidate - origin
		var distance := offset.length()
		if distance <= 0.0 or distance > max_range:
			continue
		var angle := absf(rad_to_deg(angle_difference(aim.angle(), offset.angle())))
		if angle > best_angle:
			continue
		if angle < best_angle or distance < best_distance:
			best_angle = angle
			best_distance = distance
			best_point = candidate
	return best_point
