# ABOUTME: Integration tests of the live art direction pass, T045.
# ABOUTME: The cast figures build on the real scenes, and the city look stage
# ABOUTME: wires dusk, weather, haze, and the morning into live play.
extends GdUnitTestSuite

const CITY_MAP_SCENE := preload("res://scenes/city/city_map.tscn")
const BALANCE := preload("res://resources/balance/city.tres")
const SAN_COFFESCO := preload("res://resources/city/san_coffesco.tres")

const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TOURIST_SCENE := preload("res://scenes/enemies/tourist.tscn")
const TECH_BRO_SCENE := preload("res://scenes/enemies/tech_bro.tscn")
const GAMER_SCENE := preload("res://scenes/enemies/gamer.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const KAREN_SCENE := preload("res://scenes/enemies/karen.tscn")
const MOONWALKER_SCENE := preload("res://scenes/enemies/moonwalker.tscn")

# The hat types carry their own top shape, so the nightcap node draws nothing.
const HAT_TYPES: Array[String] = ["tourist", "tinfoil_man", "karen"]


func test_every_enemy_scene_builds_its_cast_figure() -> void:
	var scenes := [
		NEIGHBOR_SCENE,
		TOURIST_SCENE,
		TECH_BRO_SCENE,
		GAMER_SCENE,
		TINFOIL_MAN_SCENE,
		KAREN_SCENE,
		MOONWALKER_SCENE
	]
	for scene: PackedScene in scenes:
		var walker := scene.instantiate() as Sleepwalker
		add_child(auto_free(walker))
		await get_tree().physics_frame
		var type_id := walker.enemy_type.type_id
		var visual := walker.get_node(^"Visual") as Polygon2D
		(
			assert_object(visual.get_node_or_null(^"Head"))
			. override_failure_message(type_id)
			. is_not_null()
		)
		(
			assert_object(visual.get_node_or_null(^"DroolArc"))
			. override_failure_message(type_id)
			. is_not_null()
		)
		var cap := visual.get_node_or_null(^"Nightcap") as Polygon2D
		if HAT_TYPES.has(type_id):
			assert_int(cap.polygon.size()).override_failure_message(type_id).is_equal(0)
		else:
			assert_int(cap.polygon.size()).override_failure_message(type_id).is_greater(0)


func test_the_karen_reads_wider_than_the_neighbor_in_play() -> void:
	var karen := KAREN_SCENE.instantiate() as Sleepwalker
	add_child(auto_free(karen))
	var neighbor := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	add_child(auto_free(neighbor))
	await get_tree().physics_frame
	assert_float(_width(karen)).is_greater(_width(neighbor))


func test_the_city_wires_its_look_into_live_play() -> void:
	var map := _build_city()
	var stage := map.look_stage()
	assert_object(stage).is_not_null()
	assert_int(stage.weather_kind()).is_equal(CityLook.Weather.CLEAR_FOG)
	assert_bool(stage.dusk_color().is_equal_approx(SAN_COFFESCO.city_look.dusk_light)).is_true()
	for i: int in range(map.block_count()):
		assert_object(map.block_view(i).city_look).is_equal(SAN_COFFESCO.city_look)
	# The speaker pole zones run the live sleep haze at full strength.
	var poles := 0
	for i: int in range(map.block_count()):
		var pole := map.block_view(i).pole_zone()
		if pole == null:
			continue
		poles += 1
		assert_float(pole.haze_strength()).is_equal(1.0)
	assert_int(poles).is_greater(0)


func test_a_loaded_off_tower_stands_in_the_morning() -> void:
	var map := _build_city()
	map.load_tower_state(BroadcastTower.Phase.BIRDSONG)
	var stage := map.look_stage()
	assert_bool(stage.is_morning()).is_true()
	assert_bool(stage.dusk_color().is_equal_approx(SAN_COFFESCO.city_look.morning_light)).is_true()
	for i: int in range(map.block_count()):
		var pole := map.block_view(i).pole_zone()
		if pole != null:
			assert_bool(pole.is_broadcast_silenced()).is_true()


func _build_city() -> CityMap:
	var map := CITY_MAP_SCENE.instantiate() as CityMap
	map.definition = SAN_COFFESCO
	map.balance = BALANCE
	add_child(auto_free(map))
	return map


func _width(walker: Sleepwalker) -> float:
	var visual := walker.get_node(^"Visual") as Polygon2D
	var min_x := visual.polygon[0].x
	var max_x := visual.polygon[0].x
	for point: Vector2 in visual.polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	return max_x - min_x


func test_the_wake_colors_the_figure_in_from_the_hit() -> void:
	# ART_DIRECTION section 1: the woken sleeper gets color back from the cup
	# hit outwards, the eyes pop open, and the drool arc goes.
	var walker := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	add_child(auto_free(walker))
	await get_tree().physics_frame
	var visual := walker.get_node(^"Visual") as Polygon2D
	var fill := visual.get_node(^"WakeFill") as ColorFill
	assert_bool(fill.is_filled()).is_false()
	assert_bool((visual.get_node(^"DroolArc") as CanvasItem).visible).is_true()
	walker.wake_up()
	assert_bool((visual.get_node(^"DroolArc") as CanvasItem).visible).is_false()
	assert_bool((visual.get_node(^"DroolShine") as CanvasItem).visible).is_false()
	assert_bool((visual.get_node(^"EyeOpenL") as CanvasItem).visible).is_true()
	assert_bool((visual.get_node(^"EyeOpenR") as CanvasItem).visible).is_true()
	assert_bool(fill.is_running()).is_true()
	# The front crosses the whole figure well inside the fill duration plus a
	# guard margin, so the expiry frame can never fail the case.
	for _frame: int in range(80):
		await get_tree().physics_frame
	assert_bool(fill.is_filled()).is_true()


func test_chalk_theme_loads_the_approved_open_license_fonts() -> void:
	# T115 / ART_DIRECTION section 11: Patrick Hand display chalk face and
	# Nunito warm rounded body sans are bundled under SIL OFL 1.1.
	assert_object(ChalkTheme.display_font()).is_not_null()
	assert_object(ChalkTheme.body_font()).is_not_null()
	var built := ChalkTheme.build()
	assert_object(built.default_font).is_not_null()
	assert_object(built.get_font("font", "HeaderLarge")).is_not_null()
