# ABOUTME: Tests for the art pass pieces: street props, cafe furniture, and the wake burst.
# ABOUTME: They pin placement rules and lifetimes, never rendered pixels.
extends GdUnitTestSuite

const BLOCK := Vector2(853.0, 720.0)
const LANE := 0.24
const NEIGHBOR_PATH := "res://resources/enemies/neighbor.tres"
# The cafe anchors of CityBlockView that the furniture must keep clear.
const CAFE_ANCHORS: Array[Vector2] = [
	Vector2(-0.72, -0.45), Vector2(0.65, -0.5), Vector2(-0.75, 0.68)
]
const ANCHOR_CLEARANCE := 0.2


func test_lamps_stand_on_the_sidewalk_inside_the_block() -> void:
	var lane := StreetPainter.lane_rect(BLOCK, LANE)
	var lamps := StreetPainter.lamp_positions(BLOCK, LANE)
	assert_int(lamps.size()).is_greater(1)
	for foot: Vector2 in lamps:
		assert_float(foot.x).is_between(0.0, BLOCK.x)
		assert_float(foot.y).is_less(lane.position.y)
		assert_float(foot.y).is_greater(lane.position.y - StreetPainter.SIDEWALK_DEPTH)


func test_trees_repeat_for_one_seed_and_stay_in_the_north_band() -> void:
	var first := StreetPainter.tree_positions(BLOCK, 42)
	var again := StreetPainter.tree_positions(BLOCK, 42)
	assert_int(first.size()).is_greater(1)
	assert_array(again).is_equal(first)
	for spot: Vector2 in first:
		assert_float(spot.x).is_between(0.0, BLOCK.x)
		assert_float(spot.y).is_less(StreetPainter.TREE_ROW_Y + StreetPainter.TREE_RADIUS)


func test_cafe_furniture_keeps_clear_of_the_cafe_anchors() -> void:
	var spots: Array[Vector2] = []
	spots.append_array(CafeDressing.TABLE_SPOTS)
	spots.append_array(CafeDressing.PLANT_SPOTS)
	for spot: Vector2 in spots:
		assert_float(absf(spot.x)).is_less_equal(1.0)
		assert_float(absf(spot.y)).is_less_equal(1.0)
		for anchor: Vector2 in CAFE_ANCHORS:
			assert_float(spot.distance_to(anchor)).is_greater(ANCHOR_CLEARANCE)
		# The walk from the south door stays open.
		assert_bool(absf(spot.x) < 0.2 and spot.y > 0.5).is_false()


func test_wake_burst_frees_itself_after_its_duration() -> void:
	var burst := WakeBurst.new()
	add_child(burst)
	var freed: Array[bool] = [false]
	burst.tree_exited.connect(func() -> void: freed[0] = true)
	var waited := 0.0
	while not freed[0] and waited < WakeBurst.DURATION + 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert_bool(freed[0]).is_true()


func test_waking_a_figure_pops_one_burst_and_a_restore_pops_none() -> void:
	var neighbor := load(NEIGHBOR_PATH) as EnemyType
	var visual: Polygon2D = auto_free(Polygon2D.new())
	var nightcap := Polygon2D.new()
	visual.add_child(nightcap)
	SleeperFigure.build(visual, nightcap, neighbor)
	assert_object(visual.get_node_or_null(^"CastShadow")).is_not_null()
	SleeperFigure.set_awake(visual, true, Vector2.ZERO, true)
	assert_object(visual.get_node_or_null(^"WakeBurst")).is_null()
	SleeperFigure.set_awake(visual, false, Vector2.ZERO)
	SleeperFigure.set_awake(visual, true, Vector2.ZERO)
	assert_object(visual.get_node_or_null(^"WakeBurst")).is_not_null()
