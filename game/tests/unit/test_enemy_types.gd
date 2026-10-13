# ABOUTME: Unit tests for the data-driven enemy type framework.
# ABOUTME: Pins The Neighbor, its cure link, and the neighbor scene wiring.
extends GdUnitTestSuite

const NEIGHBOR_TYPE := preload("res://resources/enemies/neighbor.tres")
const LIBRARY := preload("res://resources/brewing/brewing_library.tres")
const NEIGHBOR_SCENE := preload("res://scenes/enemies/neighbor.tscn")

const NEIGHBOR_PAJAMA_COLOR := Color(0.62, 0.72, 0.9)


func test_neighbor_type_pins() -> void:
	assert_bool(NEIGHBOR_TYPE is EnemyType).is_true()
	assert_str(NEIGHBOR_TYPE.type_id).is_equal("neighbor")
	assert_str(NEIGHBOR_TYPE.display_name).is_equal("The Neighbor")
	assert_int(NEIGHBOR_TYPE.special_behavior).is_equal(EnemyType.SpecialBehavior.SIMPLE_HUG)
	assert_bool(NEIGHBOR_TYPE.pajama_color == NEIGHBOR_PAJAMA_COLOR).is_true()


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
