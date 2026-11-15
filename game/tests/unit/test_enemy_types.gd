# ABOUTME: Unit tests for the data-driven enemy type framework.
# ABOUTME: Pins each enemy type, its cure link, and its scene wiring.
extends GdUnitTestSuite

const NEIGHBOR_TYPE := preload("res://resources/enemies/neighbor.tres")
const TOURIST_TYPE := preload("res://resources/enemies/tourist.tres")
const TECH_BRO_TYPE := preload("res://resources/enemies/tech_bro.tres")
const GAMER_TYPE := preload("res://resources/enemies/gamer.tres")
const TINFOIL_MAN_TYPE := preload("res://resources/enemies/tinfoil_man.tres")
const KAREN_TYPE := preload("res://resources/enemies/karen.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")
const TOURIST_SCENE := preload("res://scenes/enemies/tourist.tscn")
const TECH_BRO_SCENE := preload("res://scenes/enemies/tech_bro.tscn")
const GAMER_SCENE := preload("res://scenes/enemies/gamer.tscn")
const TINFOIL_MAN_SCENE := preload("res://scenes/enemies/tinfoil_man.tscn")
const KAREN_SCENE := preload("res://scenes/enemies/karen.tscn")

const NEIGHBOR_PAJAMA_COLOR := Color(0.62, 0.72, 0.9)
const TOURIST_PAJAMA_COLOR := Color(0.98, 0.82, 0.4)
const TECH_BRO_PAJAMA_COLOR := Color(0.8, 0.8, 0.86)
const GAMER_PAJAMA_COLOR := Color(0.58, 0.42, 0.82)
const TINFOIL_MAN_PAJAMA_COLOR := Color(0.66, 0.74, 0.62)
const KAREN_PAJAMA_COLOR := Color(0.87, 0.55, 0.66)


func test_neighbor_type_pins() -> void:
	assert_bool(NEIGHBOR_TYPE is EnemyType).is_true()
	assert_str(NEIGHBOR_TYPE.type_id).is_equal("neighbor")
	assert_str(NEIGHBOR_TYPE.display_name).is_equal("The Neighbor")
	assert_int(NEIGHBOR_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.SIMPLE_HUG)
	assert_bool(NEIGHBOR_TYPE.pajama_color == NEIGHBOR_PAJAMA_COLOR).is_true()


func _body_width(body: Polygon2D) -> float:
	# The widest left-to-right span of the placeholder body polygon.
	var min_x := body.polygon[0].x
	var max_x := body.polygon[0].x
	for point: Vector2 in body.polygon:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
	return max_x - min_x


func test_neighbor_cure_links_to_the_brewing_data() -> void:
	var cure := NEIGHBOR_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(NEIGHBOR_TYPE.type_id)
	assert_bool(cure.is_basic).is_true()
	assert_str(cure.cure_recipe_id).is_equal("")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()


func test_every_special_behavior_has_one_required_cure() -> void:
	for cure: SleepwalkerCure in LIBRARY.cures:
		if cure.is_basic:
			continue
		assert_str(cure.cure_recipe_id).is_not_equal("")
		assert_object(LIBRARY.find_recipe(cure.cure_recipe_id)).is_not_null()


func test_neighbor_scene_wires_the_framework() -> void:
	var neighbor := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	auto_free(neighbor)
	assert_object(neighbor.enemy_type).is_not_null()
	assert_str(neighbor.enemy_type.type_id).is_equal("neighbor")
	assert_object(neighbor.library).is_not_null()
	assert_int(neighbor.library.cures.size()).is_greater(0)
	assert_object(neighbor.brewing_balance).is_not_null()
	assert_float(neighbor.brewing_balance.good_tier_min_score).is_equal(80.0)


func test_tourist_type_pins() -> void:
	assert_bool(TOURIST_TYPE is EnemyType).is_true()
	assert_str(TOURIST_TYPE.type_id).is_equal("tourist")
	assert_str(TOURIST_TYPE.display_name).is_equal("The Tourist")
	assert_int(TOURIST_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.PHOTO_FLASH)
	assert_bool(TOURIST_TYPE.pajama_color == TOURIST_PAJAMA_COLOR).is_true()


func test_tourist_cure_is_a_frappuccino_with_whipped_cream() -> void:
	var cure := TOURIST_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(TOURIST_TYPE.type_id)
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("frappuccino")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()
	var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
	assert_object(recipe).is_not_null()
	# Section 15: the Frappuccino is blender plus whipped cream.
	assert_str(recipe.extra_id).is_equal("whipped_cream")


func test_tourist_scene_wires_the_framework() -> void:
	var tourist := TOURIST_SCENE.instantiate() as Sleepwalker
	auto_free(tourist)
	assert_object(tourist.enemy_type).is_not_null()
	assert_str(tourist.enemy_type.type_id).is_equal("tourist")
	assert_object(tourist.library).is_not_null()
	assert_object(tourist.brewing_balance).is_not_null()
	assert_object(tourist.tourist_balance).is_not_null()
	assert_float(tourist.tourist_balance.flash_stun_seconds).is_greater(0.0)


func test_tech_bro_type_pins() -> void:
	assert_bool(TECH_BRO_TYPE is EnemyType).is_true()
	assert_str(TECH_BRO_TYPE.type_id).is_equal("tech_bro")
	assert_str(TECH_BRO_TYPE.display_name).is_equal("The Tech Bro")
	assert_int(TECH_BRO_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.DRONE_ATTACK)
	assert_bool(TECH_BRO_TYPE.pajama_color == TECH_BRO_PAJAMA_COLOR).is_true()


func test_tech_bro_cure_is_bulletproof_espresso_with_butter() -> void:
	var cure := TECH_BRO_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(TECH_BRO_TYPE.type_id)
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("bulletproof")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()
	var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
	assert_object(recipe).is_not_null()
	# Section 15: bulletproof is an espresso base with butter, any bean, any roast.
	assert_str(recipe.method_id).is_equal("espresso")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_str(recipe.extra_id).is_equal("butter")


func test_tech_bro_scene_wires_the_framework() -> void:
	var tech_bro := TECH_BRO_SCENE.instantiate() as Sleepwalker
	auto_free(tech_bro)
	assert_object(tech_bro.enemy_type).is_not_null()
	assert_str(tech_bro.enemy_type.type_id).is_equal("tech_bro")
	assert_object(tech_bro.library).is_not_null()
	assert_object(tech_bro.brewing_balance).is_not_null()
	assert_object(tech_bro.tech_bro_balance).is_not_null()
	assert_float(tech_bro.tech_bro_balance.pitch_interval_seconds).is_greater(0.0)
	var drone := tech_bro.get_node("Drone") as Drone
	assert_object(drone).is_not_null()
	assert_object(drone.balance).is_not_null()
	assert_float(drone.balance.orbit_radius).is_equal(tech_bro.tech_bro_balance.orbit_radius)
	# The sense circle must carry the balanced dive trigger radius.
	var sense_shape := drone.get_node("SenseShape") as CollisionShape2D
	var sense_circle := sense_shape.shape as CircleShape2D
	assert_float(sense_circle.radius).is_equal(drone.balance.dive_trigger_radius)


func test_gamer_type_pins() -> void:
	assert_bool(GAMER_TYPE is EnemyType).is_true()
	assert_str(GAMER_TYPE.type_id).is_equal("gamer")
	assert_str(GAMER_TYPE.display_name).is_equal("The Gamer")
	assert_int(GAMER_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.DASH_CHARGE)
	assert_bool(GAMER_TYPE.pajama_color == GAMER_PAJAMA_COLOR).is_true()


func test_gamer_cure_is_a_triple_aeropress_shot() -> void:
	var cure := GAMER_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(GAMER_TYPE.type_id)
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("triple_shot")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()
	var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
	assert_object(recipe).is_not_null()
	# Section 15: the triple shot is any bean, light roast, Aeropress, three
	# shots. Light keeps the most caffeine for the highest synthetic level.
	assert_str(recipe.method_id).is_equal("aeropress")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.LIGHT)
	assert_str(recipe.extra_id).is_equal("three_shots")


func test_gamer_scene_wires_the_framework() -> void:
	var gamer := GAMER_SCENE.instantiate() as Sleepwalker
	auto_free(gamer)
	assert_object(gamer.enemy_type).is_not_null()
	assert_str(gamer.enemy_type.type_id).is_equal("gamer")
	assert_object(gamer.library).is_not_null()
	assert_object(gamer.brewing_balance).is_not_null()
	assert_object(gamer.gamer_balance).is_not_null()
	# The dash must outrun the player's 220 walk and the 70 steady chase.
	assert_float(gamer.gamer_balance.dash_speed).is_greater(220.0)
	assert_float(gamer.gamer_balance.dash_duration_seconds).is_less(1.0)
	# The sense and hug circles match the other special types.
	var sense_shape := gamer.get_node("SenseArea/SenseShape") as CollisionShape2D
	var sense_circle := sense_shape.shape as CircleShape2D
	assert_float(sense_circle.radius).is_equal(150.0)
	var hug_shape := gamer.get_node("HugArea/HugShape") as CollisionShape2D
	var hug_circle := hug_shape.shape as CircleShape2D
	assert_float(hug_circle.radius).is_equal(18.0)


func test_tinfoil_man_type_pins() -> void:
	assert_bool(TINFOIL_MAN_TYPE is EnemyType).is_true()
	assert_str(TINFOIL_MAN_TYPE.type_id).is_equal("tinfoil_man")
	assert_str(TINFOIL_MAN_TYPE.display_name).is_equal("The Tinfoil Man")
	assert_int(TINFOIL_MAN_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.TINFOIL_HAT)
	assert_bool(TINFOIL_MAN_TYPE.pajama_color == TINFOIL_MAN_PAJAMA_COLOR).is_true()


func test_tinfoil_man_cure_is_turkish_coffee() -> void:
	var cure := TINFOIL_MAN_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(TINFOIL_MAN_TYPE.type_id)
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("turkish_cup")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()
	var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
	assert_object(recipe).is_not_null()
	# Section 15: the Turkish cure is any bean, a medium roast, the Turkish pot.
	assert_str(recipe.method_id).is_equal("turkish")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.bean_match).is_equal(Recipe.Match.ANY)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.MEDIUM)


func test_tinfoil_man_scene_wires_the_framework() -> void:
	var tinfoil_man := TINFOIL_MAN_SCENE.instantiate() as Sleepwalker
	auto_free(tinfoil_man)
	assert_object(tinfoil_man.enemy_type).is_not_null()
	assert_str(tinfoil_man.enemy_type.type_id).is_equal("tinfoil_man")
	assert_object(tinfoil_man.library).is_not_null()
	assert_object(tinfoil_man.brewing_balance).is_not_null()
	# The hat is his only special part: the sense and hug circles and the
	# plain-hug engage match the shared sleepwalker shape.
	assert_bool(tinfoil_man.hat_stops_thrown_coffee()).is_true()
	var sense_shape := tinfoil_man.get_node("SenseArea/SenseShape") as CollisionShape2D
	var sense_circle := sense_shape.shape as CircleShape2D
	assert_float(sense_circle.radius).is_equal(150.0)
	var hug_shape := tinfoil_man.get_node("HugArea/HugShape") as CollisionShape2D
	var hug_circle := hug_shape.shape as CircleShape2D
	assert_float(hug_circle.radius).is_equal(18.0)


func test_karen_type_pins() -> void:
	assert_bool(KAREN_TYPE is EnemyType).is_true()
	assert_str(KAREN_TYPE.type_id).is_equal("karen")
	assert_str(KAREN_TYPE.display_name).is_equal("The Karen")
	assert_int(KAREN_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.KAREN_SURPRISE)
	assert_bool(KAREN_TYPE.pajama_color == KAREN_PAJAMA_COLOR).is_true()


func test_karen_cure_is_a_super_tall_american() -> void:
	var cure := KAREN_TYPE.cure
	assert_object(cure).is_not_null()
	assert_str(cure.sleeper_type_id).is_equal(KAREN_TYPE.type_id)
	assert_bool(cure.is_basic).is_false()
	assert_str(cure.cure_recipe_id).is_equal("super_tall_american")
	assert_object(LIBRARY.find_cure(cure.sleeper_type_id)).is_not_null()
	var recipe := LIBRARY.find_recipe(cure.cure_recipe_id)
	assert_object(recipe).is_not_null()
	# Section 15: house beans or better, a medium roast, filter, tall size.
	assert_str(recipe.method_id).is_equal("filter")
	assert_int(recipe.method_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.bean_match).is_equal(Recipe.Match.QUALITY_MIN)
	assert_int(recipe.min_bean_quality).is_equal(BeanType.Quality.BASIC)
	assert_int(recipe.roast_match).is_equal(Recipe.Match.EXACT)
	assert_int(recipe.roast).is_equal(RoastProfile.Kind.MEDIUM)
	assert_str(recipe.extra_id).is_equal("tall_size")


func test_karen_scene_wires_the_framework() -> void:
	var karen := KAREN_SCENE.instantiate() as Sleepwalker
	auto_free(karen)
	assert_object(karen.enemy_type).is_not_null()
	assert_str(karen.enemy_type.type_id).is_equal("karen")
	assert_object(karen.library).is_not_null()
	assert_object(karen.brewing_balance).is_not_null()
	assert_object(karen.karen_balance).is_not_null()
	# Section 6: she looks slow but moves very fast. The lull stays far under
	# the neighbor walk of 40, and the sprint outruns the player walk of 220.
	assert_float(karen.karen_balance.lull_speed).is_less(40.0)
	assert_float(karen.karen_balance.sprint_speed).is_greater(220.0)
	# The sense and hug circles match the other special types.
	var sense_shape := karen.get_node("SenseArea/SenseShape") as CollisionShape2D
	var sense_circle := sense_shape.shape as CircleShape2D
	assert_float(sense_circle.radius).is_equal(150.0)
	var hug_shape := karen.get_node("HugArea/HugShape") as CollisionShape2D
	var hug_circle := hug_shape.shape as CircleShape2D
	assert_float(hug_circle.radius).is_equal(18.0)
	# She is very fat: her placeholder body reads wider than the neighbor's.
	var karen_body := karen.get_node("Visual") as Polygon2D
	var neighbor := NEIGHBOR_SCENE.instantiate() as Sleepwalker
	auto_free(neighbor)
	var neighbor_body := neighbor.get_node("Visual") as Polygon2D
	var karen_width := _body_width(karen_body)
	var neighbor_width := _body_width(neighbor_body)
	assert_float(karen_width).is_greater(neighbor_width)
