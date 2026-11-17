# ABOUTME: CoffeePlant is the plantable bait: plant a seedling, the crowd eats.
# ABOUTME: The plant has caffeine, but raw caffeine wakes nobody, section 6.
class_name CoffeePlant
extends ForageFood

# Placeholder bush look until the art pass: leaves with red coffee cherries.
const LEAF_TINT := Color(0.22, 0.5, 0.25, 0.95)
const LEAF_RADIUS := 16.0
const CHERRY_TINT := Color(0.75, 0.12, 0.18, 1.0)
const CHERRY_RADIUS := 3.0
# A fixed scatter of cherries, so the bush draws the same every frame.
const CHERRY_SPOTS: Array[Vector2] = [
	Vector2(-8, -6),
	Vector2(6, -10),
	Vector2(10, 4),
	Vector2(-3, 8),
	Vector2(-11, 2),
	Vector2(2, -1),
]


func _ready() -> void:
	super()
	queue_redraw()


func _draw() -> void:
	# Placeholder bush: a green circle with red cherries, skipped once the
	# plant is eaten.
	if is_consumed():
		return
	draw_circle(Vector2.ZERO, LEAF_RADIUS, LEAF_TINT)
	for spot: Vector2 in CHERRY_SPOTS:
		draw_circle(spot, CHERRY_RADIUS, CHERRY_TINT)
