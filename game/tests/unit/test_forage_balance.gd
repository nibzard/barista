# ABOUTME: Unit tests for the forage balance data and its scene wiring.
# ABOUTME: Pins the section 6 rule values in forage.tres, section by section.
extends GdUnitTestSuite

const FORAGE_BALANCE := preload("res://resources/balance/forage.tres")

const ENEMY_SCENES: Array[String] = [
	"res://scenes/enemies/neighbor.tscn",
	"res://scenes/enemies/tourist.tscn",
	"res://scenes/enemies/tech_bro.tscn",
	"res://scenes/enemies/gamer.tscn",
	"res://scenes/enemies/tinfoil_man.tscn",
	"res://scenes/enemies/karen.tscn",
]


func test_forage_balance_values() -> void:
	assert_bool(FORAGE_BALANCE is ForageBalance).is_true()
	assert_bool(FORAGE_BALANCE.foraging_enabled).is_true()
	assert_float(FORAGE_BALANCE.smell_radius).is_equal(140.0)
	assert_float(FORAGE_BALANCE.forage_speed).is_equal(55.0)
	assert_float(FORAGE_BALANCE.eat_range).is_equal(24.0)
	assert_float(FORAGE_BALANCE.eat_duration_seconds).is_equal(2.5)


func test_every_sleepwalker_scene_wires_the_forage_balance() -> void:
	# A scene that misses the forage balance stands its walker out of the
	# rule silently, so every enemy scene must carry it.
	for scene_path: String in ENEMY_SCENES:
		var scene: PackedScene = load(scene_path)
		var walker := scene.instantiate() as Sleepwalker
		auto_free(walker)
		(
			assert_object(walker.forage_balance)
			. override_failure_message("%s has no forage_balance" % scene_path)
			. is_equal(FORAGE_BALANCE)
		)


func test_the_plant_scene_carries_the_same_balance() -> void:
	var scene: PackedScene = load("res://scenes/components/coffee_plant.tscn")
	var plant := scene.instantiate() as CoffeePlant
	auto_free(plant)
	assert_object(plant.balance).is_equal(FORAGE_BALANCE)
