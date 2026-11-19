# ABOUTME: The one-centimeter readability rule of GAME_DESIGN section 20, as a test.
# ABOUTME: Every sleepwalker type must read as its own solid silhouette.
extends GdUnitTestSuite

const WORLD_PALETTE := preload("res://resources/art/world_palette.tres")
const NEIGHBOR := preload("res://resources/enemies/neighbor.tres")
const TOURIST := preload("res://resources/enemies/tourist.tres")
const TECH_BRO := preload("res://resources/enemies/tech_bro.tres")
const GAMER := preload("res://resources/enemies/gamer.tres")
const TINFOIL_MAN := preload("res://resources/enemies/tinfoil_man.tres")
const KAREN := preload("res://resources/enemies/karen.tres")
const MOONWALKER := preload("res://resources/enemies/moonwalker.tres")

# One centimeter on a phone screen holds about one figure of the cast. The
# grid models that read: every figure scales into the same small cell raster,
# like the eye sees it at arm's length.
const GRID := 24
const GRID_MARGIN := 1.0
# A type must stay visible as more than a fleck, and two types must differ
# in enough cells that no pair melts together at that size.
const MIN_COVERED_CELLS := 60
const MIN_PAIR_CELL_DIFFERENCE := 6
# Section 20 proportions: about 3.5 heads tall, oversized hands. The band
# holds the body alone, hats and caps aside.
const MIN_HEADS_TALL := 3.0
const MAX_HEADS_TALL := 4.2
const MIN_HAND_TO_HEAD_RATIO := 0.5


func _types() -> Array[EnemyType]:
	return [NEIGHBOR, TOURIST, TECH_BRO, GAMER, TINFOIL_MAN, KAREN, MOONWALKER]


func test_every_type_covers_a_visible_silhouette() -> void:
	for type: EnemyType in _types():
		var covered := _covered_cells(type)
		assert_int(covered).override_failure_message(type.type_id).is_greater(MIN_COVERED_CELLS)


func test_every_pair_of_types_reads_apart() -> void:
	var types := _types()
	for a: int in types.size():
		for b: int in range(a + 1, types.size()):
			var difference := _cell_difference(types[a], types[b])
			(
				assert_int(difference)
				. override_failure_message("%s vs %s" % [types[a].type_id, types[b].type_id])
				. is_greater_equal(MIN_PAIR_CELL_DIFFERENCE)
			)


func test_the_cast_keeps_the_three_and_a_half_head_proportions() -> void:
	for type: EnemyType in _types():
		var heads := _heads_tall(type)
		assert_float(heads).override_failure_message(type.type_id).is_greater_equal(MIN_HEADS_TALL)
		assert_float(heads).override_failure_message(type.type_id).is_less_equal(MAX_HEADS_TALL)


func test_every_hand_is_oversized_against_the_head() -> void:
	# Hands made to hold cups: the hand span reads at least half the head.
	for type: EnemyType in _types():
		var ratio := _hand_to_head_ratio(type)
		assert_float(ratio).override_failure_message(type.type_id).is_greater_equal(
			MIN_HAND_TO_HEAD_RATIO
		)


func test_every_sleeper_carries_the_drool_shine_arc() -> void:
	# Section 20: the comic drool shine arc belongs to every sleepwalker.
	for type: EnemyType in _types():
		var names := _part_names(type)
		assert_bool(names.has("DroolArc")).override_failure_message(type.type_id).is_true()
		assert_bool(names.has("DroolShine")).override_failure_message(type.type_id).is_true()


func _part_names(type: EnemyType) -> Array[String]:
	var names: Array[String] = []
	for part: SleeperFigure.Part in SleeperFigure.parts_for(type, WORLD_PALETTE):
		names.append(part.part_name)
	return names


func _covered_cells(type: EnemyType) -> int:
	return _grid(type).count(1)


func _cell_difference(first: EnemyType, second: EnemyType) -> int:
	var a := _grid(first)
	var b := _grid(second)
	var difference := 0
	for i: int in a.size():
		if a[i] != b[i]:
			difference += 1
	return difference


func _grid(type: EnemyType) -> PackedInt32Array:
	# Rasterize the solid silhouette into the small cell grid.
	var shapes := SleeperFigure.silhouette_parts(type)
	var bounds := _shapes_bounds(shapes)
	var cells := PackedInt32Array()
	cells.resize(GRID * GRID)
	var usable := float(GRID) - GRID_MARGIN * 2.0
	var scale := minf(usable / maxf(bounds.size.x, 1.0), usable / maxf(bounds.size.y, 1.0))
	for y: int in GRID:
		for x: int in GRID:
			var point := Vector2(
				(float(x) + 0.5 - GRID * 0.5) / scale + bounds.get_center().x,
				(float(y) + 0.5 - GRID * 0.5) / scale + bounds.get_center().y
			)
			for shape: PackedVector2Array in shapes:
				if _contains(shape, point):
					cells[y * GRID + x] = 1
					break
	return cells


func _shapes_bounds(shapes: Array[PackedVector2Array]) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	var started := false
	for shape: PackedVector2Array in shapes:
		for point: Vector2 in shape:
			if not started:
				bounds = Rect2(point, Vector2.ZERO)
				started = true
				continue
			bounds = bounds.expand(point)
	return bounds


func _heads_tall(type: EnemyType) -> float:
	# The body height in heads: feet to the top of the head part alone.
	var head := _part_polygon(type, "Head")
	var shapes := SleeperFigure.silhouette_parts(type)
	var bounds := _shapes_bounds(shapes)
	var head_bounds := _polygon_bounds(head)
	var body_height := bounds.end.y - head_bounds.position.y
	return body_height / head_bounds.size.y


func _hand_to_head_ratio(type: EnemyType) -> float:
	var head_bounds := _polygon_bounds(_part_polygon(type, "Head"))
	var widest_hand := 0.0
	for part: SleeperFigure.Part in SleeperFigure.parts_for(type, WORLD_PALETTE):
		if not part.part_name.begins_with("Hand") and part.part_name != "Glove":
			continue
		var width := _polygon_bounds(part.polygon).size.x
		widest_hand = maxf(widest_hand, width)
	return widest_hand / head_bounds.size.x


func _part_polygon(type: EnemyType, part_name: String) -> PackedVector2Array:
	for part: SleeperFigure.Part in SleeperFigure.parts_for(type, WORLD_PALETTE):
		if part.part_name == part_name:
			return part.polygon
	return PackedVector2Array()


func _polygon_bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(Vector2.ZERO, Vector2.ZERO)
	var started := false
	for point: Vector2 in polygon:
		if not started:
			bounds = Rect2(point, Vector2.ZERO)
			started = true
			continue
		bounds = bounds.expand(point)
	return bounds


func _contains(polygon: PackedVector2Array, point: Vector2) -> bool:
	# Even-odd ray casting against one closed polygon.
	var inside := false
	var j := polygon.size() - 1
	for i: int in polygon.size():
		var a := polygon[i]
		var b := polygon[j]
		if (a.y > point.y) != (b.y > point.y):
			var cross := (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x
			if point.x < cross:
				inside = not inside
		j = i
	return inside
