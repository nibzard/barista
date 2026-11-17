# ABOUTME: Smoke asserts that a built city run keeps its whole world kit.
# ABOUTME: Guards the T102 defect: a compile-order resource cycle once built
# ABOUTME: the city with no cafe safe zone, no CafeSpawn marker, and no poles.
extends GdUnitTestSuite

# The pin of T102: this preload is the first compile-time dependency of the
# suite, so the tutorial graph compiles before the city scripts, the launch
# order that once poisoned the shared zone scene. It stays unused at runtime;
# loading it is the whole point.
const ORDER_PROBE_SCRIPT := preload("res://scripts/tutorial/tutorial_director.gd")

const INTRO_SCENE_PATH := "res://scenes/city/san_coffesco_intro.tscn"
# San Coffesco authors three speaker pole blocks; the tutorial pole spawns at
# its own step and never counts here.
const EXPECTED_POLE_ZONES := 3


func test_a_built_city_run_keeps_its_whole_world_kit() -> void:
	# The intro scene loads at use time, never as a const preload: a const
	# here would pin the city-first order and unpin the probe above.
	var run := (load(INTRO_SCENE_PATH) as PackedScene).instantiate() as CityRun
	assert_object(run).is_not_null()
	add_child(auto_free(run))
	# The run builds its bodies inside _ready, so the markers and zones sit
	# in the tree from the second physics step onward.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var map := run.city_map()
	assert_object(map).is_not_null()
	var cafe_block := map.find_block_of_kind(CityBlock.Kind.CAFE)
	assert_object(cafe_block).is_not_null()

	# The cafe safe zone: the meter shelter and the free-refill zone.
	var safe_zone := cafe_block.safe_zone()
	assert_object(safe_zone).is_not_null()
	assert_int(safe_zone.kind).is_equal(SleepZone.Kind.SAFE)

	# The CafeSpawn marker: the player start and the wake-up return point.
	var spawn := cafe_block.cafe_spawn()
	assert_object(spawn).is_not_null()
	assert_vector(run.player.global_position).is_equal(spawn.global_position)

	# The three speaker pole zones: the address reaches every block.
	var pole_count := 0
	for i: int in range(map.block_count()):
		var pole := map.block_view(i).pole_zone()
		if pole != null:
			pole_count += 1
			assert_int(pole.kind).is_equal(SleepZone.Kind.SLEEP)
	assert_int(pole_count).is_equal(EXPECTED_POLE_ZONES)


func test_the_intro_run_builds_its_tutorial_director() -> void:
	# The director scene loads lazily inside the run (T102), so the tutorial
	# child must still land in the tree from that use-time load.
	var run := (load(INTRO_SCENE_PATH) as PackedScene).instantiate() as CityRun
	add_child(auto_free(run))
	await get_tree().physics_frame
	await get_tree().physics_frame

	assert_object(run.get_node_or_null(^"Tutorial")).is_not_null()
