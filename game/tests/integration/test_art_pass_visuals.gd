# ABOUTME: Tests for the art pass pieces: street props, cafe furniture, figures, and bursts.
# ABOUTME: They pin placement rules and lifetimes, never rendered pixels.
extends GdUnitTestSuite

const BLOCK := Vector2(853.0, 720.0)
const LANE := 0.24
const NEIGHBOR_PATH := "res://resources/enemies/neighbor.tres"
const CITY_MAP_SCENE_PATH := "res://scenes/city/city_map.tscn"
const SAN_COFFESCO_PATH := "res://resources/city/san_coffesco.tres"
const CITY_BALANCE_PATH := "res://resources/balance/city.tres"
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


func test_camera_shake_clamps_and_settles_back_to_rest() -> void:
	var camera: Camera2D = auto_free(Camera2D.new())
	var shake := CameraShake.new()
	shake.name = CameraShake.NODE_NAME
	camera.add_child(shake)
	add_child(camera)
	shake.kick(0.7)
	shake.kick(0.7)
	assert_float(shake.trauma).is_equal(CameraShake.MAX_TRAUMA)
	var waited := 0.0
	while shake.trauma > 0.0 and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().process_frame
	assert_float(shake.trauma).is_equal(0.0)
	assert_that(camera.offset).is_equal(Vector2.ZERO)


func test_squash_returns_the_figure_to_rest_scale() -> void:
	var figure: Node2D = auto_free(Node2D.new())
	add_child(figure)
	Squash.play(figure)
	assert_bool(figure.scale.is_equal_approx(Vector2.ONE)).is_false()
	var waited := 0.0
	while not figure.scale.is_equal_approx(Vector2.ONE) and waited < 1.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert_bool(figure.scale.is_equal_approx(Vector2.ONE)).is_true()


func test_chibi_look_is_stable_per_name() -> void:
	var first := ChibiPainter.look_for("James Offmug")
	assert_that(ChibiPainter.look_for("James Offmug")).is_equal(first)
	assert_bool(ChibiPainter.SKIN_TONES.has(first["skin"])).is_true()
	assert_bool(ChibiPainter.HAIR_COLORS.has(first["hair"])).is_true()


func test_tower_bloom_plays_on_the_live_switch_and_never_on_a_load() -> void:
	var loaded := _build_city()
	loaded.load_tower_state(BroadcastTower.Phase.BIRDSONG)
	assert_object(loaded.get_node_or_null(^"TowerBloom")).is_null()
	var live := _build_city()
	live.broadcast_tower().switched_off.emit()
	assert_object(live.get_node_or_null(^"TowerBloom")).is_not_null()


func _build_city() -> CityMap:
	var map := (load(CITY_MAP_SCENE_PATH) as PackedScene).instantiate() as CityMap
	map.definition = load(SAN_COFFESCO_PATH) as CityDefinition
	map.balance = load(CITY_BALANCE_PATH) as CityBalance
	add_child(auto_free(map))
	return map


func test_person_figure_hides_the_body_and_follows_its_color() -> void:
	var body: Polygon2D = auto_free(Polygon2D.new())
	body.color = PersonFigure.DEFAULT_SLEEP_COLOR
	var vest := Polygon2D.new()
	body.add_child(vest)
	var figure := PersonFigure.dress(body, "x", Color.RED, ChibiPainter.Gear.VEST)
	assert_object(PersonFigure.dress(body, "x", Color.RED, ChibiPainter.Gear.VEST)).is_same(figure)
	assert_float(body.self_modulate.a).is_equal(0.0)
	assert_bool(vest.visible).is_false()
	add_child(body)
	assert_bool(figure.is_awake()).is_false()
	body.color = Color(0.45, 0.85, 0.5)
	await get_tree().process_frame
	assert_bool(figure.is_awake()).is_true()
	PersonFigure.celebrate(body)
	assert_object(body.get_node_or_null(^"WakeBurst")).is_not_null()


func test_band_member_gear_follows_the_role() -> void:
	assert_int(BandMember.gear_for("THE DRUMMER", false)).is_equal(ChibiPainter.Gear.STICKS)
	assert_int(BandMember.gear_for("THE BASSIST", false)).is_equal(ChibiPainter.Gear.BASS)
	assert_int(BandMember.gear_for("THE GUITARIST", false)).is_equal(ChibiPainter.Gear.GUITAR)
	assert_int(BandMember.gear_for("THE FRONTMAN", true)).is_equal(ChibiPainter.Gear.MIC)


func test_pitch_screen_follows_the_lit_color() -> void:
	var screen: Polygon2D = auto_free(Polygon2D.new())
	screen.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10)])
	screen.color = SamOatman.SCREEN_LIT_COLOR
	var art := PitchHallArt.attach(screen, PitchHallArt.Kind.SCREEN, SamOatman.SCREEN_LIT_COLOR)
	add_child(screen)
	assert_bool(art.is_lit()).is_true()
	screen.color = SamOatman.SCREEN_DARK_COLOR
	await get_tree().process_frame
	assert_bool(art.is_lit()).is_false()
